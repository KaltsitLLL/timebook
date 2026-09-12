import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/core/util/kv_settings.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/add_transaction_sheet.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<(ProviderContainer, BookkeepingRepository)> setup() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    await repo.createAccount(ledgerId: l, name: '卡');
    await repo.categories(l); // 默认 8 分类已随 createLedger 预置
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
      kvSettingsProvider.overrideWithValue(KvSettings(MemoryKeyValueStorage())),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return (container, repo);
  }

  testWidgets('保存一笔支出后写入数据库', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (c, repo) = await setup();
    final l = await repo.ledgers();

    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('amount_field')), '28.5');
    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();

    final rows = await repo.recentTransactions(ledgerId: l.first.id, limit: 10);
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 2850);
    expect(rows.single.direction, 'expense');
  });

  testWidgets('金额为空或 0 时点击保存不落库', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (c, repo) = await setup();
    final l = await repo.ledgers();

    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();

    final rows = await repo.recentTransactions(ledgerId: l.first.id, limit: 10);
    expect(rows, isEmpty);
  });

  testWidgets('金额输入算式时显示 = ¥ 预览，非法时隐藏', (tester) async {
    final (c, _) = await setup();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('amount_preview')), findsNothing);
    await tester.enterText(find.byKey(const Key('amount_field')), '28.5*2');
    await tester.pump();
    expect(find.text('= ¥ 57.00'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('amount_field')), 'abc');
    await tester.pump();
    expect(find.byKey(const Key('amount_preview')), findsNothing);
  });

  testWidgets('记账 Sheet 预选默认付款账户', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    await repo.createAccount(ledgerId: l, name: '卡');
    final a2 = await repo.createAccount(ledgerId: l, name: '钱包');
    final kv = KvSettings(MemoryKeyValueStorage());
    await kv.setInt('defaultAccountId:$l', a2);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
      kvSettingsProvider.overrideWithValue(kv),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    // 单 chip label 预选默认付款账户「钱包」，且不再平铺账户 ChoiceChip
    expect(find.text('钱包'), findsOneWidget);
    expect(find.byKey(Key('account_$a2')), findsNothing);
  });

  testWidgets('选择“不记账户”后保存落库到无账户 id', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (c, repo) = await setup();
    final l = await repo.ledgers();

    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account_pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick_none')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount_field')), '20');
    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();

    final noneId = await repo.ensureNoneAccount(l.first.id);
    final rows = await repo.recentTransactions(ledgerId: l.first.id, limit: 10);
    expect(rows, hasLength(1));
    expect(rows.single.accountId, noneId);
    expect(rows.single.amountCents, 2000);
  });

  testWidgets('金额区为展示式大数字行（去 label、40px 大字、无边框）', (tester) async {
    final (c, _) = await setup();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const Key('amount_field')));
    expect(field.decoration!.labelText, isNull);
    expect(field.style!.fontSize, 40);
    expect(field.decoration!.border, isA<InputBorder>());
    expect(field.decoration!.border, isNot(isA<OutlineInputBorder>()));
  });

  testWidgets('记账 Sheet 显示日期行 chip（今天 HH:mm）', (tester) async {
    final (c, _) = await setup();

    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    final chipFinder = find.byKey(const Key('book_at_chip'));
    expect(chipFinder, findsOneWidget);
    expect(tester.widget<FilterChip>(chipFinder), isA<FilterChip>());
    expect(find.textContaining('今天'), findsOneWidget);
    expect(find.textContaining(RegExp(r'今天 \d{1,2}:\d{2}')), findsOneWidget);
  });

  testWidgets('分类宫格渲染全部分类（不再截断前6个）', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    await repo.createAccount(ledgerId: l, name: '卡');
    final catIds = <int>[];
    for (var i = 0; i < 8; i++) {
      catIds.add(await repo.createCategory(ledgerId: l, name: '分类$i'));
    }
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
      kvSettingsProvider.overrideWithValue(KvSettings(MemoryKeyValueStorage())),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    for (final id in catIds) {
      expect(find.byKey(Key('cat_$id')), findsOneWidget);
    }
    expect(find.byKey(const Key('cat_nonexistent')), findsNothing);
  });

  testWidgets('选中分类后保存落库 categoryId', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (c, repo) = await setup();
    final l = await repo.ledgers();
    final cats = await repo.categories(l.first.id);
    final foodId = cats.singleWhere((c) => c.name == '餐饮').id; // 默认分类「餐饮」

    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('amount_field')), '10');
    await tester.tap(find.byKey(Key('cat_$foodId')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();

    final rows = await repo.recentTransactions(ledgerId: l.first.id, limit: 10);
    expect(rows, hasLength(1));
    expect(rows.single.categoryId, foodId);
  });

  testWidgets('收入胶囊选中时背景为青绿 #4CB3C4', (tester) async {
    final (c, _) = await setup();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    final incPill = find.byKey(const Key('dir_inc'));
    await tester.tap(incPill);
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(find.descendant(
        of: find.byKey(const Key('dir_inc')),
        matching: find.byType(Container)));
    final decor = container.decoration! as BoxDecoration;
    expect(decor.color, const Color(0xFF4CB3C4));
  });

  testWidgets('账户区为单 chip 显示当前账户名（不记账户/选择账户可切换且非平铺）',
      (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    await repo.createAccount(ledgerId: l, name: '卡');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
      kvSettingsProvider.overrideWithValue(KvSettings(MemoryKeyValueStorage())),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    // 单 chip 显示默认账户「卡」，且无平铺账户 chip
    expect(find.byKey(const Key('account_pick')), findsOneWidget);
    expect(find.text('卡'), findsOneWidget);
    expect(find.byKey(const Key('account_1')), findsNothing);

    // 弹层中选择「不记账户」后 label 更新
    await tester.tap(find.byKey(const Key('account_pick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick_none')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick_none')));
    await tester.pumpAndSettle();
    expect(find.text('不记账户'), findsOneWidget);
    expect(find.text('卡'), findsNothing);
  });
}