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
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
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
}