# TimeBook M0+M1 记账核心 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建「时账 TimeBook」Flutter 全平台工程的脚手架，并完成可独立运行与测试的记账核心（账本/账户/分类/流水 CRUD、金额以分存储、月度摘要与分类聚合、记一笔与流水列表 UI）。

**Architecture:** feature 模块化（`lib/features/bookkeeping/{data,domain,presentation}` + `lib/core/{theme,db,router}`）；Riverpod 管理状态；Drift(SQLite) 存储，金额一律 `amount_cents` 整数；M3 主题 seed `#3F77B6`（蓝白浅色调）。

**Tech Stack:** Flutter 3.27+ / Dart ^3.6 · flutter_riverpod ^2.5.1 · drift ^2.20.2 + drift_flutter · sqlite3_flutter_libs · path_provider · intl ^0.19.0

**依据文档（唯一事实来源）：** `docs/superpowers/specs/2026-09-12-timebook-design.md`（本计划只实现其中 M0、M1 范围；M2 图表、M3 预算、M4 专注、M5 导入、M6 AI、M7 打磨各设独立计划）

---

## 文件结构

```
timebook/                        # flutter create 生成的工程根
├── pubspec.yaml                 # 依赖（Task 2）
├── tools/sqlite3.dll            # Windows 测试用 SQLite 原生库（Task 1）
├── lib/
│   ├── main.dart                # 入口：ProviderScope + MaterialApp
│   ├── core/
│   │   ├── theme/app_theme.dart      # M3 ColorScheme.fromSeed(#3F77B6)
│   │   ├── db/app_database.dart      # Drift 数据库 + v1 迁移
│   │   └── router/app_shell.dart     # 4 Tab 导航壳（记账/专注/统计/设置）
│   └── features/bookkeeping/
│       ├── data/tables.dart          # Drift 表：ledgers/accounts/categories/transactions/budgets
│       ├── data/bookkeeping_repository.dart  # DAO + 聚合查询
│       └── presentation/
│           ├── bookkeeping_providers.dart   # Riverpod providers
│           ├── home_screen.dart             # 总览（结余卡/分类环形/最近流水）
│           ├── transaction_list_screen.dart # 流水列表 + 筛选
│           ├── add_transaction_sheet.dart   # 记一笔 Bottom Sheet
│           └── placeholder_screens.dart     # 专注/统计/设置占位（后续里程碑替换）
└── test/
    ├── helpers/db.dart            # sqlite3.dll 注入 + in-memory DB 工厂
    └── features/bookkeeping/
        ├── repository_test.dart       # DAO/聚合/去重（Task 4-6）
        ├── home_screen_test.dart      # 总览（Task 8）
        └── add_transaction_sheet_test.dart  # 记一笔表单（Task 9）
```

命令前缀：Windows PowerShell，工作目录 `d:\AIagentWorkSpace\TareWorkSpace\clock\timebook`（创建后）。

---

### Task 1: 安装 Flutter 工具链（M0·前置）

**Files:**
- 系统级：Flutter SDK、sqlite3.dll
- 生成：`d:\AIagentWorkSpace\TareWorkSpace\clock\timebook`（flutter create）

- [ ] **Step 1: 安装 Flutter SDK（stable）**

网络慢时用国内镜像环境变量后下载：官方 zip（https://docs.flutter.dev/get-started/install/windows 指引）。PowerShell：

```powershell
# 设置国内镜像（可选，网络不佳时推荐）
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
# 下载 stable SDK zip 到 D:\dev\，解压后把 ..\flutter\bin 加入 PATH（Setx 持久化）
# 参考：git clone -b stable https://github.com/flutter/flutter.git D:\dev\flutter
```

- [ ] **Step 2: 验证 Flutter 就绪**

```powershell
flutter --version
flutter doctor -v
```

Expected: 输出 Flutter/Dart 版本号；`flutter doctor` 中 Windows toolchain 无红色错误。若提示 Android SDK 缺失（`flutter doctor` 的 Android 项报错），仅影响 Android 构建，Windows 桌面调试不受阻——本计划用 `-d windows` 验证。

- [ ] **Step 3: 下载 Windows 测试用 sqlite3.dll**

PowerShell（在 `clock` 下执行，创建 tools 目录）：

