import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/import/presentation/recurring_rules_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<void> seed(AppDatabase db) async {
    final bk = BookkeepingRepository(db);
    final l = await bk.createLedger(name: '生活');
    final a = await bk.createAccount(ledgerId: l, name: '卡');
    await db.into(db.recurringTransactions).insert(RecurringTransactionsCompanion.insert(
        ledgerId: l, accountId: Value(a), direction: 'expense',
        amountCents: 240000, counterparty: const Value('房东'),
        dayOfMonth: Value(1), nextRun: const Value('2999-01-01')));
  }

  testWidgets('列表显示已存在规则对方，新增规则后行数+1', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    addTearDown(db.close);
    await seed(db);

    await tester.pumpWidget(MaterialApp(
        home: RecurringRulesScreen(database: db)));
    await tester.pumpAndSettle();

    // 既有规则显示对方
    expect(find.text('房东'), findsOneWidget);

    // 新增规则
    await tester.tap(find.byKey(const Key('rr_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rr_amount')), '2400');
    await tester.enterText(find.byKey(const Key('rr_counterparty')), '房东2');
    await tester.enterText(find.byKey(const Key('rr_remark')), '房租');
    await tester.enterText(find.byKey(const Key('rr_day')), '1');
    await tester.tap(find.byKey(const Key('rr_save')));
    await tester.pumpAndSettle();

    // 新规则落库，列表行数 +1
    expect(find.text('房东2'), findsOneWidget);
  });
}