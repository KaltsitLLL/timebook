# TimeBook UI 对齐原型 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Flutter 实现的界面视觉与交互对齐已定稿的 M3 原型（`prototype/Timebook M3 记账原型.html`）：总览页补齐分类环形图卡与双快捷入口、专注页补齐模式切换/任务绑定/完成确认/今日时间线、桌面端 Navigation Rail 响应式、全局视觉细节与暗色模式基础。**硬约束：既有 63 个测试全程保持绿色。**

**Architecture:** `core/theme` 扩展主题层（AppBar/Card/暗色）；总览复用 stats 的净额聚合与 fl_chart PieChart 抽为共享小组件 `CategoryDonut`；专注页将计时器扩展为三模式（读 `pomodoro_settings`），`FocusTimerWidget` 增补模式 chips 与绑定任务回调；完成/打断确认走对话框并在完成时 `addSession`；桌面响应式用 `LayoutBuilder + NavigationRail`；引用原型色板令牌（seed #3F77B6 蓝白浅色调，语义色 收入 #4CB3C4/支出 primary/蓝，图表冷色板）。

**Tech Stack:** Flutter/Dart · fl_chart 0.68 · flutter_riverpod · drift（只读聚合）· Material 3

**依据：** 定稿原型 HTML（视觉黄金标准）+ `docs/superpowers/specs/2026-09-12-timebook-design.md` §7/§8 + 已交付 M1–M6 代码。

---

## 文件结构

```
timebook/lib/
├── core/theme/app_theme.dart                  # Modify: AppBar/Card/分割线/暗色 ColorScheme.dark
├── core/router/app_shell.dart                 # Modify: LayoutBuilder → NavigationRail（宽屏）/NavigationBar（窄屏）
├── features/bookkeeping/presentation/
│   ├── widgets/category_donut.dart            # Create: 环形图共享组件（中心合计+Top4 图例）
│   ├── home_screen.dart                       # Modify: 分类支出卡 + 流水/预算双快捷入口 + 分类彩色行
│   └── stats_screen.dart                      # Modify: 复用 CategoryDonut（去重复实现）
├── features/focus/presentation/
│   ├── focus_timer_widget.dart                # Modify: 三模式 chips + 绑定任务提示 + 完成回调
│   ├── focus_timer_widget.dart → 追加 _Mode enum 支持
│   ├── focus_screen.dart                      # Modify: 🍅 绑定、完成确认对话框、今日时间线、addSession
│   └── timeline_widget.dart                   # Create: 今日专注时间线（会话列表）
└── lib/core/theme/app_theme_test.dart         # 可选（轻断言主题存在）
```

命令约定（全项目一致）：Windows/PowerShell；Flutter 全路径 `D:\dev\flutter\bin\flutter.bat`；命令前内联镜像 env；flutter 命令 cwd=`...\clock\timebook`；git cwd=`...\clock`。

---

### Task 1: 全局主题增强 + 暗色模式基础

**Files:** Modify `lib/core/theme/app_theme.dart` · 冒烟 `flutter run -d windows`（不写新测试，仅改主题；回归由 T6 全量承担）

- [ ] **Step 1: 实现**

`app_theme.dart` 扩展：

```dart
import 'package:flutter/material.dart';

const seedColor = Color(0xFF3F77B6);
const incomeColor = Color(0xFF4CB3C4);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: seedColor);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFEAF1F8),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFEAF1F8),
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFFF3F7FC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFD8E1EB)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFEAEFF6),
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: seedColor, brightness: Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF121A22),
    appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF121A22), elevation: 0),
    cardTheme: CardThemeData(
        elevation: 0, color: const Color(0xFF1D2831),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero),
  );
}
```

`main.dart`：`MaterialApp(theme: buildTheme(), darkTheme: buildDarkTheme(), themeMode: ThemeMode.system, ...)`。

- [ ] **Step 2: 冒烟 + 提交**