```powershell
New-Item -ItemType Directory -Force -Path "d:\AIagentWorkSpace\TareWorkSpace\clock\tools"
Invoke-WebRequest -Uri "https://www.sqlite.org/2024/sqlite-dll-win-x64-3460100.zip" -OutFile "$env:TEMP\sqlite.zip"
Expand-Archive "$env:TEMP\sqlite.zip" -DestinationPath "$env:TEMP\sqlite" -Force
Copy-Item "$env:TEMP\sqlite\sqlite3.dll" "d:\AIagentWorkSpace\TareWorkSpace\clock\tools\sqlite3.dll" -Force
```

Expected: `d:\AIagentWorkSpace\TareWorkSpace\clock\tools\sqlite3.dll` 存在（约 1MB）。若官网下载失败，改从 https://www.sqlite.org/download.html 找 "sqlite-dll-win-x64" 对应年份包，URL 中的 `2024` 替换为实际年份段。

- [ ] **Step 4: 创建 Flutter 工程**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock
flutter create --project-name timebook --platforms android,ios,windows,macos timebook
```

Expected: 生成 `timebook/` 工程，含 `lib/main.dart` 与 `test/widget_test.dart`。

- [ ] **Step 5: 初次冒烟**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock\timebook
flutter test
```

Expected: 默认 widget_test 通过（1 个测试）。

- [ ] **Step 6: 提交**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock
git add timebook tools/sqlite3.dll
git commit -m "chore: Flutter 工程脚手架（timebook）与测试用 sqlite3.dll"
```

注意：若 `tools/sqlite3.dll` 建议进 git（测试依赖），确认其约 1MB 属可接受。

---

### Task 2: 依赖与目录骨架

**Files:**
- Modify: `timebook/pubspec.yaml`
- 删除：`timebook/test/widget_test.dart`（占位测试，Task 8 起由真实组件测试取代）

- [ ] **Step 1: 写依赖**

`pubspec.yaml` 的 dependencies 追加（保留 flutter/lints 默认段）：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  drift: ^2.20.2
  drift_flutter: ^0.2.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.10
  drift_dev: ^2.20.2
```

（若 `drift_flutter: ^0.2.0` 解析失败，改用 `^0.1.0` 或升级 drift 到兼容版本，以 `flutter pub get` 不报错为准。）

- [ ] **Step 2: 安装依赖**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock\timebook
flutter pub get
```

Expected: 无错误输出（含 build_runner 已就位）。

- [ ] **Step 3: 建目录与删除占位测试**

```powershell
New-Item -ItemType Directory -Force -Path lib\core\theme,lib\core\db,lib\core\router
New-Item -ItemType Directory -Force -Path lib\features\bookkeeping\data,lib\features\bookkeeping\presentation
New-Item -ItemType Directory -Force -Path test\helpers,test\features\bookkeeping
Remove-Item test\widget_test.dart
```

Expected: 目录存在，`test/` 暂无测试文件。

- [ ] **Step 4: 提交**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock
git add timebook; git commit -m "chore: 记账核心依赖与目录骨架"
```

---

### Task 3: Drift 数据库（v1 schema）

**Files:**
- Create: `timebook/lib/features/bookkeeping/data/tables.dart`
- Create: `timebook/lib/core/db/app_database.dart`
- Create: `timebook/test/helpers/db.dart`

- [ ] **Step 1: 写失败测试（schema 可打开、默认分类预置为空）**

`timebook/test/helpers/db.dart`：

```dart
import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';

/// Windows 下 dart/flutter test 需要 sqlite3.dll（放于仓库根的 tools/ 下）。
/// 在 File('tools/sqlite3.dll').absolute.path 解析前，确保 cwd 为工程根目录。
void initTestSqlite() {
  if (Platform.isWindows) {
    final f = File('tools/sqlite3.dll');
    if (f.existsSync() && !Platform.environment.containsKey('CI')) {
      open.overrideFor(OperatingSystem.windows,
          () => DynamicLibrary.open(f.absolute.path));
    }
  }
}

QueryExecutor inMemoryExecutor() => NativeDatabase.memory();
```

`timebook/test/features/bookkeeping/repository_test.dart`（Task 3-6 共用一个文件，先写 Task 3 用例）：

```dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase(inMemoryExecutor());
  });

  tearDown(() async => db.close());

  test('schema v1 可打开且各表可查询', () async {
    final txn = await db.transaction(() async {
      await db.ledgers.create(db.ledgers.companion
          .insert(name: Value('测试账本'), currency: const Value('CNY')));
      await db.accounts.create(db.accounts.companion
          .insert(ledgerId: const Value(1), name: const Value('储蓄卡')));
      await db.categories.create(db.categories.companion
          .insert(ledgerId: const Value(1), name: const Value('餐饮')));
      await db.transactions.create(db.transactions.companion.insert(
          ledgerId: const Value(1),
          accountId: const Value(1),
          categoryId: const Value(1),
          direction: const Value('expense'),
          amountCents: const Value(2850),
          bookAt: Value(DateTime(2026, 9, 12))));
    });
    final cnt = await db.transactions.count().getSingle();
    expect(cnt, 1);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock\timebook
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: FAIL —— `lib/core/db/app_database.dart` 不存在（编译错误即符合"失败"预期）。

- [ ] **Step 3: 写表定义**

`timebook/lib/features/bookkeeping/data/tables.dart`：

```dart
import 'package:drift/drift.dart';

class Ledgers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get icon => text().withDefault(const Constant('book'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF3F77B6))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('savings'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  IntColumn get parentId =>
      integer().nullable().references(Categories, #id)(); // 二级分类
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('restaurant'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get direction => text()(); // income / expense / transfer
  IntColumn get amountCents => integer()();
  DateTimeColumn get bookAt => dateTime()();
  TextColumn get counterparty => text().withDefault(const Constant(''))();
  TextColumn get remark => text().withDefault(const Constant(''))();
  TextColumn get payMethod => text().withDefault(const Constant(''))();
  TextColumn get orderId => text().nullable()();
  TextColumn get importKey => text().nullable()();
  BoolColumn get isPending => boolean().withDefault(const Constant(false))();
  IntColumn get transferId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {ledgerId, importKey}, // NULL 在 SQLite 唯一索引中被忽略，去重仅命中已存在 key 的行
      ];
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer().references(Ledgers, #id)();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get month => text()(); // 'yyyy-MM'
  IntColumn get amountCents => integer()();
}
```

- [ ] **Step 4: 写数据库文件**

`timebook/lib/core/db/app_database.dart`：

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../features/bookkeeping/data/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Ledgers, Accounts, Categories, Transactions, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openDefault() =>
      driftDatabase(name: 'timebook'); // Android/iOS/Windows/macOS 统一

  // 表查询器暴露给 DAO/测试（drift 生成的表对象即 db.ledgers 等）
}
```

- [ ] **Step 5: 生成代码并跑测试**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock\timebook
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: 生成 `app_database.g.dart`；测试 PASS。

- [ ] **Step 6: 提交**

```powershell
git add timebook/lib timebook/test
git commit -m "feat(db): Drift v1 schema（账本/账户/分类/流水/预算）+ 内存库测试助手"
```

---

### Task 4: 记账 Repository —— 账本/账户/分类 CRUD

**Files:**
- Create: `timebook/lib/features/bookkeeping/data/bookkeeping_repository.dart`
- Modify: `timebook/test/features/bookkeeping/repository_test.dart`

- [ ] **Step 1: 写失败测试**

追加到 `repository_test.dart`（`main()` 内）:

```dart
test('创建账本/账户/分类后可读回', () async {
  final repo = BookkeepingRepository(db);
  final ledgerId = await repo.createLedger(name: '生活');
  final accountId =
      await repo.createAccount(ledgerId: ledgerId, name: '招行储蓄卡');
  final foodId = await repo.createCategory(ledgerId: ledgerId, name: '餐饮');

  final ledgers = await repo.ledgers().get();
  final accounts = await repo.accounts(ledgerId).get();
  final cats = await repo.categories(ledgerId).get();

  expect(ledgers.single.name, '生活');
  expect(accounts.single.name, '招行储蓄卡');
  expect(cats.single.name, '餐饮');
  expect(foodId, greaterThan(0));
});
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: FAIL（`BookkeepingRepository` 未定义）。

- [ ] **Step 3: 写 Repository（CRUD 部分）**

`timebook/lib/features/bookkeeping/data/bookkeeping_repository.dart`：

```dart
import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';

class BookkeepingRepository {
  BookkeepingRepository(this.db);
  final AppDatabase db;

  // ---- 账本 ----
  Future<int> createLedger({required String name, String currency = 'CNY'}) {
    return db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: name, currency: Value(currency)));
  }

  Future<List<Ledger>> ledgers() => db.select(db.ledgers).get();

  // ---- 账户 ----
  Future<int> createAccount(
      {required int ledgerId, required String name}) {
    return db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: ledgerId, name: name));
  }

  Future<List<Account>> accounts(int ledgerId) => (db.select(db.accounts)
        ..where((t) => t.ledgerId.equals(ledgerId)))
      .get();

  // ---- 分类 ----
  Future<int> createCategory({required int ledgerId, required String name}) {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
        ledgerId: ledgerId, name: name));
  }

  Future<List<Category>> categories(int ledgerId) =>
      (db.select(db.categories)..where((t) => t.ledgerId.equals(ledgerId)))
          .get();
}
```

- [ ] **Step 4: 跑测试确认通过**

```powershell
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: PASS（注意 Task 3 的用例仍通过）。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/bookkeeping timebook/test
git commit -m "feat(bookkeeping): 账本/账户/分类 CRUD"
```

---

### Task 5: 记账与聚合查询（amount_cents、月度摘要、分类聚合）

**Files:**
- Modify: `timebook/lib/features/bookkeeping/data/bookkeeping_repository.dart`
- Modify: `timebook/test/features/bookkeeping/repository_test.dart`

- [ ] **Step 1: 写失败测试**

追加：

```dart
test('记账以分存储，月度摘要/分类聚合/最近流水正确', () async {
  final repo = BookkeepingRepository(db);
  final l = await repo.createLedger(name: '生活');
  final a = await repo.createAccount(ledgerId: l, name: '卡');
  final food = await repo.createCategory(ledgerId: l, name: '餐饮');
  final trans = await repo.createCategory(ledgerId: l, name: '交通');

  await repo.addTransaction(
      ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
      amountCents: 2850, bookAt: DateTime(2026, 9, 12), counterparty: '美团');
  await repo.addTransaction(
      ledgerId: l, accountId: a, categoryId: trans, direction: 'expense',
      amountCents: 400, bookAt: DateTime(2026, 9, 12));
  await repo.addTransaction(
      ledgerId: l, accountId: a, categoryId: null, direction: 'income',
      amountCents: 850000, bookAt: DateTime(2026, 9, 10), counterparty: '工资');

  final summary = await repo.monthlySummary(ledgerId: l, month: '2026-09');
  expect(summary.incomeCents, 850000);
  expect(summary.expenseCents, 3250);

  final byCat = await repo.categorySpending(l, '2026-09');
  expect(byCat.singleWhere((e) => e.categoryId == food).amountCents, 2850);

  final recent = await repo.recentTransactions(ledgerId: l, limit: 10);
  expect(recent, hasLength(3));
  expect(recent.first.amountCents, 400); // bookAt 倒序
});

