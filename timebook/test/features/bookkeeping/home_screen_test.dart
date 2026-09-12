import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/home_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  final now = DateTime.now();

  Future<ProviderContainer> containerWith(int foodId, int transId) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final trans = await repo.createCategory(ledgerId: l, name: '交通');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(now.year, now.month, 12), counterparty: '美团外卖');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: trans, direction: 'expense',
        amountCents: 400, bookAt: DateTime(now.year, now.month, 12), counterparty: '地铁');
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'income', amountCents: 850000,
        bookAt: DateTime(now.year, now.month, 10), counterparty: '工资');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('总览显示结余、收入、支出与最近流水', (tester) async {
    final c = await containerWith(0, 0);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: HomeScreen()))));
    await tester.pumpAndSettle();

    expect(find.textContaining('¥ 8,467.50'), findsOneWidget); // 850000 - 3250 = 846750 分
    expect(find.textContaining('收入'), findsOneWidget);
    expect(find.textContaining('支出'), findsOneWidget);
    expect(find.text('美团外卖'), findsOneWidget);
  });

  testWidgets('空账本显示空态引导', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: HomeScreen()))));
    await tester.pumpAndSettle();

    expect(find.textContaining('记一笔'), findsWidgets);
  });
}