```powershell
flutter analyze
flutter run -d windows   # 视觉确认后关闭（人工）
git add timebook/lib/core/theme/app_theme.dart timebook/lib/main.dart
git commit -m "style(theme): AppBar/Card/导航主题化 + 暗色模式基础（跟随系统）"
```

---

### Task 2: 分类环形图共享组件（CategoryDonut）

**Files:**
- Create: `lib/features/bookkeeping/presentation/widgets/category_donut.dart`
- Create: `test/features/bookkeeping/category_donut_test.dart`

- [ ] **Step 1: 写失败测试**

`category_donut_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/bookkeeping/presentation/widgets/category_donut.dart';

void main() {
  testWidgets('环形图渲染中心合计与图例前四项', (tester) async {
    final slices = [
      const DonutSlice(color: Color(0xFF4A7DB0), value: 281200, label: '居住'),
      const DonutSlice(color: Color(0xFF5C6BC0), value: 166110, label: '购物'),
      const DonutSlice(color: Color(0xFF5B9BD5), value: 85740, label: '餐饮'),
      const DonutSlice(color: Color(0xFF4DB6AC), value: 70700, label: '交通'),
      const DonutSlice(color: Color(0xFF8F9AD1), value: 18300, label: '娱乐'),
    ];
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CategoryDonut(slices: slices, centerLabel: '本月支出'))));
    await tester.pumpAndSettle();
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('6,320.50'), findsOneWidget); // 中心合计=总和/100
    expect(find.text('居住'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('娱乐'), findsNothing); // 仅 Top4
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/category_donut_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现**

`category_donut.dart`：

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/util/formats.dart';

class DonutSlice {
  const DonutSlice({required this.color, required this.value, required this.label});
  final Color color;
  final int value; // 分
  final String label;
}

/// 环形图 + 中心合计 + Top4 图例（与原型「分类支出」卡片一致）。
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({super.key, required this.slices, this.centerLabel = '支出'});
  final List<DonutSlice> slices;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (s, e) => s + e.value);
    final top = [...slices]..sort((a, b) => b.value - a.value);
    return Row(children: [
      SizedBox(
        width: 128, height: 128,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: [
            for (final s in top)
              PieChartSectionData(value: s.value.toDouble(), color: s.color,
                  radius: 40, showTitle: false),
          ],
        )),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('¥ ${formatCents(total)} ${centerLabel}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (final s in top.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 9, height: 9,
                    decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(s.label, style: const TextStyle(fontSize: 13))),
                Text('¥ ${formatCents(s.value)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
```

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/bookkeeping/category_donut_test.dart
flutter analyze
```

Expected: PASS；analyze 0。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/bookkeeping/presentation/widgets/category_donut.dart timebook/test/features/bookkeeping/category_donut_test.dart
git commit -m "feat(ui): CategoryDonut 共享环形图组件（中心合计+Top4）"
```

---

### Task 3: 总览页对齐（环形图卡 + 双快捷入口 + 分类彩色行）

**Files:**
- Modify: `lib/features/bookkeeping/presentation/home_screen.dart`
- Modify: `test/features/bookkeeping/home_screen_test.dart`

- [ ] **Step 1: 补失败测试（追加到 home_screen_test）**

```dart
testWidgets('总览含分类支出卡与快捷入口', (tester) async {
  final c = await seeded(); // 复用现有 seeded（有支出 2850 + 收入 850000，分类餐饮）
  await tester.pumpWidget(UncontrolledProviderScope(container: c,
      child: const MaterialApp(home: HomeScreen())));
  await tester.pumpAndSettle();
  expect(find.text('分类支出'), findsOneWidget);
  expect(find.text('流水明细'), findsOneWidget);
  expect(find.textContaining('28.50'), findsWidgets); // 环形图 Top4 金额或流水金额
});
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/home_screen_test.dart
```

Expected: 新增用例 FAIL（无「分类支出」卡片）。

- [ ] **Step 3: 实现**