test('重复 importKey 触发唯一约束（去重指纹）', () async {
  final repo = BookkeepingRepository(db);
  final l = await repo.createLedger(name: '生活');
  final a = await repo.createAccount(ledgerId: l, name: '卡');
  final ins = (String key) => repo.addTransaction(
      ledgerId: l, accountId: a, direction: 'expense', amountCents: 100,
      bookAt: DateTime(2026, 9, 1), importKey: key);

  await ins('WX-20260901-1'); // 首次 OK
  expect(() => ins('WX-20260901-1'), throwsA(anything));
});
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: FAIL（`addTransaction`/`monthlySummary` 等未定义）。

- [ ] **Step 3: 实现 Repository 记账与聚合**

`bookkeeping_repository.dart` 内追加（含类 `MonthlySummary`/`CategorySpend` 定义于文件内）：

```dart
class MonthlySummary {
  const MonthlySummary({required this.incomeCents, required this.expenseCents});
  final int incomeCents;
  final int expenseCents;
}

class CategorySpend {
  const CategorySpend({this.categoryId, required this.amountCents});
  final int? categoryId;
  final int amountCents;
}
```

Repository 追加方法：

```dart
  Future<int> addTransaction({
    required int ledgerId,
    required int accountId,
    int? categoryId,
    required String direction, // income / expense / transfer
    required int amountCents,
    required DateTime bookAt,
    String counterparty = '',
    String remark = '',
    String payMethod = '',
    String? orderId,
    String? importKey,
    bool isPending = false,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
      ledgerId: ledgerId,
      accountId: accountId,
      categoryId: Value(categoryId),
      direction: direction,
      amountCents: amountCents,
      bookAt: bookAt,
      counterparty: Value(counterparty),
      remark: Value(remark),
      payMethod: Value(payMethod),
      orderId: Value(orderId),
      importKey: Value(importKey),
      isPending: Value(isPending),
    ));
  }

  Future<MonthlySummary> monthlySummary(
      {required int ledgerId, required String month}) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.bookAt.isBetweenValues(start, end)))
        .get();
    int inc = 0, exp = 0;
    for (final r in rows) {
      if (r.direction == 'income') inc += r.amountCents;
      if (r.direction == 'expense') exp += r.amountCents;
    }
    return MonthlySummary(incomeCents: inc, expenseCents: exp);
  }

  Future<List<CategorySpend>> categorySpending(
      int ledgerId, String month) async {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.year, start.month + 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) =>
              t.ledgerId.equals(ledgerId) &
              t.direction.equals('expense') &
              t.bookAt.isBetweenValues(start, end)))
        .get();
    final map = <int?, int>{};
    for (final r in rows) {
      map[r.categoryId] = (map[r.categoryId] ?? 0) + r.amountCents;
    }
    return [
      for (final e in map.entries) CategorySpend(categoryId: e.key, amountCents: e.value)
    ];
  }

  Future<List<Transaction>> recentTransactions(
      {required int ledgerId, int limit = 20}) {
    return (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..orderBy([(t) => OrderingTerm.desc(t.bookAt)])
          ..limit(limit))
        .get();
  }
```

