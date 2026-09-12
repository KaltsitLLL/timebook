# TimeBook M7 打磨与开源 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成收官功能「每日小结」（收工一键生成当日 番茄/专注分钟/支出净额/完成任务 并存档可回看），补齐 README 与 MIT 许可证为开源做准备，全量回归通过。

**Architecture:** schema 升 **v4**：新增 `day_summaries` 表（date 主键 + 快照字段）。新域 `features/daily/`：`data`（表 + DailySummaryService：生成=当日聚合、按 date 幂等 upsert、查询单日/最近 7 条）、`presentation`（DailySummaryScreen + 入口按钮，入口挂专注页摘要卡）。README 放到 `timebook/README.md`（替换 flutter create 默认），LICENSE（MIT）同时放仓库根与 timebook/。

**Tech Stack:** Flutter/Dart · drift 2.31（标准 API）· intl（金额）

**依据：** `docs/superpowers/specs/2026-09-12-timebook-design.md`（§4 总结域 day_summaries、§9 M7 里程碑）与已交付 M1-M6 代码。**调整（父代理决策）**：面试演示脚本从 M7 移除（面试临近时一次性编写，避免随功能迭代过时）；GitHub push 需用户授权后执行。

---

## 文件结构

```
timebook/
├── LICENSE                                   # Create（根与 timebook/ 各一份 MIT）
├── README.md                                 # Create：替换默认 README（中文，功能/架构/技术栈）
├── lib/core/db/app_database.dart             # Modify: schemaVersion 4（+day_summaries）
├── lib/features/daily/
│   ├── data/day_summaries_table.dart         # Create: DaySummaries
│   ├── data/daily_summary_service.dart       # Create: 当日聚合 + 幂等 upsert + 查询
│   └── presentation/
│       ├── daily_summary_screen.dart         # Create: 今日卡 + 历史列表
│       └── daily_providers.dart              # Create: dailyDatabaseProvider/dailyRepository? 简化：直接用 AppDatabase
├── lib/features/focus/presentation/focus_screen.dart  # Modify: 摘要卡加「收工小结」按钮
└── test/features/daily/
    ├── daily_summary_service_test.dart       # Create（2 用例）
    └── daily_summary_screen_test.dart        # Create（1 用例）
```

总计预期：既有 60 + 2 + 1 = **63 个测试**。

命令约定（全项目一致）：Windows/PowerShell；Flutter 全路径 `D:\dev\flutter\bin\flutter.bat`；flutter/dart 命令前内联 `$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"; $env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"`；flutter 命令 cwd=`...\clock\timebook`；git 命令 cwd=`...\clock`（提交 `git add timebook/lib timebook/test timebook/README.md timebook/LICENSE LICENSE` 按实际）。

---

### Task 1: v4 迁移 + 每日小结服务

**Files:**
- Create: `timebook/lib/features/daily/data/day_summaries_table.dart`
- Modify: `timebook/lib/core/db/app_database.dart`
- Create: `timebook/lib/features/daily/data/daily_summary_service.dart`
- Create: `timebook/test/features/daily/daily_summary_service_test.dart`

- [ ] **Step 1: 写失败测试**

`daily_summary_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/daily/data/daily_summary_service.dart';
import 'package:timebook/features/focus/data/focus_repository.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;
  late DailySummaryService svc;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase.forTesting(inMemoryExecutor());
    svc = DailySummaryService(db);
  });

  tearDown(() async => db.close());

  test('生成并幂等保存当日小结（聚合专注/支出/任务）', () async {
    // 账本+账户+一笔当日支出
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '生活'));
    await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
    final now = DateTime.now();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: 1, accountId: 1, direction: 'expense', amountCents: 2850,
        bookAt: now, counterparty: const Value('美团')));
    // 任务：一个已完成
    final focus = FocusRepository(db);
    await focus.createTask(title: '写完接口', priority: 1);
    await focus.toggleCompleted(taskId: 1);
    // 一条当日专注记录
    await focus.addSession(
        kind: 'focus', startAt: now.subtract(const Duration(minutes: 25)),
        durationMinutes: 25);

    final s1 = await svc.generateFor(date: now);
    expect(s1.focusMinutes, 25);
    expect(s1.expenseTotalCents, 2850);
    expect(s1.tasksDone, 1);

    // 幂等：再生成不新增行，值更新
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: 1, accountId: 1, direction: 'expense', amountCents: 100,
        bookAt: now));
    final s2 = await svc.generateFor(date: now);
    expect(s2.expenseTotalCents, 2950);
    expect(await db.daySummaries.count().getSingle(), 1);
  });

  test('最近 7 条历史', () async {
    await db.into(db.daySummaries).insert(DaySummariesCompanion.insert(
        date: '2026-09-10', pomodoroCount: const Value(2),
        focusMinutes: const Value(50), expenseTotalCents: const Value(1000),
        tasksDone: const Value(1)));
    await db.into(db.daySummaries).insert(DaySummariesCompanion.insert(
        date: '2026-09-11', pomodoroCount: const Value(1),
        focusMinutes: const Value(25), expenseTotalCents: const Value(500),
        tasksDone: const Value(0)));
    final list = await svc.recent(limit: 7);
    expect(list, hasLength(2));
    expect(list.first.date, '2026-09-11'); // 倒序
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/daily/daily_summary_service_test.dart
```

