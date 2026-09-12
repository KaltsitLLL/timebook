import 'package:drift/drift.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0xFF3F77B6))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().nullable().references(Projects, #id)();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get priority => integer().withDefault(const Constant(1))(); // 1高 2中 3低
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON 列表
  IntColumn get estimateMinutes => integer().withDefault(const Constant(25))();
  IntColumn get actualMinutes => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PomodoroSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().nullable().references(Tasks, #id)();
  TextColumn get kind => text().withDefault(const Constant('focus'))(); // focus/short/long
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(25))();
  BoolColumn get interrupted => boolean().withDefault(const Constant(false))();
}

class PomodoroSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get focusMinutes => integer().withDefault(const Constant(25))();
  IntColumn get shortBreakMinutes => integer().withDefault(const Constant(5))();
  IntColumn get longBreakMinutes => integer().withDefault(const Constant(15))();
  IntColumn get longBreakInterval => integer().withDefault(const Constant(4))();
}