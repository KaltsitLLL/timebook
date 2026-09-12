import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/core/util/formats.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import '../data/recurring_repository.dart';

/// 周期记账：自动生成的周期规则列表 + 新增/启用/停用/删除。
class RecurringRulesScreen extends ConsumerStatefulWidget {
  const RecurringRulesScreen({super.key, required this.database});
  final AppDatabase database;
  @override
  ConsumerState<RecurringRulesScreen> createState() =>
      _RecurringRulesScreenState();
}

class _RecurringRulesScreenState extends ConsumerState<RecurringRulesScreen> {
  late final RecurringRepository _repo;
  late final BookkeepingRepository _bk;
  late Future<List<RecurringTransaction>> _future;

  @override
  void initState() {
    super.initState();
    _bk = BookkeepingRepository(widget.database);
    _repo = RecurringRepository(widget.database);
    _runDueThenLoad();
  }

  void _runDueThenLoad() {
    // 进入时先跑一次到期生成（不阻塞列表展示）。
    Future(() => _repo.runDue());
    _future = _repo.recurringAll();
  }

  void _reload() {
    setState(() {
      _future = _repo.recurringAll();
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(RecurringTransaction rt, bool v) async {
    await _repo.toggleRecurring(rt.id, v);
    _reload();
  }

  Future<void> _delete(RecurringTransaction rt) async {
    await _repo.deleteRecurring(rt.id);
    _reload();
  }

  Future<void> _openAddSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecurringAddSheet(onSave: _save),
    );
    if (saved == true) _reload();
  }

  Future<bool> _save(_NewRule data) async {
    final ledgers = await _bk.ledgers();
    if (ledgers.isEmpty) {
      _message('请先创建账本');
      return false;
    }
    final ledgerId = ledgers.first.id;
    final accounts = await _bk.accounts(ledgerId);
    if (accounts.isEmpty) {
      _message('请先创建账户');
      return false;
    }
    await _repo.upsertRecurring(
      ledgerId: ledgerId,
      accountId: accounts.first.id,
      direction: data.direction,
      amountCents: data.amountCents,
      counterparty: data.counterparty,
      remark: data.remark,
      dayOfMonth: data.dayOfMonth,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('周期记账')),
      body: FutureBuilder<List<RecurringTransaction>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              Center(child: Text('暂无周期规则，点击下方「+ 新增规则」添加')),
            ]);
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final rt = rows[i];
              return ListTile(
                title: Text(
                    rt.counterparty.isEmpty ? '未命名' : rt.counterparty),
                subtitle: Text('¥${formatCents(rt.amountCents)}/月 · '
                    '每月${rt.dayOfMonth}日 · ${rt.direction == 'income' ? '收入' : '支出'}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(
                    key: Key('rr_toggle_${rt.id}'),
                    value: rt.active,
                    onChanged: (v) => _toggle(rt, v),
                  ),
                  IconButton(
                    key: Key('rr_del_${rt.id}'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(rt),
                  ),
                ]),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.tonalIcon(
            key: const Key('rr_add'),
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add),
            label: const Text('+ 新增规则'),
          ),
        ),
      ),
    );
  }
}

class _NewRule {
  _NewRule({
    required this.amountCents,
    required this.counterparty,
    required this.remark,
    required this.dayOfMonth,
    required this.direction,
  });
  final int amountCents;
  final String counterparty;
  final String remark;
  final int dayOfMonth;
  final String direction;
}

class _RecurringAddSheet extends StatefulWidget {
  const _RecurringAddSheet({required this.onSave});
  final Future<bool> Function(_NewRule data) onSave;
  @override
  State<_RecurringAddSheet> createState() => _RecurringAddSheetState();
}

class _RecurringAddSheetState extends State<_RecurringAddSheet> {
  final _amount = TextEditingController();
  final _counterparty = TextEditingController();
  final _remark = TextEditingController();
  final _day = TextEditingController(text: '1');
  String _direction = 'expense';
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _counterparty.dispose();
    _remark.dispose();
    _day.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    final day = int.tryParse(_day.text.trim()) ?? 1;
    if (day < 1 || day > 31) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('每月日期需在 1-31 之间')));
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSave(_NewRule(
      amountCents: (amount * 100).round(),
      counterparty: _counterparty.text.trim(),
      remark: _remark.text.trim(),
      dayOfMonth: day,
      direction: _direction,
    ));
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('新增周期规则', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('rr_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '金额（元）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('rr_counterparty'),
            controller: _counterparty,
            decoration: const InputDecoration(labelText: '对方', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('rr_remark'),
            controller: _remark,
            decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('rr_day'),
            controller: _day,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: '每月几号（1-31）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('支出'), icon: Icon(Icons.arrow_upward)),
              ButtonSegment(value: 'income', label: Text('收入'), icon: Icon(Icons.arrow_downward)),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('rr_save'),
            onPressed: _saving ? null : _submit,
            child: const Text('保存'),
          ),
        ]),
      ),
    );
  }
}