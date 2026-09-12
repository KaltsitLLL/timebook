import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/formats.dart';
import '../../../core/db/app_database.dart';
import '../data/bookkeeping_repository.dart';
import 'add_transaction_sheet.dart';
import 'bookkeeping_providers.dart';
import 'budget_screen.dart';
import 'transaction_list_screen.dart';
import 'widgets/category_donut.dart';

/// 分类色板（冷色），用于环形图切片与分类彩色块。
const List<Color> _coldPalette = [
  Color(0xFF5B9BD5), Color(0xFF4DB6AC), Color(0xFF5C6BC0),
  Color(0xFF8F9AD1), Color(0xFF4A7DB0), Color(0xFF7FB3D5),
];

/// 分类 icon 名称 → IconData（表内 icon 为字符串，默认 receipt_long）。
IconData _catIcon(String name) {
  switch (name) {
    case 'restaurant': return Icons.restaurant;
    case 'shopping': return Icons.shopping_bag;
    case 'directions': return Icons.directions_bus;
    case 'movie': return Icons.movie;
    case 'home': return Icons.home;
    case 'school': return Icons.school;
    case 'savings': return Icons.savings;
    default: return Icons.receipt_long;
  }
}

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
          return _HomeView(
              balanceCents: d.$1,
              delta: d.$2,
              recent: d.$3,
              catSlices: d.$4,
              catMap: d.$5,
              budgetSub: d.$6);
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

  Future<(int, (int, int), List<Transaction>, List<DonutSlice>,
      Map<int?, (Color, String)>, String)> _load(BookkeepingRepository repo) async {
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) {
      return (0, (0, 0), const <Transaction>[], const <DonutSlice>[],
          const <int?, (Color, String)>{}, '去设置');
    }
    final l = ledgers.first.id;
    final month = _monthKey(DateTime.now());
    final s = await repo.monthlySummary(ledgerId: l, month: month);
    final recent = await repo.recentTransactions(ledgerId: l, limit: 6);
    final cats = await repo.categories(l);
    final catNames = <int?, String>{for (final c in cats) c.id: c.name};
    final spends = await repo.categorySpending(l, month);
    final slices = <DonutSlice>[];
    var idx = 0;
    for (final sp in spends) {
      if (sp.amountCents > 0) {
        slices.add(DonutSlice(
          color: _coldPalette[idx % _coldPalette.length],
          value: sp.amountCents,
          label: catNames[sp.categoryId] ?? '其他',
        ));
        idx++;
      }
    }
    final catMap = <int?, (Color, String)>{
      for (var i = 0; i < cats.length; i++)
        cats[i].id: (_coldPalette[i % _coldPalette.length], cats[i].icon),
    };
    final bp = await repo.budgetProgress(ledgerId: l, month: month);
    final budgetSub =
        bp.totalBudgetCents == 0 ? '去设置' : '剩 ¥ ${formatCents(bp.totalBudgetCents - bp.totalSpentCents)}';
    return (s.incomeCents - s.expenseCents, (s.incomeCents, s.expenseCents),
        recent, slices, catMap, budgetSub);
  }

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

class _HomeView extends StatelessWidget {
  const _HomeView(
      {required this.balanceCents,
      required this.delta,
      required this.recent,
      required this.catSlices,
      required this.catMap,
      required this.budgetSub});
  final int balanceCents;
  final (int, int) delta;
  final List<Transaction> recent;
  final List<DonutSlice> catSlices;
  final Map<int?, (Color, String)> catMap;
  final String budgetSub;

  String get _fmt => '¥ ${formatCents(balanceCents)}';

  Widget _categoryAvatar(Transaction t, ColorScheme scheme) {
    if (t.direction == 'income') {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF4CB3C4).withValues(alpha: .18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.payments, color: Color(0xFF4CB3C4)),
      );
    }
    final entry = catMap[t.categoryId];
    final color = entry?.$1 ?? scheme.primary;
    final icon = entry == null ? Icons.receipt_long : _catIcon(entry.$2);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
            Text('收入 ¥ ${formatCents(delta.$1)}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(width: 22),
            Text('支出 ¥ ${formatCents(delta.$2)}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const BudgetScreen())),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: .18)),
              icon: const Icon(Icons.savings_outlined, size: 16),
              label: const Text('预算进度', style: TextStyle(fontSize: 12)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      Row(children: [
        _QuickCard(
          icon: Icons.receipt_long,
          title: '流水明细',
          sub: '${recent.length} 笔记录',
          color: scheme.primaryContainer,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const TransactionListScreen())),
        ),
        const SizedBox(width: 12),
        _QuickCard(
          icon: Icons.savings,
          title: '本月预算',
          sub: budgetSub,
          color: scheme.secondaryContainer,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const BudgetScreen())),
        ),
      ]),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('分类支出', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            CategoryDonut(slices: catSlices, centerLabel: '本月支出'),
          ]),
        ),
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
            leading: _categoryAvatar(t, scheme),
            title: Text(t.counterparty.isEmpty
                ? (t.direction == 'income' ? '收入' : '支出')
                : t.counterparty),
            trailing: Text(
              '${t.direction == 'income' ? '+' : '-'}¥ ${formatCents(t.amountCents)}',
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

class _QuickCard extends StatelessWidget {
  const _QuickCard(
      {required this.icon,
      required this.title,
      required this.sub,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 22, color: scheme.onPrimaryContainer),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(sub, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}