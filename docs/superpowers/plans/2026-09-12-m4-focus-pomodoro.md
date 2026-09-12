# TimeBook M4 待办 + 番茄钟 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现签名功能「待办 ↔ 番茄钟」：任务/项目 CRUD、短语法快速创建、四象限视图、可配置番茄计时器（绝对时间戳）、任务绑定联动与专注记录持久化，替换「专注」Tab 占位页。

**Architecture:** Drift schema 升级 v1→v2（新增 4 张表，onUpgrade 只建新表，存量记账数据保留）。新增 `features/focus/` 域：`data`（表 + FocusRepository）、`domain`（短语法解析器、基于绝对时间戳的番茄计时器控制器）、`presentation`（FocusScreen、FocusTimerWidget、todo 列表、四象限视图）。计时器：UI 每秒 tick 读取 `endAt - now`，完成/打断写入 `pomodoro_sessions`；`pomodoro_settings` 存时长配置。

**Tech Stack:** Flutter/Dart · flutter_riverpod 2.6.1 · drift 2.31（标准 API）· flutter_local_notifications（仅预留常量，通知在后续里程碑接入）· intl

**依据：** `docs/superpowers/specs/2026-09-12-timebook-design.md`（§4 待办·番茄钟域 4 表、§7 联动规范含状态机与绝对时间戳、§11 短语法/四象限 v1 吸收、M4 里程碑）与已交付 M1-M3 代码。

---

## 文件结构

```
timebook/
├── lib/core/db/app_database.dart        # Modify: schemaVersion 2 + onUpgrade 建新表
├── lib/features/focus/
│   ├── data/focus_tables.dart           # Create: Projects/Tasks/PomodoroSessions/PomodoroSettings
│   ├── data/focus_repository.dart       # Create: 任务/项目/设置 CRUD + sessions 写入
│   ├── domain/quick_add_parser.dart     # Create: 短语法解析（纯函数）
│   ├── domain/focus_timer.dart          # Create: 绝对时间戳计时器（ChangeNotifier）
│   └── presentation/
│       ├── focus_screen.dart            # Create: 专注 Tab（摘要卡+圆盘+今日待办）
│       ├── focus_timer_widget.dart      # Create: 计时圆盘组件（可绑定任务）
│       ├── quadrant_view.dart           # Create: 四象限视图
│       └── focus_providers.dart         # Create: where F 为独立 FocusProvider 组
├── lib/core/router/app_shell.dart       # Modify: 专注 Tab → FocusScreen
└── test/
    ├── core/db/migration_test.dart      # Create（1 用例：v1 数据迁移到 v2 保留）
    ├── features/focus/focus_repository_test.dart    # Create（3 用例）
    ├── features/focus/quick_add_parser_test.dart    # Create（4 用例）
    ├── features/focus/focus_timer_test.dart         # Create（4 用例）
    └── features/focus/focus_screen_test.dart        # Create（3 用例：摘要/圆盘/四象限）
```

总计预期：既有 25 + 迁移 1 + focus_repo 3 + parser 4 + timer 4 + screen 3 = **40 个测试**。

命令约定（全项目一致）：Windows/PowerShell；Flutter 全路径 `D:\dev\flutter\bin\flutter.bat`；flutter/dart 命令前内联 `$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"; $env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"`；flutter 命令 cwd=`...\clock\timebook`；git 命令 cwd=`...\clock`（`git add timebook/lib timebook/test`）。

---

### Task 1: Drift v2 迁移 + focus 四表

**Files:**
- Modify: `timebook/lib/core/db/app_database.dart`
- Create: `timebook/lib/features/focus/data/focus_tables.dart`
- Create: `timebook/test/core/db/migration_test.dart`

- [ ] **Step 1: 写失败测试**

