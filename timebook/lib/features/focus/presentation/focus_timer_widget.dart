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
    this.onFlowCompleted,
    required this.now,
  });
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final String? boundTask;
  final String? hintTask;
  final void Function(TimerMode mode)? onComplete;
  /// Flowtime 手动结束时回调实际专注分钟数。
  final void Function(int minutes)? onFlowCompleted;
  final DateTime Function() now;

  @override
  State<FocusTimerWidget> createState() => _FocusTimerWidgetState();
}

class _FocusTimerWidgetState extends State<FocusTimerWidget> {
  TimerMode _mode = TimerMode.focus;
  late final FocusTimer _timer;
  Timer? _clock;
  DateTime? _flowStart;
  bool _overtimePending = false;
  Timer? _overtimeTimer;

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
    _overtimeTimer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_timer.mode != TimerMode.flowtime &&
        _timer.phase == TimerPhase.focusing &&
        _timer.remainingSeconds(now: widget.now()) <= 0) {
      if (_timer.mode == TimerMode.focus) {
        // 专注到 0：进入 overtime 待决态，3 秒内可点「继续专注」延长，
        // 否则自动走完成回调。避免重复进入。
        if (!_overtimePending) {
          _overtimePending = true;
          _overtimeTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) _completeFocus();
          });
        }
      } else {
        // 休息到 0：直接按休息完成语义落库。
        final finishedMode = _timer.mode;
        _timer.reset();
        widget.onComplete?.call(finishedMode);
      }
    }
    setState(() {});
  }

  void _cancelOvertime() {
    _overtimeTimer?.cancel();
    _overtimeTimer = null;
    _overtimePending = false;
  }

  void _completeFocus() {
    _cancelOvertime();
    final finishedMode = _timer.mode;
    _timer.reset();
    widget.onComplete?.call(finishedMode);
    if (mounted) setState(() {});
  }

  void _onExtend() {
    _timer.extend(const Duration(minutes: 5));
    setState(() {});
  }

  void _onSkipBreak() {
    final finishedMode = _timer.mode;
    _timer.skipRest();
    widget.onComplete?.call(finishedMode);
    setState(() {});
  }

  void _onOvertimeContinue() {
    _cancelOvertime();
    _timer.extend(const Duration(minutes: 5));
    setState(() {});
  }

  void _switchMode(TimerMode mode) {
    setState(() {
      _mode = mode;
      _timer.mode = mode;
      _timer.reset();
      _cancelOvertime();
    });
  }

  String get _label {
    if (_timer.mode == TimerMode.flowtime) {
      // 流式无倒计时，展示已专注时长
      final base = _flowStart ?? DateTime.now();
      final s = widget.now().difference(base).inSeconds;
      final sec = s < 0 ? 0 : s;
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    final s = _timer.remainingSeconds(now: widget.now());
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  int get _elapsedFlowMinutes {
    final base = _flowStart;
    if (base == null) return 1;
    final mins = widget.now().difference(base).inMinutes;
    return mins < 1 ? 1 : mins;
  }

  void _onPrimary() {
    if (_timer.mode == TimerMode.flowtime) {
      if (_timer.phase == TimerPhase.idle) {
        _flowStart = widget.now();
        _timer.start(now: widget.now());
      } else if (_timer.phase == TimerPhase.focusing) {
        final minutes = _elapsedFlowMinutes;
        _timer.reset();
        _flowStart = null;
        widget.onFlowCompleted?.call(minutes);
      }
      _tick();
      return;
    }
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
        TimerMode.flowtime => const Color(0xFF7A5AC9),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phase = _timer.phase;
    final remain = _timer.remainingSeconds(now: widget.now());
    final shown = remain < 0 ? 0 : remain;
    final ringColor = _ringColor(scheme);
    final (IconData icon, String label) = _mode == TimerMode.flowtime
        ? (phase == TimerPhase.focusing
            ? (Icons.stop, '结束')
            : (Icons.play_arrow, '开始'))
        : switch (phase) {
            TimerPhase.focusing => (Icons.pause, '暂停'),
            TimerPhase.paused => (Icons.play_arrow, '继续'),
            TimerPhase.idle => (Icons.play_arrow, '开始专注'),
          };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          ChoiceChip(
            key: const Key('mode_focus'),
            label: const Text('专注'),
            selected: _mode == TimerMode.focus,
            onSelected: (_) => _switchMode(TimerMode.focus),
          ),
          ChoiceChip(
            key: const Key('mode_short'),
            label: const Text('短休'),
            selected: _mode == TimerMode.short,
            onSelected: (_) => _switchMode(TimerMode.short),
          ),
          ChoiceChip(
            key: const Key('mode_long'),
            label: const Text('长休'),
            selected: _mode == TimerMode.long,
            onSelected: (_) => _switchMode(TimerMode.long),
          ),
          ChoiceChip(
            key: const Key('mode_flowtime'),
            label: const Text('流式'),
            selected: _mode == TimerMode.flowtime,
            onSelected: (_) => _switchMode(TimerMode.flowtime),
          ),
        ],
      ),
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
      if (_overtimePending) ...[
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('overtime_continue'),
          onPressed: _onOvertimeContinue,
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('继续专注'),
        ),
      ],
      const SizedBox(height: 10),
      Text(
        widget.boundTask != null
            ? '专注中：${widget.boundTask}'
            : (widget.hintTask ?? '请先选择任务'),
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton.icon(
            key: const Key('focus_start'),
            onPressed: _onPrimary,
            icon: Icon(icon),
            label: Text(label),
          ),
          if (phase == TimerPhase.focusing &&
              _mode == TimerMode.focus) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              key: const Key('focus_extend'),
              onPressed: _onExtend,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('+5 分'),
            ),
          ],
          if (phase == TimerPhase.focusing &&
              (_mode == TimerMode.short || _mode == TimerMode.long)) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              key: const Key('skip_break'),
              onPressed: _onSkipBreak,
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('跳过休息'),
            ),
          ],
        ],
      ),
    ]);
  }
}