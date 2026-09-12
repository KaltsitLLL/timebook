import '../../features/ai/data/ai_settings_service.dart';

/// 轻量 KV 设置读写：复用 ai 域 [KeyValueStorage] 抽象
/// （生产 SecureStorage，测试可注入内存实现），暴露类型化读取。
class KvSettings {
  KvSettings(this.storage);
  final KeyValueStorage storage;

  Future<int?> getInt(String key) async {
    final v = await storage.read(key);
    if (v == null) return null;
    return int.tryParse(v);
  }

  Future<void> setInt(String key, int value) =>
      storage.write(key, value.toString());

  Future<bool> getBool(String key) async => await storage.read(key) == '1';

  Future<void> setBool(String key, bool value) =>
      storage.write(key, value ? '1' : '0');

  Future<String?> getString(String key) async => storage.read(key);

  Future<void> setString(String key, String value) =>
      storage.write(key, value);
}