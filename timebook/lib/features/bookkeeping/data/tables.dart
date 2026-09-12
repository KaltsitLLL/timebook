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

/// 退款独立条目：退款作为唯一事实来源挂在原支出上（Veri Fin 式），
/// `transactions.refunded_cents` 保留为派生缓存，由 `syncRefundData` 重算。
class RefundEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get amountCents => integer()();
  IntColumn get accountId => integer().nullable()(); // 收款账户，预留「退到不同账户」
  DateTimeColumn get bookAt => dateTime()(); // 发起/入账日期
  DateTimeColumn get settledAt => dateTime().nullable()(); // null=待到账
  TextColumn get importKey => text().nullable()(); // 导入去重指纹

  @override
  List<Set<Column>> get uniqueKeys => [
        {ledgerId, importKey}, // 同账本同导入单号不重复建条目
      ];
}