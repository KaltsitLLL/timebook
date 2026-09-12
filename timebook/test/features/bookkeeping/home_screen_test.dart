import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/home_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  final now = DateTime.now();

  Future<ProviderContainer> containerWith(int foodId, int transId) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final trans = await repo.createCategory(ledgerId: l, name: '交通');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(now.year, now.month, 12), counterparty: '美团外卖');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: trans, direction: 'expense',
        amountCents: 400, bookAt: DateTime(now.year, now.month, 12), counterparty: '地铁');
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'income', amountCents: 850000,
        bookAt: DateTime(now.year, now.month, 10), counterparty: '工资');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('总览显示结余、收入、支出与最近流水', (tester) async {
    final c = await containerWith(0, 0);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: HomeScreen()))));
    await tester.pumpAndSettle();

    expect(find.textContaining('¥ 8,467.50'), findsOneWidget); // 850000 - 3250 = 846750 分
    expect(find.textContaining('收入'), findsOneWidget);
    expect(find.text('¥ 32.50'), findsOneWidget); // 结余卡支出金额（标签与金额分行渲染）
    // 分类支出卡使列表变长，最近流水需滚动可见
    await tester.scrollUntilVisible(find.text('美团外卖'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('美团外卖'), findsOneWidget);
  });

  testWidgets('空账本显示空态引导', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db, storage: MemoryKeyValueStorage());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: HomeScreen()))));
    await tester.pumpAndSettle();

    expect(find.textContaining('记一笔'), findsWidgets);
  });

  testWidgets('总览提供预算入口并可跳转', (tester) async {
    final c = await containerWith(0, 0);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('预算进度'));
    await tester.pumpAndSettle();
    expect(find.text('本月预算'), findsOneWidget);
  });

  testWidgets('总览含分类支出卡与快捷入口', (tester) async {
    final c = await containerWith(0, 0); // 复用现有 seeded（餐饮支出 2850 + 交通 400 + 收入）
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();
    expect(find.text('分类支出'), findsOneWidget);
    expect(find.text('流水明细'), findsOneWidget);
    expect(find.textContaining('28.50'), findsWidgets); // 环形图 Top4 金额或流水金额
  });

  testWidgets('点击 FAB 打开记一笔 Sheet', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = await containerWith(0, 0);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Sheet 标题与 FAB 标签文案一致，断言至少出现一次（Sheet 已打开）
    expect(find.text('记一笔'), findsWidgets);
    expect(find.byKey(const Key('save_button')), findsOneWidget);
  });

  testWidgets('长按 FAB 触发 AI 记账入口', (tester) async {
    final c = await containerWith(0, 0);
    var aiCalled = false;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            home: Scaffold(
                body: HomeScreen(
                    aiDialogOpener: (ctx, ref) async {
          aiCalled = true;
        })))));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(FloatingActionButton));
    await tester.pump();

    expect(aiCalled, isTrue);
  });

  testWidgets('长按 FAB 未打开记一笔 Sheet（双入口互斥）', (tester) async {
    final c = await containerWith(0, 0);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            home: Scaffold(
                body: HomeScreen(aiDialogOpener: (ctx, ref) async {})))));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.byKey(const Key('save_button')), findsNothing);
  });
}