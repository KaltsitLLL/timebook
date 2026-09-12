import 'package:flutter/material.dart';
import '../../../core/db/app_database.dart';

/// 今日专注时间线：会话圆点色块 + 类型标签 + 任务 + 时长（取前 6 条）。
class TimelineWidget extends StatelessWidget {
  const TimelineWidget({super.key, required this.sessions});
  final List<PomodoroSession> sessions; // 当日，startAt desc 由调用者传入

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('今天还没有专注记录，开始第一个番茄吧',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      );
    }
    return Column(children: [
      for (final s in sessions.take(6))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: s.kind == 'focus'
                      ? scheme.primary
                      : (s.kind == 'short'
                          ? const Color(0xFF4CB3C4)
                          : const Color(0xFF6C96C9)),
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${s.kind == 'focus' ? '专注' : (s.kind == 'short' ? '短休' : '长休')}'
                '${s.taskId != null ? ' · 任务 #${s.taskId}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Text('${s.durationMinutes} 分钟',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
    ]);
  }
}