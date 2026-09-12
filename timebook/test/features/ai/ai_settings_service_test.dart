import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/ai/data/ai_settings_service.dart';

class MemStorage implements KeyValueStorage {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

void main() {
  test('保存与读取 Key/Endpoint，默认端点', () async {
    final svc = AISettingsService(MemStorage());
    expect(await svc.endpoint(), 'https://open.bigmodel.cn/api/paas/v4');
    await svc.saveEndpoint('https://example.com/v1');
    await svc.saveApiKey('sk-test');
    expect(await svc.apiKey(), 'sk-test');
    expect(await svc.endpoint(), 'https://example.com/v1');
  });

  test('清除 Key', () async {
    final svc = AISettingsService(MemStorage());
    await svc.saveApiKey('sk-1');
    await svc.deleteApiKey();
    expect(await svc.apiKey(), isNull);
  });
}