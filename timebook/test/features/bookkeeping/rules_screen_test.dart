import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/rules_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<(AppDatabase, int)> seed() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final bk = BookkeepingRepository(db);
    final l = await bk.createLedger(name: '生活');
    await bk.createAccount(ledgerId: l, name: '卡');
    final food =
        (await bk.categories(l)).singleWhere((c) => c.name == '餐饮').id;
    await bk.upsertRule(keyword: '美团', categoryId: food, priority: 1);
    return (db, food);
  }

  testWidgets('规则列表展示关键词与分类名，删除后消失', (tester) async {
    final (db, _) = await seed();
    addTearDown(db.close);

    await tester.pumpWidget(MaterialApp(home: RulesScreen(database: db)));
    await tester.pumpAndSettle();

    expect(find.text('美团'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);

    // 删除该规则
    await tester.tap(find.byKey(const Key('rule_del_1')));
    await tester.pumpAndSettle();
    expect(find.text('美团'), findsNothing);
    expect(await BookkeepingRepository(db).rules(), isEmpty);
  });

  testWidgets('新增规则：关键词+分类保存后落库并出现在列表', (tester) async {
    final (db, food) = await seed();
    addTearDown(db.close);

    await tester.pumpWidget(MaterialApp(home: RulesScreen(database: db)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rule_add')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('rule_keyword')), '滴滴');
    await tester.tap(find.byKey(const Key('rule_save')));
    await tester.pumpAndSettle();

    expect(find.text('滴滴'), findsOneWidget);
    final rules = await BookkeepingRepository(db).rules();
    expect(rules, hasLength(2));
    expect(rules.singleWhere((r) => r.keyword == '滴滴').categoryId, food);
  });
}