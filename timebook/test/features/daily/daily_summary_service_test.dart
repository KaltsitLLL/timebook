import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/daily/data/daily_summary_service.dart';
import 'package:timebook/features/focus/data/focus_repository.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;
  late DailySummaryService svc;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase.forTesting(inMemoryExecutor());
    svc = DailySummaryService(db);
  });

  tearDown(() async => db.close());

  test('生成并幂等保存当日小结（聚合专注/支出/任务）', () async {
    // 账本+账户+一笔当日支出
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '生活'));
    await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
    final now = DateTime.now();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: 1, accountId: 1, direction: 'expense', amountCents: 2850,
        bookAt: now, counterparty: const Value('美团')));
    // 任务：一个已完成
    final focus = FocusRepository(db);
    await focus.createTask(title: '写完接口', priority: 1);
    await focus.toggleCompleted(taskId: 1);
    // 一条当日专注记录
    await focus.addSession(
        kind: 'focus', startAt: now.subtract(const Duration(minutes: 25)),
        durationMinutes: 25);

    final s1 = await svc.generateFor(date: now);
    expect(s1.focusMinutes, 25);
    expect(s1.expenseTotalCents, 2850);
    expect(s1.tasksDone, 1);

    // 幂等：再生成不新增行，值更新
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: 1, accountId: 1, direction: 'expense', amountCents: 100,
        bookAt: now));
    final s2 = await svc.generateFor(date: now);
    expect(s2.expenseTotalCents, 2950);
    expect(await db.daySummaries.count().getSingle(), 1);
  });

  test('最近 7 条历史', () async {
    await db.into(db.daySummaries).insert(DaySummariesCompanion.insert(
        date: '2026-09-10', pomodoroCount: const Value(2),
        focusMinutes: const Value(50), expenseTotalCents: const Value(1000),
        tasksDone: const Value(1)));
    await db.into(db.daySummaries).insert(DaySummariesCompanion.insert(
        date: '2026-09-11', pomodoroCount: const Value(1),
        focusMinutes: const Value(25), expenseTotalCents: const Value(500),
        tasksDone: const Value(0)));
    final list = await svc.recent(limit: 7);
    expect(list, hasLength(2));
    expect(list.first.date, '2026-09-11'); // 倒序
  });
}