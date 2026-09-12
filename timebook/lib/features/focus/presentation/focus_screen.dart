import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../daily/presentation/daily_summary_screen.dart';
import '../domain/quick_add_parser.dart';
import 'focus_providers.dart';
import 'focus_timer_widget.dart';
import 'quadrant_view.dart';
import 'timeline_widget.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final _quick = TextEditingController();
  Task? _bound;

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

  Future<void> _onComplete(int focusMinutes) async {
    final repo = ref.read(focusRepositoryProvider);
    final bound = _bound;
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
    final endAt = DateTime.now();
    await repo.addSession(
        taskId: bound?.id,
        kind: 'focus',
        startAt: endAt.subtract(Duration(minutes: focusMinutes)),
        endAt: endAt,
        durationMinutes: focusMinutes,
        interrupted: false);
    setState(() {});
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
                onComplete: () => _onComplete(settings.focusMinutes),
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