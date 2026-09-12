import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../data/bookkeeping_repository.dart';
import 'add_transaction_sheet.dart';
import 'bookkeeping_providers.dart';
import 'transaction_list_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookkeepingRepositoryProvider);
    return Scaffold(
      body: FutureBuilder(
        future: _load(repo),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          return _HomeView(balanceCents: d.$1, delta: d.$2, recent: d.$3);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddTransactionSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Future<(int, (int, int), List<Transaction>)> _load(
      BookkeepingRepository repo) async {
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) return (0, (0, 0), const <Transaction>[]);
    final l = ledgers.first.id;
    final s = await repo.monthlySummary(ledgerId: l, month: _monthKey(DateTime.now()));
    final recent = await repo.recentTransactions(ledgerId: l, limit: 6);
    return (s.incomeCents - s.expenseCents, (s.incomeCents, s.expenseCents), recent);
  }

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

class _HomeView extends StatelessWidget {
  const _HomeView(
      {required this.balanceCents, required this.delta, required this.recent});
  final int balanceCents;
  final (int, int) delta;
  final List<Transaction> recent;

  String get _fmt => '¥ ${(balanceCents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = recent.isEmpty;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              colors: [Color(0xFF3F77B6), Color(0xFF6FA8DC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('本月结余', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .85))),
          const SizedBox(height: 4),
          Text(_fmt, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          Row(children: [
            Text('收入 ¥ ${(delta.$1 / 100).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(width: 22),
            Text('支出 ¥ ${(delta.$2 / 100).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ]),
        ]),
      ),
      const SizedBox(height: 18),
      if (empty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(children: [
            Icon(Icons.account_balance_wallet_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text('还没有账单\n点击右下角「记一笔」开始', textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        )
      else ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('最近流水', style: theme.textTheme.titleMedium),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TransactionListScreen())),
              child: const Text('全部'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final t in recent)
          ListTile(
            dense: true,
            leading: CircleAvatar(child: Icon(t.direction == 'income' ? Icons.payments : Icons.receipt_long)),
            title: Text(t.counterparty.isEmpty
                ? (t.direction == 'income' ? '收入' : '支出')
                : t.counterparty),
            trailing: Text(
              '${t.direction == 'income' ? '+' : '-'}¥ ${(t.amountCents / 100).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: t.direction == 'income'
                    ? const Color(0xFF4CB3C4)
                    : theme.colorScheme.primary),
            ),
          ),
      ],
    ]);
  }
}