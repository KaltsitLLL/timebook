import 'package:drift/drift.dart';

class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer()();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get accountId => integer().nullable()();
  TextColumn get direction => text()();
  IntColumn get amountCents => integer()();
  TextColumn get counterparty => text().withDefault(const Constant(''))();
  TextColumn get remark => text().withDefault(const Constant(''))();
  TextColumn get frequency => text().withDefault(const Constant('monthly'))(); // monthly/weekly/custom_day
  IntColumn get dayOfMonth => integer().withDefault(const Constant(1))();
  TextColumn get nextRun => text().withDefault(const Constant(''))(); // 'yyyy-MM-dd'
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get lastGenerated => text().withDefault(const Constant(''))();
}

class ImportBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text()();
  TextColumn get fileName => text()();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get okRows => integer().withDefault(const Constant(0))();
  IntColumn get skipRows => integer().withDefault(const Constant(0))();
  IntColumn get dupRows => integer().withDefault(const Constant(0))();
  IntColumn get errorRows => integer().withDefault(const Constant(0))();
}

class ImportRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get keyword => text()();
  IntColumn get categoryId => integer()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
}