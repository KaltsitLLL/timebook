import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/import/presentation/import_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  testWidgets('粘贴微信 CSV → 预览成功行 → 确认后流水落库', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '生活'));
    await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
    addTearDown(db.close);

    await tester.pumpWidget(MaterialApp(home: ImportScreen(database: db)));
    await tester.pumpAndSettle();

    const csv = '交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,交易单号\n'
        '2026-09-12 12:00:00,商户消费,美团外卖,午餐,支出,28.50,零钱,WX-9\n';
    await tester.enterText(find.byKey(const Key('csv_input')), csv);
    await tester.tap(find.byKey(const Key('preview_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('成功'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_button')));
    await tester.pumpAndSettle();

    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 2850);
  });
}