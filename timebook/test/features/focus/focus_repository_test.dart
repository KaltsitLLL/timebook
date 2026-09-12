import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/focus/data/focus_repository.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;
  late FocusRepository repo;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase.forTesting(inMemoryExecutor());
    repo = FocusRepository(db);
  });

  tearDown(() async => db.close());

  test('建项目与任务，读回并按完成状态过滤', () async {
    final pid = await repo.createProject(name: '研究');
    await repo.createTask(title: '整理PRD', projectId: pid, priority: 1);
    await repo.createTask(title: '已完事项', priority: 3);

    final open = await repo.openTasks();
    expect(open, hasLength(2));

    final t = open.singleWhere((x) => x.title == '已完事项');
    await repo.toggleCompleted(taskId: t.id);
    final openAfter = await repo.openTasks();
    expect(openAfter, hasLength(1));
    final done = await repo.completedTasks();
    expect(done.single.title, '已完事项');
  });

  test('设置默认存在并更新', () async {
    final s = await repo.settings();
    expect(s.focusMinutes, 25);
    await repo.updateSettings(focusMinutes: 30, shortBreakMinutes: 5,
        longBreakMinutes: 15, longBreakInterval: 4);
    final after = await repo.settings();
    expect(after.focusMinutes, 30);
  });

  test('focusMinutesByDay 近7天聚合：昨日25 + 今日50 + 空日0', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    await repo.addSession(kind: 'focus', startAt: yesterday, durationMinutes: 25);
    await repo.addSession(kind: 'focus', startAt: today, durationMinutes: 50);
    // 非 focus 或 interrupted 均不计入
    await repo.addSession(kind: 'short', startAt: today, durationMinutes: 5);
    await repo.addSession(kind: 'focus', startAt: today, durationMinutes: 99, interrupted: true);

    final rows = await repo.focusMinutesByDay();

    expect(rows, hasLength(7));
    expect(rows.first.$1, today.subtract(const Duration(days: 6)));
    expect(rows.last.$1, today);
    expect(rows[5].$2, 25); // 昨日
    expect(rows[6].$2, 50); // 今日
    expect(rows[0].$2, 0); // 远端空日补 0
  });

  test('todayPomodoro 统计今日完成的专注会话数，短休不计', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await repo.addSession(kind: 'focus', startAt: today, durationMinutes: 25);
    // 短休不计
    await repo.addSession(kind: 'short', startAt: today, durationMinutes: 5);
    // 中断的专注不计
    await repo.addSession(kind: 'focus', startAt: today, durationMinutes: 25, interrupted: true);

    expect(await repo.todayPomodoro(), 1);
  });

  test('todayPomodoro 无当日会话时返回 0', () async {
    expect(await repo.todayPomodoro(), 0);
  });
}