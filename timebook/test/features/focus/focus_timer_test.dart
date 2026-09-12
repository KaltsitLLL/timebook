import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/focus/domain/focus_timer.dart';

void main() {
  test('默认 idle 显示配置时长 25:00', () {
    final t = FocusTimer(focusMinutes: 25);
    expect(t.phase, TimerPhase.idle);
    expect(t.remainingLabel(), '25:00');
  });

  test('启动后剩余按绝对时间戳递减（钟快 3s 只算一次）', () {
    final t = FocusTimer(focusMinutes: 25);
    final now = DateTime(2026, 9, 12, 8, 0, 0);
    t.start(now: now);
    t.tick(now: now.add(const Duration(seconds: 3)));
    expect(t.remainingSeconds(now: now.add(const Duration(seconds: 3))),
        25 * 60 - 3);
  });

  test('暂停保留剩余，继续续跑', () {
    final t = FocusTimer(focusMinutes: 25);
    final now = DateTime(2026, 9, 12, 8, 0, 0);
    t.start(now: now);
    final remain5 =
        t.remainingSeconds(now: now.add(const Duration(minutes: 5)));
    expect(remain5, 25 * 60 - 5 * 60);
    t.pause(now: now.add(const Duration(minutes: 5)));
    // 暂停期间时间流动不影响
    expect(t.remainingSeconds(now: now.add(const Duration(minutes: 10))),
        remain5);
    t.resume(now: now.add(const Duration(minutes: 10)));
    expect(
        t.remainingSeconds(
            now: now.add(const Duration(minutes: 10, seconds: 60))),
        remain5 - 60);
  });

  test('归零视为完成', () {
    final t = FocusTimer(focusMinutes: 25);
    final past = DateTime(2000, 1, 1);
    t.start(now: past);
    expect(
        t.remainingSeconds(now: past.add(const Duration(minutes: 25, seconds: 1))),
        0);
    // endAt 早已过去：绝对时间戳归零 → 完成
    expect(t.isFinished, isTrue);
  });

  test('flowtime 不自动归零，由手动停止', () {
    final t = FocusTimer(focusMinutes: 25, mode: TimerMode.flowtime);
    t.start(now: DateTime(2026, 1, 1, 10));
    // 1 小时后：剩余展示为 0 但不触发完成
    expect(t.remainingSeconds(now: DateTime(2026, 1, 1, 11)), 0);
    expect(t.isFinished, isFalse); // 不自动结束
  });
}