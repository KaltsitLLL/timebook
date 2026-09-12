import 'dart:ffi';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:timebook/features/ai/data/ai_settings_service.dart';

/// Windows 下 dart/flutter test 需要 sqlite3.dll（存放于仓库根 tools/ 下，
/// 相对 cwd 可能多级，逐个尝试）。
void initTestSqlite() {
  if (Platform.isWindows) {
    const candidates = ['tools/sqlite3.dll', '../tools/sqlite3.dll',
        '../../tools/sqlite3.dll', '../../../tools/sqlite3.dll'];
    for (final rel in candidates) {
      final f = File(rel);
      if (f.existsSync()) {
        open.overrideFor(OperatingSystem.windows,
            () => DynamicLibrary.open(f.absolute.path));
        break;
      }
    }
  }
}

QueryExecutor inMemoryExecutor() => NativeDatabase.memory();

/// 内存 KV：替代 SecureStorage，供 widget/单元测试注入 [kvSettingsProvider]。
class MemoryKeyValueStorage implements KeyValueStorage {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}