import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/formats.dart';
import '../data/bookkeeping_repository.dart';
import 'bookkeeping_providers.dart';
import 'budget_period_helper.dart';
import 'budget_setting_sheet.dart';

/// 分类预算行图标色块调色板（与首页环形图冷色调一致）。
const List<Color> _catPalette = [
  Color(0xFF5B9BD5), Color(0xFF4DB6AC), Color(0xFF5C6BC0),
  Color(0xFF8F9AD1), Color(0xFF4A7DB0), Color(0xFF7FB3D5),
];

IconData _catIcon(String name) {
  switch (name) {
    case 'restaurant': return Icons.restaurant;
    case 'shopping': return Icons.shopping_bag;
    case 'directions_bus': return Icons.directions_bus;
    case 'movie': return Icons.movie;
    case 'home': return Icons.home;
    case 'medical_services': return Icons.medical_services;
    case 'payments': return Icons.payments;
    case 'more_horiz': return Icons.more_horiz;
    default: return Icons.receipt_long;
  }
}

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookkeepingRepositoryProvider);
    final currentFuture = ref.watch(currentLedgerProvider.future);
    return Scaffold(
      appBar: AppBar(title: const Text('预算')),
      body: FutureBuilder(
        future: currentFuture.then((id) => _load(repo, id)),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          final p = data.$1;
          final periodLabel = data.$2;
          final catMap = data.$3;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(periodLabel,
                  key: const Key('period_label'),
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              _totalCard(context, p),
              const SizedBox(height: 12),
              Row(children: [
                Text('分类预算', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openSettings(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('编辑'),
                ),
              ]),
              for (final line in p.lines)
                _lineTile(context, line, catMap[line.categoryId]),
              if (p.lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('未设置分类预算，点「编辑」添加',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<(BudgetProgress, String, Map<int?, (Color, IconData)>)> _load(
      BookkeepingRepository repo, int? ledgerId) async {
    final now = DateTime.now();
    final startDay = await repo.periodStartDay();
    final range = periodRangeFor(now, startDay);
    final label =
        '本期（${range.start.month}/${range.start.day}–${range.end.month}/${range.end.day}）';
    if (ledgerId == null) {
      return (
        const BudgetProgress(
            totalBudgetCents: 0,
            totalSpentCents: 0,
            lines: [],
            remainingDailyCents: 0),
        label,
        const <int?, (Color, IconData)>{}
      );
    }
    final s = await repo.budgetProgress(
        ledgerId: ledgerId,
        month: budgetCycleKeyMonth(now, startDay),
        periodStart: range.start,
        periodEnd: range.end);
    final cats = await repo.categories(ledgerId);
    final catMap = <int?, (Color, IconData)>{
      for (var i = 0; i < cats.length; i++)
        cats[i].id: (_catPalette[i % _catPalette.length], _catIcon(cats[i].icon)),
    };
    return (s, label, catMap);
  }

  void _openSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const BudgetSettingSheet(),
    );
  }

  Widget _totalCard(BuildContext context, BudgetProgress p) {
    final scheme = Theme.of(context).colorScheme;
    final warn = p.totalPct > 80 && p.totalPct < 100;
    final over = p.totalPct >= 100;
    final barColor = over
        ? scheme.error
        : (warn ? const Color(0xFFC8891A) : scheme.primary);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('本期预算',
              style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13)),
          const Spacer(),
          Text('${p.totalPct.round()}%',
              style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700)),
        ]),
        if (p.usingDefault)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('已使用默认预算',
                key: const Key('default_tag'),
                style: TextStyle(
                    color: scheme.onPrimaryContainer.withValues(alpha: .75),
                    fontSize: 11)),
          ),
        const SizedBox(height: 4),
        Text('¥ ${formatCents(p.totalBudgetCents)}',
            style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 30,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (p.totalPct.clamp(0, 100)) / 100,
            minHeight: 8,
            backgroundColor:
                scheme.onPrimaryContainer.withValues(alpha: .18),
            color: barColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Text('已用 ¥ ${formatCents(p.totalSpentCents)}',
              style: TextStyle(
                  color: scheme.onPrimaryContainer.withValues(alpha: .8),
                  fontSize: 12)),
          const SizedBox(width: 18),
          Text(
              '剩余 ¥ ${formatCents((p.totalBudgetCents - p.totalSpentCents).clamp(0, 1 << 62))}',
              style: TextStyle(
                  color: scheme.onPrimaryContainer.withValues(alpha: .8),
                  fontSize: 12)),
          const Spacer(),
          if (over)
            Text('已超支',
                style: TextStyle(
                    color: scheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
          if (!over && p.nearLimit)
            Text('已用 ${p.totalPct.round()}%',
                style: const TextStyle(
                    color: Color(0xFFC8891A),
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          if (!over && !p.nearLimit)
            Text('剩余日均 ¥ ${formatCents(p.remainingDailyCents)}',
                style: TextStyle(
                    color: scheme.onPrimaryContainer.withValues(alpha: .8),
                    fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _lineTile(BuildContext context, BudgetLine line,
      (Color, IconData)? cat) {
    final scheme = Theme.of(context).colorScheme;
    final over = line.isOverBudget;
    final warn = !over && line.pct > 80;
    final barColor = over
        ? scheme.error
        : (warn ? const Color(0xFFC8891A) : scheme.primary);
    final color = cat?.$1 ?? scheme.primary;
    final icon = cat?.$2 ?? Icons.receipt_long;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(line.categoryName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500))),
              Text('¥ ${formatCents(line.spentCents)} / ${formatCents(line.amountCents)}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: over ? FontWeight.w700 : FontWeight.w400,
                      color: over ? scheme.error : scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (line.pct.clamp(0, 100)) / 100,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: barColor,
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Text('${line.pct.round()}%',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const Spacer(),
              if (over)
                Text('超支',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.error,
                        fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ]),
    );
  }
}