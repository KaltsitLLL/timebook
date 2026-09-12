import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../daily/presentation/daily_summary_screen.dart';
import '../domain/quick_add_parser.dart';
import '../domain/focus_timer.dart';
import 'focus_providers.dart';
import 'focus_timer_widget.dart';
import 'quadrant_view.dart';
import 'timeline_widget.dart';
import '../notifications/notification_service.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, this.notification});
  /// 完成通知服务；不传时生产用 [FlutterNotificationService]，测试注入 Fake。
  final NotificationService? notification;
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final _quick = TextEditingController();
  late final NotificationService _notification =
      widget.notification ?? FlutterNotificationService();
  Task? _bound;

  @override
  void initState() {
    super.initState();
    _notification.initialize();
  }

  @override
  void dispose() {
    _quick.dispose();
    super.dispose();
  }

  Future<void> _quickAdd() async {
    final text = _quick.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(focusRepositoryProvider);
    final d = parseQuickAdd(text);
    int? projectId;
    if (d.project != null) {
      final existing = await repo.projects();
      final hit = existing.where((p) => p.name == d.project).toList();
      projectId = hit.isNotEmpty ? hit.first.id : await repo.createProject(name: d.project!);
    }
    await repo.createTask(
        title: d.title,
        projectId: projectId,
        priority: 1,
        estimateMinutes: d.estimateMinutes,
        dueDate: d.dueDate);
    _quick.clear();
    setState(() {});
  }

  Future<void> _onComplete(TimerMode mode) async {
    _notifyCompleted(mode);
    final repo = ref.read(focusRepositoryProvider);
    final settings = await repo.settings();
    final endAt = DateTime.now();
    // 休息/专注映射到各自会话类型与时长；专注结束需确认，休息直接落库。
    final kind = switch (mode) {
      TimerMode.focus => 'focus',
      TimerMode.short => 'short',
      TimerMode.long => 'long',
    };
    final minutes = switch (mode) {
      TimerMode.focus => settings.focusMinutes,
      TimerMode.short => settings.shortBreakMinutes,
      TimerMode.long => settings.longBreakMinutes,
    };
    final bound = _bound;
    if (!mounted) return;
    if (mode == TimerMode.focus) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('专注完成'),
          content: const Text('记一次专注？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, '标记任务完成'),
                child: const Text('标记任务完成')),
            TextButton(
                onPressed: () => Navigator.pop(context, '仍进行中'),
                child: const Text('仍进行中')),
            TextButton(
                onPressed: () => Navigator.pop(context, '取消'),
                child: const Text('取消')),
          ],
        ),
      );
      if (action == null || action == '取消') return;
      if (action == '标记任务完成' && bound != null) {
        await repo.toggleCompleted(taskId: bound.id);
      }
    }
    await repo.addSession(
        taskId: mode == TimerMode.focus ? bound?.id : null,
        kind: kind,
        startAt: endAt.subtract(Duration(minutes: minutes)),
        endAt: endAt,
        durationMinutes: minutes,
        interrupted: false);
    setState(() {});
  }

  /// 计时周期完成时发系统通知；按模式给不同文案。
  void _notifyCompleted(TimerMode mode) {
    final (title, body) = switch (mode) {
      TimerMode.focus => ('番茄完成 🍅', '休息一下吧'),
      TimerMode.short => ('短休结束', '可以开始下一轮专注了'),
      TimerMode.long => ('长休结束', '可以开始下一轮专注了'),
    };
    _notification.show(id: 1, title: title, body: body);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(focusRepositoryProvider);
    final now = ref.read(focusClockProvider);
    return FutureBuilder(
      future: Future.wait([repo.openTasks(), repo.todayFocusMinutes(), repo.settings()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final tasks = snap.data![0] as List<Task>;
        final focusMin = snap.data![1] as int;
        final settings = snap.data![2] as PomodoroSetting;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Text('今日专注', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                    key: const Key('daily_entry'),
                    icon: const Icon(Icons.summarize_outlined, size: 16),
                    label: const Text('收工小结'),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const DailySummaryScreen()))),
                Text('$focusMin 分钟',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('本周专注', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                FutureBuilder<List<(DateTime, int)>>(
                  future: repo.focusMinutesByDay(),
                  builder: (context, snap) =>
                      _Heatmap(days: snap.data ?? const <(DateTime, int)>[]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('今日专注时间线', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                FutureBuilder<List<PomodoroSession>>(
                  future: repo.sessionsToday(),
                  builder: (context, snap) =>
                      TimelineWidget(sessions: snap.data ?? const <PomodoroSession>[]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FocusTimerWidget(
                focusMinutes: settings.focusMinutes,
                shortBreakMinutes: settings.shortBreakMinutes,
                longBreakMinutes: settings.longBreakMinutes,
                boundTask: _bound?.title,
                onComplete: _onComplete,
                now: now,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text('今日待办', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const QuadrantView())),
              child: const Text('四象限'),
            ),
          ]),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '添加任务后在任务行点 🍅 绑定开始专注',
                key: const Key('focus_guide'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400),
              ),
            )
          else
            for (final t in tasks)
              ListTile(
                dense: true,
                leading: Checkbox(
                  value: false,
                  onChanged: (_) async {
                    await repo.toggleCompleted(taskId: t.id);
                    setState(() {});
                  },
                ),
                title: Text(t.title),
                trailing: TextButton(
                  key: Key('bind_${t.id}'),
                  onPressed: () => setState(() => _bound = t),
                  child: const Text('🍅'),
                ),
              ),
          const SizedBox(height: 8),
          TextField(
            controller: _quick,
            decoration: InputDecoration(
              hintText: '快速添加：任务 +项目 25m #标签 @明天',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _quickAdd),
            ),
          ),
        ]);
      },
    );
  }
}

/// 本周专注热力图：近 7 日色块（0 分灰、有分主色透明度按强度），次日为「今」。
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.days});
  final List<(DateTime, int)> days;

  static const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Row(
      key: const Key('focus_heatmap'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (day, minutes) in days) _cell(scheme, day, minutes, now),
      ],
    );
  }

  Widget _cell(ColorScheme scheme, DateTime day, int minutes, DateTime now) {
    final today = day.year == now.year && day.month == now.month && day.day == now.day;
    final color = minutes <= 0
        ? const Color(0xFFD8E1EB)
        : scheme.primary.withValues(alpha: (minutes / 60).clamp(0.15, 0.9));
    return Column(children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: minutes <= 0
            ? null
            : Text('${minutes}m',
                style: const TextStyle(fontSize: 9, color: Colors.black87)),
      ),
      const SizedBox(height: 3),
      Text(today ? '今' : _weekdayNames[day.weekday - 1],
          style: const TextStyle(fontSize: 10)),
    ]);
  }
}