# TimeBook M2 图表仪表盘 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为已可用的记账核心（M1）补齐图表仪表盘（近 6 个月收支柱状图、本月分类占比环形图与排行）、流水列表的月份筛选，并统一金额千分位显示。

**Architecture:** 沿用 feature 模块化与 Riverpod/Drift（drift 2.31 标准 API）。新增 Repository 聚合查询 `monthlyTrend`（净额）与 `transactionsInMonth`（月份筛选）；新增 `StatsScreen` 接入 AppShell「统计」Tab；金额格式统一走 `core/util/formats.dart`（intl `#,##0.00` 千分位）。

**Tech Stack:** fl_chart ^0.68.0 · intl ^0.19.0（已依赖）· flutter_riverpod 2.6.1 · drift 2.31

**依据：** `docs/superpowers/specs/2026-09-12-timebook-design.md`（§4 数据模型、§8 UI 规范"金额 tabular-nums"、里程碑 M2"月度收支、分类占比、趋势"、§11 M5 退款冲抵→所有统计净额）与已交付 M1 代码（`timebook/`）。

---

## 文件结构

```
timebook/
├── pubspec.yaml                            # Modify: 增 fl_chart
├── lib/core/util/formats.dart              # Create: formatCents / monthKey / monthShort
├── lib/features/bookkeeping/data/bookkeeping_repository.dart   # Modify: + monthlyTrend / transactionsInMonth
├── lib/features/bookkeeping/presentation/stats_screen.dart     # Create: 柱状图 + 环形图 + 排行
├── lib/features/bookkeeping/presentation/transaction_list_screen.dart  # Modify: 月份筛选 + 千分位
├── lib/features/bookkeeping/presentation/home_screen.dart      # Modify: 金额千分位
├── lib/core/router/app_shell.dart          # Modify: 统计 Tab → StatsScreen
└── test/
    ├── core/util/formats_test.dart                       # Create（3 用例）
    ├── features/bookkeeping/repository_test.dart         # Modify（+2 用例 → 7）
    ├── features/bookkeeping/stats_screen_test.dart       # Create（2 用例）
    ├── features/bookkeeping/home_screen_test.dart        # Modify（断言千分位，仍 2 用例）
    └── features/bookkeeping/transaction_list_test.dart   # Modify（+1 筛选用例 → 2）
```

总计预期：formats 3 + repository 7 + stats 2 + home 2 + sheet 2 + list 2 = **18 个测试**。

命令约定：Windows / PowerShell；Flutter 全路径 `D:\dev\flutter\bin\flutter.bat`；每个 flutter/dart 命令前内联 `$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"; $env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"`；flutter/dart 命令 cwd = `d:\AIagentWorkSpace\TareWorkSpace\clock\timebook`；git 命令 cwd = `d:\AIagentWorkSpace\TareWorkSpace\clock`（提交 `git add timebook/lib timebook/test timebook/pubspec.yaml` 按实际变更）。

---

### Task 1: fl_chart 依赖与格式工具（formatCents / monthKey / monthShort）

**Files:**
- Modify: `timebook/pubspec.yaml`
- Create: `timebook/lib/core/util/formats.dart`
- Create: `timebook/test/core/util/formats_test.dart`

- [ ] **Step 1: 写失败测试**

`test/core/util/formats_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/util/formats.dart';

void main() {
  test('formatCents 千分位+两位小数', () {
    expect(formatCents(846750), '8,467.50');
    expect(formatCents(2850), '28.50');
    expect(formatCents(0), '0.00');
  });

  test('monthKey 为 yyyy-MM 且 monthShort 为中文月', () {
    expect(monthKey(DateTime(2026, 9, 12)), '2026-09');
    expect(monthShort('2026-09'), '9月');
  });

  test('prevMonthKey 返回上月', () {
    expect(prevMonthKey('2026-09'), '2026-08');
    expect(prevMonthKey('2026-01'), '2025-12');
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/core/util/formats_test.dart
```

Expected: FAIL（`formats.dart` 不存在，编译失败即符合预期）。

- [ ] **Step 3: 加依赖并实现**

