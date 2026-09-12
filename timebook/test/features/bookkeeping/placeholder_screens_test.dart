import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/core/util/kv_settings.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/placeholder_screens.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  testWidgets('设置页含导入导出入口且可进入账单导入', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      kvSettingsProvider.overrideWithValue(KvSettings(MemoryKeyValueStorage())),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('导入导出'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import_export_entry')));
    await tester.pumpAndSettle();

    expect(find.text('账单导入'), findsOneWidget);
  });

  testWidgets('设置默认付款账户：保存后行 subtitle 显示账户名且 kv 读取一致', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    await repo.createAccount(ledgerId: l, name: '卡');
    final a2 = await repo.createAccount(ledgerId: l, name: '钱包');
    final kv = KvSettings(MemoryKeyValueStorage());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
      kvSettingsProvider.overrideWithValue(kv),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('default_account_entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('default_account_$a2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('default_account_save')));
    await tester.pumpAndSettle();

    // 行 subtitle 显示所选项的账户名；kv 已持久化所选 id
    expect(find.text('钱包'), findsOneWidget);
    expect(await kv.getInt('defaultAccountId:$l'), a2);
  });
}