import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/focus/domain/focus_timer.dart';
import 'package:timebook/features/focus/presentation/focus_timer_widget.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('专注中显示 +5 分按钮，点击延长 5 分钟', (tester) async {
    var fakeNow = DateTime(2026, 9, 12, 9, 0, 0);
    await tester.pumpWidget(_wrap(FocusTimerWidget(
      focusMinutes: 25,
      now: () => fakeNow,
      onComplete: (_) {},
    )));
    await tester.pump();

    await tester.tap(find.byKey(const Key('focus_start')));
    await tester.pump();
    expect(find.byKey(const Key('focus_extend')), findsOneWidget);
    expect(find.byKey(const Key('skip_break')), findsNothing);

    fakeNow = fakeNow.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('24:30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('focus_extend')));
    await tester.pump();
    expect(find.text('29:30'), findsOneWidget);
  });

  testWidgets('短休中显示跳过休息，点击触发 short 完成回调', (tester) async {
    var fakeNow = DateTime(2026, 9, 12, 9, 0, 0);
    TimerMode? completed;
    await tester.pumpWidget(_wrap(FocusTimerWidget(
      focusMinutes: 25,
      now: () => fakeNow,
      onComplete: (m) => completed = m,
    )));
    await tester.pump();

    await tester.tap(find.byKey(const Key('mode_short')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('focus_start')));
    await tester.pump();

    expect(find.byKey(const Key('skip_break')), findsOneWidget);
    expect(find.byKey(const Key('focus_extend')), findsNothing);

    await tester.tap(find.byKey(const Key('skip_break')));
    await tester.pump();
    expect(completed, TimerMode.short);
    expect(find.byKey(const Key('skip_break')), findsNothing);
    expect(find.byKey(const Key('focus_start')), findsOneWidget);
  });

  testWidgets('专注到 0 出现继续专注，点击后恢复到 5:00', (tester) async {
    var fakeNow = DateTime(2026, 9, 12, 9, 0, 0);
    await tester.pumpWidget(_wrap(FocusTimerWidget(
      focusMinutes: 25,
      now: () => fakeNow,
      onComplete: (_) {},
    )));
    await tester.pump();

    await tester.tap(find.byKey(const Key('focus_start')));
    await tester.pump();

    fakeNow = fakeNow.add(const Duration(minutes: 25));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('overtime_continue')), findsOneWidget);

    await tester.tap(find.byKey(const Key('overtime_continue')));
    await tester.pump();
    expect(find.byKey(const Key('overtime_continue')), findsNothing);
    expect(find.text('05:00'), findsOneWidget);
  });

  testWidgets('专注到 0 不点击则 3 秒后自动走完成回调', (tester) async {
    var fakeNow = DateTime(2026, 9, 12, 9, 0, 0);
    TimerMode? completed;
    await tester.pumpWidget(_wrap(FocusTimerWidget(
      focusMinutes: 25,
      now: () => fakeNow,
      onComplete: (m) => completed = m,
    )));
    await tester.pump();

    await tester.tap(find.byKey(const Key('focus_start')));
    await tester.pump();

    fakeNow = fakeNow.add(const Duration(minutes: 26));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('overtime_continue')), findsOneWidget);
    expect(completed, isNull);

    await tester.pump(const Duration(seconds: 3));
    expect(completed, TimerMode.focus);
    expect(find.byKey(const Key('overtime_continue')), findsNothing);
  });
}