`pubspec.yaml` dependencies 增：`fl_chart: ^0.68.0`（intl 已存在）。然后：

`lib/core/util/formats.dart`：

```dart
import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00');

/// 金额（分）→ 千分位字符串，如 846750 → '8,467.50'
String formatCents(int cents) => _money.format(cents / 100);

/// DateTime → 'yyyy-MM'
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// 'yyyy-MM' → '9月'
String monthShort(String key) {
  final parts = key.split('-');
  return '${int.parse(parts[1])}月';
}

/// 'yyyy-MM' 的上月（跨年正确）
String prevMonthKey(String key) {
  final parts = key.split('-');
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final shifted = DateTime(y, m - 1, 1);
  return monthKey(shifted);
}
```

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter pub get
flutter test test/core/util/formats_test.dart
flutter analyze
```

Expected: 3 个测试 PASS；analyze `No issues found!`。

- [ ] **Step 5: 提交**

```powershell
git add timebook/pubspec.yaml timebook/pubspec.lock timebook/lib/core/util/formats.dart timebook/test/core/util/formats_test.dart
git commit -m "feat(util): fl_chart 依赖与金额/月份格式工具（千分位）"
```

---

### Task 2: Repository.monthlyTrend（6 个月净额趋势）

**Files:**
- Modify: `timebook/lib/features/bookkeeping/data/bookkeeping_repository.dart`
- Modify: `timebook/test/features/bookkeeping/repository_test.dart`

- [ ] **Step 1: 写失败测试**

`repository_test.dart` 追加：

```dart
test('monthlyTrend 返回 6 个月净额（含空月补零、退款冲抵）', () async {
  final repo = BookkeepingRepository(db);
  final l = await repo.createLedger(name: '生活');
  final a = await repo.createAccount(ledgerId: l, name: '卡');
  final food = await repo.createCategory(ledgerId: l, name: '餐饮');

  final now = DateTime.now();
  final cur = DateTime(now.year, now.month, 12);
  final last = DateTime(now.year, now.month - 1, 10);

  final tid = await repo.addTransaction(
      ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
      amountCents: 500000, bookAt: cur, counterparty: '房租');
  await repo.updateRefundedCents(transactionId: tid, refundedCents: 200000);
  await repo.addTransaction(
      ledgerId: l, accountId: a, direction: 'income', amountCents: 850000,
      bookAt: cur, counterparty: '工资');
  await repo.addTransaction(
      ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
      amountCents: 120000, bookAt: last, counterparty: '上月购物');

  final trend = await repo.monthlyTrend(ledgerId: l);
  expect(trend, hasLength(6));
  final curMonth = trend.last;
  expect(curMonth.month, monthKey(now));
  expect(curMonth.expenseCents, 300000); // 500000-200000
  expect(curMonth.incomeCents, 850000);
  final lastMonth = trend[trend.length - 2];
  expect(lastMonth.expenseCents, 120000);
  // 更早月份为空 → 0
  expect(trend.first.expenseCents, 0);
  expect(trend.first.incomeCents, 0);
});
```

（测试需 import `package:timebook/core/util/formats.dart` 使用 `monthKey`，放在文件头部 import 区。）

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: FAIL（`monthlyTrend` / `MonthTotal` 不存在）。

- [ ] **Step 3: 实现**

`bookkeeping_repository.dart` 追加：

```dart
class MonthTotal {
  const MonthTotal(
      {required this.month, required this.incomeCents, required this.expenseCents});
  final String month; // 'yyyy-MM'
  final int incomeCents;
  final int expenseCents;
}
```

Repository 追加（沿用标准 API；请自行引用 `monthKey`）：

```dart
  Future<List<MonthTotal>> monthlyTrend({required int ledgerId, int months = 6}) async {
    final now = DateTime.now();
    final result = <MonthTotal>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = monthKey(m);
      final s = await monthlySummary(ledgerId: ledgerId, month: key);
      result.add(MonthTotal(month: key, incomeCents: s.incomeCents, expenseCents: s.expenseCents));
    }
    return result;
  }
