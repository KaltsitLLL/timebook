import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';

class FocusRepository {
  FocusRepository(this.db);
  final AppDatabase db;

  Future<int> createProject({required String name, int color = 0xFF3F77B6}) {
    return db.into(db.projects).insert(
        ProjectsCompanion.insert(name: name, color: Value(color)));
  }

  Future<int> createTask(
      {required String title,
      int? projectId,
      int priority = 1,
      int estimateMinutes = 25,
      DateTime? dueDate}) {
    return db.into(db.tasks).insert(TasksCompanion.insert(
        title: title,
        projectId: Value(projectId),
        priority: Value(priority),
        estimateMinutes: Value(estimateMinutes),
        dueDate: Value(dueDate)));
  }

  Future<List<Task>> openTasks() {
    return (db.select(db.tasks)
          ..where((t) => t.completedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .get();
  }

  Future<List<Task>> completedTasks() {
    return (db.select(db.tasks)
          ..where((t) => t.completedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
        .get();
  }

  Future<void> toggleCompleted({required int taskId}) async {
    final t = await (db.select(db.tasks)..where((x) => x.id.equals(taskId))).getSingle();
    await (db.update(db.tasks)..where((x) => x.id.equals(taskId)))
        .write(TasksCompanion(
            completedAt: Value(t.completedAt == null ? DateTime.now() : null)));
  }

  Future<List<Project>> projects() => db.select(db.projects).get();

  Future<PomodoroSetting> settings() async {
    final all = await db.select(db.pomodoroSettings).get();
    if (all.isNotEmpty) return all.first;
    final id = await db.into(db.pomodoroSettings).insert(PomodoroSettingsCompanion.insert());
    return (db.select(db.pomodoroSettings)..where((s) => s.id.equals(id))).getSingle();
  }

  Future<void> updateSettings({
    required int focusMinutes,
    required int shortBreakMinutes,
    required int longBreakMinutes,
    required int longBreakInterval,
  }) async {
    final s = await settings();
    await (db.update(db.pomodoroSettings)..where((x) => x.id.equals(s.id)))
        .write(PomodoroSettingsCompanion(
            focusMinutes: Value(focusMinutes),
            shortBreakMinutes: Value(shortBreakMinutes),
            longBreakMinutes: Value(longBreakMinutes),
            longBreakInterval: Value(longBreakInterval)));
  }

  Future<int> addSession({
    int? taskId,
    String kind = 'focus',
    required DateTime startAt,
    DateTime? endAt,
    int durationMinutes = 25,
    bool interrupted = false,
  }) {
    return db.into(db.pomodoroSessions).insert(PomodoroSessionsCompanion.insert(
        taskId: Value(taskId),
        kind: Value(kind),
        startAt: startAt,
        endAt: Value(endAt),
        durationMinutes: Value(durationMinutes),
        interrupted: Value(interrupted)));
  }

  Future<List<PomodoroSession>> sessionsToday() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    return (db.select(db.pomodoroSessions)
          ..where((s) => s.startAt.isBiggerOrEqualValue(dayStart))
          ..orderBy([(s) => OrderingTerm.desc(s.startAt)]))
        .get();
  }

  /// 近 [days] 天（默认 7）每天 kind=='focus' 且未中断的专注分钟聚合，
  /// 自老到新返回，day 归一为当日零点；空日补 0。
  Future<List<(DateTime, int)>> focusMinutesByDay({int days = 7}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayStart = today.subtract(Duration(days: days - 1));
    final rows = await (db.select(db.pomodoroSessions)
          ..where((s) =>
              s.kind.equals('focus') &
              s.interrupted.equals(false) &
              s.startAt.isBiggerOrEqualValue(dayStart)))
        .get();
    final byDay = <int, int>{};
    for (final r in rows) {
      final day =
          DateTime(r.startAt.year, r.startAt.month, r.startAt.day).millisecondsSinceEpoch;
      byDay[day] = (byDay[day] ?? 0) + r.durationMinutes;
    }
    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      return (day, byDay[day.millisecondsSinceEpoch] ?? 0);
    });
  }

  Future<int> todayFocusMinutes() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final rows = await (db.select(db.pomodoroSessions)
          ..where((s) =>
              s.kind.equals('focus') &
              s.startAt.isBiggerOrEqualValue(dayStart) &
              s.interrupted.equals(false)))
        .get();
    return rows.fold<int>(0, (sum, s) => sum + s.durationMinutes);
  }
}