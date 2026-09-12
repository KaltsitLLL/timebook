import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/ai/domain/ai_bookkeeping_service.dart';
import 'package:timebook/features/ai/domain/ai_models.dart';
import 'package:timebook/features/ai/presentation/confirm_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  testWidgets('确认页可修改金额并落库', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final svc = AiBookkeepingService(db);
    await svc.createLedgerIfEmpty(name: '生活');
    await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
    addTearDown(db.close);

    await tester.pumpWidget(MaterialApp(home: ConfirmScreen(
        draft: const AiDraft(direction: 'expense', amountCents: 5000,
            counterparty: '滴滴'),
        service: svc)));
    await tester.pumpAndSettle();

    expect(find.text('50.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_save')));
    await tester.pumpAndSettle();
    final rows = await db.select(db.transactions).get();
    expect(rows.single.amountCents, 5000);
  });

  testWidgets('金额不足 0.5 元仍可入账（按分精确入库）', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final svc = AiBookkeepingService(db);
    await svc.createLedgerIfEmpty(name: '生活');
    await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
    addTearDown(db.close);

    await tester.pumpWidget(MaterialApp(home: ConfirmScreen(
        draft: const AiDraft(direction: 'expense', amountCents: 5000,
            counterparty: '滴滴'),
        service: svc)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('confirm_amount')), '0.40');
    await tester.tap(find.byKey(const Key('confirm_save')));
    await tester.pumpAndSettle();
    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 40);
  });
}