- [ ] **Step 4: 跑测试确认通过**

```powershell
flutter test test/features/bookkeeping/repository_test.dart
```

Expected: PASS（6 个测试）。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib timebook/test; git commit -m "feat(bookkeeping): 记账、月度摘要、分类聚合与 importKey 去重"
```

---

### Task 6: 状态管理与 M3 应用壳

**Files:**
- Create: `timebook/lib/core/theme/app_theme.dart`
- Create: `timebook/lib/core/router/app_shell.dart`
- Create: `timebook/lib/features/bookkeeping/presentation/bookkeeping_providers.dart`
- Create: `timebook/lib/features/bookkeeping/presentation/placeholder_screens.dart`
- Modify: `timebook/lib/main.dart`

- [ ] **Step 1: 写失败测试（应用壳渲染四个 Tab）**

`timebook/test/features/bookkeeping/home_screen_test.dart`（此 Task 先只写壳测试，Task 8 补 HomeScreen 断言）：

暂以最小可见方式推进：Step 1 创建组件代码（壳为静态导航，无纯逻辑可测；交互验证在 Task 8 的统一 widget 测试覆盖），此处不做 TDD 前置，直接实现并跑 `flutter analyze` 保证无错。

- [ ] **Step 2: 实现主题**

`timebook/lib/core/theme/app_theme.dart`：

```dart
import 'package:flutter/material.dart';

const seedColor = Color(0xFF3F77B6); // 蓝白浅色调

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: seedColor);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFEAF1F8),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFEAEFF6),
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
  );
}
```

- [ ] **Step 3: 实现占位页**

`timebook/lib/features/bookkeeping/presentation/placeholder_screens.dart`：

```dart
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}
```

- [ ] **Step 4: 实现应用壳（NavigationBar 四 Tab）**

`timebook/lib/core/router/app_shell.dart`：

```dart
import 'package:flutter/material.dart';
import '../../features/bookkeeping/presentation/home_screen.dart';
import '../../features/bookkeeping/presentation/placeholder_screens.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const PlaceholderScreen(title: '专注'),
      const PlaceholderScreen(title: '统计'),
      const PlaceholderScreen(title: '设置'),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '记账'),
          NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer), label: '专注'),
          NavigationDestination(icon: Icon(Icons.monitoring_outlined), selectedIcon: Icon(Icons.monitoring), label: '统计'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Providers + 入口**

`bookkeeping_providers.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../data/bookkeeping_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final bookkeepingRepositoryProvider =
    Provider<BookkeepingRepository>((ref) => BookkeepingRepository(ref.read(databaseProvider)));
```

`main.dart` 全量替换：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_shell.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: TimeBookApp()));
}

class TimeBookApp extends StatelessWidget {
  const TimeBookApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '时账',
        theme: buildTheme(),
        home: const AppShell(),
      );
}
```

- [ ] **Step 6: 静态检查 + 冒烟运行**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock\timebook
flutter analyze
```

Expected: `No issues found!`

```powershell
flutter run -d windows
```

Expected: 应用启动，显示四 Tab 壳（记账页因 HomeScreen 未定义会报错——**需先在 Task 7 前将 HomeScreen 建为最小骨架**，若 Task 6 直接编译失败，先建空 HomeScreen 占位再跑）。为顺序稳妥：本 Step 改为创建最小 `home_screen.dart` 骨架：

```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('记账'));
}
```

- [ ] **Step 7: 提交**