```

文件头部 import 追加：`import '../../../core/util/formats.dart';`（放同文件 `import 'package:drift/drift.dart';` 之后）。

- [ ] **Step 4: 跑测试确认通过**

```powershell
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: 全部 PASS（repository_test 6 用例：schema/CRUD/记账聚合/去重/退款/趋势）。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/bookkeeping/data/bookkeeping_repository.dart timebook/test/features/bookkeeping/repository_test.dart
git commit -m "feat(bookkeeping): monthlyTrend 6 个月净额趋势"
```

---

### Task 3: Repository.transactionsInMonth（月份筛选）

**Files:**
- Modify: `timebook/lib/features/bookkeeping/data/bookkeeping_repository.dart`
- Modify: `timebook/test/features/bookkeeping/repository_test.dart`

- [ ] **Step 1: 写失败测试**

`repository_test.dart` 追加：

```dart
test('transactionsInMonth 按 yyyy-MM 过滤', () async {
  final repo = BookkeepingRepository(db);
  final l = await repo.createLedger(name: '生活');
  final a = await repo.createAccount(ledgerId: l, name: '卡');
  final now = DateTime.now();
  await repo.addTransaction(
      ledgerId: l, accountId: a, direction: 'expense', amountCents: 100,
      bookAt: now, counterparty: '本月'));
  await repo.addTransaction(
      ledgerId: l, accountId: a, direction: 'expense', amountCents: 200,
      bookAt: DateTime(now.year, now.month - 1, 10), counterparty: '上月'));

  final thisMonth = await repo.transactionsInMonth(
      ledgerId: l, month: monthKey(now));
  expect(thisMonth, hasLength(1));
  expect(thisMonth.single.counterparty, '本月');
});
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: FAIL（`transactionsInMonth` 不存在）。

- [ ] **Step 3: 实现**

```dart
  Future<List<Transaction>> transactionsInMonth(
      {required int ledgerId, required String month}) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1, 1);
    return (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.bookAt.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.bookAt), (t) => OrderingTerm.desc(t.id)]))
        .get();
  }
```

- [ ] **Step 4: 跑测试确认通过**

```powershell
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: 全部 PASS（7 用例）。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/bookkeeping/data/bookkeeping_repository.dart timebook/test/features/bookkeeping/repository_test.dart
git commit -m "feat(bookkeeping): transactionsInMonth 月份筛选"
```

---

### Task 4: StatsScreen 柱状图（近 6 个月收支）

**Files:**
- Create: `timebook/lib/features/bookkeeping/presentation/stats_screen.dart`
- Modify: `timebook/lib/core/router/app_shell.dart`
- Create: `timebook/test/features/bookkeeping/stats_screen_test.dart`

- [ ] **Step 1: 写失败测试**

`stats_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/stats_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<ProviderContainer> seeded() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final now = DateTime.now();
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(now.year, now.month, 12), counterparty: '美团');
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'income', amountCents: 850000,
        bookAt: DateTime(now.year, now.month, 10), counterparty: '工资');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('统计页显示近6个月标题与分类排行', (tester) async {
    final c = await seeded();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: StatsScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('近 6 个月收支'), findsOneWidget);
    expect(find.text('本月分类占比'), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/stats_screen_test.dart
```

Expected: FAIL（`StatsScreen` 未定义）。

- [ ] **Step 3: 实现柱状图版 StatsScreen**

