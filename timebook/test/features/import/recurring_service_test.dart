import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/import/domain/recurring_service.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;
  late RecurringService svc;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase.forTesting(inMemoryExecutor());
    svc = RecurringService(db);
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '生活'));
    await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
  });

  tearDown(() async => db.close());

  test('到期周期交易生成待确认流水并推进 nextRun', () async {
    await db.into(db.recurringTransactions).insert(RecurringTransactionsCompanion.insert(
        ledgerId: 1, accountId: const Value(1), direction: 'expense', amountCents: 240000,
        counterparty: const Value('房东'), frequency: const Value('monthly'),
        dayOfMonth: Value(DateTime.now().day),
        nextRun: Value(DateTime(2020, 1, 1).toIso8601String().substring(0, 10))));

    final n = await svc.generateDue(today: DateTime.now());
    expect(n, 1);

    final pending = await db.select(db.transactions).get();
    expect(pending.single.isPending, isTrue);
    final rt = await db.select(db.recurringTransactions).get();
    expect(rt.single.nextRun, isNot('2020-01-01')); // 已推进
  });

  test('未到期不生成', () async {
    await db.into(db.recurringTransactions).insert(RecurringTransactionsCompanion.insert(
        ledgerId: 1, direction: 'expense', amountCents: 100,
        nextRun: Value('2999-01-01')));

    final n = await svc.generateDue(today: DateTime.now());
    expect(n, 0);
    expect(await db.select(db.transactions).get(), isEmpty);
  });
}