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
}