Expected: FAIL（表/服务不存在）。

- [ ] **Step 3: 建表 + v4 + 服务**

`day_summaries_table.dart`：

```dart
import 'package:drift/drift.dart';

class DaySummaries extends Table {
  TextColumn get date => text()(); // 'yyyy-MM-dd'
  IntColumn get pomodoroCount => integer().withDefault(const Constant(0))();
  IntColumn get focusMinutes => integer().withDefault(const Constant(0))();
  IntColumn get expenseTotalCents => integer().withDefault(const Constant(0))();
  IntColumn get tasksDone => integer().withDefault(const Constant(0))();
  IntColumn get rating => integer().nullable()(); // 1-5
  TextColumn get snapshotJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {date};
}
```

`app_database.dart`：`schemaVersion => 4`；@DriftDatabase 增 DaySummaries；onUpgrade `from < 4` 时 `await m.createTable(daySummaries)`（沿用已证实的表 getter 写法）。

`daily_summary_service.dart`：

```dart
import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import '../data/day_summaries_table.dart';

class DailySummaryService {
  DailySummaryService(this.db);
  final AppDatabase db;

  /// 生成并幂等保存某日小结（当日 番茄数/专注分钟/支出净额/完成任务数）。
  Future<DaySummary> generateFor({required DateTime date}) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final key = _key(dayStart);

    // 专注
    final sessions = await (db.select(db.pomodoroSessions)
          ..where((s) =>
              s.kind.equals('focus') &
              s.startAt.isBiggerOrEqualValue(dayStart) &
              s.startAt.isSmallerThanValue(dayEnd) &
              s.interrupted.equals(false)))
        .get();
    final focusMinutes = sessions.fold<int>(0, (a, s) => a + s.durationMinutes);
    final pomodoroCount = sessions.length;

    // 支出净额（当日）
    final txs = await (db.select(db.transactions)
          ..where((t) =>
              t.direction.equals('expense') &
              t.bookAt.isBiggerOrEqualValue(dayStart) &
              t.bookAt.isSmallerThanValue(dayEnd)))
        .get();
    final expenseTotal =
        txs.fold<int>(0, (a, t) => a + (t.amountCents - t.refundedCents));

    // 当日完成任务（completedAt 落在当日）
    final done = await (db.select(db.tasks)
          ..where((t) =>
              t.completedAt.isNotNull() &
              t.completedAt.isBiggerOrEqualValue(dayStart) &
              t.completedAt.isSmallerThanValue(dayEnd)))
        .get();

    final summary = DaySummary(
        date: key, pomodoroCount: pomodoroCount, focusMinutes: focusMinutes,
        expenseTotalCents: expenseTotal, tasksDone: done.length);
    await _upsert(summary);
    return summary;
  }

  Future<void> _upsert(DaySummary s) async {
    final existing = await (db.select(db.daySummaries)..where((t) => t.date.equals(s.date))).get();
    if (existing.isEmpty) {
      await db.into(db.daySummaries).insert(DaySummariesCompanion.insert(
          date: s.date, pomodoroCount: Value(s.pomodoroCount),
          focusMinutes: Value(s.focusMinutes),
          expenseTotalCents: Value(s.expenseTotalCents),
          tasksDone: Value(s.tasksDone)));
    } else {
      await (db.update(db.daySummaries)..where((t) => t.date.equals(s.date)))
          .write(DaySummariesCompanion(
              pomodoroCount: Value(s.pomodoroCount),
              focusMinutes: Value(s.focusMinutes),
              expenseTotalCents: Value(s.expenseTotalCents),
              tasksDone: Value(s.tasksDone)));
    }
  }

  Future<List<DaySummary>> recent({int limit = 7}) {
    return (db.select(db.daySummaries)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .get();
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
```

