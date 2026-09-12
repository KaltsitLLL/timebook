import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';

class RecurringService {
  RecurringService(this.db);
  final AppDatabase db;

  /// 到期（nextRun <= today）且 active 的周期交易 → 生成 isPending 流水（默认账户解析），推进 nextRun 到下月同日。
  Future<int> generateDue({DateTime? today}) async {
    final now = today ?? DateTime.now();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final due = await (db.select(db.recurringTransactions)
          ..where((t) =>
              t.active.equals(true) & t.nextRun.isSmallerOrEqualValue(todayKey)))
        .get();
    var count = 0;
    for (final rt in due) {
      if (rt.accountId == null || rt.accountId == 0) continue; // 无账户跳过（同外键策略）
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: rt.ledgerId,
          accountId: rt.accountId!,
          categoryId: Value(rt.categoryId),
          direction: rt.direction,
          amountCents: rt.amountCents,
          bookAt: DateTime.parse(todayKey),
          counterparty: Value(rt.counterparty),
          remark: Value(rt.remark),
          isPending: const Value(true)));
      // 推进：下月同日，若该日超过下月天数则裁剪为月末（dayOfMonth>=28 视为「月末语义」）
      final base = DateTime.parse(todayKey);
      final DateTime next;
      if (rt.dayOfMonth >= 28) {
        next = DateTime(base.year, base.month + 2, 0); // 下月最后一天
      } else {
        next = DateTime(base.year, base.month + 1, rt.dayOfMonth);
      }
      final nextKey = _key(next);
      await (db.update(db.recurringTransactions)..where((t) => t.id.equals(rt.id)))
          .write(RecurringTransactionsCompanion(
              nextRun: Value(nextKey), lastGenerated: Value(todayKey)));
      count++;
    }
    return count;
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}