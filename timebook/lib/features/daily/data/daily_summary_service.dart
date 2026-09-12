import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../data/day_summaries_table.dart';

class DailySummaryService {
  DailySummaryService(this.db);
  final AppDatabase db;

  /// 生成并幂等保存某日小结（当日 番茄数/专注分钟/支出净额/完成任务数）。
  Future<DaySummary> generateFor({required DateTime date}) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final key = _key(dayStart);

    // 专注
    final sessions = await (db.select(db.pomodoroSessions)
          ..where((s) =>
              s.kind.equals('focus') &
              s.startAt.isBiggerOrEqualValue(dayStart) &
              s.startAt.isSmallerThanValue(dayEnd) &
              s.interrupted.equals(false)))
        .get();
    final focusMinutes = sessions.fold<int>(0, (a, s) => a + s.durationMinutes);
    final pomodoroCount = sessions.length;

    // 支出净额（当日）
    final txs = await (db.select(db.transactions)
          ..where((t) =>
              t.direction.equals('expense') &
              t.bookAt.isBiggerOrEqualValue(dayStart) &
              t.bookAt.isSmallerThanValue(dayEnd)))
        .get();
    final expenseTotal =
        txs.fold<int>(0, (a, t) => a + (t.amountCents - t.refundedCents));

    // 当日完成任务（completedAt 落在当日）
    final done = await (db.select(db.tasks)
          ..where((t) =>
              t.completedAt.isNotNull() &
              t.completedAt.isBiggerOrEqualValue(dayStart) &
              t.completedAt.isSmallerThanValue(dayEnd)))
        .get();

    final summary = DaySummary(
        date: key, pomodoroCount: pomodoroCount, focusMinutes: focusMinutes,
        expenseTotalCents: expenseTotal, tasksDone: done.length,
        snapshotJson: '{}');
    await _upsert(summary);
    return summary;
  }

  Future<void> _upsert(DaySummary s) async {
    final existing = await (db.select(db.daySummaries)..where((t) => t.date.equals(s.date))).get();
    if (existing.isEmpty) {
      await db.into(db.daySummaries).insert(DaySummariesCompanion.insert(
          date: s.date, pomodoroCount: Value(s.pomodoroCount),
          focusMinutes: Value(s.focusMinutes),
          expenseTotalCents: Value(s.expenseTotalCents),
          tasksDone: Value(s.tasksDone)));
    } else {
      await (db.update(db.daySummaries)..where((t) => t.date.equals(s.date)))
          .write(DaySummariesCompanion(
              pomodoroCount: Value(s.pomodoroCount),
              focusMinutes: Value(s.focusMinutes),
              expenseTotalCents: Value(s.expenseTotalCents),
              tasksDone: Value(s.tasksDone)));
    }
  }

  Future<List<DaySummary>> recent({int limit = 7}) {
    return (db.select(db.daySummaries)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .get();
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}