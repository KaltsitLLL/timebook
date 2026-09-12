import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import 'ai_models.dart';

class AiBookkeepingService {
  AiBookkeepingService(this.db);
  final AppDatabase db;

  Future<int> createLedgerIfEmpty({required String name}) async {
    final ledgers = await db.select(db.ledgers).get();
    if (ledgers.isNotEmpty) return ledgers.first.id;
    return db.into(db.ledgers).insert(LedgersCompanion.insert(name: name));
  }

  /// 分类名模糊匹配（包含匹配返回首个命中）。
  Future<int?> _matchCategory(int ledgerId, String? name) async {
    if (name == null || name.isEmpty) return null;
    final cats = await (db.select(db.categories)..where((t) => t.ledgerId.equals(ledgerId))).get();
    final hit = cats.where((c) => c.name.contains(name) || name.contains(c.name)).toList();
    return hit.isEmpty ? null : hit.first.id;
  }

  Future<void> confirm(AiDraft draft) async {
    final ledgerId = await createLedgerIfEmpty(name: '生活');
    final accounts = await (db.select(db.accounts)..where((t) => t.ledgerId.equals(ledgerId))).get();
    if (accounts.isEmpty) throw StateError('请先创建账户');
    final categoryId = await _matchCategory(ledgerId, draft.category);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: ledgerId,
        accountId: accounts.first.id,
        categoryId: Value(categoryId),
        direction: draft.direction,
        amountCents: draft.amountCents,
        bookAt: draft.bookAt ?? DateTime.now(),
        counterparty: Value(draft.counterparty),
        remark: Value(draft.remark)));
  }
}