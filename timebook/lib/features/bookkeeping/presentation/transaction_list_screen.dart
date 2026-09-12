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

  // 多选模式
  bool _selecting = false;
  final Set<int> _selected = {};

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

  Future<int?> _ledgerId() async {
    final ledgers = await ref.read(bookkeepingRepositoryProvider).ledgers();
    return ledgers.isEmpty ? null : ledgers.first.id;
  }

  Future<void> _enterSelect() async {
    final l = await _ledgerId();
    if (l == null) return;
    setState(() {
      _selecting = true;
      _selected.clear();
    });
  }

  Future<void> _exitSelect() async {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
    _reload();
  }

  void _toggleSelect(int id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  Future<void> _bulkCategory() async {
    final repo = ref.read(bookkeepingRepositoryProvider);
    final l = await _ledgerId();
    if (l == null || _selected.isEmpty) return;
    final cats = await repo.categories(l);
    if (!mounted) return;
    final picked = await showDialog<int?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('设置为分类'),
        children: [
          SimpleDialogOption(
            key: const Key('bulk_category_none'),
            onPressed: () => Navigator.pop(ctx, -1), // 清除分类
            child: const Text('不设置分类'),
          ),
          for (final c in cats)
            SimpleDialogOption(
              key: Key('bulk_category_${c.id}'),
              onPressed: () => Navigator.pop(ctx, c.id),
              child: Text(c.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    final ids = _selected.toList();
    // -1 表示清除分类
    await repo.bulkUpdateCategory(
        ids: ids, categoryId: picked == -1 ? null : picked);
    if (!mounted) return;
    _showMessage('已更新 ${ids.length} 笔');
    await _exitSelect();
  }

  Future<void> _bulkDelete() async {
    final repo = ref.read(bookkeepingRepositoryProvider);
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除流水'),
        content: Text('确定删除选中的 ${_selected.length} 笔流水？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              key: const Key('bulk_delete_confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    final ids = _selected.toList();
    await repo.bulkDelete(ids);
    if (!mounted) return;
    _showMessage('已删除 ${ids.length} 笔');
    await _exitSelect();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
          if (!_selecting)
            TextButton(
              key: const Key('select_mode'),
              onPressed: _enterSelect,
              child: const Text('选择'),
            ),
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
      bottomNavigationBar: _selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Text('已选 ${_selected.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                      key: const Key('bulk_category'),
                      onPressed: _bulkCategory,
                      child: const Text('改分类')),
                  TextButton(
                      key: const Key('bulk_delete'),
                      onPressed: _bulkDelete,
                      child: const Text('删除')),
                  TextButton(
                      key: const Key('bulk_cancel'),
                      onPressed: _exitSelect,
                      child: const Text('取消')),
                ]),
              ),
            )
          : null,
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
                  final selected = _selected.contains(t.id);
                  return ListTile(
                    onTap: _selecting
                        ? () => _toggleSelect(t.id)
                        : null,
                    selected: selected,
                    selectedTileColor:
                        Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                    leading: _selecting
                        ? Checkbox(
                            key: Key('row_check_${t.id}'),
                            value: selected,
                            onChanged: (_) => _toggleSelect(t.id),
                          )
                        : Icon(
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