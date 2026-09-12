import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../data/daily_summary_service.dart';

final dailyDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final dailySummaryServiceProvider = Provider<DailySummaryService>(
    (ref) => DailySummaryService(ref.read(dailyDatabaseProvider)));