import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/formats.dart';
import '../../../core/db/app_database.dart';
import '../../import/presentation/import_screen.dart';
import '../data/bookkeeping_repository.dart';
import 'bookkeeping_providers.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});
  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  String _filter = 'all'; // all / this / prev
  late Future<List<Transaction>> _future;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(bookkeepingRepositoryProvider);
    _future = _load(repo);
  }

  void _reload() {
    setState(() {
      _future = _load(ref.read(bookkeepingRepositoryProvider));
    });
  }

  Future<List<Transaction>> _load(BookkeepingRepository repo) async {
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) return const [];
    final l = ledgers.first.id;
    final now = DateTime.now();
    final key = monthKey(now);
    switch (_filter) {
      case 'this':
        return repo.transactionsInMonth(ledgerId: l, month: key);
      case 'prev':
        return repo.transactionsInMonth(
            ledgerId: l, month: prevMonthKey(key));
      default:
        return repo.recentTransactions(ledgerId: l, limit: 200);
    }
  }

  Widget _chip(String label, String v) => FilterChip(
        label: Text(label),
        selected: _filter == v,
        onSelected: (_) {
          _filter = v;
          _reload();
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('流水明细'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ImportScreen(database: ref.read(databaseProvider)),
              ));
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _chip('全部', 'all'),
            const SizedBox(width: 8),
            _chip('本月', 'this'),
            const SizedBox(width: 8),
            _chip('上月', 'prev'),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Transaction>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
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
                    leading: Icon(
                        t.direction == 'income'
                            ? Icons.payments
                            : Icons.receipt_long),
                    title: Text(t.counterparty.isEmpty ? '收支' : t.counterparty),
                    subtitle: Row(children: [
                      if (t.isPending)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDEDED),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('待确认',
                                style: TextStyle(fontSize: 10)),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          t.remark.isEmpty
                              ? t.bookAt.toIso8601String().substring(0, 10)
                              : t.remark,
                        ),
                      ),
                    ]),
                    trailing: Text(
                      '${t.direction == 'income' ? '+' : '-'}¥ ${formatCents(t.amountCents)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: t.direction == 'income'
                              ? const Color(0xFF4CB3C4)
                              : Theme.of(context).colorScheme.primary),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}