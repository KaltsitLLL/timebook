import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/stats_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<ProviderContainer> seeded() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final now = DateTime.now();
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(now.year, now.month, 12), counterparty: '美团');
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

  testWidgets('统计页显示近6个月标题与分类排行', (tester) async {
    final c = await seeded();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: StatsScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('近 6 个月收支'), findsOneWidget);
    expect(find.text('本月分类占比'), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
  });
}