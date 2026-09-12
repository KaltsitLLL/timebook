import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../../bookkeeping/data/bookkeeping_repository.dart';
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
    final repo = BookkeepingRepository(db);
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
          final matched =
              await _applyRefund(ledgerId, r, repo, account.id);
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
        final txId = await repo.addTransaction(
          ledgerId: ledgerId,
          accountId: account.id,
          categoryId: r.categoryId,
          direction: r.direction,
          amountCents: r.amountCents,
          bookAt: r.bookAt,
          counterparty: r.counterparty,
          remark: r.remark,
          payMethod: r.payMethod,
          orderId: r.orderId,
          importKey: r.orderId,
          applyRules: true,
        );
        // 分类兜底：无显式分类且规则引擎未命中时归入「未分类」，导入行绝不落空
        // categoryId（仅在导入主流程；退款冲抵路径不建行、不兜底）。
        if (r.categoryId == null) {
          final tx = await (db.select(db.transactions)
                ..where((t) => t.id.equals(txId)))
              .getSingle();
          if (tx.categoryId == null) {
            final uncatId = await repo.ensureCategoryByName(ledgerId, '未分类');
            await (db.update(db.transactions)..where((t) => t.id.equals(txId)))
                .write(TransactionsCompanion(categoryId: Value(uncatId)));
          }
        }
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

  Future<bool> _applyRefund(
      int ledgerId, ImportedRow r, BookkeepingRepository repo, int accountId) async {
    final target = await _matchRefundTarget(ledgerId, r);
    if (target == null) return false;

    // 幂等：同账本同导入单号已建过条目则跳过（同批次/跨批次重导入不重复建条目）。
    if (r.orderId != null) {
      final dup = await (db.select(db.refundEntries)
            ..where((e) =>
                e.ledgerId.equals(ledgerId) & e.importKey.equals(r.orderId!)))
          .get();
      if (dup.isNotEmpty) return true;
    }

    await repo.upsertRefund(
      ledgerId: ledgerId,
      transactionId: target.id,
      amountCents: r.amountCents,
      accountId: accountId,
      importKey: r.orderId,
      bookAt: r.bookAt,
      settledAt: _settledAtFor(r.bookAt),
    );
    return true;
  }

  /// 退款目标解析：优先按单号（`-REFUND` 后缀指向原单号）；失败后按
  /// 「同账本 + 金额相等 + 方向相反 + 日期差 ≤7 天 + 唯一候选」启发匹配。
  Future<Transaction?> _matchRefundTarget(int ledgerId, ImportedRow r) async {
    if (r.orderId != null) {
      final base = _stripRefundSuffix(r.orderId!);
      final rows = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(ledgerId) & t.orderId.equals(base)))
          .get();
      if (rows.isNotEmpty) return rows.first;
    }
    final candidates = await _heuristicCandidates(ledgerId, r);
    return candidates.length == 1 ? candidates.first : null;
  }

  Future<List<Transaction>> _heuristicCandidates(
      int ledgerId, ImportedRow r) async {
    final opposite = _oppositeDirection(r.direction);
    if (opposite == null) return const [];
    final rows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    return [
      for (final t in rows)
        if (t.amountCents == r.amountCents &&
            t.direction == opposite &&
            (r.bookAt.difference(t.bookAt).inDays).abs() <= 7)
          t,
    ];
  }

  String? _oppositeDirection(String d) {
    switch (d) {
      case 'income':
        return 'expense';
      case 'expense':
        return 'income';
      default:
        return null;
    }
  }

  /// 导入退款记录无独立到账时间字段，视为「当日已到账」，取当日 23:59:59.999。
  DateTime _settledAtFor(DateTime bookAt) =>
      DateTime(bookAt.year, bookAt.month, bookAt.day, 23, 59, 59, 999);

  String _stripRefundSuffix(String id) =>
      id.endsWith('-REFUND')
          ? id.substring(0, id.length - '-REFUND'.length)
          : id;
}