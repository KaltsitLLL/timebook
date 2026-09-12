import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';

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

  test('创建账本/账户/分类后可读回', () async {
    final repo = BookkeepingRepository(db);
    final ledgerId = await repo.createLedger(name: '生活');
    final accountId =
        await repo.createAccount(ledgerId: ledgerId, name: '招行储蓄卡');
    final foodId = await repo.createCategory(ledgerId: ledgerId, name: '餐饮');

    final ledgers = await repo.ledgers();
    final accounts = await repo.accounts(ledgerId);
    final cats = await repo.categories(ledgerId);

    expect(ledgers.single.name, '生活');
    expect(accounts.single.name, '招行储蓄卡');
    expect(cats.single.name, '餐饮');
    expect(foodId, greaterThan(0));
  });
}