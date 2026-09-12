import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import 'bookkeeping_providers.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});
  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amount = TextEditingController();
  String _direction = 'expense';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? _amountCents(String raw) {
    final n = double.tryParse(raw.trim());
    if (n == null || n <= 0) return null;
    return (n * 100).round();
  }

  Future<void> _save() async {
    final cents = _amountCents(_amount.text);
    if (cents == null) return; // 校验失败：不落库（测试即验证此行为）
    final repo = ref.read(bookkeepingRepositoryProvider);
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) return;
    final accounts = await repo.accounts(ledgers.first.id);
    if (accounts.isEmpty) return;
    await repo.addTransaction(
      ledgerId: ledgers.first.id,
      accountId: accounts.first.id,
      direction: _direction,
      amountCents: cents,
      bookAt: DateTime.now(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已记账')));
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('记一笔', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'expense', label: Text('支出')),
            ButtonSegment(value: 'income', label: Text('收入')),
          ],
          selected: {_direction},
          onSelectionChanged: (s) => setState(() => _direction = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('amount_field'),
          controller: _amount,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '金额（元）',
            border: OutlineInputBorder(),
            prefixText: '¥ ',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cats.isEmpty
              ? const [Text('暂无分类，可在后续里程碑管理')]
              : [
                  for (final c in cats.take(6))
                    ChoiceChip(
                        label: Text(c.name), selected: false, onSelected: (_) {}),
                ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('save_button'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ]),
    );
  }
}