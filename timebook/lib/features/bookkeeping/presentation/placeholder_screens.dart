import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../ai/presentation/ai_settings_screen.dart';
import '../../import/presentation/import_screen.dart';
import '../../import/presentation/recurring_rules_screen.dart';
import 'bookkeeping_providers.dart';
import 'rules_screen.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// 设置页：静态设置列表入口 + 默认付款账户 + 记账提醒。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _defaultAccountName;

  Future<void> _pickDefaultAccount() async {
    final repo = ref.read(bookkeepingRepositoryProvider);
    final kv = ref.read(kvSettingsProvider);
    final ledgers = await repo.ledgers();
    if (!mounted) return;
    if (ledgers.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先创建账本')));
      return;
    }
    final ledgerId = ledgers.first.id;
    final accts = await repo.accounts(ledgerId);
    if (!mounted) return;
    if (accts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂无账户，请先添加')));
      return;
    }
    final current = await kv.getInt('defaultAccountId:$ledgerId');
    if (!mounted) return;
    final selected = await showDialog<int?>(
      context: context,
      builder: (_) =>
          _DefaultAccountDialog(accounts: accts, selectedId: current),
    );
    if (selected == null) return;
    await kv.setInt('defaultAccountId:$ledgerId', selected);
    String? name;
    for (final a in accts) {
      if (a.id == selected) name = a.name;
    }
    if (!mounted) return;
    setState(() => _defaultAccountName = name);
  }

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
        ListTile(
          key: const Key('default_account_entry'),
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('默认付款账户'),
          subtitle: Text(_defaultAccountName ?? '未设置（记账时默认第一个账户）'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickDefaultAccount,
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
        ListTile(
          key: const Key('rules_entry'),
          leading: const Icon(Icons.rule),
          title: const Text('分类规则'),
          subtitle: const Text('按关键词自动分类导入流水'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  RulesScreen(database: ref.read(databaseProvider)))),
        ),
      ]),
    );
  }
}

// ---- 账户单选保存 Dialog ----
class _DefaultAccountDialog extends StatefulWidget {
  const _DefaultAccountDialog({required this.accounts, this.selectedId});
  final List<Account> accounts;
  final int? selectedId;
  @override
  State<_DefaultAccountDialog> createState() => _DefaultAccountDialogState();
}

class _DefaultAccountDialogState extends State<_DefaultAccountDialog> {
  int? _sel;

  @override
  void initState() {
    super.initState();
    _sel = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('选择默认付款账户'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final a in widget.accounts)
                  ListTile(
                    key: Key('default_account_${a.id}'),
                    leading: Icon(
                      _sel == a.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: _sel == a.id
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(a.name),
                    onTap: () => setState(() => _sel = a.id),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消')),
            FilledButton(
              key: const Key('default_account_save'),
              onPressed: () => Navigator.of(context).pop(_sel),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}