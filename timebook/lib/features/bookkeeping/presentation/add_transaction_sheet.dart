import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../../../core/util/formats.dart';
import '../../ai/presentation/open_ai_dialog.dart';
import 'bookkeeping_providers.dart';

/// 分类宫格色板（Category 表无 color 字段，按宫格顺序取色，与首页调色一致）。
const List<Color> _catPalette = [
  Color(0xFF5B9BD5), Color(0xFF4DB6AC), Color(0xFF5C6BC0),
  Color(0xFF8F9AD1), Color(0xFF4A7DB0), Color(0xFF7FB3D5),
];

/// 分类 icon 名称 → IconData（默认 receipt_long）。
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

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});
  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amount = TextEditingController();
  String _direction = 'expense';
  int? _pickedAccountId; // 用户显式选择的真实账户
  bool _useNoneAccount = false; // 无账户模式（Task2）
  int? _pickCategoryId; // 用户显式选择的分类（可空：未选则不落分类）

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? _amountCents(String raw) {
    final n = double.tryParse(raw.trim());
    if (n == null || n <= 0) return null;
    return (n * 100).round();
  }

  Future<void> _save() async {
    final cents = _amountCents(_amount.text);
    if (cents == null) return; // 校验失败：不落库（测试即验证此行为）
    final repo = ref.read(bookkeepingRepositoryProvider);
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) return;
    final ledgerId = ledgers.first.id;
    final accounts = await repo.accounts(ledgerId);
    int? accountId;
    if (_useNoneAccount) {
      accountId = await repo.ensureNoneAccount(ledgerId);
    } else {
      accountId =
          _pickedAccountId ?? await repo.getDefaultAccountId(ledgerId);
      if (accountId == null && accounts.isNotEmpty) accountId = accounts.first.id;
    }
    if (accountId == null) return;
    await repo.addTransaction(
      ledgerId: ledgerId,
      accountId: accountId,
      categoryId: _pickCategoryId,
      direction: _direction,
      amountCents: cents,
      bookAt: DateTime.now(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已记账')));
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop(true);
    }
  }

  Future<void> _openAiDialog() => openAiDialog(context, ref);

  /// 分类宫格单元格：selected 高亮（边框=分类色 + 浅色底，圆角 12）。
  Widget _builtCategoryCell(Category c, int index) {
    final color = _catPalette[index % _catPalette.length];
    final selected = _pickCategoryId == c.id;
    return InkWell(
      key: Key('cat_${c.id}'),
      onTap: () => setState(() => _pickCategoryId = c.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: .14)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_catIcon(c.icon), size: 22, color: color),
            const SizedBox(height: 5),
            Text(c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final accounts =
        ref.watch(ledgerAccountsProvider).value ?? const <Account>[];
    final defaultId = ref.watch(defaultAccountProvider).value;

    final nowChip = DateTime.now();
    final hh = nowChip.hour.toString().padLeft(2, '0');
    final mm = nowChip.minute.toString().padLeft(2, '0');

    final int? effectiveAccountId;
    if (_useNoneAccount) {
      effectiveAccountId = null;
    } else {
      effectiveAccountId = _pickedAccountId ??
          defaultId ??
          (accounts.isEmpty ? null : accounts.first.id);
    }

    final raw = _amount.text.trim();
    final arithCents = parseArithmeticToCents(raw);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('记一笔', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'expense', label: Text('支出')),
            ButtonSegment(value: 'income', label: Text('收入')),
          ],
          selected: {_direction},
          onSelectionChanged: (s) => setState(() => _direction = s.first),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('ai_dialog_open'),
            onPressed: _openAiDialog,
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            label: const Text('AI 记账'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('amount_field'),
          controller: _amount,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '金额（元）',
            border: OutlineInputBorder(),
            prefixText: '¥ ',
          ),
        ),
        if (raw.isNotEmpty && arithCents != null && arithCents > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('= ¥ ${formatCents(arithCents)}',
                  key: const Key('amount_preview'),
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 16),
        Text('账户', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              key: const Key('none_account'),
              label: const Text('不记账户'),
              selected: _useNoneAccount,
              onSelected: (v) => setState(() {
                _useNoneAccount = v;
                if (v) _pickedAccountId = null;
              }),
            ),
            for (final a in accounts)
              ChoiceChip(
                key: Key('account_${a.id}'),
                label: Text(a.name),
                selected: effectiveAccountId == a.id,
                onSelected: (_) => setState(() {
                  _pickedAccountId = a.id;
                  _useNoneAccount = false;
                }),
              ),
            FilterChip(
              key: const Key('book_at_chip'),
              avatar: const Icon(Icons.calendar_today, size: 16),
              label: Text('今天 $hh:$mm'),
              onSelected: (_) {}, // 只读展示，保存仍用 DateTime.now()
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (cats.isEmpty)
          const Text('暂无分类，可在后续里程碑管理')
        else
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              for (var i = 0; i < cats.length; i++)
                _builtCategoryCell(cats[i], i),
            ],
          ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('save_button'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ]),
    );
  }
}