import 'dart:convert';

import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../../../core/util/formats.dart';
import '../../../core/util/kv_settings.dart';
import '../../ai/data/ai_settings_service.dart';
import '../../ai/presentation/ai_settings_screen.dart';
import 'rule_classifier.dart';

class BookkeepingRepository {
  BookkeepingRepository(this.db, {KeyValueStorage? storage})
      : settings = KvSettings(storage ?? const SecureStorage());
  final AppDatabase db;
  final KvSettings settings;

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

  // ---- 默认账户（kv 存储 + 校验存在） ----
  static const _defaultAccountKey = 'defaultAccountId:';

  Future<int?> getDefaultAccountId(int ledgerId) async {
    final id = await settings.getInt('$_defaultAccountKey$ledgerId');
    if (id == null) return null;
    final exists = await (db.select(db.accounts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return exists == null ? null : id;
  }

  Future<void> saveDefaultAccountId(int ledgerId, int accountId) =>
      settings.setInt('$_defaultAccountKey$ledgerId', accountId);

  /// 确保存在名为「不记账户」的系统账户（type 'none'）并返回其 id（幂等）。
  Future<int> ensureNoneAccount(int ledgerId) async {
    final existing = await (db.select(db.accounts)
          ..where((t) => t.ledgerId.equals(ledgerId) & t.name.equals('不记账户')))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: ledgerId, name: '不记账户', type: const Value('none')));
  }

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
    bool applyRules = false,
  }) async {
    var catId = categoryId;
    // 未显式指定分类且开启自动分类时，按规则引擎从「对方+备注」推断。
    if (applyRules && catId == null) {
      final ruleRows = await rules();
      catId = RuleClassifier.classify(
        text: '$counterparty$remark',
        rules: [
          for (final r in ruleRows) (r.keyword, r.categoryId, r.priority),
        ],
      );
    }
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
      ledgerId: ledgerId,
      accountId: accountId,
      categoryId: Value(catId),
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

  // ---- 分类规则 ----
  Future<int> upsertRule({
    required String keyword,
    required int categoryId,
    required int priority,
  }) async {
    final existing = await (db.select(db.importRules)
          ..where((r) => r.keyword.equals(keyword)))
        .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.importRules)..where((r) => r.id.equals(existing.id)))
          .write(ImportRulesCompanion(
              categoryId: Value(categoryId), priority: Value(priority)));
      return existing.id;
    }
    return db.into(db.importRules).insert(ImportRulesCompanion.insert(
        keyword: keyword, categoryId: categoryId, priority: Value(priority)));
  }

  Future<List<ImportRule>> rules() => db.select(db.importRules).get();

  Future<void> deleteRule(int id) async {
    await (db.delete(db.importRules)..where((r) => r.id.equals(id))).go();
  }

  Future<void> updateRefundedCents(
      {required int transactionId, required int refundedCents}) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(transactionId)))
        .write(TransactionsCompanion(refundedCents: Value(refundedCents)));
  }

  Future<MonthlySummary> monthlySummary(
      {required int ledgerId,
      required String month,
      DateTime? periodStart,
      DateTime? periodEnd}) async {
    final start = periodStart ?? DateTime.parse('$month-01');
    final end = periodEnd ?? DateTime(start.year, start.month + 1, 1);
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

  Future<List<CategorySpend>> categorySpending(int ledgerId, String month,
      {DateTime? periodStart, DateTime? periodEnd}) async {
    final start = periodStart ?? DateTime.parse('$month-01');
    final end = periodEnd ?? DateTime(start.year, start.month + 1, 1);
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

  // ---- 批量操作 ----
  /// 批量修改多笔流水的分类（categoryId 为 null 表示清除分类）。
  Future<void> bulkUpdateCategory(
      {required List<int> ids, required int? categoryId}) async {
    await (db.update(db.transactions)..where((t) => t.id.isIn(ids)))
        .write(TransactionsCompanion(categoryId: Value(categoryId)));
  }

  /// 批量删除多笔流水。
  Future<void> bulkDelete(List<int> ids) async {
    await (db.delete(db.transactions)..where((t) => t.id.isIn(ids))).go();
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

  // ---- 导出 ----
  /// 全量流水按 bookAt 升序导出为 CSV（含表头）。字段含逗号/引号/换行时会以双引号包裹并转义。
  Future<String> exportCsv({required int ledgerId}) async {
    final rows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([(t) => OrderingTerm.asc(t.bookAt), (t) => OrderingTerm.asc(t.id)]))
        .get();
    final catNames = <int?, String>{
      for (final c in await categories(ledgerId)) c.id: c.name
    };
    String field(String s) => (s.contains(',') || s.contains('"') || s.contains('\n'))
        ? '"${s.replaceAll('"', '""')}"'
        : s;
    final lines = <String>[
      'book_at,direction,amount_cents,refunded_cents,counterparty,remark,category,pay_method,order_id',
      for (final r in rows)
        [
          _formatCsvDateTime(r.bookAt),
          r.direction,
          r.amountCents.toString(),
          r.refundedCents.toString(),
          r.counterparty,
          r.remark,
          catNames[r.categoryId] ?? '',
          r.payMethod,
          r.orderId ?? '',
        ].map((e) => field(e)).join(','),
    ];
    return lines.join('\n');
  }

  String _formatCsvDateTime(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:'
      '${d.second.toString().padLeft(2, '0')}';

  // ---- 默认预算（kv 存储；某月无记录时回退用，仅展示/计算不写库） ----
  static const _defaultBudgetKey = 'defaultBudget';
  static const _periodStartKey = 'budgetPeriodStartDay';

  /// 保存默认预算（catCents 键为 categoryId，json 存 kv）。
  Future<void> saveDefaultBudget(
      {required int totalCents, required Map<int, int> catCents}) async {
    final map = {
      'totalCents': totalCents,
      'catCents': {
        for (final e in catCents.entries) '${e.key}': e.value,
      },
    };
    await settings.setString(_defaultBudgetKey, jsonEncode(map));
  }

  /// 读取默认预算；未设置或解析失败返回 null。
  Future<({int totalCents, Map<int, int> catCents})?> loadDefaultBudget() async {
    final raw = await settings.getString(_defaultBudgetKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final total = map['totalCents'];
      final cats = map['catCents'];
      if (total is! int || cats is! Map) return null;
      return (
        totalCents: total,
        catCents: {
          for (final e in cats.entries)
            if (e.key is String)
              int.parse(e.key as String): (e.value as num).toInt(),
        },
      );
    } catch (_) {
      return null;
    }
  }

  /// 预算期起始日（1-28，默认 1 = 自然月）。
  Future<int> periodStartDay() async =>
      await settings.getInt(_periodStartKey) ?? 1;

  Future<void> setPeriodStartDay(int day) =>
      settings.setInt(_periodStartKey, day);

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
      {required int ledgerId,
      required String month,
      DateTime? periodStart,
      DateTime? periodEnd}) async {
    final budgets = await budgetsForMonth(ledgerId: ledgerId, month: month);
    final catNames = <int, String>{
      for (final c in await categories(ledgerId)) c.id: c.name
    };
    final spends = await categorySpending(ledgerId, month,
        periodStart: periodStart, periodEnd: periodEnd);
    final spendByCat = <int?, int>{
      for (final s in spends) s.categoryId: s.amountCents
    };
    final summary = await monthlySummary(ledgerId: ledgerId, month: month,
        periodStart: periodStart, periodEnd: periodEnd);

    // 某月无预算记录时回退到默认预算（仅展示/计算，不写库）；有记录以库为准（单月覆盖）。
    final defaultBud = await loadDefaultBudget();
    final usingDefault = budgets.isEmpty && defaultBud != null;

    final totalBudget = usingDefault
        ? defaultBud.totalCents
        : budgets
            .where((b) => b.categoryId == null)
            .fold<int>(0, (s, b) => s + b.amountCents);
    final totalSpent = summary.expenseCents;

    final budgetedCatIds = <int>{
      for (final b in budgets)
        if (b.categoryId != null) b.categoryId!,
      if (usingDefault) ...defaultBud.catCents.keys,
    };
    final lines = <BudgetLine>[
      for (final b in budgets.where((b) => b.categoryId != null))
        BudgetLine(
          categoryId: b.categoryId,
          categoryName: catNames[b.categoryId!] ?? '分类#${b.categoryId}',
          amountCents: b.amountCents,
          spentCents: spendByCat[b.categoryId] ?? 0,
        ),
      // 默认预算的分类行（未写库时按默认额展示）
      if (usingDefault)
        for (final e in defaultBud.catCents.entries)
          BudgetLine(
            categoryId: e.key,
            categoryName: catNames[e.key] ?? '分类#${e.key}',
            amountCents: e.value,
            spentCents: spendByCat[e.key] ?? 0,
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
    final daysLeft = periodEnd != null
        ? periodEnd.difference(today).inDays + 1
        : DateTime(today.year, today.month + 1, 0).day - today.day + 1;
    return BudgetProgress(
      totalBudgetCents: totalBudget,
      totalSpentCents: totalSpent,
      lines: lines,
      remainingPerDayCents: daysLeft <= 0 ? 0 : remaining ~/ daysLeft,
      usingDefault: usingDefault,
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
      required this.remainingPerDayCents,
      this.usingDefault = false});
  final int totalBudgetCents;
  final int totalSpentCents;
  final List<BudgetLine> lines;
  final int remainingPerDayCents;
  final bool usingDefault; // 是否回退用了默认预算（本月无预算记录）
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