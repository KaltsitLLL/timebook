enum TimerPhase { idle, focusing, paused }

enum TimerMode { focus, short, long }

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

  int get durationSeconds => switch (mode) {
        TimerMode.focus => focusMinutes * 60,
        TimerMode.short => shortBreakMinutes * 60,
        TimerMode.long => longBreakMinutes * 60,
      };

  int remainingSeconds({DateTime? now}) {
    if (phase == TimerPhase.paused) {
      return _remainAtPauseSeconds ?? durationSeconds;
    }
    if (_endAt == null) return durationSeconds;
    final s = _endAt!.difference(now ?? DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  bool get isFinished => phase == TimerPhase.focusing && remainingSeconds() == 0;

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