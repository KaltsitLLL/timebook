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