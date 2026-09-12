/// 可注入存储（测试用内存实现，生产用 SecureStorage）
abstract class KeyValueStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class AISettingsService {
  AISettingsService(this._storage);
  final KeyValueStorage _storage;

  static const defaultEndpoint = 'https://open.bigmodel.cn/api/paas/v4';
  static const _keyKey = 'ai_api_key';
  static const _endpointKey = 'ai_endpoint';

  Future<String?> apiKey() => _storage.read(_keyKey);
  Future<void> saveApiKey(String key) => _storage.write(_keyKey, key);
  Future<void> deleteApiKey() => _storage.delete(_keyKey);

  Future<String> endpoint() async =>
      await _storage.read(_endpointKey) ?? defaultEndpoint;
  Future<void> saveEndpoint(String url) => _storage.write(_endpointKey, url);
}