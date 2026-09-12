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
}