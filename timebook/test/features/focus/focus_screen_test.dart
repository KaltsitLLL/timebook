import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/focus/data/focus_repository.dart';
import 'package:timebook/features/focus/presentation/focus_providers.dart';
import 'package:timebook/features/focus/presentation/focus_screen.dart';
import 'package:timebook/features/focus/presentation/quadrant_view.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  testWidgets('专注页显示摘要、计时圆盘与今日待办，且倒计时递减', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);
    final pid = await repo.createProject(name: '研究');
    await repo.createTask(title: '整理PRD', projectId: pid, priority: 1);

    // 可控假时钟：widget 测试中 fake-async 只推进 Timer，不前进 DateTime.now()，
    // 因此用可变 fakeNow 注入驱动倒计时。
    var fakeNow = DateTime(2026, 9, 12, 9, 0, 0);
    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
      focusClockProvider.overrideWithValue(() => fakeNow),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FocusScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('今日专注'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);

    // 本周专注卡加高后计时器移出首屏，滚动到主按钮再操作
    await tester.ensureVisible(find.byKey(const Key('focus_start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus_start')));
    await tester.pump();
    fakeNow = fakeNow.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('24:5'), findsOneWidget); // 倒计时开始

    // 时间线/计时卡加高后待办区在首屏外，滚动以核对今日待办与任务
    await tester.dragUntilVisible(find.text('整理PRD'), find.byType(ListView),
        const Offset(0, -100));
    expect(find.text('今日待办'), findsOneWidget);
    expect(find.text('整理PRD'), findsOneWidget);
  });

  testWidgets('专注页提供模式 chips 与任务绑定按钮', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);
    final pid = await repo.createProject(name: '研究');
    await repo.createTask(title: '整理PRD', projectId: pid, priority: 1);

    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FocusScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('短休'), findsOneWidget);
    expect(find.text('长休'), findsOneWidget);
    // 任务行绑定按钮在首屏外，滚动后再断言
    await tester.dragUntilVisible(find.byKey(const Key('bind_1')),
        find.byType(ListView), const Offset(0, -100));
    expect(find.byKey(const Key('bind_1')), findsOneWidget);
  });

  testWidgets('短休结束记录 short 会话而非 focus', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);

    var fakeNow = DateTime(2026, 9, 12, 9, 0, 0);
    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
      focusClockProvider.overrideWithValue(() => fakeNow),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FocusScreen()))));
    await tester.pumpAndSettle();

    // 切到短休并开始（本周专注卡加高后计时器移出首屏，先滚动）
    await tester.ensureVisible(find.byKey(const Key('mode_short')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mode_short')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('focus_start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus_start')));
    await tester.pump();

    // 推进过短休时长（默认 5min = 300s），触发周期 tick 完成
    fakeNow = fakeNow.add(const Duration(seconds: 301));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final sessions = await repo.sessionsToday();
    expect(sessions, hasLength(1));
    expect(sessions.single.kind, 'short');
    expect(sessions.single.durationMinutes, 5);
  });

  testWidgets('四象限视图按重要/紧急分组', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);
    final pid = await repo.createProject(name: '研究');
    await repo.createTask(title: '整理PRD', projectId: pid, priority: 1);

    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: QuadrantView()))));
    await tester.pumpAndSettle();

    // priority=1 → 重要；无 dueDate → 不紧急，故落在「重要·不紧急」
    expect(find.text('重要·紧急'), findsOneWidget);
    expect(find.text('重要·不紧急'), findsOneWidget);
    expect(find.text('整理PRD'), findsOneWidget);
  });

  testWidgets('无待办任务时显示绑定引导文案', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);

    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FocusScreen()))));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(find.byKey(const Key('focus_guide')),
        find.byType(ListView), const Offset(0, -100));
    expect(find.byKey(const Key('focus_guide')), findsOneWidget);
    expect(find.text('添加任务后在任务行点 🍅 绑定开始专注'), findsOneWidget);
  });

  testWidgets('本周专注热力图显示 7 色块与当日「今」标签', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);
    // seed 今日 50 分钟专注
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await repo.addSession(kind: 'focus', startAt: today, durationMinutes: 50);

    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FocusScreen()))));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('focus_heatmap')), findsOneWidget);
    expect(find.text('今'), findsOneWidget);
    // 今日 50 分 → 显示 '50m'
    expect(find.text('50m'), findsOneWidget);
  });

  testWidgets('提供 Flowtime 流式模式 chip', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);

    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FocusScreen()))));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mode_flowtime')), findsOneWidget);
    expect(find.text('流式'), findsOneWidget);
  });

  testWidgets('摘要卡显示今日待办完成比与番茄数·分钟', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 1 未完成任务 + 1 已完成（当日）+ 1 条 25 分钟 focus 会话
    await repo.createTask(title: '进行中事项', priority: 1);
    final doneId = await repo.createTask(title: '已完成事项', priority: 2);
    await repo.addSession(kind: 'focus', startAt: today, durationMinutes: 25);
    // 标记完成 → completedAt 为当日
    await repo.toggleCompleted(taskId: doneId);

    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: FocusScreen()))));
    await tester.pumpAndSettle();

    // done=1（当日完成），total=open(1)+done(1)=2 → '1/2'
    expect(find.byKey(const Key('today_todo_stat')), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('1 🍅 · 25 分钟'), findsOneWidget);
    expect(find.byKey(const Key('today_focus_stat')), findsOneWidget);
  });
}