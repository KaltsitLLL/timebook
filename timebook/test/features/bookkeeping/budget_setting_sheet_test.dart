import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/core/util/formats.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/budget_setting_sheet.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  testWidgets('设置总预算与分类预算后落库', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final food = (await repo.categories(l)).singleWhere((c) => c.name == '餐饮').id;
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: BudgetSettingSheet()))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('total_budget_field')), '7500');
    await tester.enterText(find.byKey(const Key('food_budget_field')), '200');
    await tester.tap(find.byKey(const Key('save_budget_button')));
    await tester.pumpAndSettle();

    final month = monthKey(DateTime.now());
    final all = await repo.budgetsForMonth(ledgerId: l, month: month);
    expect(all, hasLength(2));
    final total = all.singleWhere((b) => b.categoryId == null);
    expect(total.amountCents, 750000);
    final foodB = all.singleWhere((b) => b.categoryId == food);
    expect(foodB.amountCents, 20000);
  });

  testWidgets('设为默认：按当前字段值保存默认预算并提示', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final food = (await repo.categories(l)).singleWhere((c) => c.name == '餐饮').id;
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: BudgetSettingSheet()))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('total_budget_field')), '7500');
    await tester.enterText(find.byKey(const Key('food_budget_field')), '200');
    await tester.tap(find.byKey(const Key('set_default_budget')));
    await tester.pumpAndSettle();

    final d = await repo.loadDefaultBudget();
    expect(d, isNotNull);
    expect(d!.totalCents, 750000);
    expect(d.catCents, {food: 20000});
    expect(find.text('已设为默认预算'), findsOneWidget);
  });

  testWidgets('沿用上月：上月预算 copy 到本月', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final nowMonth = monthKey(DateTime.now());
    final lastMonth = prevMonthKey(nowMonth);
    await repo.upsertBudget(ledgerId: l, month: lastMonth, amountCents: 60000);
    await repo.upsertBudget(
        ledgerId: l, categoryId: food, month: lastMonth, amountCents: 12000);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: BudgetSettingSheet()))));
    await tester.pumpAndSettle();

    expect(await repo.budgetsForMonth(ledgerId: l, month: nowMonth), isEmpty);
    await tester.tap(find.byKey(const Key('inherit_last_month')));
    await tester.pumpAndSettle();

    final cur = await repo.budgetsForMonth(ledgerId: l, month: nowMonth);
    expect(cur, hasLength(2));
    expect(cur.singleWhere((b) => b.categoryId == null).amountCents, 60000);
    expect(cur.singleWhere((b) => b.categoryId == food).amountCents, 12000);
    expect(find.text('已沿用上月预算'), findsOneWidget);
  });

  testWidgets('设置页可保存周期起始日', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    await repo.createLedger(name: '生活');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: BudgetSettingSheet()))));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('period_start_field')), '22');
    await tester.tap(find.byKey(const Key('save_budget_button')));
    await tester.pumpAndSettle();

    expect(await repo.periodStartDay(), 22);
  });
}