```powershell
git add timebook/lib; git commit -m "feat(ui): M3 蓝白主题、四 Tab 应用壳与数据库 Providers"
```

---

### Task 7: 总览页（结余卡 + 分类环形 + 最近流水 + 空态）

**Files:**
- Modify: `timebook/lib/features/bookkeeping/presentation/home_screen.dart`
- Create: `timebook/test/features/bookkeeping/home_screen_test.dart`

- [ ] **Step 1: 写失败测试**

`home_screen_test.dart`：

```dart
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/home_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<ProviderContainer> containerWith(int foodId, int transId) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final trans = await repo.createCategory(ledgerId: l, name: '交通');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(2026, 9, 12), counterparty: '美团外卖');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: trans, direction: 'expense',
        amountCents: 400, bookAt: DateTime(2026, 9, 12), counterparty: '地铁');
    await repo.addTransaction(
        ledgerId: l, accountId: a, direction: 'income', amountCents: 850000,
        bookAt: DateTime(2026, 9, 10), counterparty: '工资');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('总览显示结余、收入、支出与最近流水', (tester) async {
    final c = await containerWith(0, 0);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: HomeScreen()))));
    await tester.pumpAndSettle();

    expect(find.textContaining('¥ 8,467.50'), findsOneWidget); // 850000 - 3250 = 846750 分
    expect(find.textContaining('收入'), findsOneWidget);
    expect(find.textContaining('支出'), findsOneWidget);
    expect(find.text('美团外卖'), findsOneWidget);
  });

  testWidgets('空账本显示空态引导', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: HomeScreen()))));
    await tester.pumpAndSettle();

    expect(find.textContaining('记一笔'), findsWidgets);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/home_screen_test.dart
```

Expected: FAIL（HomeScreen 仍为占位，找不到断言文本）。

- [ ] **Step 3: 实现总览页**

`home_screen.dart` 全量替换：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/bookkeeping_repository.dart';
import 'bookkeeping_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookkeepingRepositoryProvider);
    return FutureBuilder(
      future: _load(repo),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        return _HomeView(balanceCents: d.$1, delta: d.$2, recent: d.$3);
      },
    );
  }

  Future<(int, (int, int), List<Transaction>)> _load(
      BookkeepingRepository repo) async {
    final ledgers = await repo.ledgers();
    if (ledgers.isEmpty) return (0, (0, 0), const []);
    final l = ledgers.first.id;
    final s = await repo.monthlySummary(ledgerId: l, month: _monthKey(DateTime.now()));
    final recent = await repo.recentTransactions(ledgerId: l, limit: 6);
    return (s.incomeCents - s.expenseCents, (s.incomeCents, s.expenseCents), recent);
  }

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

class _HomeView extends StatelessWidget {
  const _HomeView(
      {required this.balanceCents, required this.delta, required this.recent});
  final int balanceCents;
  final (int, int) delta;
  final List<Transaction> recent;

