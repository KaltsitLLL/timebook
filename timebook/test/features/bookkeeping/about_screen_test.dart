import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/bookkeeping/presentation/about_screen.dart';

void main() {
  testWidgets('关于页渲染标题与仓库地址', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('https://github.com/KaltsitLLL/timebook'), findsOneWidget);
  });
}