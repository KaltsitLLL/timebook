import 'package:flutter/material.dart';

/// 关于页：展示版本、开源许可与仓库地址。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// 版本号（硬编码，未引入 package_info_plus；如需自动读取后续接入）。
  static const String version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: Column(children: [
            const SizedBox(height: 8),
            Icon(Icons.account_balance_wallet_outlined,
                size: 56, color: scheme.primary),
            const SizedBox(height: 8),
            const Text('时账 TimeBook',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('版本 $version（硬编码）',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('数据说明',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('MIT 开源 · 本地优先 · 数据自主'),
        const SizedBox(height: 24),
        const Text('仓库地址', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const SelectableText('https://github.com/KaltsitLLL/timebook'),
      ]),
    );
  }
}