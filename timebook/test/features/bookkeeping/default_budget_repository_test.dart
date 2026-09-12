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

  test('保存/读取默认预算往返（含分类，catCents 键为 categoryId 字符串）', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');

    expect((await repo.loadDefaultBudget()) == null, isTrue);

    await repo.saveDefaultBudget(
        totalCents: 1000000, catCents: {food: 200000});
    final d = await repo.loadDefaultBudget();
    expect(d != null, isTrue);
    expect(d!.totalCents, 1000000);
    expect(d.catCents, {food: 200000});
  });

  test('budgetProgress：无库预算但有默认 → 回退默认（不写库）', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final now = DateTime.now();
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(now.year, now.month, 12));
    await repo.saveDefaultBudget(
        totalCents: 1000000, catCents: {food: 200000});

    final p = await repo.budgetProgress(
        ledgerId: l, month: monthKey(now));
    expect(p.usingDefault, isTrue);
    expect(p.totalBudgetCents, 1000000);
    expect(p.totalSpentCents, 2850);
    final foodLine = p.lines.singleWhere((x) => x.categoryId == food);
    expect(foodLine.amountCents, 200000); // 默认分类预算额度
    expect(foodLine.spentCents, 2850);

    // 回退不写库：本月预算库仍为空
    expect(await repo.budgetsForMonth(ledgerId: l, month: monthKey(now)),
        isEmpty);
  });

  test('budgetProgress：写入库记录后默认不再生效（单月覆盖优先）', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final now = DateTime.now();
    final month = monthKey(now);
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(now.year, now.month, 12));
    await repo.saveDefaultBudget(
        totalCents: 1000000, catCents: {food: 200000});

    // 单月覆盖：写入本月总预算与分类预算
    await repo.upsertBudget(ledgerId: l, month: month, amountCents: 500000);
    await repo.upsertBudget(
        ledgerId: l, categoryId: food, month: month, amountCents: 100000);

    final p = await repo.budgetProgress(ledgerId: l, month: month);
    expect(p.usingDefault, isFalse);
    expect(p.totalBudgetCents, 500000); // 以库为准
    final foodLine = p.lines.singleWhere((x) => x.categoryId == food);
    expect(foodLine.amountCents, 100000);
  });

  test('周期起始日保存/读取往返（默认 1）', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    expect(await repo.periodStartDay(), 1);
    await repo.setPeriodStartDay(22);
    expect(await repo.periodStartDay(), 22);
  });

  test('monthlySummary/categorySpending 支持期边界（默认自然月兼容）', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 100, bookAt: DateTime(2026, 9, 25)); // 期内
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 200, bookAt: DateTime(2026, 10, 20)); // 期内
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 50, bookAt: DateTime(2026, 9, 12)); // 期外

    final start = DateTime(2026, 9, 22);
    final end = DateTime(2026, 10, 21, 23, 59, 59, 999);
    final s = await repo.monthlySummary(ledgerId: l, month: '2026-09',
        periodStart: start, periodEnd: end);
    expect(s.expenseCents, 300); // 仅期内
    final cat = await repo.categorySpending(l, '2026-09',
        periodStart: start, periodEnd: end);
    expect(cat.single.amountCents, 300);

    // 不带期边界 = 自然月
    final nat = await repo.monthlySummary(ledgerId: l, month: '2026-09');
    expect(nat.expenseCents, 150);
  });

  test('budgetProgress 支持期边界聚合', () async {
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    await repo.upsertBudget(ledgerId: l, month: '2026-09', amountCents: 100000);
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 10000, bookAt: DateTime(2026, 9, 25)); // 期内
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 60000, bookAt: DateTime(2026, 9, 10)); // 期外

    final p = await repo.budgetProgress(ledgerId: l, month: '2026-09',
        periodStart: DateTime(2026, 9, 22),
        periodEnd: DateTime(2026, 10, 21, 23, 59, 59, 999));
    expect(p.totalBudgetCents, 100000);
    expect(p.totalSpentCents, 10000); // 仅期内
  });
}