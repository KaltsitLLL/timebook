import 'dart:async';
import 'package:flutter/material.dart';

import '../domain/focus_timer.dart';

/// 计时圆盘：绝对时间戳计时器 + 每秒 tick 刷新 + 开始/暂停/继续主按钮。
/// 时间源由 [now] 注入（生产传 focusClockProvider 默认真实时钟，测试传可控时钟）。
class FocusTimerWidget extends StatefulWidget {
  const FocusTimerWidget({super.key, required this.focusMinutes, required this.now});
  final int focusMinutes;
  final DateTime Function() now;

  @override
  State<FocusTimerWidget> createState() => _FocusTimerWidgetState();
}

class _FocusTimerWidgetState extends State<FocusTimerWidget> {
  late final FocusTimer _timer;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _timer = FocusTimer(focusMinutes: widget.focusMinutes);
    // 启动后持有 periodic timer，每秒驱动 setState；dispose 必须 cancel。
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_timer.phase == TimerPhase.focusing &&
        _timer.remainingSeconds(now: widget.now()) <= 0) {
      _timer.reset();
    }
    setState(() {});
  }

  String get _label {
    final s = _timer.remainingSeconds(now: widget.now());
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _onPrimary() {
    if (_timer.phase == TimerPhase.focusing) {
      _timer.pause(now: widget.now());
    } else if (_timer.phase == TimerPhase.paused) {
      _timer.resume(now: widget.now());
    } else {
      _timer.start(now: widget.now());
    }
    _tick();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phase = _timer.phase;
    final remain = _timer.remainingSeconds(now: widget.now());
    final shown = remain < 0 ? 0 : remain;
    final (IconData icon, String label) = switch (phase) {
      TimerPhase.focusing => (Icons.pause, '暂停'),
      TimerPhase.paused => (Icons.play_arrow, '继续'),
      TimerPhase.idle => (Icons.play_arrow, '开始专注'),
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 170,
          height: 170,
          child: CircularProgressIndicator(
            value: 1 - (shown / _timer.durationSeconds),
            strokeWidth: 12,
            backgroundColor: scheme.surfaceContainerHighest,
            color: scheme.primary,
          ),
        ),
        Text(
          _label,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
        ),
      ]),
      const SizedBox(height: 14),
      FilledButton.icon(
        key: const Key('focus_start'),
        onPressed: _onPrimary,
        icon: Icon(icon),
        label: Text(label),
      ),
    ]);
  }
}