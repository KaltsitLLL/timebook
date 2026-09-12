import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/util/kv_settings.dart';
import '../../ai/presentation/ai_settings_screen.dart';
import '../data/bookkeeping_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final kvSettingsProvider = Provider<KvSettings>(
    (ref) => KvSettings(const SecureStorage()));

final bookkeepingRepositoryProvider =
    Provider<BookkeepingRepository>((ref) => BookkeepingRepository(ref.read(databaseProvider)));

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(bookkeepingRepositoryProvider);
  final ledgers = await repo.ledgers();
  if (ledgers.isEmpty) return const [];
  return repo.categories(ledgers.first.id);
});

/// 首个账本的账户列表（供记账 Sheet/设置默认账户使用）。
final ledgerAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final repo = ref.watch(bookkeepingRepositoryProvider);
  final ledgers = await repo.ledgers();
  if (ledgers.isEmpty) return const [];
  return repo.accounts(ledgers.first.id);
});

/// 首个账本的默认付款账户 id（读取 kv + 校验存在；无则 null）。
final defaultAccountProvider = FutureProvider<int?>((ref) async {
  final repo = ref.watch(bookkeepingRepositoryProvider);
  final kv = ref.watch(kvSettingsProvider);
  final ledgers = await repo.ledgers();
  if (ledgers.isEmpty) return null;
  final id = await kv.getInt('defaultAccountId:${ledgers.first.id}');
  if (id == null) return null;
  final accts = await repo.accounts(ledgers.first.id);
  return accts.any((a) => a.id == id) ? id : null;
});