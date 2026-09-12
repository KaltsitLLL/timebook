import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/core/util/formats.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase(inMemoryExecutor());
  });

  tearDown(() async => db.close());

  test('schema v1 可打开且各表可查询', () async {
    await db.transaction(() async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本', currency: const Value('CNY')));
      await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(ledgerId: 1, name: '储蓄卡'));
      await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(ledgerId: 1, name: '餐饮'));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          accountId: 1,
          categoryId: const Value(1),
          direction: 'expense',
          amountCents: 2850,
          bookAt: DateTime(2026, 9, 12)));
    });
    final cnt = await db.transactions.count().getSingle();
    expect(cnt, 1);
  });

  test('创建账本/账户/分类后可读回', () async {
    final repo = BookkeepingRepository(db);
    final ledgerId = await repo.createLedger(name: '生活');
    await repo.createAccount(ledgerId: ledgerId, name: '招行储蓄卡');
    final foodId = await repo.createCategory(ledgerId: ledgerId, name: '餐饮');

    final ledgers = await repo.ledgers();
    final accounts = await repo.accounts(ledgerId);
    final cats = await repo.categories(ledgerId);

    expect(ledgers.single.name, '生活');
    expect(accounts.single.name, '招行储蓄卡');
    expect(cats.map((c) => c.name), contains('餐饮')); // 默认分类已预置
    expect(foodId, greaterThan(0));
  });

  test('记账以分存储，月度摘要/分类聚合/最近流水正确', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final trans = await repo.createCategory(ledgerId: l, name: '交通');

    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(2026, 9, 12), counterparty: '美团');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: trans, direction: 'expense',
        amountCents: 400, bookAt: DateTime(2026, 9, 12));
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: null, direction: 'income',
        amountCents: 850000, bookAt: DateTime(2026, 9, 10), counterparty: '工资');

    final summary = await repo.monthlySummary(ledgerId: l, month: '2026-09');
    expect(summary.incomeCents, 850000);
    expect(summary.expenseCents, 3250);

    final byCat = await repo.categorySpending(l, '2026-09');
    expect(byCat.singleWhere((e) => e.categoryId == food).amountCents, 2850);

    final recent = await repo.recentTransactions(ledgerId: l, limit: 10);
    expect(recent, hasLength(3));
    expect(recent.first.amountCents, 400); // bookAt 倒序
  });

  test('重复 importKey 触发唯一约束（去重指纹）', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    Future<int> ins(String key) => repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'expense', amountCents: 100,
        bookAt: DateTime(2026, 9, 1), importKey: key);

    await ins('WX-20260901-1'); // 首次 OK
    expect(() => ins('WX-20260901-1'), throwsA(anything));
  });

  test('退款冲抵：按净额统计且原行保留，不新增收入行', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final tid = await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 5000, bookAt: DateTime(2026, 9, 12), counterparty: '某店');

    await repo.updateRefundedCents(transactionId: tid, refundedCents: 5000);

    final s = await repo.monthlySummary(ledgerId: l, month: '2026-09');
    expect(s.expenseCents, 0); // 全额退款 → 净支出 0

    final all = await repo.recentTransactions(ledgerId: l, limit: 10);
    expect(all, hasLength(1)); // 原行保留、无新增行
    expect(all.single.refundedCents, 5000);
  });

  test('monthlyTrend 返回 6 个月净额（含空月补零、退款冲抵）', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');

    final now = DateTime.now();
    final cur = DateTime(now.year, now.month, 12);
    final last = DateTime(now.year, now.month - 1, 10);

    final tid = await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 500000, bookAt: cur, counterparty: '房租');
    await repo.updateRefundedCents(transactionId: tid, refundedCents: 200000);
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'income', amountCents: 850000,
        bookAt: cur, counterparty: '工资');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 120000, bookAt: last, counterparty: '上月购物');

    final trend = await repo.monthlyTrend(ledgerId: l);
    expect(trend, hasLength(6));
    final curMonth = trend.last;
    expect(curMonth.month, monthKey(now));
    expect(curMonth.expenseCents, 300000); // 500000-200000
    expect(curMonth.incomeCents, 850000);
    final lastMonth = trend[trend.length - 2];
    expect(lastMonth.expenseCents, 120000);
    // 更早月份为空 → 0
    expect(trend.first.expenseCents, 0);
    expect(trend.first.incomeCents, 0);
  });

  test('transactionsInMonth 按 yyyy-MM 过滤', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final now = DateTime.now();
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'expense', amountCents: 100,
        bookAt: now, counterparty: '本月');
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'expense', amountCents: 200,
        bookAt: DateTime(now.year, now.month - 1, 10), counterparty: '上月');

    final thisMonth = await repo.transactionsInMonth(
        ledgerId: l, month: monthKey(now));
    expect(thisMonth, hasLength(1));
    expect(thisMonth.single.counterparty, '本月');
  });

  test('预算 upsert：总预算与分类预算并存、再写覆盖', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final month = monthKey(DateTime.now());

    await repo.upsertBudget(ledgerId: l, month: month, amountCents: 750000);
    await repo.upsertBudget(
        ledgerId: l, categoryId: food, month: month, amountCents: 200000);

    final all = await repo.budgetsForMonth(ledgerId: l, month: month);
    expect(all, hasLength(2));

    await repo.upsertBudget(ledgerId: l, month: month, amountCents: 800000);
    final after = await repo.budgetsForMonth(ledgerId: l, month: month);
    final total = after.singleWhere((b) => b.categoryId == null);
    expect(total.amountCents, 800000);
  });

  test('删除分类预算', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final month = monthKey(DateTime.now());
    await repo.upsertBudget(
        ledgerId: l, categoryId: food, month: month, amountCents: 100000);
    await repo.removeBudget(ledgerId: l, categoryId: food, month: month);
    final all = await repo.budgetsForMonth(ledgerId: l, month: month);
    expect(all, isEmpty);
  });

  test('exportCsv 导出表头与纯文本流水行', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(2026, 9, 12), counterparty: '美团',
        remark: '点餐', payMethod: '零钱', orderId: 'WX-1');

    final csv = await repo.exportCsv(ledgerId: l);
    expect(csv.split('\n').first,
        'book_at,direction,amount_cents,refunded_cents,counterparty,remark,category,pay_method,order_id');
    expect(csv, contains('expense,2850'));
    expect(csv, contains('美团'));
  });

  test('exportCsv 含逗号字段以双引号包裹', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'expense', amountCents: 1000,
        bookAt: DateTime(2026, 9, 12), counterparty: '店,一家');

    final csv = await repo.exportCsv(ledgerId: l);
    expect(csv, contains('"店,一家"'));
  });

  test('upsertRule/rules/deleteRule 规则 CRUD', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');

    final id1 = await repo.upsertRule(keyword: '美团', categoryId: food, priority: 1);
    await repo.upsertRule(keyword: '滴滴', categoryId: food, priority: 2);

    final all = await repo.rules();
    expect(all, hasLength(2));

    // 同关键词 upsert 覆盖而非新增
    await repo.upsertRule(keyword: '滴滴', categoryId: food, priority: 9);
    expect(await repo.rules(), hasLength(2));
    expect((await repo.rules()).singleWhere((r) => r.id == id1).id, id1);
    expect((await repo.rules()).singleWhere((r) => r.keyword == '滴滴').priority, 9);

    await repo.deleteRule(id1);
    expect(await repo.rules(), hasLength(1));
  });

  test('addTransaction applyRules：categoryId 为 null 时按规则自动分类', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    await repo.upsertRule(keyword: '美团', categoryId: food, priority: 1);

    final id = await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'expense', amountCents: 2850,
        bookAt: DateTime(2026, 9, 12), counterparty: '美团外卖', applyRules: true);

    final t = await (db.select(db.transactions)..where((x) => x.id.equals(id))).getSingle();
    expect(t.categoryId, food);
  });

  test('addTransaction applyRules：已有显式 categoryId 不被覆盖', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final trans = await repo.createCategory(ledgerId: l, name: '交通');
    await repo.upsertRule(keyword: '美团', categoryId: trans, priority: 1);

    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(2026, 9, 12), counterparty: '美团',
        applyRules: true);
    // 显式分类优先，规则不覆盖
    expect((await repo.recentTransactions(ledgerId: l)).single.categoryId, food);
  });

  test('budgetProgress：总分类净额进度与剩余日均、超支标记', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final trans = await repo.createCategory(ledgerId: l, name: '交通');
    final now = DateTime.now();
    final month = monthKey(now);

    await repo.upsertBudget(ledgerId: l, month: month, amountCents: 1000000);
    await repo.upsertBudget(
        ledgerId: l, categoryId: food, month: month, amountCents: 300000);
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 150000, bookAt: DateTime(now.year, now.month, 12));
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: trans, direction: 'expense',
        amountCents: 120000, bookAt: DateTime(now.year, now.month, 12));

    final p = await repo.budgetProgress(ledgerId: l, month: month);
    expect(p.totalBudgetCents, 1000000);
    expect(p.totalSpentCents, 270000);
    expect(p.totalPct, closeTo(27.0, 0.05));
    expect(p.remainingDailyCents,
        greaterThanOrEqualTo(24000)); // (1000000-270000)/当月剩余天数
    final foodLine = p.lines.singleWhere((x) => x.categoryId == food);
    expect(foodLine.spentCents, 150000);
    expect(foodLine.pct, closeTo(50.0, 0.05));
    final transLine = p.lines.singleWhere((x) => x.categoryId == trans);
    expect(transLine.spentCents, 120000);
    expect(transLine.isOverBudget, isFalse); // 未设分类预算 → 不参与超支判定
  });

  test('budgetProgress：85% 阈值触发 nearLimit（>=100% 不触发）', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final now = DateTime.now();
    final month = monthKey(now);
    await repo.upsertBudget(ledgerId: l, month: month, amountCents: 100000);
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'expense',
        amountCents: 90000, bookAt: now); // 90% → 预警

    final p = await repo.budgetProgress(ledgerId: l, month: month);
    expect(p.nearLimit, isTrue);

    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'expense',
        amountCents: 20000, bookAt: now); // 110% → 超支
    final over = await repo.budgetProgress(ledgerId: l, month: month);
    expect(over.nearLimit, isFalse);
  });

  test('budgetProgress：过去期 remainingDailyCents 为 0', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    await repo.upsertBudget(ledgerId: l, month: '2020-01', amountCents: 100000);
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'expense',
        amountCents: 20000, bookAt: DateTime(2020, 1, 5));

    final p = await repo.budgetProgress(ledgerId: l, month: '2020-01',
        periodStart: DateTime(2020, 1, 1),
        periodEnd: DateTime(2020, 1, 31, 23, 59, 59, 999));
    expect(p.remainingDailyCents, 0);
  });

  test('addTransaction 开启 applyRules 时从未分类自动推断分类', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    await repo.upsertRule(keyword: '美团', categoryId: food, priority: 1);

    final tid = await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'expense', amountCents: 2850,
        bookAt: DateTime(2026, 9, 12), counterparty: '美团外卖', applyRules: true);
    final t = await (db.select(db.transactions)..where((x) => x.id.equals(tid))).getSingle();
    expect(t.categoryId, food);
  });

  test('upsertRule/rules/deleteRule 完整 CRUD', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');

    await repo.upsertRule(keyword: '美团', categoryId: food, priority: 1);
    await repo.upsertRule(keyword: '滴滴', categoryId: food, priority: 2);
    expect(await repo.rules(), hasLength(2));

    // 同关键词 upsert 覆盖而非新增
    final id = await repo.upsertRule(keyword: '美团', categoryId: food, priority: 5);
    expect(await repo.rules(), hasLength(2));
    expect((await repo.rules()).singleWhere((r) => r.id == id).priority, 5);

    await repo.deleteRule(id);
    expect(await repo.rules(), hasLength(1));
  });

  test('默认付款账户保存后读取一致（内存 KV）', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a1 = await repo.createAccount(ledgerId: l, name: '卡');
    final a2 = await repo.createAccount(ledgerId: l, name: '钱包');

    expect((await repo.getDefaultAccountId(l)) == null, isTrue);
    await repo.saveDefaultAccountId(l, a2);
    expect(await repo.getDefaultAccountId(l), a2);
    // 校验存在：账户不存在时回落 null
    await repo.saveDefaultAccountId(l, 9999);
    expect((await repo.getDefaultAccountId(l)) == null, isTrue);
    await repo.saveDefaultAccountId(l, a1);
    expect(await repo.getDefaultAccountId(l), a1);
  });

  test('bulkUpdateCategory：批量修改/清除分类后读回正确', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final trans = await repo.createCategory(ledgerId: l, name: '交通');
    final ids = <int>[];
    for (var i = 0; i < 2; i++) {
      ids.add(await repo.addTransaction(
          ledgerId: l, accountId: a, direction: 'expense', amountCents: 1000,
          bookAt: DateTime(2026, 9, i + 1), counterparty: '行$i'));
    }

    await repo.bulkUpdateCategory(ids: ids, categoryId: trans);
    for (final t in await repo.recentTransactions(ledgerId: l)) {
      expect(t.categoryId, trans);
    }

    await repo.bulkUpdateCategory(ids: ids, categoryId: null);
    for (final t in await repo.recentTransactions(ledgerId: l)) {
      expect(t.categoryId, equals(null));
    }
  });

  test('bulkDelete：批量删除后计数正确', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final ids = <int>[];
    for (var i = 0; i < 3; i++) {
      ids.add(await repo.addTransaction(
          ledgerId: l, accountId: a, direction: 'expense', amountCents: 1000,
          bookAt: DateTime(2026, 9, i + 1)));
    }
    expect(await repo.recentTransactions(ledgerId: l), hasLength(3));

    await repo.bulkDelete(ids.sublist(0, 2));
    final left = await repo.recentTransactions(ledgerId: l);
    expect(left, hasLength(1));
    expect(left.single.id, ids[2]);
  });

  test('ensureNoneAccount 幂等：连调两次返回同一『不记账户』 id', () async {
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final id1 = await repo.ensureNoneAccount(l);
    final id2 = await repo.ensureNoneAccount(l);
    expect(id1, id2);
    final acct = await (db.select(db.accounts)..where((a) => a.id.equals(id1)))
        .getSingle();
    expect(acct.name, '不记账户');
    expect(acct.type, 'none');
  });

  test('createLedger 自动预置 8 个默认分类且幂等同 session', () async {
    final repo = BookkeepingRepository(db);

    final l1 = await repo.createLedger(name: '生活');
    final cats1 = await repo.categories(l1);
    expect(cats1, hasLength(8));
    expect(cats1.map((c) => c.name),
        containsAll(['餐饮', '交通', '购物', '娱乐', '居住', '医疗', '工资', '其他']));
    expect(cats1.map((c) => c.icon),
        containsAll(['restaurant', 'directions_bus', 'shopping_bag', 'movie',
                     'home', 'medical_services', 'payments', 'more_horiz']));

    // 幂等：再建账本各自预置 8 个（不重复、不泄漏跨账本）
    final l2 = await repo.createLedger(name: '生意');
    expect(await repo.categories(l2), hasLength(8));
    expect(await repo.categories(l1), hasLength(8));
  });
}