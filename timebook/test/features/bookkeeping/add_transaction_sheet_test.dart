import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/add_transaction_sheet.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<(ProviderContainer, BookkeepingRepository)> setup() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    await repo.createAccount(ledgerId: l, name: '卡');
    await repo.createCategory(ledgerId: l, name: '餐饮');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return (container, repo);
  }

  testWidgets('保存一笔支出后写入数据库', (tester) async {
    final (c, repo) = await setup();
    final l = await repo.ledgers();

    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('amount_field')), '28.5');
    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();

    final rows = await repo.recentTransactions(ledgerId: l.first.id, limit: 10);
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 2850);
    expect(rows.single.direction, 'expense');
  });

  testWidgets('金额为空或 0 时点击保存不落库', (tester) async {
    final (c, repo) = await setup();
    final l = await repo.ledgers();

    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();

    final rows = await repo.recentTransactions(ledgerId: l.first.id, limit: 10);
    expect(rows, isEmpty);
  });
}