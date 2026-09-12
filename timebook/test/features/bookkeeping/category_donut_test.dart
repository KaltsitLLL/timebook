import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/bookkeeping/presentation/widgets/category_donut.dart';

void main() {
  testWidgets('环形图渲染中心合计与图例前四项', (tester) async {
    final slices = [
      const DonutSlice(color: Color(0xFF4A7DB0), value: 281200, label: '居住'),
      const DonutSlice(color: Color(0xFF5C6BC0), value: 166110, label: '购物'),
      const DonutSlice(color: Color(0xFF5B9BD5), value: 85740, label: '餐饮'),
      const DonutSlice(color: Color(0xFF4DB6AC), value: 70700, label: '交通'),
      const DonutSlice(color: Color(0xFF8F9AD1), value: 18300, label: '娱乐'),
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CategoryDonut(slices: slices, centerLabel: '本月支出'))));
    await tester.pumpAndSettle();
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('6,220.50'), findsOneWidget); // 中心合计=总和/100
    expect(find.text('居住'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('娱乐'), findsNothing); // 仅 Top4
  });
}