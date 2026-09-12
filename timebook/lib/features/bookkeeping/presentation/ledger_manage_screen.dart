import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import 'bookkeeping_providers.dart';

/// 账本管理：切换当前账本、新建账本。
class LedgerManageScreen extends ConsumerStatefulWidget {
  const LedgerManageScreen({super.key});
  @override
  ConsumerState<LedgerManageScreen> createState() =>
      _LedgerManageScreenState();
}

class _LedgerManageScreenState extends ConsumerState<LedgerManageScreen> {
  List<Ledger> _ledgers = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final repo = ref.read(bookkeepingRepositoryProvider);
    final ls = await repo.ledgers();
    if (!mounted) return;
    setState(() {
      _ledgers = ls;
      _loaded = true;
    });
  }

  Future<int?> _currentId() =>
      ref.read(kvSettingsProvider).getInt('currentLedgerId');

  Future<void> _setCurrent(int id) async {
    await ref.read(kvSettingsProvider).setInt('currentLedgerId', id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已切换为当前账本')));
  }

  Future<void> _addLedger() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewLedgerSheet(),
    );
    if (name == null || name.isEmpty) return;
    final repo = ref.read(bookkeepingRepositoryProvider);
    final id = await repo.createLedger(name: name);
    await ref.read(kvSettingsProvider).setInt('currentLedgerId', id);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账本管理')),
      body: FutureBuilder<int?>(
        future: _currentId(),
        builder: (context, snap) {
          final currentId = snap.data;
          return ListView(children: [
            for (final l in _ledgers)
              ListTile(
                key: Key('ledger_${l.id}'),
                title: Text(l.name),
                trailing: currentId == l.id
                    ? const Text('当前',
                        style: TextStyle(fontSize: 12, color: Colors.grey))
                    : const Icon(Icons.chevron_right),
                onTap: currentId == l.id ? null : () => _setCurrent(l.id),
              ),
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                key: const Key('ledger_add'),
                onPressed: _addLedger,
                icon: const Icon(Icons.add),
                label: const Text('新建账本'),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// 新建账本名称输入 Sheet。
class _NewLedgerSheet extends StatefulWidget {
  const _NewLedgerSheet();
  @override
  State<_NewLedgerSheet> createState() => _NewLedgerSheetState();
}

class _NewLedgerSheetState extends State<_NewLedgerSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('ledger_name'),
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '账本名称'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消')),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('ledger_save'),
                  onPressed: () =>
                      Navigator.of(context).pop(_ctrl.text.trim()),
                  child: const Text('创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}