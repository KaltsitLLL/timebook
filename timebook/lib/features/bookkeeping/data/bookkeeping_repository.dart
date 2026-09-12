import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';

class BookkeepingRepository {
  BookkeepingRepository(this.db);
  final AppDatabase db;

  // ---- 账本 ----
  Future<int> createLedger({required String name, String currency = 'CNY'}) {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: name, currency: Value(currency)));
  }

  Future<List<Ledger>> ledgers() => db.select(db.ledgers).get();

  // ---- 账户 ----
  Future<int> createAccount(
      {required int ledgerId, required String name}) {
    return db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: ledgerId, name: name));
  }

  Future<List<Account>> accounts(int ledgerId) => (db.select(db.accounts)
        ..where((t) => t.ledgerId.equals(ledgerId)))
      .get();

  // ---- 分类 ----
  Future<int> createCategory({required int ledgerId, required String name}) {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
        ledgerId: ledgerId, name: name));
  }

  Future<List<Category>> categories(int ledgerId) =>
      (db.select(db.categories)..where((t) => t.ledgerId.equals(ledgerId)))
          .get();
}