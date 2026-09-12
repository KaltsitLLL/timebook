import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../ai/presentation/ai_settings_screen.dart';
import '../../focus/presentation/focus_providers.dart';
import '../../import/presentation/import_screen.dart';
import '../../import/presentation/recurring_rules_screen.dart';
import 'about_screen.dart';
import 'bookkeeping_providers.dart';
import 'ledger_manage_screen.dart';
import 'rules_screen.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// 记账提醒配置结果。
class _ReminderChoice {
  const _ReminderChoice({required this.on, required this.time});
  final bool on;
  final TimeOfDay time;
}

/// 设置页：静态设置列表入口 + 默认付款账户 + 记账提醒。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _defaultAccountName;
  bool _reminderOn = false;

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

  Future<void> _editReminder() async {
    final kv = ref.read(kvSettingsProvider);
    final currentOn = await kv.getBool('reminder_on');
    if (!mounted) return;
    final result = await showDialog<_ReminderChoice>(
      context: context,
      builder: (_) => _ReminderDialog(initialOn: currentOn),
    );
    if (result == null) return;
    await kv.setBool('reminder_on', result.on);
    if (result.on) {
      final ns = ref.read(notificationServiceProvider);
      await ns.scheduleDaily(
        id: 1001,
        title: '记账提醒',
        body: '记得记录今天的收支',
        time: result.time,
      );
    }
    if (!mounted) return;
    setState(() => _reminderOn = result.on);
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
          key: const Key('reminder_entry'),
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('记账提醒'),
          subtitle: Text(_reminderOn ? '每天 21:00 提醒记账' : '未开启'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _editReminder,
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
          key: const Key('ledger_entry'),
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('账本管理'),
          subtitle: const Text('多账本 · 切换 · 新建'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const LedgerManageScreen())),
        ),
        ListTile(
          key: const Key('about_entry'),
          leading: const Icon(Icons.info_outline),
          title: const Text('关于'),
          subtitle: const Text('版本 · 开源许可'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AboutScreen())),
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

// ---- 记账提醒 Dialog ----
class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({required this.initialOn});
  final bool initialOn;
  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late bool _on;
  final TimeOfDay _time = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    _on = widget.initialOn;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('记账提醒'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            key: const Key('reminder_on'),
            value: _on,
            onChanged: (v) => setState(() => _on = v),
            title: const Text('每日记账提醒'),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('提醒时间'),
            trailing: Text(
              '${_time.hour.toString().padLeft(2, '0')}:'
              '${_time.minute.toString().padLeft(2, '0')}',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        FilledButton(
          key: const Key('reminder_save'),
          onPressed: () => Navigator.of(context)
              .pop(_ReminderChoice(on: _on, time: _time)),
          child: const Text('保存'),
        ),
      ],
    );
  }
}