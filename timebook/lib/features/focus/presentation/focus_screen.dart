import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../daily/presentation/daily_summary_screen.dart';
import '../domain/quick_add_parser.dart';
import 'focus_providers.dart';
import 'focus_timer_widget.dart';
import 'quadrant_view.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final _quick = TextEditingController();

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
              child: FocusTimerWidget(focusMinutes: settings.focusMinutes, now: now),
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