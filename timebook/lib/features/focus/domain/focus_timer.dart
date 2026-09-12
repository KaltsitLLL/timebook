enum TimerPhase { idle, focusing, paused }

enum TimerMode { focus, short, long, flowtime }

class FocusTimer {
  FocusTimer({
    required this.focusMinutes,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.mode = TimerMode.focus,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;

  TimerMode mode;
  TimerPhase phase = TimerPhase.idle;
  DateTime? _endAt; // 绝对时间戳：剩余 = _endAt - now
  int? _remainAtPauseSeconds;

  // flowtime 无固定时长，用一天占位（durationSeconds 仅供非流式 UI 进度环使用）。
  int get durationSeconds => switch (mode) {
        TimerMode.focus => focusMinutes * 60,
        TimerMode.short => shortBreakMinutes * 60,
        TimerMode.long => longBreakMinutes * 60,
        TimerMode.flowtime => 24 * 60 * 60,
      };

  int remainingSeconds({DateTime? now}) {
    if (mode == TimerMode.flowtime) return 0; // 流式剩余恒显示 0，不结束
    if (phase == TimerPhase.paused) {
      return _remainAtPauseSeconds ?? durationSeconds;
    }
    if (_endAt == null) return durationSeconds;
    final s = _endAt!.difference(now ?? DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  bool get isFinished =>
      mode == TimerMode.flowtime
          ? false
          : phase == TimerPhase.focusing && remainingSeconds() == 0;

  String remainingLabel() {
    final s = remainingSeconds();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void start({DateTime? now}) {
    phase = TimerPhase.focusing;
    _endAt = (now ?? DateTime.now()).add(Duration(seconds: durationSeconds));
  }

  void tick({DateTime? now}) {
    // 剩余完全由 remainingSeconds() 从 _endAt 计算（绝对时间戳），
    // UI 每秒调用本方法触发 setState 即可，休眠/阻塞后自动补偿。
  }

  /// 专注中延长结束时间（仅 focus 专注计时有效）。成功返回 true，
  /// 其它状态/模式（idle/paused/休息/流式）保持原状返回 false。
  bool extend(Duration d, {DateTime? now}) {
    if (phase != TimerPhase.focusing || mode != TimerMode.focus) return false;
    _endAt = _endAt!.add(d);
    return true;
  }

  /// 休息中（短/长休计时）直接跳过：回到 idle 并清空结束时间。
  /// 专注/流式/非计时中无操作。
  void skipRest({DateTime? now}) {
    if (phase != TimerPhase.focusing) return;
    if (mode != TimerMode.short && mode != TimerMode.long) return;
    phase = TimerPhase.idle;
    _endAt = null;
    _remainAtPauseSeconds = null;
  }

  void pause({DateTime? now}) {
    if (phase != TimerPhase.focusing) return;
    _remainAtPauseSeconds = remainingSeconds(now: now);
    phase = TimerPhase.paused;
  }

  void resume({DateTime? now}) {
    if (phase != TimerPhase.paused) return;
    phase = TimerPhase.focusing;
    _endAt = (now ?? DateTime.now())
        .add(Duration(seconds: _remainAtPauseSeconds ?? durationSeconds));
  }

  void reset() {
    phase = TimerPhase.idle;
    _endAt = null;
    _remainAtPauseSeconds = null;
  }
}