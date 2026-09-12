import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/util/formats.dart';

class DonutSlice {
  const DonutSlice({
    required this.color,
    required this.value,
    required this.label,
  });
  final Color color;
  final int value; // 分
  final String label;
}

/// 环形图 + 中心合计 + Top4 图例（与原型「分类支出」卡片一致）。
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.slices,
    this.centerLabel = '支出',
  });
  final List<DonutSlice> slices;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (s, e) => s + e.value);
    final top = [...slices]..sort((a, b) => b.value - a.value);
    return Row(children: [
      SizedBox(
        width: 128,
        height: 128,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: [
            for (final s in top)
              PieChartSectionData(
                value: s.value.toDouble(),
                color: s.color,
                radius: 40,
                showTitle: false,
              ),
          ],
        )),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic, mainAxisSize: MainAxisSize.min,
              children: [
                const Text('¥ ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(formatCents(total),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Text(centerLabel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
          const SizedBox(height: 10),
          for (final s in top.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s.label, style: const TextStyle(fontSize: 13))),
                Text('¥ ${formatCents(s.value)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}