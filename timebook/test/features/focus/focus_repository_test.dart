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
}