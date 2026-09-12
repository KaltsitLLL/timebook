import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../../../core/util/formats.dart';

class BookkeepingRepository {
  BookkeepingRepository(this.db);
  final AppDatabase db;

  // ---- 账本 ----
  Future<int> createLedger({required String name, String currency = 'CNY'}) {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: name, currency: Value(currency)));
  }

  Future<List<Ledger>> ledgers() => db.select(db.ledgers).get();

  // ---- 账户 ----
  Future<int> createAccount(
      {required int ledgerId, required String name}) {
    return db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: ledgerId, name: name));
  }

  Future<List<Account>> accounts(int ledgerId) => (db.select(db.accounts)
        ..where((t) => t.ledgerId.equals(ledgerId)))
      .get();

  // ---- 分类 ----
  Future<int> createCategory({required int ledgerId, required String name}) {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
        ledgerId: ledgerId, name: name));
  }

  Future<List<Category>> categories(int ledgerId) =>
      (db.select(db.categories)..where((t) => t.ledgerId.equals(ledgerId)))
          .get();

  Future<int> addTransaction({
    required int ledgerId,
    required int accountId,
    int? categoryId,
    required String direction, // income / expense / transfer
    required int amountCents,
    required DateTime bookAt,
    String counterparty = '',
    String remark = '',
    String payMethod = '',
    String? orderId,
    String? importKey,
    bool isPending = false,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
      ledgerId: ledgerId,
      accountId: accountId,
      categoryId: Value(categoryId),
      direction: direction,
      amountCents: amountCents,
      bookAt: bookAt,
      counterparty: Value(counterparty),
      remark: Value(remark),
      payMethod: Value(payMethod),
      orderId: Value(orderId),
      importKey: Value(importKey),
      isPending: Value(isPending),
    ));
  }

  Future<void> updateRefundedCents(
      {required int transactionId, required int refundedCents}) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(transactionId)))
        .write(TransactionsCompanion(refundedCents: Value(refundedCents)));
  }

  Future<MonthlySummary> monthlySummary(
      {required int ledgerId, required String month}) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.bookAt.isBetweenValues(start, end)))
        .get();
    int inc = 0, exp = 0;
    for (final r in rows) {
      if (r.direction == 'income') inc += r.amountCents;
      if (r.direction == 'expense') {
        exp += r.amountCents - r.refundedCents; // 净额：退款冲抵
      }
    }
    return MonthlySummary(incomeCents: inc, expenseCents: exp);
  }

  Future<List<CategorySpend>> categorySpending(
      int ledgerId, String month) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.direction.equals('expense') &
              t.bookAt.isBetweenValues(start, end)))
        .get();
    final map = <int?, int>{};
    for (final r in rows) {
      map[r.categoryId] =
          (map[r.categoryId] ?? 0) + (r.amountCents - r.refundedCents);
    }
    return [
      for (final e in map.entries) CategorySpend(categoryId: e.key, amountCents: e.value)
    ];
  }

  Future<List<Transaction>> recentTransactions(
      {required int ledgerId, int limit = 20}) {
    return (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([(t) => OrderingTerm.desc(t.bookAt), (t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
  }

  Future<List<MonthTotal>> monthlyTrend(
      {required int ledgerId, int months = 6}) async {
    final now = DateTime.now();
    final result = <MonthTotal>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = monthKey(m);
      final s = await monthlySummary(ledgerId: ledgerId, month: key);
      result.add(
          MonthTotal(month: key, incomeCents: s.incomeCents, expenseCents: s.expenseCents));
    }
    return result;
  }

  Future<List<Transaction>> transactionsInMonth(
      {required int ledgerId, required String month}) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1, 1);
    return (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.bookAt.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.bookAt), (t) => OrderingTerm.desc(t.id)]))
        .get();
  }

  // ---- 预算 ----
  Future<void> upsertBudget(
      {required int ledgerId,
      int? categoryId,
      required String month,
      required int amountCents}) async {
    await db.transaction(() async {
      final query = db.select(db.budgets)
        ..where((t) =>
            t.ledgerId.equals(ledgerId) &
            t.month.equals(month) &
            (categoryId == null
                ? t.categoryId.isNull()
                : t.categoryId.equals(categoryId)));
      final existing = await query.get();
      if (existing.isEmpty) {
        await db.into(db.budgets).insert(BudgetsCompanion.insert(
            ledgerId: ledgerId,
            categoryId: Value(categoryId),
            month: month,
            amountCents: amountCents));
      } else {
        await (db.update(db.budgets)..where((t) => t.id.equals(existing.first.id)))
            .write(BudgetsCompanion(amountCents: Value(amountCents)));
      }
    });
  }

  Future<List<Budget>> budgetsForMonth(
          {required int ledgerId, required String month}) =>
      (db.select(db.budgets)
            ..where((t) =>
                t.ledgerId.equals(ledgerId) & t.month.equals(month)))
          .get();

  Future<void> removeBudget(
      {required int ledgerId, int? categoryId, required String month}) async {
    await (db.delete(db.budgets)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.month.equals(month) &
              (categoryId == null
                  ? t.categoryId.isNull()
                  : t.categoryId.equals(categoryId))))
        .go();
  }

  Future<BudgetProgress> budgetProgress(
      {required int ledgerId, required String month}) async {
    final budgets = await budgetsForMonth(ledgerId: ledgerId, month: month);
    final catNames = <int, String>{
      for (final c in await categories(ledgerId)) c.id: c.name
    };
    final spends = await categorySpending(ledgerId, month);
    final spendByCat = <int?, int>{
      for (final s in spends) s.categoryId: s.amountCents
    };
    final summary = await monthlySummary(ledgerId: ledgerId, month: month);

    final totalBudget = budgets
        .where((b) => b.categoryId == null)
        .fold<int>(0, (s, b) => s + b.amountCents);
    final totalSpent = summary.expenseCents;

    final budgetedCatIds = <int>{
      for (final b in budgets)
        if (b.categoryId != null) b.categoryId!,
    };
    final lines = <BudgetLine>[
      for (final b in budgets.where((b) => b.categoryId != null))
        BudgetLine(
          categoryId: b.categoryId,
          categoryName: catNames[b.categoryId!] ?? '分类#${b.categoryId}',
          amountCents: b.amountCents,
          spentCents: spendByCat[b.categoryId] ?? 0,
        ),
      // 无预算但有支出的分类也展示（amountCents=0 → 不参与超支判定）
      for (final e in spendByCat.entries)
        if (e.key != null && !budgetedCatIds.contains(e.key!))
          BudgetLine(
            categoryId: e.key,
            categoryName: catNames[e.key!] ?? '分类#${e.key}',
            amountCents: 0,
            spentCents: e.value,
          ),
    ];

    final remaining =
        totalBudget > totalSpent ? totalBudget - totalSpent : 0;
    final today = DateTime.now();
    final daysLeft =
        DateTime(today.year, today.month + 1, 0).day - today.day + 1;
    return BudgetProgress(
      totalBudgetCents: totalBudget,
      totalSpentCents: totalSpent,
      lines: lines,
      remainingPerDayCents: daysLeft <= 0 ? 0 : remaining ~/ daysLeft,
    );
  }
}

