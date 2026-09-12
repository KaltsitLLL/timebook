import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../data/bookkeeping_repository.dart';
import 'bookkeeping_providers.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookkeepingRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('流水明细')),
      body: FutureBuilder(
        future: _load(repo),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('暂无流水'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = rows[i];
              return ListTile(
                leading: Icon(t.direction == 'income' ? Icons.payments : Icons.receipt_long),
                title: Text(t.counterparty.isEmpty ? '收支' : t.counterparty),
                subtitle: Text(t.remark.isEmpty ? t.bookAt.toIso8601String().substring(0, 10) : t.remark),
                trailing: Text(
                  '${t.direction == 'income' ? '+' : '-'}¥ ${(t.amountCents / 100).toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: t.direction == 'income'
                          ? const Color(0xFF4CB3C4)
                          : Theme.of(context).colorScheme.primary),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Transaction>> _load(BookkeepingRepository repo) async {
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) return const [];
    return repo.recentTransactions(ledgerId: ledgers.first.id, limit: 100);
  }
}