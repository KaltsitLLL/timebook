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