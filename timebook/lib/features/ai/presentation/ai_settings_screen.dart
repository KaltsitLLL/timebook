import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/ai_settings_service.dart';

/// 生产环境 SecureStorage 实现（Windows DPAPI / 移动 Keystore）。
class SecureStorage implements KeyValueStorage {
  const SecureStorage();
  static const _s = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});
  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _svc = AISettingsService(const SecureStorage());
  late final TextEditingController _key;
  late final TextEditingController _endpoint;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController();
    _endpoint = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final k = await _svc.apiKey();
    final e = await _svc.endpoint();
    if (!mounted) return;
    setState(() {
      _key.text = k ?? '';
      _endpoint.text = e;
    });
  }

  @override
  void dispose() {
    _key.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_key.text.trim().isNotEmpty) {
      await _svc.saveApiKey(_key.text.trim());
    }
    if (_endpoint.text.trim().isNotEmpty) {
      await _svc.saveEndpoint(_endpoint.text.trim());
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 设置')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            key: const Key('ai_key_field'),
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'GLM API Key',
              hintText: 'sk-...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('ai_endpoint_field'),
            controller: _endpoint,
            decoration: const InputDecoration(
              labelText: 'API 端点',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Key 保存于安全存储（Windows DPAPI / 移动 Keystore），仅用于记账文本请求。智谱 Key 请到 open.bigmodel.cn 申请。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Spacer(),
          FilledButton(
            key: const Key('ai_settings_save'),
            onPressed: _save,
            child: const Text('保存'),
          ),
        ]),
      ),
    );
  }
}