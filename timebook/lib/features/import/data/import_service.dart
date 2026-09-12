import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../domain/import_models.dart';

class ImportOutcome {
  ImportOutcome(
      {this.saved = 0,
      this.duplicated = 0,
      this.refunded = 0,
      this.refundUnmatched = 0});
  int saved;
  int duplicated;
  int refunded;
  int refundUnmatched;
}

class ImportService {
  ImportService(this.db);
  final AppDatabase db;

  Future<ImportOutcome> importRows({
    required String source,
    required String fileName,
    required List<ImportedRow> rows,
    int? priorityLedgerId,
  }) async {
    final outcome = ImportOutcome();
    await db.transaction(() async {
      final ledgers = await db.select(db.ledgers).get();
      if (ledgers.isEmpty) throw StateError('请先创建账本');
      final ledgerId = priorityLedgerId ?? ledgers.first.id;

      // 默认账户：取该账本第一个账户；无账户则抛错（外键完整性），由上层捕获。
      final account = await (db.select(db.accounts)
            ..where((a) => a.ledgerId.equals(ledgerId)))
          .getSingleOrNull();
      if (account == null) throw StateError('请先创建账户');

      for (final r in rows) {
        if (r.isRefund) {
          final matched = await _applyRefund(ledgerId, r);
          if (matched) {
            outcome.refunded++;
          } else {
            outcome.refundUnmatched++;
          }
          continue;
        }
        final oid = r.orderId;
        if (oid != null) {
          final dup = await (db.select(db.transactions)
                ..where((t) =>
                    t.ledgerId.equals(ledgerId) & t.orderId.equals(oid)))
              .get();
          if (dup.isNotEmpty) {
            outcome.duplicated++;
            continue;
          }
        }
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          accountId: account.id,
          direction: r.direction,
          amountCents: r.amountCents,
          bookAt: r.bookAt,
          counterparty: Value(r.counterparty),
          remark: Value(r.remark),
          payMethod: Value(r.payMethod),
          orderId: Value(r.orderId),
          importKey: r.orderId == null ? const Value(null) : Value(r.orderId),
        ));
        outcome.saved++;
      }

      await db.into(db.importBatches).insert(ImportBatchesCompanion.insert(
          source: source,
          fileName: fileName,
          okRows: Value(outcome.saved),
          dupRows: Value(outcome.duplicated),
          errorRows: Value(outcome.refundUnmatched)));
    });
    return outcome;
  }

  Future<bool> _applyRefund(int ledgerId, ImportedRow r) async {
    if (r.orderId == null) return false;
    final base = _stripRefundSuffix(r.orderId!);
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) & t.orderId.equals(base)))
        .get();
    if (rows.isEmpty) return false;
    final target = rows.first;
    final newRefund =
        (target.refundedCents + r.amountCents).clamp(0, target.amountCents);
    await (db.update(db.transactions)..where((t) => t.id.equals(target.id)))
        .write(TransactionsCompanion(refundedCents: Value(newRefund)));
    return true;
  }

  String _stripRefundSuffix(String id) =>
      id.endsWith('-REFUND')
          ? id.substring(0, id.length - '-REFUND'.length)
          : id;
}