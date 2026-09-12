import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../domain/recurring_service.dart';

/// 周期交易（recurringTransactions 表）的 CRUD 与到期生成封装。
/// 不新建表，直接操作既有表；到期生成复用 RecurringService.generateDue。
class RecurringRepository {
  RecurringRepository(this.db);
  final AppDatabase db;

  /// 新增（id==null）或更新（id!=null）一条周期规则。
  /// nextRun 初始 = 下个同日；若本月当天未到则为本月同日，否则顺延下月同日（月末语义裁剪）。
  Future<int> upsertRecurring({
    int? id,
    required int ledgerId,
    int? accountId,
    int? categoryId,
    required String direction,
    required int amountCents,
    String counterparty = '',
    String remark = '',
    required int dayOfMonth,
    bool active = true,
  }) async {
    final now = DateTime.now();
    final nextRun = _initialNextRun(dayOfMonth, now);
    if (id == null) {
      return db.into(db.recurringTransactions).insert(
          RecurringTransactionsCompanion.insert(
              ledgerId: ledgerId,
              accountId: Value(accountId),
              categoryId: Value(categoryId),
              direction: direction,
              amountCents: amountCents,
              counterparty: Value(counterparty),
              remark: Value(remark),
              dayOfMonth: Value(dayOfMonth),
              active: Value(active),
              nextRun: Value(nextRun)));
    }
    await (db.update(db.recurringTransactions)..where((t) => t.id.equals(id)))
        .write(RecurringTransactionsCompanion(
            accountId: Value(accountId),
            categoryId: Value(categoryId),
            direction: Value(direction),
            amountCents: Value(amountCents),
            counterparty: Value(counterparty),
            remark: Value(remark),
            dayOfMonth: Value(dayOfMonth),
            active: Value(active),
            nextRun: Value(nextRun)));
    return id;
  }

  Future<List<RecurringTransaction>> recurringAll() =>
      db.select(db.recurringTransactions).get();

  Future<void> deleteRecurring(int id) =>
      (db.delete(db.recurringTransactions)..where((t) => t.id.equals(id))).go();

  Future<void> toggleRecurring(int id, bool active) async {
    await (db.update(db.recurringTransactions)..where((t) => t.id.equals(id)))
        .write(RecurringTransactionsCompanion(active: Value(active)));
  }

  /// 到期生成一次（封装 RecurringService.generateDue）。
  Future<int> runDue({DateTime? today}) =>
      RecurringService(db).generateDue(today: today);

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// nextRun 初始：本月未至则本月同日，否则下月同日；dayOfMonth>=28 时按目标月天数裁剪为月末。
  String _initialNextRun(int dayOfMonth, DateTime now) {
    final inThisMonth = dayOfMonth >= now.day;
    var m = inThisMonth ? now.month : now.month + 1;
    var y = now.year + ((m - 1) ~/ 12);
    m = ((m - 1) % 12) + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    final d = dayOfMonth > lastDay ? lastDay : dayOfMonth;
    return _key(DateTime(y, m, d));
  }
}