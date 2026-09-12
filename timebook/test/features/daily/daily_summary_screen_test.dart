import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/daily/data/daily_summary_service.dart';
import 'package:timebook/features/daily/presentation/daily_summary_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  testWidgets('今日小结卡展示聚合数据', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final svc = DailySummaryService(db);
    addTearDown(db.close);

    await tester.pumpWidget(MaterialApp(
        home: DailySummaryScreen(service: svc, date: DateTime.now())));
    await tester.pumpAndSettle();

    expect(find.textContaining('今日小结'), findsOneWidget);
    // 空数据不显示金额行数也可通过（聚合为 0）
    await tester.tap(find.byKey(const Key('daily_save')));
    await tester.pumpAndSettle();
    final all = await db.select(db.daySummaries).get();
    expect(all, hasLength(1));
  });
}