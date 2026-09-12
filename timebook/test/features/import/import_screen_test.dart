import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/import/presentation/import_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<AppDatabase> seed() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '生活'));
    await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
    addTearDown(db.close);
    return db;
  }

  const singleRow = '交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,交易单号\n'
      '2026-09-12 12:00:00,商户消费,美团外卖,午餐,支出,28.50,零钱,WX-9\n';

  testWidgets('粘贴微信 CSV → 预览逐行 → 确认后流水落库', (tester) async {
    final db = await seed();
    await tester.pumpWidget(MaterialApp(home: ImportScreen(database: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('csv_input')), singleRow);
    await tester.tap(find.byKey(const Key('preview_button')));
    await tester.pumpAndSettle();

    // 预览显示逐行列表统计（成功行数由统计文本体现）
    expect(find.textContaining('已勾选 1'), findsOneWidget);
    expect(find.textContaining('共 1'), findsOneWidget);
    expect(find.byKey(const Key('row_ok_0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_button')));
    await tester.pumpAndSettle();

    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 2850);
  });

  testWidgets('2 行 CSV → 取消勾选第 2 行 → 确认仅 1 行落库', (tester) async {
    final db = await seed();
    await tester.pumpWidget(MaterialApp(home: ImportScreen(database: db)));
    await tester.pumpAndSettle();

    const csv = '交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,交易单号\n'
        '2026-09-12 12:00:00,商户消费,美团外卖,午餐,支出,28.50,零钱,WX-9\n'
        '2026-09-12 13:00:00,商户消费,瑞幸咖啡,咖啡,支出,19.90,零钱,WX-10\n';
    await tester.enterText(find.byKey(const Key('csv_input')), csv);
    await tester.tap(find.byKey(const Key('preview_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('已勾选 2'), findsOneWidget);
    // 取消勾选第 2 行（下标 1）
    await tester.tap(find.byKey(const Key('row_ok_1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已勾选 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_button')));
    await tester.pumpAndSettle();

    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(1));
    expect(rows.single.orderId, 'WX-9');
  });

  testWidgets('改金额行 → 确认落库为编辑后值', (tester) async {
    final db = await seed();
    await tester.pumpWidget(MaterialApp(home: ImportScreen(database: db)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('csv_input')), singleRow);
    await tester.tap(find.byKey(const Key('preview_button')));
    await tester.pumpAndSettle();

    // 28.50 → 30.00
    await tester.enterText(find.byKey(const Key('row_amt_0')), '30.00');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_button')));
    await tester.pumpAndSettle();

    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 3000);
  });
}