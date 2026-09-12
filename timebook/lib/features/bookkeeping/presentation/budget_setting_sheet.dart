import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/formats.dart';
import 'bookkeeping_providers.dart';

class BudgetSettingSheet extends ConsumerStatefulWidget {
  const BudgetSettingSheet({super.key});
  @override
  ConsumerState<BudgetSettingSheet> createState() => _BudgetSettingSheetState();
}

class _BudgetSettingSheetState extends ConsumerState<BudgetSettingSheet> {
  final _total = TextEditingController();
  final _food = TextEditingController();

  @override
  void dispose() {
    _total.dispose();
    _food.dispose();
    super.dispose();
  }

  int? _yuanToCents(String raw) {
    final n = double.tryParse(raw.trim());
    return (n != null && n >= 0) ? (n * 100).round() : null;
  }

  Future<void> _save() async {
    if (!mounted) return;
    final repo = ref.read(bookkeepingRepositoryProvider);
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) return;
    final l = ledgers.first.id;
    final month = monthKey(DateTime.now());
    final totalCents = _yuanToCents(_total.text);
    final foodCents = _yuanToCents(_food.text);
    if (totalCents != null) {
      await repo.upsertBudget(ledgerId: l, month: month, amountCents: totalCents);
    }
    final cats = await repo.categories(l);
    final food = cats.where((c) => c.name == '餐饮').toList();
    if (foodCents != null && food.isNotEmpty) {
      await repo.upsertBudget(
          ledgerId: l, categoryId: food.first.id, month: month, amountCents: foodCents);
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 14),
            Text('预算设置', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              key: const Key('total_budget_field'),
              controller: _total,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: '本月总预算（元）',
                  border: OutlineInputBorder(),
                  prefixText: '¥ '),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('food_budget_field'),
              controller: _food,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: '餐饮分类预算（元）',
                  border: OutlineInputBorder(),
                  prefixText: '¥ '),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('save_budget_button'),
              onPressed: _save,
              child: const Text('保存'),
            ),
          ]),
    );
  }
}