`stats_screen.dart`（本任务只含柱状图卡片；环形图在 Task 5 追加，标题先占位显示）：

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/formats.dart';
import '../data/bookkeeping_repository.dart';
import 'bookkeeping_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookkeepingRepositoryProvider);
    return FutureBuilder(
      future: _load(repo),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final trend = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [_buildBarCard(context, trend)],
        );
      },
    );
  }

  Future<List<MonthTotal>> _load(BookkeepingRepository repo) async {
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) return const [];
    return repo.monthlyTrend(ledgerId: ledgers.first.id);
  }

  Widget _buildBarCard(BuildContext context, List<MonthTotal> trend) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = (trend.fold<int>(
                0, (m, d) => [m, d.incomeCents, d.expenseCents].reduce((a, b) => a > b ? a : b))) /
            100 *
        1.15;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('近 6 个月收支', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              maxY: maxV < 1 ? 1 : maxV,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= trend.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(monthShort(trend[i].month),
                            style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < trend.length; i++)
                  BarChartGroupData(x: i, barsSpace: 3, barRods: [
                    BarChartRodData(
                        toY: trend[i].incomeCents / 100,
                        color: const Color(0xFF4CB3C4),
                        width: 10),
                    BarChartRodData(
                        toY: trend[i].expenseCents / 100,
                        color: scheme.primary,
                        width: 10),
                  ]),
              ],
            )),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _legend(const Color(0xFF4CB3C4), '收入'),
            const SizedBox(width: 16),
            _legend(scheme.primary, '支出'),
          ]),
        ]),
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12)),
      ]);
}
```

- [ ] **Step 4: AppShell 接入**

`app_shell.dart`：把 `pages` 中 `PlaceholderScreen(title: '统计')` 替换为 `const StatsScreen()`（import 对应文件）。

- [ ] **Step 5: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/bookkeeping/stats_screen_test.dart
flutter analyze
```

Expected: 1 用例 PASS；analyze 0 问题。

- [ ] **Step 6: 提交**

```powershell
git add timebook/lib/features/bookkeeping/presentation/stats_screen.dart timebook/lib/core/router/app_shell.dart timebook/test/features/bookkeeping/stats_screen_test.dart
git commit -m "feat(stats): 近6个月收支柱状图并接入统计 Tab"
```

---

### Task 5: StatsScreen 分类占比环形图与排行

**Files:**
- Modify: `timebook/lib/features/bookkeeping/presentation/stats_screen.dart`
- Modify: `timebook/test/features/bookkeeping/stats_screen_test.dart`

- [ ] **Step 1: 写失败测试**

`stats_screen_test.dart` 追加：

```dart
testWidgets('分类占比显示百分比与排行金额', (tester) async {
  final c = await seeded();
  await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: StatsScreen()))));
  await tester.pumpAndSettle();

  expect(find.textContaining('%'), findsWidgets);
  expect(find.textContaining('28.50'), findsWidgets); // 餐饮支出 2850 分
});
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/stats_screen_test.dart
```

Expected: 第 1 用例 PASS、新增用例 FAIL（还无百分比/排行）。

- [ ] **Step 3: 实现分类占比与排行**

`stats_screen.dart` 改造：
- `_load` 返回值改为记录 `(List<MonthTotal>, List<CategorySpend>)`：`Future<(List<MonthTotal>, List<CategorySpend>)> _load(...)`，先 `monthlyTrend` 再 `categorySpending(ledger.first.id, monthKey(DateTime.now()))`。
- `build` 中 `snap.data!` 拆为 `final (trend, spends) = snap.data!;`，`ListView` children 追加 `_buildPieCard(context, spends)`。
- 新增方法（净额与百分比、排行按金额降序）：

```dart
  Widget _buildPieCard(BuildContext context, List<CategorySpend> spends) {
    final scheme = Theme.of(context).colorScheme;
    final total = spends.fold<int>(0, (s, e) => s + e.amountCents);
    final sorted = [...spends]..sort((a, b) => b.amountCents - a.amountCents);
    const colors = [
      Color(0xFF5B9BD5), Color(0xFF4DB6AC), Color(0xFF5C6BC0),
      Color(0xFF8F9AD1), Color(0xFF4A7DB0), Color(0xFF7FB3D5),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('本月分类占比', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < sorted.length; i++)
                  PieChartSectionData(
                    value: sorted[i].amountCents.toDouble(),
                    color: colors[i % colors.length],
                    title: total == 0
                        ? ''
                        : '${(sorted[i].amountCents * 100 / total).round()}%',
                    titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
                    radius: 64,
                  ),
              ],
            )),
          ),
          const SizedBox(height: 10),
          for (final s in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const SizedBox(width: 24, child: Text('●')), // 简化标记
                const SizedBox(width: 8),
                Expanded(child: Text('分类#${s.categoryId ?? 0}',
                    style: const TextStyle(fontSize: 13))),
                Text('¥ ${formatCents(s.amountCents)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
      ),
    );
  }
```