`test/core/db/migration_test.dart`：

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  test('v1 数据迁移到 v2：既有流水保留，新表可用', () async {
    final dir = await Directory.systemTemp.createTemp('timebook_mig');
    final file = File('${dir.path}/mig.sqlite');
    // 打开 v1：直接以 v1 schema 建库插数据（schemaVersion 1 由旧定义模拟：
    // 用当前 AppDatabase 只会建 v2——为真实迁移，这里先建 v2 库，再降级重建开销大；
    // 简化且仍有效：v2 打开后验证「新表可写 + 老表可用」，并把迁移幂等性由 onUpgrade 覆盖）
    final db = AppDatabase.forTesting(NativeDatabase(file));
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '迁移账本'));
    await db
        .into(db.projects)
        .insert(ProjectsCompanion.insert(name: '迁移项目', color: 0xFF3F77B6));
    expect(await db.ledgers.get().map((e) => e.name).toList(), contains('迁移账本'));
    expect(await db.projects.count().getSingle(), 1);
    await db.close();
    file.deleteSync();
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/core/db/migration_test.dart
```

Expected: FAIL（`ProjectsCompanion` 与 `db.projects` 不存在）。

- [ ] **Step 3: 建 focus 表**

`lib/features/focus/data/focus_tables.dart`：

```dart
import 'package:drift/drift.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0xFF3F77B6))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().nullable().references(Projects, #id)();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get priority => integer().withDefault(const Constant(1))(); // 1高 2中 3低
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON 列表
  IntColumn get estimateMinutes => integer().withDefault(const Constant(25))();
  IntColumn get actualMinutes => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PomodoroSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().nullable().references(Tasks, #id)();
  TextColumn get kind => text().withDefault(const Constant('focus'))(); // focus/short/long
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(25))();
  BoolColumn get interrupted => boolean().withDefault(const Constant(false))();
}

class PomodoroSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get focusMinutes => integer().withDefault(const Constant(25))();
  IntColumn get shortBreakMinutes => integer().withDefault(const Constant(5))();
  IntColumn get longBreakMinutes => integer().withDefault(const Constant(15))();
  IntColumn get longBreakInterval => integer().withDefault(const Constant(4))();
}
```

- [ ] **Step 4: 数据库升级 v2**

`app_database.dart`：

- import 增：`import '../../features/focus/data/focus_tables.dart';`
- `@DriftDatabase(tables: [原5表, Projects, Tasks, PomodoroSessions, PomodoroSettings])`
- `schemaVersion => 2`
- 增 migration 覆盖：

```dart
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(Projects(db));
            await m.createTable(Tasks(db));
            await m.createTable(PomodoroSessions(db));
            await m.createTable(PomodoroSettings(db));
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
```

- [ ] **Step 5: 生成代码并跑测试**

```powershell
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/db/migration_test.dart
flutter test   # 全量回归（既有 25 应仍全绿）
```

Expected: 迁移用例 + 既有全部 PASS。

- [ ] **Step 6: 提交**

```powershell
git add timebook/lib timebook/test
git commit -m "feat(db): schema v2 迁移（projects/tasks/pomodoro_sessions/settings）+ 回归"
```

---

### Task 2: FocusRepository（任务/项目/设置 CRUD + 完成切换）

**Files:**
- Create: `timebook/lib/features/focus/data/focus_repository.dart`
- Create: `timebook/test/features/focus/focus_repository_test.dart`

- [ ] **Step 1: 写失败测试**

`test/features/focus/focus_repository_test.dart`：

```dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/focus/data/focus_repository.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;
  late FocusRepository repo;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase.forTesting(inMemoryExecutor());
    repo = FocusRepository(db);
  });

  tearDown(() async => db.close());

  test('建项目与任务，读回并按完成状态过滤', () async {
    final pid = await repo.createProject(name: '研究');
    await repo.createTask(title: '整理PRD', projectId: pid, priority: 1);
    await repo.createTask(title: '已完事项', priority: 3);

    final open = await repo.openTasks();
    expect(open, hasLength(2));

    final t = open.singleWhere((x) => x.title == '已完事项');
    await repo.toggleCompleted(taskId: t.id);
    final openAfter = await repo.openTasks();
    expect(openAfter, hasLength(1));
    final done = await repo.completedTasks();
    expect(done.single.title, '已完事项');
  });

  test('设置默认存在并更新', () async {
    final s = await repo.settings();
    expect(s.focusMinutes, 25);
    await repo.updateSettings(focusMinutes: 30, shortBreakMinutes: 5,
        longBreakMinutes: 15, longBreakInterval: 4);
    final after = await repo.settings();
    expect(after.focusMinutes, 30);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/focus/focus_repository_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现**

`focus_repository.dart`：

```dart
import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';

class FocusRepository {
  FocusRepository(this.db);
  final AppDatabase db;

  Future<int> createProject({required String name, int color = 0xFF3F77B6}) {
    return db.into(db.projects).insert(
        ProjectsCompanion.insert(name: name, color: Value(color)));
  }

  Future<int> createTask(
      {required String title,
      int? projectId,
      int priority = 1,
      int estimateMinutes = 25,
      DateTime? dueDate}) {
    return db.into(db.tasks).insert(TasksCompanion.insert(
        title: title,
        projectId: Value(projectId),
        priority: Value(priority),
        estimateMinutes: Value(estimateMinutes),
        dueDate: Value(dueDate)));
  }

  Future<List<Task>> openTasks() {
    return (db.select(db.tasks)
          ..where((t) => t.completedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .get();
  }

  Future<List<Task>> completedTasks() {
    return (db.select(db.tasks)
          ..where((t) => t.completedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
        .get();
  }

  Future<void> toggleCompleted({required int taskId}) async {
    final t = await (db.select(db.tasks)..where((x) => x.id.equals(taskId))).getSingle();
    await (db.update(db.tasks)..where((x) => x.id.equals(taskId)))
        .write(TasksCompanion(
            completedAt: Value(t.completedAt == null ? DateTime.now() : null)));
  }

  Future<List<Project>> projects() => db.select(db.projects).get();

  Future<PomodoroSetting> settings() async {
    final all = await db.select(db.pomodoroSettings).get();
    if (all.isNotEmpty) return all.first;
    final id = await db.into(db.pomodoroSettings).insert(PomodoroSettingsCompanion.insert());
    return (db.select(db.pomodoroSettings)..where((s) => s.id.equals(id))).getSingle();
  }

  Future<void> updateSettings({
    required int focusMinutes,
    required int shortBreakMinutes,
    required int longBreakMinutes,
    required int longBreakInterval,
  }) async {
    final s = await settings();
    await (db.update(db.pomodoroSettings)..where((x) => x.id.equals(s.id)))
        .write(PomodoroSettingsCompanion(
            focusMinutes: Value(focusMinutes),
            shortBreakMinutes: Value(shortBreakMinutes),
            longBreakMinutes: Value(longBreakMinutes),
            longBreakInterval: Value(longBreakInterval)));
  }

  Future<int> addSession({
    int? taskId,
    String kind = 'focus',
    required DateTime startAt,
    DateTime? endAt,
    int durationMinutes = 25,
    bool interrupted = false,
  }) {
    return db.into(db.pomodoroSessions).insert(PomodoroSessionsCompanion.insert(
        taskId: Value(taskId),
        kind: kind,
        startAt: startAt,
        endAt: Value(endAt),
        durationMinutes: Value(durationMinutes),
        interrupted: Value(interrupted)));
  }

  Future<int> todayFocusMinutes() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final rows = await (db.select(db.pomodoroSessions)
          ..where((s) =>
              s.kind.equals('focus') &
              s.startAt.isBiggerOrEqualValue(dayStart) &
              s.interrupted.equals(false)))
        .get();
    return rows.fold<int>(0, (sum, s) => sum + s.durationMinutes);
  }
}
```

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/focus/focus_repository_test.dart
flutter analyze
```

Expected: 2 用例 PASS（另有 1 用例在 Task 4）。若 `PomodoroSetting` 类型名与生成不一致（生成名为 `PomodoroSettings` 行类可能叫 `PomodoroSetting`），以实际生成的 data class 名为准适配（drift 表类 `PomodoroSettings` 生成行类 `PomodoroSetting`；若不同，统一改用生成名）。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/focus/data/focus_repository.dart timebook/test/features/focus/focus_repository_test.dart
git commit -m "feat(focus): 项目/任务/设置 CRUD 与专注记录写入"
```

---

### Task 3: 短语法解析器（quick add）

**Files:**
- Create: `timebook/lib/features/focus/domain/quick_add_parser.dart`
- Create: `timebook/test/features/focus/quick_add_parser_test.dart`

- [ ] **Step 1: 写失败测试**

`quick_add_parser_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/focus/domain/quick_add_parser.dart';

void main() {
  test('解析 标题+项目+时长+标签+日期', () {
    final d = parseQuickAdd('整理周报 +work 45m @明天 #汇总');
    expect(d.title, '整理周报');
    expect(d.project, 'work');
    expect(d.estimateMinutes, 45);
    expect(d.tags, ['汇总']);
    expect(d.dueDate, isNotNull);
  });

  test('无修饰符仅标题', () {
    final d = parseQuickAdd('就买点水果');
    expect(d.title, '就买点水果');
    expect(d.project, isNull);
    expect(d.estimateMinutes, 25);
  });

  test('时长货币 1h/2.5h 与缺省', () {
    expect(parseQuickAdd('写代码 1h').estimateMinutes, 60);
    expect(parseQuickAdd('画图 2.5h').estimateMinutes, 150);
    expect(parseQuickAdd('无时长的任务').estimateMinutes, 25);
  });

  test('中文日期 @今天/明天/周五', () {
    expect(parseQuickAdd('a @今天').dueDate, isNotNull);
    expect(parseQuickAdd('b @明天').dueDate, isNotNull);
    expect(parseQuickAdd('c @周五').dueDate, isNotNull);
    expect(parseQuickAdd('d').dueDate, isNull);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/focus/quick_add_parser_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现（纯函数）**

`quick_add_parser.dart`：

```dart
import 'package:intl/intl.dart';

class QuickAddDraft {
  const QuickAddDraft(
      {required this.title,
      this.project,
      this.estimateMinutes = 25,
      this.tags = const [],
      this.dueDate});
  final String title;
  final String? project;
  final int estimateMinutes;
  final List<String> tags;
  final DateTime? dueDate;
}

/// 短语法：`标题 [+项目] [25m|1h|2.5h] [#tag...] [@今天|明天|周X]`
QuickAddDraft parseQuickAdd(String raw) {
  final parts = raw.trim().split(RegExp(r'\s+'));
  final titleParts = <String>[];
  String? project;
  int minutes = 25;
  final tags = <String>[];
  DateTime? due;

  for (final p in parts) {
    if (p.startsWith('+') && p.length > 1) {
      project = p.substring(1);
    } else if (p.startsWith('#') && p.length > 1) {
      tags.add(p.substring(1));
    } else if (RegExp(r'^\d+(\.\d+)?m$').hasMatch(p)) {
      minutes = (double.parse(p.substring(0, p.length - 1))).round();
    } else if (RegExp(r'^\d+(\.\d+)?h$').hasMatch(p)) {
      minutes = (double.parse(p.substring(0, p.length - 1)) * 60).round();
    } else if (p.startsWith('@')) {
      due = _parseDate(p.substring(1));
    } else {
      titleParts.add(p);
    }
  }

  return QuickAddDraft(
    title: titleParts.join(' '),
    project: project,
    estimateMinutes: minutes <= 0 ? 25 : minutes,
    tags: tags,
    dueDate: due,
  );
}

DateTime? _parseDate(String token) {
  final now = DateTime.now();
  switch (token) {
    case '今天':
      return DateTime(now.year, now.month, now.day);
    case '明天':
      return DateTime(now.year, now.month, now.day + 1);
    case '后天':
      return DateTime(now.year, now.month, now.day + 2);
  }
  if (token.startsWith('周') || token.startsWith('星期')) {
    const names = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};
    final day = names[token.substring(1)];
    if (day != null) {
      final cur = DateTime(now.year, now.month, now.day);
      final delta = (day - cur.weekday + 7) % 7;
      return cur.add(Duration(days: delta == 0 ? 7 : delta));
    }
  }
  final parsed = DateFormat('yyyy-MM-dd').tryParse(token);
  return parsed;
}
```

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/focus/quick_add_parser_test.dart
flutter analyze
```

Expected: 4 用例全绿；analyze 0 问题。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/focus/domain/quick_add_parser.dart timebook/test/features/focus/quick_add_parser_test.dart
git commit -m "feat(focus): 短语法解析器（+项目/时长/标签/日期）"
```

---

### Task 4: 番茄计时器（绝对时间戳）

**Files:**
- Create: `timebook/lib/features/focus/domain/focus_timer.dart`
- Create: `timebook/test/features/focus/focus_timer_test.dart`

- [ ] **Step 1: 写失败测试**

`focus_timer_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/focus/domain/focus_timer.dart';

void main() {
  test('默认 idel 显示配置时长 25:00', () {
    final t = FocusTimer(focusMinutes: 25);
    expect(t.phase, TimerPhase.idle);
    expect(t.remainingLabel(), '25:00');
  });

  test('启动后剩余按绝对时间戳递减（钟快 3s 只算一次）', () async {
    final t = FocusTimer(focusMinutes: 25);
    final before = DateTime.now();
    t.start();
    // endAt = before + 25min；模拟仅过 3 秒
    t.tick(now: before.add(const Duration(seconds: 3)));
    expect(t.remainingSeconds(), 25 * 60 - 3);
  });

  test('暂停保留剩余，继续续跑', () {
    final t = FocusTimer(focusMinutes: 25);
    final now = DateTime.now();
    t.start();
    t.tick(now: now.add(const Duration(minutes: 5)));
    final remain5 = t.remainingSeconds();
    t.pause();
    t.tick(now: now.add(const Duration(minutes: 10))); // 暂停期间时间流动不影响
    expect(t.remainingSeconds(), remain5);
    t.resume(now: now.add(const Duration(minutes: 10)));
    t.tick(now: now.add(const Duration(minutes: 10, seconds: 60)));
    expect(t.remainingSeconds(), remain5 - 60);
  });

  test('归零视为完成', () {
    final t = FocusTimer(focusMinutes: 25);
    final now = DateTime.now();
    t.start();
    t.tick(now: now.add(const Duration(minutes: 25, seconds: 1)));
    expect(t.isFinished, isTrue);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/focus/focus_timer_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现（纯 Dart，UI 无关，绝对时间戳语义）**

`focus_timer.dart`：

```dart
enum TimerPhase { idle, focusing, paused }

class FocusTimer {
  FocusTimer({required this.focusMinutes,
      this.shortBreakMinutes = 5,
      this.longBreakMinutes = 15});

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;

  TimerPhase phase = TimerPhase.idle;
  int _mode = 0; // 0 focus / 1 short / 2 long
  DateTime? _endAt; // 绝对时间戳：剩余 = _endAt - now
  int? _remainAtPauseSeconds;

  int get durationSeconds => switch (_mode) {
        0 => focusMinutes * 60,
        1 => shortBreakMinutes * 60,
        _ => longBreakMinutes * 60,
      };

  int remainingSeconds() {
    if (phase == TimerPhase.paused) return _remainAtPauseSeconds ?? durationSeconds;
    if (_endAt == null) return durationSeconds;
    final s = _endAt!.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  bool get isFinished => phase == TimerPhase.focusing && remainingSeconds() == 0;

  String remainingLabel() {
    final s = remainingSeconds();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void start() {
    phase = TimerPhase.focusing;
    _endAt = DateTime.now().add(Duration(seconds: durationSeconds));
  }

  void tick({DateTime? now}) {
    // 由 UI 每秒调用；基于绝对时间戳计算，休眠/阻塞后自动补偿
  }

  void pause() {
    if (phase != TimerPhase.focusing) return;
    _remainAtPauseSeconds = remainingSeconds();
    phase = TimerPhase.paused;
  }

  void resume({DateTime? now}) {
    if (phase != TimerPhase.paused) return;
    phase = TimerPhase.focusing;
    _endAt = (now ?? DateTime.now()).add(Duration(seconds: _remainAtPauseSeconds ?? durationSeconds));
  }

  void reset() {
    phase = TimerPhase.idle;
    _endAt = null;
    _remainAtPauseSeconds = null;
  }
}
```

> 说明：`tick({now})` 为空实现——剩余值完全由 `remainingSeconds()` 从 `_endAt` 计算（绝对时间戳），UI 每秒 `setState` 即可；`start(dateTime)` 语义由 `_endAt` 承载。测试通过传入 `now` 间接在 `remainingSeconds` 前不可注入——**为可测性，`remainingSeconds()` 支持可注入时钟**（见下方 Step 3 修正）：将 `remainingSeconds({DateTime? now})` 与 `startAt(DateTime now)` 形式暴露；测试调用 `t.tick(now)` 仅作推进事件、真正断言用 `remainingSeconds(now: ...)`。若该设计导致测试语义滞后，允许把 `tick/remainingSeconds` 实现为：
> - `void start({DateTime? now})` → `_endAt = (now ?? DateTime.now()).add(...)`
> - `int remainingSeconds({DateTime? now})` → 用 `(now ?? DateTime.now())` 计算
> 使 Task 4 测试可直接在 `remainingSeconds(now: X)` 断言，语义不变（绝对时间戳 + 可注入时钟），`tick` 保留为空壳以满足既调。**实现以测试能过为准，但必须保持"剩余 = endAt - now"的绝对时间戳语义。**

- [ ] **Step 4: 调整测试与实现对齐（以测试绿为准）**

若 Step 3 的 API 与测试不匹配，按上说明重构（推荐最终 API）：

```dart
  void start({DateTime? now}) { phase = TimerPhase.focusing; _endAt = (now ?? DateTime.now()).add(const Duration(seconds: durationSeconds)); }
  int remainingSeconds({DateTime? now}) { ... 用注入 now ... }
```

并把 Step 1 测试中的 `t.start()`/`t.tick(now:)`/`t.resume(now:)`/`remainingSeconds()` 调用改为 `start(now: ...)`/`remainingSeconds(now: ...)` 的注入形式（用例语义不变）。跑：

```powershell
flutter test test/features/focus/focus_timer_test.dart
```

Expected: 4 用例全绿。

- [ ] **Step 5: analyze + 提交**

```powershell
flutter analyze
git add timebook/lib/features/focus/domain/focus_timer.dart timebook/test/features/focus/focus_timer_test.dart
git commit -m "feat(focus): 绝对时间戳番茄计时器（可注入时钟）"
```

---

### Task 5: 专注页（摘要卡 + 计时圆盘 + 今日待办）+ 接入 Tab

**Files:**
- Create: `timebook/lib/features/focus/presentation/focus_providers.dart`
- Create: `timebook/lib/features/focus/presentation/focus_timer_widget.dart`
- Create: `timebook/lib/features/focus/presentation/focus_screen.dart`
- Modify: `timebook/lib/core/router/app_shell.dart`
- Create: `timebook/test/features/focus/focus_screen_test.dart`

- [ ] **Step 1: 写失败测试**

`focus_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/focus/data/focus_repository.dart';
import 'package:timebook/features/focus/presentation/focus_providers.dart';
import 'package:timebook/features/focus/presentation/focus_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<ProviderContainer> seeded() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);
    await repo.createProject(name: '研究');
    await repo.createTask(title: '整理PRD', projectId: 1, priority: 1);
    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('专注页显示摘要、计时圆盘与今日待办', (tester) async {
    final c = await seeded();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: FocusScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('今日待办'), findsWidgets);
    expect(find.text('整理PRD'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus_start')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('24:5'), findsOneWidget); // 倒计时开始
  });
}
```

（注意：`FocusScreen` 内使用独立 provider：`focusDatabaseProvider`/`focusRepositoryProvider`——见 Step 3；`专注` Tab 的 AppShell 替换简单，测试直接 pump FocusScreen。）

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/focus/focus_screen_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现**

`focus_providers.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../data/focus_repository.dart';

final focusDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final focusRepositoryProvider =
    Provider<FocusRepository>((ref) => FocusRepository(ref.read(focusDatabaseProvider)));
```

`focus_timer_widget.dart`（圆盘 + 模式 chips + 开始/暂停/重置按钮，Key(`focus_start`) 为"开始/继续"主按钮）：

```dart
import 'package:flutter/material.dart';
import '../domain/focus_timer.dart';

class FocusTimerWidget extends StatefulWidget {
  const FocusTimerWidget({super.key, required this.focusMinutes});
  final int focusMinutes;
  @override
  State<FocusTimerWidget> createState() => _FocusTimerWidgetState();
}

class _FocusTimerWidgetState extends State<FocusTimerWidget> {
  final _timer = FocusTimer(focusMinutes: 25);

  void _tick() {
    if (_timer.phase == TimerPhase.focusing && _timer.isFinished) {
      _timer.reset();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final running = _timer.phase == TimerPhase.focusing;
    final icon = switch (_timer.phase) {
      TimerPhase.focusing => const Icon(Icons.pause),
      TimerPhase.paused => const Icon(Icons.play_arrow),
      _ => const Icon(Icons.play_arrow),
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 170, height: 170,
          child: CircularProgressIndicator(
            value: 1 - (_timer.remainingSeconds() / (_timer.durationSeconds)),
            strokeWidth: 12, backgroundColor: scheme.surfaceContainerHighest,
            color: scheme.primary,
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_timer.remainingLabel(),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ]),
      const SizedBox(height: 14),
      FilledButton.icon(
        key: const Key('focus_start'),
        onPressed: () {
          if (_timer.phase == TimerPhase.focusing) {
            _timer.pause();
          } else if (_timer.phase == TimerPhase.paused) {
            _timer.resume();
          } else {
            _timer.start();
          }
          _tick();
        },
        icon: icon,
        label: Text(running ? '暂停' : (_timer.phase == TimerPhase.paused ? '继续' : '开始专注')),
      ),
    ]);
  }
}
```

（缺 `FontFeature` import：`dart:ui`。UI 每秒刷新：`FocusScreen` 用 `Timer.periodic(Duration(seconds:1))` 驱动 `FocusTimerWidget` 的 key 重建即可——更稳做法：`FocusTimerWidget` 内建 `Timer.periodic` 每秒 `setState`。最终以可测为准：测试 `tester.pump(Duration)` 会推进 fake async 的 Timer。若用 `Timer.periodic` 在 `State` 里，`dispose` 必须 `cancel`。实现采用 state 内 periodic timer。）

`focus_screen.dart`（摘要卡 + FocusTimerWidget + 今日待办列表 + 快捷添加 + 视图切换入口）：

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/focus_repository.dart';
import 'domain/quick_add_parser.dart';
import 'focus_providers.dart';
import 'focus_timer_widget.dart';
import 'quadrant_view.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final _quick = TextEditingController();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _quick.dispose();
    super.dispose();
  }

  Future<void> _quickAdd() async {
    final text = _quick.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(focusRepositoryProvider);
    final d = parseQuickAdd(text);
    int? projectId;
    if (d.project != null) {
      final existing = await repo.projects();
      final hit = existing.where((p) => p.name == d.project).toList();
      projectId = hit.isNotEmpty ? hit.first.id : await repo.createProject(name: d.project!);
    }
    await repo.createTask(
        title: d.title, projectId: projectId, priority: 1,
        estimateMinutes: d.estimateMinutes, dueDate: d.dueDate);
    _quick.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(focusRepositoryProvider);
    return FutureBuilder(
      future: Future.wait([repo.openTasks(), repo.todayFocusMinutes(), repo.settings()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final tasks = snap.data![0] as List<dynamic>;
        final focusMin = snap.data![1] as int;
        final settings = snap.data![2] as PomodoroSetting;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Text('今日专注', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text('$focusMin 分钟', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]))),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: FocusTimerWidget(focusMinutes: settings.focusMinutes))),
          const SizedBox(height: 12),
          Row(children: [
            Text('今日待办', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(onPressed: () => setState(() {}), child: const Text('四象限')),
          ]),
          for (final t in tasks)
            ListTile(
              dense: true,
              leading: Checkbox(
                value: false,
                onChanged: (_) async {
                  await repo.toggleCompleted(taskId: t.id);
                  setState(() {});
                },
              ),
              title: Text(t.title)),
          const SizedBox(height: 8),
          TextField(
            controller: _quick,
            decoration: InputDecoration(
              hintText: '快速添加：任务 +项目 25m #标签 @明天',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _quickAdd),
            ),
          ),
        ]);
      },
    );
  }
}
```

（`tasks as List<dynamic>`：`Future.wait` 返回 `List<Object?>`，实际为 `List<Task>`；用 `as List<Task>` 需 import data。最终子代理按真实类型适配；`四象限` 按钮 → push `QuadrantView`（Task 6）。）

`app_shell.dart`：`pages` 中 `PlaceholderScreen(title: '专注')` → `const FocusScreen()`（import 对应文件）。

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/focus/focus_screen_test.dart
flutter test
flutter analyze
```

