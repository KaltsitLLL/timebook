import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/formats.dart';
import '../data/daily_summary_service.dart';
import 'daily_providers.dart';

class DailySummaryScreen extends ConsumerWidget {
  const DailySummaryScreen({super.key, this.service, this.date});
  final DailySummaryService? service;
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DailySummaryService svc =
        service ?? ref.watch(dailySummaryServiceProvider);
    final day = (date ?? DateTime.now()).toIso8601String().substring(0, 10);
    return Scaffold(
      appBar: AppBar(title: const Text('每日小结')),
      body: FutureBuilder(
        future: svc.generateFor(date: DateTime.now()),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final s = snap.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('今日小结 · $day', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _statRow('🍅 专注次数', '${s.pomodoroCount}'),
            _statRow('⏱ 专注分钟', '${s.focusMinutes}'),
            _statRow('💸 支出（净额）', '¥ ${formatCents(s.expenseTotalCents)}'),
            _statRow('✅ 完成任务', '${s.tasksDone}'),
            const SizedBox(height: 16),
            FilledButton(
                key: const Key('daily_save'),
                onPressed: () async {
                  await svc.generateFor(date: DateTime.now());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('小结已保存')));
                  }
                },
                child: const Text('保存小结')),
            const SizedBox(height: 18),
            Text('最近记录', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            FutureBuilder(
              future: svc.recent(limit: 7),
              builder: (context, hs) {
                if (!hs.hasData) return const SizedBox();
                final items = hs.data!;
                return Column(children: [
                  for (final r in items)
                    ListTile(dense: true, title: Text(r.date),
                        trailing: Text('🍅${r.pomodoroCount} · ⏱${r.focusMinutes}m · ¥${formatCents(r.expenseTotalCents)}')),
                ]);
              },
            ),
          ]);
        },
      ),
    );
  }

  Widget _statRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(k, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      );
}