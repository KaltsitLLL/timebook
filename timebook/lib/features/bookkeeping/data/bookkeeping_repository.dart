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