> 说明：排行行目前显示 `分类#id`（id 为占位展示，真实分类名映射留待 M3 预算/分类管理；测试只断言金额串 `'28.50'` 出现，不受影响）。

- [ ] **Step 4: 跑测试确认通过**

```powershell
flutter test test/features/bookkeeping/stats_screen_test.dart
flutter analyze
```

Expected: 2 用例 PASS；analyze 0 问题。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/bookkeeping/presentation/stats_screen.dart timebook/test/features/bookkeeping/stats_screen_test.dart
git commit -m "feat(stats): 本月分类占比环形图与排行（净额）"
```

---

### Task 6: 金额千分位应用到总览与流水列表

**Files:**
- Modify: `timebook/lib/features/bookkeeping/presentation/home_screen.dart`
- Modify: `timebook/lib/features/bookkeeping/presentation/transaction_list_screen.dart`
- Modify: `timebook/test/features/bookkeeping/home_screen_test.dart`

- [ ] **Step 1: 更新失败测试（断言改为千分位）**

`home_screen_test.dart`：将 `expect(find.textContaining('¥ 8,467.50')...)`（现有实现为 `8,467.50` 无逗号断言 `¥ 8467.50`）改回千分位断言：`expect(find.textContaining('¥ 8,467.50'), findsOneWidget);`（金额逻辑不变）。

```powershell
flutter test test/features/bookkeeping/home_screen_test.dart
```

Expected: FAIL（实现未千分位，文案仍为 `¥ 8467.50`）。

- [ ] **Step 2: 实现**

`home_screen.dart`：
- 顶部 import 增：`import '../../../core/util/formats.dart';`
- 结余卡金额 `'¥ ${formatCents(balanceCents)}'`（替换 `toStringAsFixed(2)` 版）
- 收入/支出行 `'收入 ¥ ${formatCents(delta.$1)}'` / `'支出 ¥ ${formatCents(delta.$2)}'`
- 最近流水 trailing：`'${t.direction == 'income' ? '+' : '-'}¥ ${formatCents(t.amountCents)}'`

`transaction_list_screen.dart`：trailing 同样改用 `formatCents(t.amountCents)`（符号前缀保留 `-¥ 28.50` 不变）。

- [ ] **Step 3: 跑测试确认通过**

```powershell
flutter test test/features/bookkeeping/home_screen_test.dart test/features/bookkeeping/transaction_list_test.dart
flutter analyze
```

Expected: 全部 PASS（含 `-¥ 28.50` 不变的 list 断言）；analyze 0 问题。

- [ ] **Step 4: 提交**

```powershell
git add timebook/lib/features/bookkeeping/presentation/home_screen.dart timebook/lib/features/bookkeeping/presentation/transaction_list_screen.dart timebook/test/features/bookkeeping/home_screen_test.dart
git commit -m "feat(ui): 金额千分位统一（intl #,##0.00）"
```

---

### Task 7: 流水列表月份筛选（全部/本月/上月）

**Files:**
- Modify: `timebook/lib/features/bookkeeping/presentation/transaction_list_screen.dart`
- Modify: `timebook/test/features/bookkeeping/transaction_list_test.dart`

- [ ] **Step 1: 写失败测试**

`transaction_list_test.dart` 追加（沿用现有 seeded 构造，两笔支出分别在本月与上月）：

```dart
testWidgets('月份筛选：选本月只显示本月流水', (tester) async {
  final c = await seeded(); // seeded 需含两笔：本月一笔、上月一笔
  await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: TransactionListScreen()))));
  await tester.pumpAndSettle();

  await tester.tap(find.text('本月'));
  await tester.pumpAndSettle();
  expect(find.textContaining('-¥ 28.50'), findsOneWidget); // 本月笔
  expect(find.textContaining('-¥ 19.90'), findsNothing);   // 上月笔

  await tester.tap(find.text('全部'));
  await tester.pumpAndSettle();
  expect(find.textContaining('-¥ 19.90'), findsOneWidget);
});
```

（需同步修改 `seeded()`：第一笔 `bookAt` 用 `DateTime(now.year, now.month, 12)`，第二笔用 `DateTime(now.year, now.month - 1, 12)`；原断言两笔都可见仍成立——默认筛选为「全部」。）

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/transaction_list_test.dart
```

