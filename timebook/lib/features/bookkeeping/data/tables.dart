import 'package:drift/drift.dart';

class Ledgers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get icon => text().withDefault(const Constant('book'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF3F77B6))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('savings'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  IntColumn get parentId =>
      integer().nullable().references(Categories, #id)(); // 二级分类
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('restaurant'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get direction => text()(); // income / expense / transfer
  IntColumn get amountCents => integer()();
  IntColumn get refundedCents => integer().withDefault(const Constant(0))(); // 退款冲抵金额（含部分退款），统计按净额
  DateTimeColumn get bookAt => dateTime()();
  TextColumn get counterparty => text().withDefault(const Constant(''))();
  TextColumn get remark => text().withDefault(const Constant(''))();
  TextColumn get payMethod => text().withDefault(const Constant(''))();
  TextColumn get orderId => text().nullable()();
  TextColumn get importKey => text().nullable()();
  BoolColumn get isPending => boolean().withDefault(const Constant(false))();
  IntColumn get transferId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {ledgerId, importKey}, // NULL 在 SQLite 唯一索引中被忽略，去重仅命中已存在 key 的行
      ];
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get month => text()(); // 'yyyy-MM'
  IntColumn get amountCents => integer()();
}