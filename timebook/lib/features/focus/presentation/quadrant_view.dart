import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import 'focus_providers.dart';

enum _Q { q1, q2, q3, q4 }

/// 四象限视图：按「重要 = priority<=1」与「紧急 = dueDate 在 2 天内截止」分组。
class QuadrantView extends ConsumerWidget {
  const QuadrantView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(focusRepositoryProvider);
    final now = ref.read(focusClockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('四象限')),
      body: FutureBuilder(
        future: repo.openTasks(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final tasks = snap.data!;
          final groups = <_Q, List<Task>>{for (final q in _Q.values) q: []};
          for (final t in tasks) {
            final urgent =
                t.dueDate != null && t.dueDate!.isBefore(now().add(const Duration(days: 2)));
            final important = t.priority <= 1;
            groups[(important && urgent)
                ? _Q.q1
                : (important ? _Q.q2 : (urgent ? _Q.q3 : _Q.q4))]!.add(t);
          }
          const titles = {
            _Q.q1: '重要·紧急',
            _Q.q2: '重要·不紧急',
            _Q.q3: '不重要·紧急',
            _Q.q4: '不重要·不紧急',
          };
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(12),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              for (final q in _Q.values)
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titles[q]!,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView(children: [
                            for (final t in groups[q]!)
                              ListTile(
                                dense: true,
                                title: Text(t.title,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}