（drift 行类名 `DaySummary`（表 DaySummaries）——若生成名不同以实际为准统一。）

- [ ] **Step 4: 生成代码并跑测试**

```powershell
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/daily/daily_summary_service_test.dart
flutter test   # 全量回归
```

Expected: 2 用例 + 全量（62）绿。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib timebook/test
git commit -m "feat(daily): schema v4 + 每日小结生成服务（幂等/历史）"
```

---

### Task 2: 每日小结 UI + 专注页入口

**Files:**
- Create: `timebook/lib/features/daily/presentation/daily_summary_screen.dart`
- Create: `timebook/lib/features/daily/presentation/daily_providers.dart`
- Modify: `timebook/lib/features/focus/presentation/focus_screen.dart`
- Create: `timebook/test/features/daily/daily_summary_screen_test.dart`

- [ ] **Step 1: 写失败测试**

`daily_summary_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/daily/data/daily_summary_service.dart';
import 'package:timebook/features/daily/presentation/daily_summary_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  testWidgets('今日小结卡展示聚合数据', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final svc = DailySummaryService(db);
    addTearDown(db.close);

    await tester.pumpWidget(MaterialApp(
        home: DailySummaryScreen(service: svc, date: DateTime.now())));
    await tester.pumpAndSettle();

    expect(find.text('今日小结'), findsOneWidget);
    // 空数据不显示金额行数也可通过（聚合为 0）
    await tester.tap(find.byKey(const Key('daily_save')));
    await tester.pumpAndSettle();
    final all = await db.daySummaries.get();
    expect(all, hasLength(1));
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/daily/daily_summary_screen_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现**

`daily_providers.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../data/daily_summary_service.dart';

final dailyDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final dailySummaryServiceProvider = Provider<DailySummaryService>(
    (ref) => DailySummaryService(ref.read(dailyDatabaseProvider)));
```

`daily_summary_screen.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/util/formats.dart';
import '../data/daily_summary_service.dart';

class DailySummaryScreen extends ConsumerWidget {
  const DailySummaryScreen({super.key, this.service, this.date});
  final DailySummaryService? service;
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = service ?? ref.watch(dailySummaryServiceProvider);
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
```

`focus_screen.dart`：摘要卡（`今日专注` 卡片）尾部加 `TextButton.icon(key: Key('daily_entry'), icon: Icon(Icons.summarize_outlined, size: 16), label: Text('收工小结'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailySummaryScreen())))`，import daily 页面。

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/daily/daily_summary_screen_test.dart
flutter analyze
```

Expected: 用例全绿（空聚合也生成一行）；analyze 0 问题。**注意**：`daySummaries.get()` 在 drift 中应为 `db.select(db.daySummaries).get()`——测试内按此修正。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib timebook/test
git commit -m "feat(daily): 每日小结页（今日卡/历史/保存）+ 专注页入口"
```

---

### Task 3: README + LICENSE（开源准备）

**Files:**
- Create: `timebook/README.md`（替换默认）
- Create: `timebook/LICENSE`、`LICENSE`（仓库根）——MIT 文本

- [ ] **Step 1: 写 README（直接创建，非 TDD）**

`timebook/README.md` 内容（中文）：

```markdown
# 时账 TimeBook

本地优先、全平台（Android/iOS/Windows/macOS）的个人记账 + 待办 + 番茄钟应用。数据 100% 存于本地 SQLite，支持账单导入（微信/支付宝 CSV）、退款冲抵、AI 对话记账（智谱 GLM-4-Flash，可选）。

## 功能
- **记账**：多账本/多账户/二级分类/流水；金额以「分」存储，统计按净额（退款冲抵）
- **预算**：总预算 + 分类预算、月度进度、超支/预警高亮、剩余日均
- **统计**：近 6 个月收支柱状图、本月分类占比与排行
- **待办 + 番茄钟**：任务/项目、短语法快速创建（`整理周报 +work 45m #汇总 @明天`）、四象限视图、绝对时间戳计时器（切后台自动补偿）、任务联动
- **账单导入**：YAML 声明式模板、错误行显式化、重复去重、周期记账、退款冲抵
- **AI 记账**（可选）：设置 GLM API Key 后一句话记账，确认页人工复核后入账