`home_screen.dart`：
- `_load` 返回值扩展为 `(int balance, (int,int) delta, List<Transaction> recent, List<(int?,int,Color,String)> catSlices)`：追加 `categorySpending(ledgerId, month)`，并读 categories 映射 name；`catSlices` 组装 `DonutSlice(color: 冷色板[i%6], value: amountCents, label: catName ?? '其他')`（冷色板 `[0xFF5B9BD5,0xFF4DB6AC,0xFF5C6BC0,0xFF8F9AD1,0xFF4A7DB0,0xFF7FB3D5]`）。
- `_HomeView` 新增两处：
  - 结余卡下方「双快捷入口」Row：`_QuickCard(icon: receipt_long, title: '流水明细', sub: '${recent.length} 笔记录', onTap: TxList)` 与 `_QuickCard(icon: savings, title: '本月预算', sub: '剩 ¥…', onTap: BudgetScreen)`（半透明浅色块 primaryContainer/secondaryContainer，圆角 16）——实现为内部小 widget（两行内联代码）。
  - 「分类支出」卡片：`Card(child: Padding(16, child: Column(header Title 分类支出, CategoryDonut(slices: catSlices, centerLabel: '本月支出'))))`，放在快捷入口之后、最近流水之前。
- 最近流水行 leading 用分类色块：需要按 Category 映射 icon/色——用传入的 catColor map（按 categoryId）；简化：`Container(width:38,height:38, decoration: BoxDecoration(color: 分类色.withValues(alpha:.18), borderRadius 12), child: Icon(catIcon, color: 分类色))`，`catIcon` 默认 `receipt_long`，收入行 `payments`。

（复用既有 `_monthKey`；`Category` 行类型已在 import。）

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/bookkeeping/home_screen_test.dart
flutter analyze
```

Expected: home 3 用例全绿；analyze 0。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/bookkeeping/presentation/home_screen.dart timebook/test/features/bookkeeping/home_screen_test.dart
git commit -m "feat(ui): 总览页对齐（分类支出环形图卡/双快捷入口/分类彩色行）"
```

---

### Task 4: 专注页对齐（三模式 chips + 🍅 绑定 + 完成确认 + 今日时间线）

**Files:**
- Modify: `lib/features/focus/presentation/focus_timer_widget.dart`
- Modify: `lib/features/focus/presentation/focus_screen.dart`
- Create: `lib/features/focus/presentation/timeline_widget.dart`
- Modify: `test/features/focus/focus_screen_test.dart`（新增 1 用例）+ 既有断言保持

- [ ] **Step 1: 写失败测试（追加到 focus_screen_test）**

```dart
testWidgets('专注页提供模式 chips 与任务绑定按钮', (tester) async {
  final c = await seeded(); // 复用（含任务 整理PRD）
  await tester.pumpWidget(UncontrolledProviderScope(container: c,
      child: const MaterialApp(home: Scaffold(body: FocusScreen()))));
  await tester.pumpAndSettle();
  expect(find.text('短休'), findsOneWidget);
  expect(find.text('长休'), findsOneWidget);
  // 任务行存在 🍅 绑定图标（Key focus_bind_<id> 或文本 '🍅'）
  expect(find.byKey(const Key('bind_1')), findsOneWidget);
});
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/focus/focus_screen_test.dart
```

Expected: 新增用例 FAIL。

- [ ] **Step 3: 实现（改造三处）**

`focus_timer_widget.dart`：
- 新增 `enum TimerMode { focus, short, long }` 与构造参数 `modes: Map<TimerMode,int>`（分钟数，来自 settings）；内部 `FocusTimer(mode: ...)`（扩展 domain `FocusTimer` 增加 mode/short/long 时长参——**需同步改 domain/focus_timer.dart 构造**：`FocusTimer({required int focusMinutes, int shortBreakMinutes = 5, int longBreakMinutes = 15, TimerMode mode = TimerMode.focus})`，`durationSeconds` 按 mode 取对应值；`start` 沿用）；UI 顶部加三枚 `ChoiceChip`（focus/short/long，`Key('mode_focus')/'mode_short'/'mode_long'`），切换时 `reset()` 并按 mode 重建。
- 绑定任务：新增可选参数 `String? boundTask` + `Key('focus_start')` 主按钮不变；圆盘下方小字显示 `boundTask != null ? '专注中：$boundTask' : '请先选择任务'`（与原型一致）。
- 完成回调：新增 `VoidCallback? onComplete`；`_tick` 检测 `remainingSeconds<=0 && phase==focusing` 时 `_timer.reset()` 后调用 `onComplete`（完成确认对话框由屏幕层处理）。
- 圆环色按 mode：focus primary / short 收入青蓝 / long #6C96C9（与原型一致）。

