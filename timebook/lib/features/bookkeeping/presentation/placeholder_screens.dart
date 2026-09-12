import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/presentation/ai_settings_screen.dart';
import '../../import/presentation/import_screen.dart';
import '../../import/presentation/recurring_rules_screen.dart';
import 'bookkeeping_providers.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// 设置页：静态设置列表入口。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        ListTile(
          key: const Key('import_export_entry'),
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('导入导出'),
          subtitle: const Text('微信/支付宝 CSV 导入 · 全量导出'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  ImportScreen(database: ref.read(databaseProvider)))),
        ),
        ListTile(
          key: const Key('recurring_entry'),
          leading: const Icon(Icons.autorenew),
          title: const Text('周期记账'),
          subtitle: const Text('自动生成每月固定收支流水'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  RecurringRulesScreen(database: ref.read(databaseProvider)))),
        ),
      ]),
    );
  }
}