import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../features/bookkeeping/data/tables.dart';
import '../../features/focus/data/focus_tables.dart';
import '../../features/daily/data/day_summaries_table.dart';
import '../../features/import/data/import_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
    tables: [Ledgers, Accounts, Categories, Transactions, Budgets, Projects,
        Tasks, PomodoroSessions, PomodoroSettings, RecurringTransactions,
        ImportBatches, ImportRules, DaySummaries, RefundEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(projects);
            await m.createTable(tasks);
            await m.createTable(pomodoroSessions);
            await m.createTable(pomodoroSettings);
          }
          if (from < 3) {
            await m.createTable(recurringTransactions);
            await m.createTable(importBatches);
            await m.createTable(importRules);
          }
          if (from < 4) {
            await m.createTable(daySummaries);
          }
          if (from < 5) {
            await m.createTable(refundEntries);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openDefault() =>
      driftDatabase(name: 'timebook'); // Android/iOS/Windows/macOS 统一

  // 表查询器暴露给 DAO/测试（drift 生成的表对象即 db.ledgers 等）
}