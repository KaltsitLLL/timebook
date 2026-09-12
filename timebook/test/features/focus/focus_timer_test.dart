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

  test('extend 使剩余时间增加 5 分钟', () {
    final t = FocusTimer(focusMinutes: 25);
    final now = DateTime(2026, 9, 12, 8, 0, 0);
    t.start(now: now);
    final before = t.remainingSeconds(now: now.add(const Duration(minutes: 5)));
    expect(t.extend(const Duration(minutes: 5)), isTrue);
    expect(t.remainingSeconds(now: now.add(const Duration(minutes: 5))),
        before + 5 * 60);
  });

  test('非 focusing 时 extend 返回 false 无副作用', () {
    final t = FocusTimer(focusMinutes: 25);
    // idle 状态
    expect(t.extend(const Duration(minutes: 5)), isFalse);
    expect(t.phase, TimerPhase.idle);
    // paused 状态
    final now = DateTime(2026, 9, 12, 8, 0, 0);
    t.start(now: now);
    t.pause(now: now.add(const Duration(minutes: 1)));
    final before = t.remainingSeconds(now: now.add(const Duration(minutes: 1)));
    expect(t.extend(const Duration(minutes: 5)), isFalse);
    expect(t.remainingSeconds(now: now.add(const Duration(minutes: 1))), before);
    expect(t.phase, TimerPhase.paused);
    // 休息模式（短休计时中）同样不可延长
    final s = FocusTimer(focusMinutes: 25, mode: TimerMode.short);
    s.start(now: now);
    expect(s.extend(const Duration(minutes: 5)), isFalse);
  });

  test('skipRest 后 phase==idle 且剩余归默认', () {
    final t = FocusTimer(focusMinutes: 25, mode: TimerMode.short);
    final now = DateTime(2026, 9, 12, 8, 0, 0);
    t.start(now: now);
    t.skipRest(now: now.add(const Duration(minutes: 1)));
    expect(t.phase, TimerPhase.idle);
    expect(t.remainingSeconds(), t.durationSeconds);
    expect(t.isFinished, isFalse);
  });

  test('focus 模式 skipRest 无操作、非计时中 skipRest 无操作', () {
    final t = FocusTimer(focusMinutes: 25);
    final now = DateTime(2026, 9, 12, 8, 0, 0);
    t.start(now: now);
    t.skipRest(now: now.add(const Duration(seconds: 30)));
    expect(t.phase, TimerPhase.focusing);
    expect(t.remainingSeconds(now: now.add(const Duration(seconds: 30))),
        25 * 60 - 30);
    // idle 状态下 skipRest 也无效
    t.reset();
    t.skipRest();
    expect(t.phase, TimerPhase.idle);
  });
}