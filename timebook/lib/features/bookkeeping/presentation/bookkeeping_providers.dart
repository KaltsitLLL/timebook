import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../data/bookkeeping_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final bookkeepingRepositoryProvider =
    Provider<BookkeepingRepository>((ref) => BookkeepingRepository(ref.read(databaseProvider)));

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(bookkeepingRepositoryProvider);
  final ledgers = await repo.ledgers();
  if (ledgers.isEmpty) return const [];
  return repo.categories(ledgers.first.id);
});