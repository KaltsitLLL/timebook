import 'package:drift/drift.dart';

class DaySummaries extends Table {
  TextColumn get date => text()(); // 'yyyy-MM-dd'
  IntColumn get pomodoroCount => integer().withDefault(const Constant(0))();
  IntColumn get focusMinutes => integer().withDefault(const Constant(0))();
  IntColumn get expenseTotalCents => integer().withDefault(const Constant(0))();
  IntColumn get tasksDone => integer().withDefault(const Constant(0))();
  IntColumn get rating => integer().nullable()(); // 1-5
  TextColumn get snapshotJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {date};
}