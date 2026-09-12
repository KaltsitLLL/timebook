import 'dart:async';
import 'package:flutter/material.dart';

import '../domain/focus_timer.dart';

/// 计时圆盘：绝对时间戳计时器 + 每秒 tick 刷新 + 开始/暂停/继续主按钮。
/// 时间源由 [now] 注入（生产传 focusClockProvider 默认真实时钟，测试传可控时钟）。
class FocusTimerWidget extends StatefulWidget {
  const FocusTimerWidget({
    super.key,
    required this.focusMinutes,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.boundTask,
    this.hintTask,
    this.onComplete,
    required this.now,
  });
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final String? boundTask;
  final String? hintTask;
  final void Function(TimerMode mode)? onComplete;
  final DateTime Function() now;

  @override
  State<FocusTimerWidget> createState() => _FocusTimerWidgetState();
}

class _FocusTimerWidgetState extends State<FocusTimerWidget> {
  TimerMode _mode = TimerMode.focus;
  late final FocusTimer _timer;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _timer = _buildTimer();
    // 启动后持有 periodic timer，每秒驱动 setState；dispose 必须 cancel。
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  FocusTimer _buildTimer() => FocusTimer(
        focusMinutes: widget.focusMinutes,
        shortBreakMinutes: widget.shortBreakMinutes,
        longBreakMinutes: widget.longBreakMinutes,
        mode: _mode,
      );

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_timer.phase == TimerPhase.focusing &&
        _timer.remainingSeconds(now: widget.now()) <= 0) {
      final finishedMode = _timer.mode;
      _timer.reset();
      widget.onComplete?.call(finishedMode);
    }
    setState(() {});
  }

  void _switchMode(TimerMode mode) {
    setState(() {
      _mode = mode;
      _timer.mode = mode;
      _timer.reset();
    });
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

  Color _ringColor(ColorScheme scheme) => switch (_mode) {
        TimerMode.focus => scheme.primary,
        TimerMode.short => const Color(0xFF4CB3C4),
        TimerMode.long => const Color(0xFF6C96C9),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phase = _timer.phase;
    final remain = _timer.remainingSeconds(now: widget.now());
    final shown = remain < 0 ? 0 : remain;
    final ringColor = _ringColor(scheme);
    final (IconData icon, String label) = switch (phase) {
      TimerPhase.focusing => (Icons.pause, '暂停'),
      TimerPhase.paused => (Icons.play_arrow, '继续'),
      TimerPhase.idle => (Icons.play_arrow, '开始专注'),
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ChoiceChip(
          key: const Key('mode_focus'),
          label: const Text('专注'),
          selected: _mode == TimerMode.focus,
          onSelected: (_) => _switchMode(TimerMode.focus),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          key: const Key('mode_short'),
          label: const Text('短休'),
          selected: _mode == TimerMode.short,
          onSelected: (_) => _switchMode(TimerMode.short),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          key: const Key('mode_long'),
          label: const Text('长休'),
          selected: _mode == TimerMode.long,
          onSelected: (_) => _switchMode(TimerMode.long),
        ),
      ]),
      const SizedBox(height: 16),
      Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 170,
          height: 170,
          child: CircularProgressIndicator(
            value: 1 - (shown / _timer.durationSeconds),
            strokeWidth: 12,
            backgroundColor: scheme.surfaceContainerHighest,
            color: ringColor,
          ),
        ),
        Text(
          _label,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
        ),
      ]),
      const SizedBox(height: 10),
      Text(
        widget.boundTask != null
            ? '专注中：${widget.boundTask}'
            : (widget.hintTask ?? '请先选择任务'),
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
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