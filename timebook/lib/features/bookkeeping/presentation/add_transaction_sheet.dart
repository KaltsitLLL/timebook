import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
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
    case 'directions_bus': return Icons.directions_bus;
    case 'shopping_bag': return Icons.shopping_bag;
    case 'movie': return Icons.movie;
    case 'home': return Icons.home;
    case 'medical_services': return Icons.medical_services;
    case 'payments': return Icons.payments;
    case 'more_horiz': return Icons.more_horiz;
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

  /// 打开账户选择弹层：列出「不记账户」+ 各真实账户，点击后更新选中态并关闭。
  Future<void> _openAccountPicker() {
    final accounts =
        ref.read(ledgerAccountsProvider).value ?? const <Account>[];
    return showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('pick_none'),
              leading: const Icon(Icons.credit_card_off_outlined),
              title: const Text('不记账户'),
              trailing: _useNoneAccount
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                setState(() {
                  _useNoneAccount = true;
                  _pickedAccountId = null;
                });
                Navigator.pop(ctx);
              },
            ),
            for (final a in accounts)
              ListTile(
                key: Key('pick_${a.id}'),
                leading: const Icon(Icons.credit_card),
                title: Text(a.name),
                trailing: !_useNoneAccount && _pickedAccountId == a.id
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () {
                  setState(() {
                    _pickedAccountId = a.id;
                    _useNoneAccount = false;
                  });
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 记一笔顶部方向胶囊：选中=primary/tertiary 底·白字；未选中=surface 底·outlineVariant 边框。
  Widget _directionPill(String key, String label, String value,
      {required bool selected, required Color selectedColor}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: Key(key),
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _direction = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedColor : scheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

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

    // 账户区单 chip 的 label：不记账户 / 当前有效账户名 / 无账户时「选择账户」。
    final String accountLabel;
    if (_useNoneAccount) {
      accountLabel = '不记账户';
    } else {
      final found = accounts.where((a) => a.id == effectiveAccountId);
      accountLabel = found.isEmpty ? '选择账户' : found.first.name;
    }

    final raw = _amount.text.trim();
    final arithCents = parseArithmeticToCents(raw);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('记一笔', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            _directionPill(
              'dir_exp',
              '支出',
              'expense',
              selected: _direction == 'expense',
              selectedColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            // 收入青绿胶囊：theme.tertiary 即原型 incomeColor #4CB3C4
            _directionPill(
              'dir_inc',
              '收入',
              'income',
              selected: _direction == 'income',
              selectedColor: incomeColor,
            ),
          ],
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
        // 金额区（对齐原型：¥ 22/700 + 40/700 tabular 输入，baseline 对齐 gap 6，占位 40px 灰显）
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('¥',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1B2634))),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                key: const Key('amount_field'),
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2634),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    fontSize: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
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
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('account_pick'),
                borderRadius: BorderRadius.circular(999),
                onTap: _openAccountPicker,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.credit_card,
                          size: 18,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(accountLabel,
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 日期 chip（原型 m3.chip：outlineVariant 边框·surface 底·图标 18·字号 13）
            Container(
              key: const Key('book_at_chip'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('今天 $hh:$mm',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (cats.isEmpty)
          const Text('默认分类未生成，请新建账本或稍后重试')
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