`timeline_widget.dart`（今日时间线）：

```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // 可选；为简单用色条 Row
import '../data/focus_repository.dart';

class TimelineWidget extends StatelessWidget {
  const TimelineWidget({super.key, required this.sessions});
  final List<PomodoroSession> sessions; // 当日（dateTime desc 由调用者传入）

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Padding(padding: const EdgeInsets.all(12),
          child: Text('今天还没有专注记录，开始第一个番茄吧',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }
    return Column(children: [
      for (final s in sessions.take(6))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(
                    color: s.kind == 'focus' ? Theme.of(context).colorScheme.primary
                        : (s.kind == 'short' ? const Color(0xFF4CB3C4) : const Color(0xFF6C96C9)),
                    shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(
                '${s.kind == 'focus' ? '专注' : (s.kind == 'short' ? '短休' : '长休')}'
                '${s.taskId != null ? ' · 任务 #${s.taskId}' : ''}',
                style: const TextStyle(fontSize: 12))),
            Text('${s.durationMinutes} 分钟',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
    ]);
  }
}
```

`focus_screen.dart`：
- 读 settings 得三种时长，传给 `FocusTimerWidget(modes: ..., boundTask: _bound?.title, onComplete: _onComplete)`；`_bound` 状态（Task? null）。
- 待办行尾部加 `TextButton(key: Key('bind_${t.id}'), onPressed: () => setState(() => _bound = t), child: const Text('🍅'))`。
- `_onComplete()`：`showDialog` 确认框（「完成一次专注」，选项 `标记任务完成` / `仍进行中` / `取消`）；选「标记完成」时 `toggleCompleted(taskId)`；无论完成/中断都在完成后 `repo.addSession(taskId: _bound?.id, kind: 'focus', startAt: 本次开始, endAt: now, durationMinutes: 对应时长, interrupted: false)`（计时器需回传本次 startAt — 简化：用 `DateTime.now().subtract(时长)` 作为 startAt）；关闭对话框后 `_bound` 保留（可选）。
- 摘要卡下方加「今日专注时间线」卡片：`FutureBuilder(repo.sessionsToday())` → TimelineWidget；`FocusRepository` 增 `Future<List<PomodoroSession>> sessionsToday()`（当日 kind=='focus'，startAt desc）——**Task 4 一并实现**（`db.select(db.pomodoroSessions)..where(startAt >= 当天 0 点)..orderBy(startAt desc)`）。

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/focus/focus_screen_test.dart test/features/focus/focus_timer_test.dart
flutter analyze
```

Expected: focus 既有（摘要 + 四象限 + new chip/bind）+ timer 4 全绿；analyze 0。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/focus timebook/test/features/focus
git commit -m "feat(focus): 三模式计时/任务绑定/完成确认/今日时间线（对齐原型）"
```

---

### Task 5: 桌面响应式（NavigationRail）

**Files:**
- Modify: `lib/core/router/app_shell.dart`
- Modify: `test/features/bookkeeping/home_screen_test.dart`（若 AppShell 相关无断言则不改）

- [ ] **Step 1: 实现（无纯逻辑，直接改 + analyze）**

`app_shell.dart`：`build` 用 `LayoutBuilder(builder: (context, c) => c.maxWidth >= 840 ? _rail() : _bar())`：

```dart
  Widget _rail() {
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: const Color(0xFFF3F7FC),
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('记账')),
            NavigationRailDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer), label: Text('专注')),
            NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('统计')),
            NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('设置')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: IndexedStack(index: _index, children: _pages)),
      ]),
      floatingActionButton: _index == 0 ? null : null, // 桌面 FAB 由各页自理或隐藏
    );
  }

  Widget _bar() => Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(...原实现...),
      );
```

