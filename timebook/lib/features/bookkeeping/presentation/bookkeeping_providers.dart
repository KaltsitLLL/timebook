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
  final ledgerId = await ref.watch(currentLedgerProvider.future);
  if (ledgerId == null) return const [];
  var cats = await repo.categories(ledgerId);
  if (cats.isEmpty) {
    // 兜底：既有账本无分类时自动预置默认分类（对齐原型 8 分类）
    await repo.ensureDefaultCategories(ledgerId);
    cats = await repo.categories(ledgerId);
  }
  return cats;
});

/// 首个账本的账户列表（供记账 Sheet/设置默认账户使用）。
final ledgerAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final repo = ref.watch(bookkeepingRepositoryProvider);
  final ledgers = await repo.ledgers();
  if (ledgers.isEmpty) return const [];
  return repo.accounts(ledgers.first.id);
});

/// 首账本的默认付款账户 id（读取 kv + 校验存在；无则 null）。
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

/// 当前账本 id：优先 kv `currentLedgerId`，否则回退首个账本；无账本 → null。
/// kv 读取失败/超时（如测试环境无安全存储导致挂起）时静默回退首账本，
/// 保证基本功能可用；测试可通过 override 本 provider 直接指定当前账本。
final currentLedgerProvider = FutureProvider<int?>((ref) async {
  final repo = ref.watch(bookkeepingRepositoryProvider);
  final kv = ref.watch(kvSettingsProvider);
  int? current;
  try {
    current =
        await kv.getInt('currentLedgerId').timeout(const Duration(seconds: 2));
  } catch (_) {
    current = null;
  }
  if (current != null) return current;
  final ledgers = await repo.ledgers();
  if (ledgers.isEmpty) return null;
  return ledgers.first.id;
});