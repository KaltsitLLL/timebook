import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/core/util/kv_settings.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/home_screen.dart';

import '../../helpers/db.dart';

Future<ProviderContainer> seed(MemoryKeyValueStorage kvBackend,
    {int? currentLedgerId}) async {
  final db = AppDatabase.forTesting(inMemoryExecutor());
  final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
  final kv = KvSettings(kvBackend);
  final l1 = await repo.createLedger(name: '账本1');
  final l2 = await repo.createLedger(name: '账本2');
  final a1 = await repo.createAccount(ledgerId: l1, name: '卡1');
  final a2 = await repo.createAccount(ledgerId: l2, name: '卡2');
  final now = DateTime.now();
  await repo.addTransaction(
      ledgerId: l1, accountId: a1, direction: 'expense', amountCents: 100,
      bookAt: DateTime(now.year, now.month, 3), counterparty: '旧账本流水');
  await repo.addTransaction(
      ledgerId: l2, accountId: a2, direction: 'expense', amountCents: 8800,
      bookAt: DateTime(now.year, now.month, 5), counterparty: '当前账本流水');
  if (currentLedgerId != null) await kv.setInt('currentLedgerId', currentLedgerId);
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    bookkeepingRepositoryProvider.overrideWithValue(repo),
    kvSettingsProvider.overrideWithValue(kv),
  ]);
  addTearDown(db.close);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(initTestSqlite);

  testWidgets('kv 设当前账本=2 → home 显示账本2数据，不显示账本1', (tester) async {
    final c = await seed(MemoryKeyValueStorage(), currentLedgerId: 2);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('当前账本流水'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('当前账本流水'), findsOneWidget);
    expect(find.text('旧账本流水'), findsNothing);
  });

  testWidgets('无 kv → 回退账本1', (tester) async {
    final c = await seed(MemoryKeyValueStorage());
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('旧账本流水'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('旧账本流水'), findsOneWidget);
    expect(find.text('当前账本流水'), findsNothing);
  });
}