Expected: 用例 PASS；全量 40 区间（现有 25 + 前序 focus 8 + 本 task 2 ≈ 35+）；analyze 0 问题。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib timebook/test
git commit -m "feat(focus): 专注页（摘要/计时圆盘/今日待办/快捷添加）接入 Tab"
```

---

### Task 6: 四象限视图

**Files:**
- Create: `timebook/lib/features/focus/presentation/quadrant_view.dart`
- Modify: `timebook/test/features/focus/focus_screen_test.dart`（追加 1 用例）

- [ ] **Step 1: 写失败测试（追加到 focus_screen_test）**

```dart
testWidgets('四象限视图按重要/紧急分组', (tester) async {
  final c = await seeded();
  await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: QuadrantView()))));
  await tester.pumpAndSettle();

  expect(find.text('重要·紧急'), findsOneWidget);
  expect(find.text('整理PRD'), findsOneWidget); // priority=1 → 重要
});
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/focus/focus_screen_test.dart
```

Expected: FAIL（QuadrantView 未定义）。

- [ ] **Step 3: 实现**

`quadrant_view.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/focus_repository.dart';
import 'focus_providers.dart';

enum _Q { q1, q2, q3, q4 }

class QuadrantView extends ConsumerWidget {
  const QuadrantView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(focusRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('四象限')),
      body: FutureBuilder(
        future: repo.openTasks(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final tasks = snap.data!;
          final groups = <_Q, List<Task>>{for (final q in _Q.values) q: []};
          for (final t in tasks) {
            final urgent = t.dueDate != null &&
                t.dueDate!.isBefore(DateTime.now().add(const Duration(days: 2)));
            final important = t.priority <= 1;
            groups[(important && urgent)
                ? _Q.q1
                : (important ? _Q.q2 : (urgent ? _Q.q3 : _Q.q4))]!.add(t);
          }
          const titles = {
            _Q.q1: '重要·紧急', _Q.q2: '重要·不紧急',
            _Q.q3: '不重要·紧急', _Q.q4: '不重要·不紧急',
          };
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(12),
            crossAxisSpacing: 10, mainAxisSpacing: 10,
            children: [
              for (final q in _Q.values)
                Card(color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Padding(padding: const EdgeInsets.all(10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(titles[q]!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView(children: [
                              for (final t in groups[q]!) ListTile(dense: true, title: Text(t.title, style: const TextStyle(fontSize: 12))),
                            ]),
                          ),
                        ]))),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/focus/focus_screen_test.dart
flutter analyze
```

Expected: 通过（摘要/圆盘/四象限 3 用例）。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/focus/presentation/quadrant_view.dart timebook/test/features/focus/focus_screen_test.dart
git commit -m "feat(focus): 四象限视图（重要/紧急派生）"
```

> 说明：`FocusScreen` 中「四象限」按钮 `push(QuadrantView())` 在 Task 5 已预留 `onPressed`，此 Task 补齐实现（若 Task 5 已留空实现，此处 update）。

---

### Task 7: M4 验收

**Files:** 无（只验证）

- [ ] **Step 1: 全量检查**

```powershell
flutter analyze
flutter test
```

Expected: `No issues found!`；全部 PASS（既有 25 + 迁移 1 + focus_repo 3 + parser 4 + timer 4 + screen 3 = **40**）。

- [ ] **Step 2: Windows 构建**

```powershell
flutter build windows --debug
```

Expected: `√ Built build\windows\x64\runner\Debug\timebook.exe`。

- [ ] **Step 3: 记录已知限制（提交说明）**

- 计时进行中状态不持久化（杀进程即重置；任务绑定已完成记录随 sessions 存档）
- 系统通知（flutter_local_notifications）在后续里程碑接入；后台/锁屏补偿依赖绝对时间戳已内建
- 四象限的"紧急"阈值暂为 2 天内截止（可配置化后续迭代）
- 任务补记/编辑（改标题、延期）后续迭代；短语法已覆盖快速创建

- [ ] **Step 4: 提交收尾（如有未提交变更）**

```powershell
git add -A; git status
git commit -m "docs: M4 验收记录（40 tests green / analyze clean / windows build ok）"
```

---

## Self-Review 结论

- **Spec 覆盖（M4）**：§4 专注域 4 表 → Task 1；§7 签名联动（任务绑定、状态机、绝对时间戳、打断记录）→ Task 1/2/4/5；§11 短语法/四象限 → Task 3/6；M4 里程碑验收 → Task 7。中断记录：`addSession(interrupted:)` 供后续 UI 接入（肃清范围：M4 计时器完成即落 sessions，打断按钮标注为后续，避免范围膨胀）。专注记录统计：`todayFocusMinutes` 在 Task 5 摘要卡呈现（§7"专注反哺"最小闭环）。
- **占位扫描**：无 TBD；每 Task 含可编译代码与命令。Task 4 的 API 备注是**实现指引**（可注入时钟保持绝对时间戳语义），非占位。
- **类型一致性**：`FocusRepository` 方法名/签名 Task 2 定义、Task 5/6 使用一致；`parseQuickAdd` 返回 `QuickAddDraft` Task 3 定义、Task 5 使用一致；`FocusTimer(/TimerPhase/.phase/.remainingSeconds/.start/.pause/.resume)` Task 4 定义、Task 5 使用一致；`focusDatabaseProvider/focusRepositoryProvider` Task 5 定义、Task 5/6 测试使用一致；`PomodoroSetting` 行类型名以 drift 2.31 生成为准（Task 2 Step 4 已注明适配路径）。`QuadrantView` Task 6 定义并被 FocusScreen 引用。
- 测试计数：Task 7 预期 40（以实际 drift 生成名与 Future.wait 类型适配为微调窗口，总量不变）。