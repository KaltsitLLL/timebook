import 'package:flutter/material.dart';

import '../../ai/presentation/ai_settings_screen.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// 设置页：静态设置列表入口。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.smart_toy_outlined),
          title: const Text('AI 设置'),
          subtitle: const Text('配置 GLM API Key 后可用一句话记账'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AiSettingsScreen())),
        ),
      ]),
    );
  }
}