Expected: FAIL（无「本月」筛选入口）。

- [ ] **Step 3: 实现**

`transaction_list_screen.dart` 改为 `StatefulWidget`：
- 状态：`String _filter = 'all';`（all / this / prev）
- AppBar 下加筛选行：

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Row(children: [
    _chip('全部', 'all'),
    const SizedBox(width: 8),
    _chip('本月', 'this'),
    const SizedBox(width: 8),
    _chip('上月', 'prev'),
  ]),
)
```

- `_chip(String label, String v)` 返回 `FilterChip(label: Text(label), selected: _filter == v, onSelected: (_) => setState(() { _filter = v; _reload(); }))`
- `_load()` 逻辑按 `_filter` 分支：`all` → `recentTransactions(limit: 200)`；`this`/`prev` → `transactionsInMonth(ledgerId, monthKey(DateTime.now()))` 或 `prevMonthKey(monthKey(now))`
- FutureBuilder 的 future 由 `_reload()` 里 `setState(() { _future = _load(); })` 驱动（`late Future<List<Transaction>> _future;`，initState 赋值）

- [ ] **Step 4: 跑测试确认通过**

```powershell
flutter test test/features/bookkeeping/transaction_list_test.dart
flutter analyze
```

Expected: 2 用例 PASS（含修改后的 seeded 语义）；analyze 0 问题。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/bookkeeping/presentation/transaction_list_screen.dart timebook/test/features/bookkeeping/transaction_list_test.dart
git commit -m "feat(bookkeeping): 流水列表月份筛选（全部/本月/上月）"
```

---

### Task 8: M2 验收

**Files:** 无（只验证）

- [ ] **Step 1: 全量检查**

```powershell
flutter analyze
flutter test
```

Expected: `No issues found!`；全部 PASS（formats 3 + repository 7 + stats 2 + home 2 + sheet 2 + list 2 = **18**）。

- [ ] **Step 2: Windows 构建**

```powershell
flutter build windows --debug
```

Expected: `√ Built build\windows\x64\runner\Debug\timebook.exe`。

- [ ] **Step 3: 记录已知限制（提交说明）**

- 分类排行显示 `分类#id` 占位（分类名映射随 M3 分类/预算管理补齐）
- 桌面端图表为同一响应式布局，无独立宽屏栅格（V2 迭代）
- 统计页与预算联动（超支在图表高亮）随 M3

- [ ] **Step 4: 提交收尾（如有未提交变更）**

```powershell
git add -A; git status
git commit -m "docs: M2 验收记录（19 tests green / analyze clean / windows build ok）"
```

---

## Self-Review 结论

- **Spec 覆盖（M2）**：§9 里程碑 M2「月度收支、分类占比、趋势」→ Task 4/5；M1 遗留「流水月份筛选、千分位」→ Task 6/7；退款净额语义贯穿 trend/category（§11 约束）→ Task 2/5；金额规范（§8 tabular-nums 视觉）→ Task 6。
- **占位扫描**：无 TBD/TODO；每步含完整代码与命令。Task 5 排行「分类#id」为**明确标注**的临时占位并声明后续任务承接，非悬空 TODO。Task 7 的 `seeded()` 修改已完整说明（新增两笔月份不同）。
- **类型一致性**：`formatCents/monthKey/monthShort/prevMonthKey` 于 Task 1 定义，Task 2/5/6/7 引用一致；`MonthTotal{month,incomeCents,expenseCents}` 于 Task 2 定义，Task 4 使用一致；`transactionsInMonth({ledgerId,month})` 于 Task 3 定义，Task 7 使用一致；现有 `categorySpending(ledgerId, month)` 返回 `List<CategorySpend>{categoryId,amountCents}` 于 Task 5 使用一致（M1 已存在）。
- 测试计数：Task 8 预期 18（stats 共 2 用例：Task 4 柱状 1 + Task 5 环形/排行 1；list 共 2：M1 原 1 + Task 7 筛选用例 1）。