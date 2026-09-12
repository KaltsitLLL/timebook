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
  final _periodStart = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _initPeriodStart();
  }

  Future<void> _initPeriodStart() async {
    final repo = ref.read(bookkeepingRepositoryProvider);
    final day = await repo.periodStartDay();
    if (mounted) _periodStart.text = '$day';
  }

  @override
  void dispose() {
    _total.dispose();
    _food.dispose();
    _periodStart.dispose();
    super.dispose();
  }

  int? _yuanToCents(String raw) {
    final n = double.tryParse(raw.trim());
    return (n != null && n >= 0) ? (n * 100).round() : null;
  }

  Future<int?> _ledgerId(WidgetRef ref) async {
    final ledgers = await ref.read(bookkeepingRepositoryProvider).ledgers();
    return ledgers.isEmpty ? null : ledgers.first.id;
  }

  Future<void> _save() async {
    if (!mounted) return;
    final repo = ref.read(bookkeepingRepositoryProvider);
    final l = await _ledgerId(ref);
    if (l == null) return;
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
    final startDay = int.tryParse(_periodStart.text.trim()) ?? 1;
    await repo.setPeriodStartDay(startDay.clamp(1, 28).toInt());
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  Future<void> _setDefault() async {
    if (!mounted) return;
    final repo = ref.read(bookkeepingRepositoryProvider);
    final l = await _ledgerId(ref);
    if (l == null) return;
    final totalCents = _yuanToCents(_total.text) ?? 0;
    final foodCents = _yuanToCents(_food.text);
    final cats = await repo.categories(l);
    final food = cats.where((c) => c.name == '餐饮').toList();
    await repo.saveDefaultBudget(
      totalCents: totalCents,
      catCents: {
        if (foodCents != null && food.isNotEmpty) food.first.id: foodCents,
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已设为默认预算')));
  }

  Future<void> _inheritLastMonth() async {
    if (!mounted) return;
    final repo = ref.read(bookkeepingRepositoryProvider);
    final l = await _ledgerId(ref);
    if (l == null) return;
    final nowMonth = monthKey(DateTime.now());
    final lastMonth = prevMonthKey(nowMonth);
    final lastBudgets =
        await repo.budgetsForMonth(ledgerId: l, month: lastMonth);
    for (final b in lastBudgets) {
      await repo.upsertBudget(
          ledgerId: l,
          categoryId: b.categoryId,
          month: nowMonth,
          amountCents: b.amountCents);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lastBudgets.isEmpty
            ? '上月无预算可沿用'
            : '已沿用上月预算')));
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
            const SizedBox(height: 12),
            TextField(
              key: const Key('period_start_field'),
              controller: _periodStart,
              keyboardType: const TextInputType.numberWithOptions(),
              decoration: const InputDecoration(
                  labelText: '周期起始日（1-28，默认 1 = 自然月）',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('set_default_budget'),
                  onPressed: _setDefault,
                  child: const Text('设为默认'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const Key('inherit_last_month'),
                  onPressed: _inheritLastMonth,
                  child: const Text('沿用上月'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('save_budget_button'),
              onPressed: _save,
              child: const Text('保存'),
            ),
          ]),
    );
  }
}