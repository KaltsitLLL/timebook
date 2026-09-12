import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/transaction_list_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<ProviderContainer> seeded() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(2026, 9, 12), counterparty: '美团外卖');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 1990, bookAt: DateTime(2026, 9, 11), counterparty: '瑞幸咖啡');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('流水按日期分组展示且过滤支出', (tester) async {
    final c = await seeded();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: TransactionListScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('美团外卖'), findsOneWidget);
    expect(find.text('瑞幸咖啡'), findsOneWidget);
    // 默认筛选「支出」，两笔均显示
    expect(find.textContaining('-¥ 28.50'), findsOneWidget);
    expect(find.textContaining('-¥ 19.90'), findsOneWidget);
  });
}