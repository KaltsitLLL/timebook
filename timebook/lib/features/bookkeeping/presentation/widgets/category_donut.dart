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
    // 无数据：占位灰环 + 中心 ¥ 0.00 + 图例灰字提示
    if (slices.isEmpty || total == 0) {
      return Row(children: [
        SizedBox(
          width: 128,
          height: 128,
          child: CustomPaint(painter: _EmptyDonutPainter()),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _TotalLine(amountCents: 0, centerLabel: centerLabel),
            const SizedBox(height: 10),
            const Text('暂无支出数据',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w400)),
          ]),
        ),
      ]);
    }
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

/// 中心合计行（空态复用以渲染 ¥ 0.00 {centerLabel}）。
class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.amountCents, required this.centerLabel});
  final int amountCents;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('¥ ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(formatCents(amountCents),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text(centerLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// 空态占位：70% 透明度灰环弧段。
class _EmptyDonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = 14.0;
    final radius = size.shortestSide / 2 - stroke / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.grey.withValues(alpha: 0.7);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.5708, 1.25 * 3.141592653589793, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}