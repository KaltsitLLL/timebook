import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../data/focus_repository.dart';

final focusDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final focusRepositoryProvider =
    Provider<FocusRepository>((ref) => FocusRepository(ref.read(focusDatabaseProvider)));

/// 可注入的时钟源：生产用 [DateTime.now]；测试中 override 为可控假时钟，
/// 以便 widget 测试用 `tester.pump` 推进倒计时（fake-async 不会前进 DateTime.now()）。
final focusClockProvider = Provider<DateTime Function()>((_) => DateTime.now);