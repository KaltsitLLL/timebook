import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/core/util/formats.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/budget_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<ProviderContainer> seeded({required bool over}) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final now = DateTime.now();
    final month = monthKey(now);
    await repo.upsertBudget(ledgerId: l, month: month, amountCents: 1000000);
    await repo.upsertBudget(
        ledgerId: l, categoryId: food, month: month, amountCents: 200000);
    await repo.addTransaction(
        ledgerId: l,
        accountId: a,
        categoryId: food,
        direction: 'expense',
        amountCents: over ? 250000 : 80000,
        bookAt: DateTime(now.year, now.month, 12));
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('预算页展示总预算进度与分类进度', (tester) async {
    final c = await seeded(over: false);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: BudgetScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('本月预算'), findsOneWidget);
    expect(find.textContaining('10,000.00'), findsWidgets); // 总预算 ¥10,000
    expect(find.textContaining('800.00'), findsWidgets); // 餐饮净额 ¥800
    expect(find.text('餐饮'), findsWidgets);
  });

  testWidgets('超支分类显示超支标记', (tester) async {
    final c = await seeded(over: true);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: BudgetScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('超支'), findsWidgets);
  });

  testWidgets('无库预算但存默认 → 显示已使用默认预算', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
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
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: BudgetScreen()))));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('default_tag')), findsOneWidget);
    expect(find.text('已使用默认预算'), findsOneWidget);
    expect(find.textContaining('10,000.00'), findsWidgets);
  });

  testWidgets('预算页显示本期标签（默认起始日 1 = 整月）', (tester) async {
    final c = await seeded(over: false);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: BudgetScreen()))));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    expect(find.text('本期（${now.month}/1–${now.month}/$lastDay）'),
        findsOneWidget);
  });
}