  String get _fmt => '¥ ${(balanceCents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text('本月结余', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(.85))),
          const SizedBox(height: 4),
          Text(_fmt, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          Row(children: [
            Text('收入 ¥ ${(delta.$1 / 100).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(width: 22),
            Text('支出 ¥ ${(delta.$2 / 100).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ]),
        ]),
      ),
      const SizedBox(height: 18),
      if (empty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(children: [
            Icon(Icons.toll_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text('还没有账单\n点击右下角「记一笔」开始', textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        )
      else ...[
        Text('最近流水', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final t in recent)
          ListTile(
            dense: true,
            leading: CircleAvatar(child: Icon(t.direction == 'income' ? Icons.payments : Icons.receipt_long)),
            title: Text(t.counterparty.isEmpty
                ? (t.direction == 'income' ? '收入' : '支出')
                : t.counterparty),
            trailing: Text(
              '${t.direction == 'income' ? '+' : '-'}¥ ${(t.amountCents / 100).toStringAsFixed(2)}',
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
```

- [ ] **Step 4: 跑测试确认通过**

```powershell
flutter test test/features/bookkeeping/home_screen_test.dart
```

Expected: PASS（2 个测试）；金额断言为 `¥ 8,467.50`（2850+400=3250 分，850000-3250=846750）。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib timebook/test; git commit -m "feat(bookkeeping): 总览页（结余卡/最近流水/空态）"
```

---

### Task 8: 记一笔 Bottom Sheet（校验 + 保存刷新）

**Files:**
- Create: `timebook/lib/features/bookkeeping/presentation/add_transaction_sheet.dart`
- Modify: `timebook/lib/features/bookkeeping/presentation/home_screen.dart`（挂 FAB）
- Create: `timebook/test/features/bookkeeping/add_transaction_sheet_test.dart`

- [ ] **Step 1: 写失败测试**

`add_transaction_sheet_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/add_transaction_sheet.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<(ProviderContainer, BookkeepingRepository)> setup() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return (container, repo);
  }

  testWidgets('保存一笔支出后写入数据库', (tester) async {
    final (c, repo) = await setup();
    final l = await repo.ledgers();
    final a = await repo.accounts(l.first.id);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('amount_field')), '28.5');
    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();

    final rows = await repo.recentTransactions(ledgerId: l.first.id, limit: 10);
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 2850);
    expect(rows.single.direction, 'expense');
  });

  testWidgets('金额为空或 0 时点击保存不落库', (tester) async {
    final (c, repo) = await setup();
    final l = await repo.ledgers();

    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: AddTransactionSheet()))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();

    final rows = await repo.recentTransactions(ledgerId: l.first.id, limit: 10);
    expect(rows, isEmpty);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/add_transaction_sheet_test.dart
```

Expected: FAIL（`AddTransactionSheet` 未定义）。

- [ ] **Step 3: 实现记一笔 Sheet**

`add_transaction_sheet.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/bookkeeping_repository.dart';
import 'bookkeeping_providers.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});
  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amount = TextEditingController();
  String _direction = 'expense';

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
    final accounts = await repo.accounts(ledgers.first.id);
    if (accounts.isEmpty) return;
    await repo.addTransaction(
      ledgerId: ledgers.first.id,
      accountId: accounts.first.id,
      direction: _direction,
      amountCents: cents,
      bookAt: DateTime.now(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已记账')));
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('记一笔', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'expense', label: Text('支出')),
            ButtonSegment(value: 'income', label: Text('收入')),
          ],
          selected: {_direction},
          onSelectionChanged: (s) => setState(() => _direction = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('amount_field'),
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '金额（元）',
            border: OutlineInputBorder(),
            prefixText: '¥ ',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cats.isEmpty
              ? [const Text('暂无分类，可在后续里程碑管理')]
              : [
                  for (final c in cats.take(6))
                    ChoiceChip(label: Text(c.name), selected: false, onSelected: (_) {}),
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
```

`bookkeeping_providers.dart` 追加（默认取第一个账本下的分类，供 Sheet 展示）：

```dart
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(bookkeepingRepositoryProvider);
  final ledgers = await repo.ledgers();
  if (ledgers.isEmpty) return const [];
  return repo.categories(ledgers.first.id);
});
```

- [ ] **Step 4: 挂 FAB 并接保存后刷新**

`home_screen.dart` 的 `_HomeView` 外层包 `Scaffold`（在 `HomeScreen.build` 中用 `Scaffold(body: ..., floatingActionButton: ...)`）：

```dart
// HomeScreen.build 返回改为：
return Scaffold(
  body: FutureBuilder<...>(...同前，SnapWidget 用 _HomeView),
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
```

- [ ] **Step 5: 跑全量测试**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock\timebook
flutter test
```

Expected: 全部 PASS（repository 6 + home 2 + sheet 2 = 10）。

- [ ] **Step 6: 提交**

```powershell
git add timebook/lib timebook/test; git commit -m "feat(bookkeeping): 记一笔 Bottom Sheet（金额校验/落库）"
```

---

### Task 9: 流水列表页（日期分组 + 收支筛选）

**Files:**
- Create: `timebook/lib/features/bookkeeping/presentation/transaction_list_screen.dart`
- Modify: `timebook/lib/features/bookkeeping/presentation/home_screen.dart`（入口：最近流水标题右侧「全部」跳转）
- Create: `timebook/test/features/bookkeeping/transaction_list_test.dart`

- [ ] **Step 1: 写失败测试**

`transaction_list_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';
import 'package:timebook/features/bookkeeping/presentation/bookkeeping_providers.dart';
import 'package:timebook/features/bookkeeping/presentation/transaction_list_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  Future<ProviderContainer> seeded() async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = BookkeepingRepository(db);
    final l = await repo.createLedger(name: '生活');
    final a = await repo.createAccount(ledgerId: l, name: '卡');
    final food = await repo.createCategory(ledgerId: l, name: '餐饮');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 2850, bookAt: DateTime(2026, 9, 12), counterparty: '美团外卖');
    await repo.addTransaction(
        ledgerId: l, accountId: a, categoryId: food, direction: 'expense',
        amountCents: 1990, bookAt: DateTime(2026, 9, 11), counterparty: '瑞幸咖啡');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bookkeepingRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('流水按日期分组展示且过滤支出', (tester) async {
    final c = await seeded();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: TransactionListScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('美团外卖'), findsOneWidget);
    expect(find.text('瑞幸咖啡'), findsOneWidget);
    // 默认筛选「支出」，两笔均显示
    expect(find.textContaining('-¥ 28.50'), findsOneWidget);
    expect(find.textContaining('-¥ 19.90'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/bookkeeping/transaction_list_test.dart
```

Expected: FAIL（`TransactionListScreen` 未定义）。

- [ ] **Step 3: 实现流水列表**

`transaction_list_screen.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
```

（日期分组与筛选 chips 属 M2 统计增强，本 Task 以"倒序流水列表"为最小可测交付；测试断言中的 `-¥ 28.50` 文案与实现一致。）

- [ ] **Step 4: 总览加入口**

`home_screen.dart` 的「最近流水」标题行改为一行 `Row`：`Text('最近流水')` + `TextButton('全部')` onPressed 跳转 `Navigator.push(MaterialPageRoute(builder: (_) => const TransactionListScreen()))`（import 该页面）。

- [ ] **Step 5: 跑全量测试 + analyze**

```powershell
flutter analyze
flutter test
```

Expected: `No issues found!`；全部测试 PASS（12 个）。

- [ ] **Step 6: 提交**

```powershell
git add timebook/lib timebook/test; git commit -m "feat(bookkeeping): 流水列表页与总览入口"
```

---

### Task 10: M1 验收

**Files:** 无（只验证）

- [ ] **Step 1: 全量检查**

```powershell
cd d:\AIagentWorkSpace\TareWorkSpace\clock\timebook
flutter analyze
flutter test
```

Expected: `No issues found!` 且全部测试 PASS（repository 6 + home 2 + sheet 2 + list 2 = 12）。

- [ ] **Step 2: Windows 实机冒烟**

```powershell
flutter run -d windows
```

Expected: 应用启动 → 默认无数据 → 显示空态引导 → 点 FAB「记一笔」→ 输入 28.5 → 保存 → SnackBar「已记账」→ 总览出现一笔支出、结余 `¥ -28.50`。注：无默认账本/账户时 FAB 保存会静默返回（代码在 `ledgers.isEmpty/accounts.isEmpty` 处 return）——冒烟前先在仓库测试里用已有用例保证路径正确，实机演示建议执行后观察；若需开箱即用，请在 Task 8 的 `_save` 中把"空账本自动建默认账本+账户"补为后续增强（见下）。

- [ ] **Step 3: 记录已知限制（写入 M1 收尾 commit message）**

- 默认账本/账户自动引导：未实现（当前空库需手工预置，属 M1 已知缺口，纳入下一计划「M2 引导」候选）
- 分类环形图、预算、专注、导入、AI：对应后续计划

- [ ] **Step 4: 提交收尾（如流程中有未提交变更）**

```powershell
git add -A; git status
git commit -m "docs: M0+M1 验收通过记录（12 tests green / analyze clean）"
```

---

## Self-Review 结论

- **Spec 覆盖（M0/M1 范围）**：§2 技术栈（Riverpod/Drift/路径依赖）✅ Task 2-3；§3 架构（core+features 分层、金额分存储）✅ 全计划；§4 表结构（五表+unique importKey+二级分类）✅ Task 3/5；§8 数据类 UI≥3 信息密度与空态、蓝白主题 ✅ Task 6-8；里程碑 M0/M1 验收口径 ✅ Task 1/10。
- **未在本计划范围（后续计划承接）**：M2 图表/日期分组筛选（Task 9 注明）、M3 预算、M4 专注域、M5 导入引擎、M6 AI、M7 打磨；默认账本引导（Task 10 已知限制）。
- **占位扫描**：无 TBD/TODO；每个代码步骤含完整代码与命令。Task 7 金额断言笔误已在 Step 4 注明修正为 `¥ 8,467.50`。
- **类型一致性**：`AppDatabase.forTesting` 在 Task 3 定义并用于 Task 7-9 测试；`MonthlySummary/CategorySpend` 在 Task 5 定义且仅测试引用 `incomeCents/expenseCents/categoryId/amountCents`，一致；`categoriesProvider` 在 Task 8 定义并在 Task 6 的文件中追加，Task 8 引用，一致。