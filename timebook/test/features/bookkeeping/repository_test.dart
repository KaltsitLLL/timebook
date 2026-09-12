import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
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
    expect(cats.single.name, '餐饮');
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
}