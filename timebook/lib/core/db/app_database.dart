import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../features/bookkeeping/data/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Ledgers, Accounts, Categories, Transactions, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openDefault() =>
      driftDatabase(name: 'timebook'); // Android/iOS/Windows/macOS 统一

  // 表查询器暴露给 DAO/测试（drift 生成的表对象即 db.ledgers 等）
}