class BudgetLine {
  const BudgetLine(
      {this.categoryId,
      required this.categoryName,
      required this.amountCents,
      required this.spentCents});
  final int? categoryId;
  final String categoryName;
  final int amountCents; // 预算额
  final int spentCents; // 该类目净额支出
  double get pct => amountCents == 0 ? 0 : spentCents * 100 / amountCents;
  bool get isOverBudget => amountCents > 0 && spentCents > amountCents;
}

class BudgetProgress {
  const BudgetProgress(
      {required this.totalBudgetCents,
      required this.totalSpentCents,
      required this.lines,
      required this.remainingPerDayCents});
  final int totalBudgetCents;
  final int totalSpentCents;
  final List<BudgetLine> lines;
  final int remainingPerDayCents;
  double get totalPct =>
      totalBudgetCents == 0 ? 0 : totalSpentCents * 100 / totalBudgetCents;
}

class MonthlySummary {
  const MonthlySummary({required this.incomeCents, required this.expenseCents});
  final int incomeCents;
  final int expenseCents;
}

class CategorySpend {
  const CategorySpend({this.categoryId, required this.amountCents});
  final int? categoryId;
  final int amountCents;
}

class MonthTotal {
  const MonthTotal(
      {required this.month, required this.incomeCents, required this.expenseCents});
  final String month; // 'yyyy-MM'
  final int incomeCents;
  final int expenseCents;
}