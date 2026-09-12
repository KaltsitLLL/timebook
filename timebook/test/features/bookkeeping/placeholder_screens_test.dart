import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
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
}