（`_pages` 抽为最终字段；桌面模式 FAB 由 HomeScreen 自带 Scaffold 的 FAB 保留——HomeScreen 自带 FAB，故 Rail 模式下无需重复。`_bar` 保留原 FAB 结构不动。）

- [ ] **Step 2: 验证**

```powershell
flutter analyze
flutter run -d windows   # 确认宽屏出现左侧 Rail（人工）
```

- [ ] **Step 3: 提交**

```powershell
git add timebook/lib/core/router/app_shell.dart
git commit -m "feat(ui): 桌面响应式 NavigationRail（≥840 宽屏）"
```

---

### Task 6: 统计页复用组件 + 微调

**Files:**
- Modify: `lib/features/bookkeeping/presentation/stats_screen.dart`

- [ ] **Step 1: 重构（复用 CategoryDonut）**

`stats_screen.dart` 的「本月分类占比」卡片：将内部自绘 PieChart 段落替换为 `CategoryDonut(slices: DonutSlice 列表（含 % 显示并入图例金额不变）…，centerLabel: '本月支出')`，去掉重复的排序/绘图代码，保持标题「本月分类占比」与排行列表（真实分类名 + 百分比）不变。`_load` 现返回 `(trend, spends)`；补 categories 映射 name 组装 DonutSlice（同 Task 3 逻辑，抽为共享帮助函数放 `widgets/category_donut.dart` 旁 `buildDonutSlices(spends, catNames)`）。

- [ ] **Step 2: 回归**

```powershell
flutter test test/features/bookkeeping/stats_screen_test.dart
flutter analyze
```

Expected: stats 2 用例全绿（断言 '近 6 个月收支'/'本月分类占比'/'餐饮' 与 % 位仍在）。

- [ ] **Step 3: 提交**

```powershell
git add timebook/lib/features/bookkeeping/presentation/stats_screen.dart
git commit -m "refactor(stats): 复用 CategoryDonut，环形图与总览一致"
```

---

### Task 7: 验收

- [ ] **Step 1: 全量**

```powershell
flutter analyze
flutter test
```

Expected: `No issues found!`；全部 PASS（63 + 新增：category_donut 1 + home 4 + focus 3 + … ≈ **68**）。

- [ ] **Step 2: Windows 构建 + 截图对照**

```powershell
flutter build windows --debug
```

Expected: 构建通过；打开 exe 对照原型逐屏核对（总览环形图/快捷卡、专注 chips/绑定/时间线、宽屏 Rail、暗色模式）。

- [ ] **Step 3: 提交收尾（如有未提交变更）**

```powershell
git add -A; git status
git commit -m "docs: UI 对齐原型验收记录（68 tests green / analyze clean / build ok）"
```

---

## Self-Review 结论

- **范围覆盖（用户四选）**：总览页对齐 → Task 3；专注页对齐 → Task 4；桌面响应式 → Task 5；全局视觉细节+暗色 → Task 1；附加：环形组件共享（Task 2）与统计页复用（Task 6）防止两处重复实现。原型色板（蓝白/收入青蓝/冷分类色）在 Task 1-3 落地。
- **占位扫描**：无 TBD。Task 4 的 `startAt` 用「now − 时长」近似（会话记录准确性在后续记账审计迭代精化），已注明。
- **类型一致性**：`DonutSlice{color,value,label}` Task 2 定义、Task 3/6 使用一致；`TimerMode`/`FocusTimer` 构造扩展 Task 4 定义并被 FocusTimerWidget 使用（domain/focus_timer.dart 同步扩展）；`TimelineWidget({sessions})` Task 4 定义；`FocusRepository.sessionsToday()` Task 4 实现并被 FocusScreen 使用。
- **回归约束**：所有既有断言保持；新增断言只新增。Task 1 无新测试（主题纯视觉），由 T7 全量与人工截图承担。