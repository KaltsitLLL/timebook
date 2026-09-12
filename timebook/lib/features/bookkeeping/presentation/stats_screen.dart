import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/formats.dart';
import '../data/bookkeeping_repository.dart';
import 'bookkeeping_providers.dart';
import 'widgets/category_donut.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookkeepingRepositoryProvider);
    return FutureBuilder(
      future: _load(repo),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (trend, spends, names) = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [_buildBarCard(context, trend), const SizedBox(height: 16), _buildPieCard(context, spends, names)],
        );
      },
    );
  }

  Future<(List<MonthTotal>, List<CategorySpend>, Map<int?, String>)> _load(
      BookkeepingRepository repo) async {
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) {
      return (const <MonthTotal>[], const <CategorySpend>[], const <int?, String>{});
    }
    final ledgerId = ledgers.first.id;
    final trend = await repo.monthlyTrend(ledgerId: ledgerId);
    final spends =
        await repo.categorySpending(ledgerId, monthKey(DateTime.now()));
    final cats = await repo.categories(ledgerId);
    final names = {for (final c in cats) c.id: c.name};
    return (trend, spends, names);
  }

  Widget _buildBarCard(BuildContext context, List<MonthTotal> trend) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = (trend.fold<int>(
                0, (m, d) => [m, d.incomeCents, d.expenseCents].reduce((a, b) => a > b ? a : b))) /
            100 *
        1.15;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('近 6 个月收支', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              maxY: maxV < 1 ? 1 : maxV,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= trend.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(monthShort(trend[i].month),
                            style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < trend.length; i++)
                  BarChartGroupData(x: i, barsSpace: 3, barRods: [
                    BarChartRodData(
                        toY: trend[i].incomeCents / 100,
                        color: const Color(0xFF4CB3C4),
                        width: 10),
                    BarChartRodData(
                        toY: trend[i].expenseCents / 100,
                        color: scheme.primary,
                        width: 10),
                  ]),
              ],
            )),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _legend(const Color(0xFF4CB3C4), '收入'),
            const SizedBox(width: 16),
            _legend(scheme.primary, '支出'),
          ]),
        ]),
      ),
    );
  }

  Widget _buildPieCard(BuildContext context, List<CategorySpend> spends,
      Map<int?, String> names) {
    final total = spends.fold<int>(0, (s, e) => s + e.amountCents);
    final sorted = [...spends]..sort((a, b) => b.amountCents - a.amountCents);
    const colors = [
      Color(0xFF5B9BD5), Color(0xFF4DB6AC), Color(0xFF5C6BC0),
      Color(0xFF8F9AD1), Color(0xFF4A7DB0), Color(0xFF7FB3D5),
    ];
    final slices = <DonutSlice>[
      for (var i = 0; i < spends.length; i++)
        DonutSlice(
          color: colors[i % colors.length],
          value: spends[i].amountCents,
          label: names[spends[i].categoryId] ?? '分类#${spends[i].categoryId ?? 0}',
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('本月分类占比', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          CategoryDonut(slices: slices, centerLabel: '本月支出'),
          const SizedBox(height: 10),
          for (final s in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const SizedBox(width: 24, child: Text('●')), // 简化标记
                const SizedBox(width: 8),
                Expanded(child: Text(names[s.categoryId] ?? '分类#${s.categoryId ?? 0}',
                    style: const TextStyle(fontSize: 13))),
                Text(total == 0
                    ? ''
                    : '${(s.amountCents * 100 / total).round()}%',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 10),
                Text('¥ ${formatCents(s.amountCents)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12)),
      ]);
}