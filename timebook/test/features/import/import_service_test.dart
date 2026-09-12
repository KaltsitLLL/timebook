import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/import/data/import_service.dart';
import 'package:timebook/features/import/domain/import_models.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;
  late ImportService svc;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase.forTesting(inMemoryExecutor());
    svc = ImportService(db);
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '生活'));
    await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
  });

  tearDown(() async => db.close());

  ImportedRow row({String? orderId}) => ImportedRow(
      bookAt: DateTime(2026, 9, 12, 12), direction: 'expense',
      amountCents: 2850, counterparty: '美团', orderId: orderId);

  test('confirm 事务落库并写批次留痕', () async {
    final result = await svc.importRows(
        source: 'wechat', fileName: '微信账单.csv',
        rows: [row(orderId: 'WX-1'), row(orderId: 'WX-2')]);
    expect(result.saved, 2);
    expect(result.duplicated, 0);
    final count = await db.transactions.count().getSingle();
    expect(count, 2);
    expect(await db.importBatches.count().getSingle(), 1);
  });

  test('importKey 去重：已存在单号被跳过并计数', () async {
    await svc.importRows(source: 'wechat', fileName: 'a.csv', rows: [row(orderId: 'WX-X')]);
    final result = await svc.importRows(source: 'wechat', fileName: 'b.csv', rows: [row(orderId: 'WX-X')]);
    expect(result.saved, 0);
    expect(result.duplicated, 1);
  });

  test('退款行匹配 order_id 原支出 → 更新 refunded_cents 不新增行', () async {
    await svc.importRows(source: 'wechat', fileName: 'a.csv', rows: [row(orderId: 'WX-P')]);
    final refund = ImportedRow(
        bookAt: DateTime(2026, 9, 13), direction: 'income',
        amountCents: 2850, counterparty: '美团', orderId: 'WX-P-REFUND', isRefund: true);
    final result = await svc.importRows(source: 'wechat', fileName: 'r.csv', rows: [refund]);
    expect(result.saved, 0);
    expect(result.refunded, 1);
    final t = await (db.select(db.transactions)..where((x) => x.orderId.equals('WX-P'))).getSingle();
    expect(t.refundedCents, 2850);
  });

  test('未匹配退款进入 refundUnmatched 供人工处理', () async {
    final refund = ImportedRow(
        bookAt: DateTime(2026, 9, 13), direction: 'income',
        amountCents: 1000, counterparty: '未知单退款', orderId: 'NOPE', isRefund: true);
    final result = await svc.importRows(source: 'wechat', fileName: 'r.csv', rows: [refund]);
    expect(result.saved, 0);
    expect(result.refundUnmatched, 1);
  });

  test('有分类规则时导入自动分类入库（对方命中关键词）', () async {
    final catId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(ledgerId: 1, name: '外卖'));
    await db.into(db.importRules).insert(ImportRulesCompanion.insert(
        keyword: '美团', categoryId: catId, priority: Value(1)));

    final result = await svc.importRows(
        source: 'wechat', fileName: 'a.csv', rows: [row(orderId: 'WX-7')]);
    expect(result.saved, 1);

    final t = await (db.select(db.transactions)..where((x) => x.orderId.equals('WX-7'))).getSingle();
    expect(t.categoryId, catId);
  });

  test('无规则且行无分类 → 兜底归入「未分类」且创建该分类', () async {
    final result = await svc.importRows(
        source: 'wechat', fileName: 'a.csv', rows: [row(orderId: 'WX-U')]);
    expect(result.saved, 1);

    final t = await (db.select(db.transactions)..where((x) => x.orderId.equals('WX-U'))).getSingle();

    final uncat = await (db.select(db.categories)
          ..where((c) => c.ledgerId.equals(1) & c.name.equals('未分类')))
        .getSingle();
    expect(t.categoryId, uncat.id);
  });

  test('有规则命中时仍走规则，不落到「未分类」兜底', () async {
    final catId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(ledgerId: 1, name: '外卖'));
    await db.into(db.importRules).insert(ImportRulesCompanion.insert(
        keyword: '美团', categoryId: catId, priority: Value(1)));

    await svc.importRows(
        source: 'wechat', fileName: 'a.csv', rows: [row(orderId: 'WX-8')]);
    final t = await (db.select(db.transactions)..where((x) => x.orderId.equals('WX-8'))).getSingle();
    expect(t.categoryId, catId);

    final uncat = await (db.select(db.categories)
          ..where((c) => c.name.equals('未分类')))
        .get();
    expect(uncat, isEmpty);
  });
}