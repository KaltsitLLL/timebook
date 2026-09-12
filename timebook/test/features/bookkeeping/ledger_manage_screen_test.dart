import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/core/util/kv_settings.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/ledger_manage_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<({ProviderContainer c, KvSettings kv, List<int> ids})> setup(
      int count) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final kv = KvSettings(MemoryKeyValueStorage());
    final ids = <int>[];
    for (var i = 1; i <= count; i++) {
      ids.add(await repo.createLedger(name: '账本$i'));
    }
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
      kvSettingsProvider.overrideWithValue(kv),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return (c: container, kv: kv, ids: ids);
  }

  testWidgets('两账本：点击第二行设为当前 → kv currentLedgerId==id', (tester) async {
    final (c: c, kv: kv, ids: ids) = await setup(2);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: LedgerManageScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('账本1'), findsOneWidget);
    expect(find.text('账本2'), findsOneWidget);

    await tester.tap(find.byKey(Key('ledger_${ids[1]}')));
    await tester.pumpAndSettle();

    expect(await kv.getInt('currentLedgerId'), ids[1]);
    expect(find.text('当前'), findsOneWidget);
  });

  testWidgets('新建账本：输入名称保存后列表 +1 且设为当前', (tester) async {
    final (c: c, kv: kv, ids: ids) = await setup(1);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: LedgerManageScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ledger_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ledger_name')), '新本');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ledger_save')));
    await tester.pumpAndSettle();

    expect(find.text('新本'), findsOneWidget);
    final ledgers = await c.read(bookkeepingRepositoryProvider).ledgers();
    expect(ledgers, hasLength(ids.length + 1));
    expect(await kv.getInt('currentLedgerId'), ledgers.last.id);
  });
}