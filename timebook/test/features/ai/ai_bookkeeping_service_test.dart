import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/ai/domain/ai_bookkeeping_service.dart';
import 'package:timebook/features/ai/domain/ai_models.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;
  late AiBookkeepingService svc;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase.forTesting(inMemoryExecutor());
    svc = AiBookkeepingService(db);
  });

  tearDown(() async => db.close());

  test('confirm 将草稿落库为支出（分类名模糊匹配）', () async {
    final l = await svc.createLedgerIfEmpty(name: '生活');
    await db.into(db.accounts)
        .insert(AccountsCompanion.insert(ledgerId: l, name: '卡'));
    final food = await db.into(db.categories).insert(
        CategoriesCompanion.insert(ledgerId: l, name: '餐饮'));

    final draft = AiDraft(direction: 'expense', amountCents: 2850,
        counterparty: '美团外卖', category: '餐饮');
    await svc.confirm(draft);

    final rows = await db.select(db.transactions).get();
    expect(rows.single.amountCents, 2850);
    expect(rows.single.categoryId, food);
    expect(rows.single.isPending, isFalse);
  });

  test('分类未匹配 → categoryId 为空仍可落库', () async {
    final l = await svc.createLedgerIfEmpty(name: '生活');
    await db.into(db.accounts)
        .insert(AccountsCompanion.insert(ledgerId: l, name: '卡'));
    await db.into(db.categories)
        .insert(CategoriesCompanion.insert(ledgerId: l, name: '餐饮'));
    await svc.confirm(const AiDraft(direction: 'income', amountCents: 100));
    final rows = await db.select(db.transactions).get();
    expect(rows.single.direction, 'income');
  });
}