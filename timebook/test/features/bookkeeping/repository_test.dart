import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase(inMemoryExecutor());
  });

  tearDown(() async => db.close());

  test('schema v1 可打开且各表可查询', () async {
    await db.transaction(() async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本', currency: const Value('CNY')));
      await db
          .into(db.accounts)
          .insert(AccountsCompanion.insert(ledgerId: 1, name: '储蓄卡'));
      await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(ledgerId: 1, name: '餐饮'));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: 1,
          accountId: 1,
          categoryId: const Value(1),
          direction: 'expense',
          amountCents: 2850,
          bookAt: DateTime(2026, 9, 12)));
    });
    final cnt = await db.transactions.count().getSingle();
    expect(cnt, 1);
  });
}