## 技术栈
Flutter · Riverpod · Drift(SQLite) · fl_chart · intl · http · flutter_secure_storage

## 架构
```
lib/
├── core/          # 主题(M3 蓝白)、数据库(迁移 v1..v4)、工具(金额/日期)
└── features/      # bookkeeping / focus / import / ai / daily / stats
```
每个 feature：data（Drift DAO）→ domain（服务/纯函数）→ presentation（Riverpod + UI）。

## 开发
```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test    # 63 个测试
flutter run -d windows
```

## 开源协议
MIT License（见 LICENSE）。基于本人考研复试个人项目，从零编写。
```

- [ ] **Step 2: 写 LICENSE（MIT，作者名占位 `[Your Name] - 2026`）**

License 使用标准 MIT 文本；作者行留 `Copyright (c) 2026 <Your Name>`（README 同）。**用户可自行替换署名**。

- [ ] **Step 3: 提交**

```powershell
git add timebook/README.md timebook/LICENSE LICENSE
git commit -m "docs: README 与 MIT 许可证（开源准备）"
```

---

### Task 4: GitHub 发布（需用户授权）

**Files:** 无（仓库操作）

- [ ] **Step 1: 检查 gh 工具与授权**

```powershell
gh auth status 2>&1
```

Expected: 已登录则继续；未登录/未授权 → **停下并向用户请求 GitHub 授权**（`RequestAuthorization` 或指导手动登录），本步骤不自动创建仓库。

- [ ] **Step 2: 创建远端仓库并推送（授权后将命令交给执行者）**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock
gh repo create timebook --public --source . --push --description "时账 TimeBook：本地优先记账+待办+番茄钟（Flutter）"
```

Expected: 仓库创建成功并推送全部 commit（44+ commits）。
> 若用户不希望用 `gh`，可改手动：在 GitHub 新建空仓库后 `git remote add origin <url> && git push -u origin master`。

- [ ] **Step 3: 记录仓库地址到 README（可选）与提交说明**

---

### Task 5: M7 验收

- [ ] **Step 1: 全量检查**

```powershell
flutter analyze
flutter test
```

Expected: `No issues found!`；全部 PASS（**63**）。

- [ ] **Step 2: Windows 构建**

```powershell
flutter build windows --debug
```

Expected: `√ Built ...\timebook.exe`。

- [ ] **Step 3: 项目收尾记录（提交说明）**

- 面试演示脚本：**移除**，面试临近时一次性编写（随最新功能）
- 已知后续：ML Kit 原生 OCR（M6 补丁）、语音记账、云同步、多币种、发薪日预算周期（见 spec §11 未来扩展池）
- GitHub 推送状态以 Task 4 授权结果为准

- [ ] **Step 4: 提交收尾（如有未提交变更）**

```powershell
git add -A; git status
git commit -m "docs: M7 验收记录（63 tests green / analyze clean / windows build ok）"
```

---

## Self-Review 结论

- **Spec 覆盖（M7）**：§4 day_summaries 表 → Task 1；M7 里程碑（每日小结/回归/README/开源）→ Task 1-4；演示脚本调整 → 计划头声明移除依据。GitHub 发布 → Task 4 授权门控。
- **占位扫描**：无 TBD/TODO；Task 3 README/License 直接产出（非代码任务）。`[Your Name]` 为署名占位，用户可改（非功能占位）。
- **类型一致性**：`DailySummaryService.generateFor({date})/recent({limit})` Task 1 定义、Task 2 使用一致；`DaySummary` 行类型名以 drift 生成为准（Task 1 Step 3 注明）；`DailySummaryScreen({service?,date?})` Task 2 定义并被 FocusScreen 引用；`dailySummaryServiceProvider` Task 2 定义。
- 测试计数：Task 5 预期 63（60 + 2 + 1）。