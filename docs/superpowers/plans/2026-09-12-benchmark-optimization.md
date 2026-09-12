# TimeBook 三项目优化包 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 对标 BeeCount / Veri Fin / Super Productivity 落地 8 项优化：①记账算式键盘+默认付款账户 ②无账户模式 ③流水批量操作 ④记账每日提醒 ⑤导入逐行确认列表 ⑥预算默认值+单月覆盖 ⑦发薪日预算周期 ⑧长按 AI 双入口。**硬约束：既有 97 测试全程保持全绿。**

**Architecture:** 无 schema 迁移（沿用现有表；「无账户」用系统账户语义、预算默认/周期用 `settings` kv 存储、提醒复用 `NotificationService`）。记账体验改动集中 `add_transaction_sheet.dart`/流水页；数据预算改动集中 `budget_*` 与 `import_screen.dart`；周期边界抽共享 helper `core/util/formats.dart`。

**Tech Stack:** Flutter/Dart · flutter_riverpod · drift 2.31 · flutter_local_notifications（已依赖）· intl

**依据：** 三项目 README 特性对照 + 用户 8 选 + 已交付代码（含 `qa_report.md`）。

---

## 文件结构

```
timebook/lib/
├── core/util/formats.dart                 # M: + parseArithmetic / periodStart(周期起始) helper
├── features/bookkeeping/
│   ├── data/bookkeeping_repository.dart   # M: bulkUpdateCategory/bulkDelete/默认账户与无账户查询
│   ├── presentation/add_transaction_sheet.dart  # M: 算式解析+无账户chip+默认账户预选+长按AI
│   ├── presentation/transaction_list_screen.dart # M: 多选模式+批量操作条
│   ├── presentation/budget_screen.dart    # M: 默认预算沿用/单月覆盖/周期说明
│   ├── presentation/budget_setting_sheet.dart   # M: 「设为默认」「沿用上月」「周期起始日」
│   └── presentation/budget_period_helper.dart   # C: 周期起始日 → 期边界（供 6/7 复用）
│   ├── presentation/settings 相关         # M: 默认账户行/记账提醒行（设置页）
├── features/import/presentation/import_screen.dart # M: 逐行确认列表
├── features/focus/notifications/notification_service.dart # M: + scheduleDaily
├── features/ai/presentation/ai_dialog.dart # 复用（长按入口）
```

命令约定（全项目一致）：Windows/PowerShell；Flutter 全路径 `D:\dev\flutter\bin\flutter.bat`；命令前内联镜像 env；flutter cwd=`...\clock\timebook`；git cwd=`...\clock`。

---

### Task 1: 算式键盘 + 默认付款账户（Veri Fin）

**Files:** `formats.dart`(M) · `bookkeeping_repository.dart`(M) · `add_transaction_sheet.dart`(M) · `placeholder_screens.dart`(M) · 测试

- [ ] **Step 1: 算式解析（TDD）** `formats.dart` 增 `int? parseArithmeticToCents(String input)`：支持 `数字[+-*/]数字`、可多运算符从左到右（含小数→分 round）；非法返回 null。测试：`500+800`→130000、`28.5*2`→5700、`abc`→null、`100/4`→2500。
- [ ] **Step 2: 默认账户（TDD）** settings kv：`defaultAccountId`（`SettingsService` 或 repository `getDefaultAccountId/saveDefaultAccountId`——用现有 `settings` 表 kv 或新增简单 KV helper；由实现者裁定最简，建议复用 `flutter_secure_storage` 的 settings 也行，但为可测用内存注入）。repo 增 `Future<int?> defaultAccountId(int ledgerId)`（读取 kv + 校验存在）。设置页加「默认付款账户」行（Key('default_account_entry')）→ 账户选择 Sheet（账本账户列表单选→保存）。测试：保存后读取一致；Sheet 保存落 kv。
- [ ] **Step 3: Sheet 集成** `add_transaction_sheet.dart`：金额输入 onChange 用 `parseArithmeticToCents` 实时显示 `= ¥ xx.xx` 预览（非空且结果≠null 时）；账户区预选默认账户（无则不选）。
- [ ] **Step 4: 提交** `feat(bookkeeping): 记账算式解析 + 默认付款账户（Veri Fin）`

---

### Task 2: 无账户模式 + 每日记账提醒

**Files:** `bookkeeping_repository.dart`(M) · `add_transaction_sheet.dart`(M) · `notification_service.dart`(M) · 设置页(M) · 测试

- [ ] **Step 1: 无账户模式** `bookkeeping_repository.dart` 增 `ensureNoneAccount(ledgerId)`：确保存在名为「不记账户」的账户（type 'none'）并返回 id；`addTransaction` 保持必填 accountId（无账户记账即写入该账户，语义"不进资产"后续再细化）。Sheet 账户区加 `FilterChip('不记账户')`（选中 → 保存用 ensureNoneAccount 的账户）。测试：ensureNoneAccount 幂等；Sheet 选择「不记账户」后落库 accountId=该账户。
- [ ] **Step 2: 每日提醒（TDD）** `NotificationService` 增 `Future<void> scheduleDaily({required int id, required String title, required String body, required TimeOfDay time})`（实现用 flutter_local_notifications `zonedSchedule`+timezone 需 `timezone` 包与 `tz` 初始化——若包新依赖增加过多，退化为 `periodicallyShow`(daily, 固定时间) 或注释移动端精确 schedule 采用 `zonedSchedule`；由实现者按可用 API 裁定并在报告中说明）。设置页加「记账提醒」行（Key('reminder_entry')）→ Sheet：开关 + 时间选择（showTimePicker）+ 保存（调 scheduleDaily；开启状态存 kv）。
- [ ] **Step 3: 测试** 提醒：注入 fake service 断言 scheduleDaily 被调用（参数 id/title 含「记账」）。无账户：如上。
- [ ] **Step 4: 提交** `feat(bookkeeping): 无账户模式 + 记账每日提醒（复用通知服务）`

---

### Task 3: 流水批量操作

**Files:** `bookkeeping_repository.dart`(M) · `transaction_list_screen.dart`(M) · 测试

- [ ] **Step 1: repo（TDD）** `bulkUpdateCategory(List<int> ids, int? categoryId)`（update where id in ids）、`bulkDelete(List<int> ids)`。测试：批量改分类/删除后计数正确。
- [ ] **Step 2: UI** 流水列表 AppBar 加「选择」按钮（Key('select_mode')）→ 进入多选模式：行左侧 Checkbox（Key('row_check_<id>')）、选中高亮；底部出现操作条（`改分类` Key('bulk_category') → 分类选择 dialog → bulkUpdateCategory；`删除` Key('bulk_delete') → 确认 → bulkDelete；`取消`）；退出选择模式回正常。测试：widget 测试进入选择 → 勾选 2 行 → 改分类 → 数据库断言。
- [ ] **Step 3: 提交** `feat(bookkeeping): 流水批量操作（多选改分类/删除）`

---

### Task 4: 导入逐行确认列表

**Files:** `import_screen.dart`(M) · 测试

- [ ] **Step 1: 预览升级（TDD）** 预览后不再只显示计数，改渲染逐行卡片列表（最大 50 行提示）：每行 = Checkbox（Key('row_ok_<i>')，默认勾选）+ 金额可编辑 TextField（Key('row_amt_<i>')）+ 分类 Dropdown（账本分类，Key('row_cat_<i>')）+ 对方/备注只读小字 + 错误行/退款未匹配区（灰显 + 原因文本）。顶部统计「已勾选 N / 共 M」。
- [ ] **Step 2: 确认逻辑** 确认入库仅导入**勾选且可解析**的行（编辑后的值生效）；保留去重/退款/批次语义。测试：widget 测试——预览 2 行 → 取消勾选第 2 行 → 确认 → 仅 1 行落库；改金额行生效。
- [ ] **Step 3: 提交** `feat(import): 导入逐行确认列表（可编辑/排除/分类映射）`

---

### Task 5: 预算默认值 + 单月覆盖（Veri Fin）

**Files:** `bookkeeping_repository.dart`(M) · `budget_screen.dart`(M) · `budget_setting_sheet.dart`(M) · 测试

- [ ] **Step 1: 默认与覆盖（TDD）** kv：`defaultTotalBudgetCents`、`defaultCatBudgets`（json）；repo 增 `saveDefaultBudget({totalCents, Map<int,int> catCents})/loadDefaultBudget()`。`budgetProgress` 当某月**无预算记录**时回退默认值（仅展示与计算用，不自动写库）；仍在库记录时以库为准（=单月覆盖）。
- [ ] **Step 2: UI** budget_setting_sheet 加两项：`设为默认`（Key('set_default_budget')：把当前月设置值存默认）、`沿用上月预算`（Key('inherit_last_month')：上月 budgets copy 到本月，缺失补 0）。budget_screen 未设置时展示默认值并提示「已使用默认预算」。测试：默认值回退；沿用上月 copy；覆盖优先。
- [ ] **Step 3: 提交** `feat(budget): 预算默认值沿用 + 单月覆盖（Veri Fin）`

---

### Task 6: 发薪日预算周期

**Files:** `formats.dart`(M) · `budget_period_helper.dart`(C) · `bookkeeping_repository.dart`(M) · `budget_setting_sheet.dart`(M) · 测试

- [ ] **Step 1: 周期 helper（TDD）** `budget_period_helper.dart`：`PeriodRange {start, end}`；`periodRangeFor(DateTime now, int periodStartDay)`（起始日 1-28；now 的日期 < startDay 时本期=上月 startDay→本月 startDay-1，否则 本期=本月 startDay→下月 startDay-1）。测试：startDay=22, now=9/12 → 期 8/22..9/21；now=9/25 → 期 9/22..10/21。
- [ ] **Step 2: 接入聚合** `formats.dart`/repo：`monthlySummary`、`categorySpending`、`budgetProgress` 接受可选 `(DateTime start, DateTime end)` 期边界参数（默认自然月兼容既有测试；调用方 balance 页/预算页/小结传 `periodRangeFor(now, kv 起始日)`）；设置页 budget_setting_sheet 加「周期起始日」数字行（Key('period_start_field') 1-28，存 kv `budgetPeriodStartDay` 默认 1）。**范围控制**：本期只把预算页与总览结余卡接入周期边界（统计页/小结保持自然月，后续再统一，以降低回归面）。
- [ ] **Step 3: 提交** `feat(budget): 发薪日预算周期（自定义起始日，预算/总览生效）`

---

### Task 7: 长按 AI 双入口（Veri Fin）

**Files:** `add_transaction_sheet.dart`(M) 或所在入口 · 测试

- [ ] **Step 1: 实现** 「记一笔」FAB 改 `GestureDetector(onTap: 打开记账 Sheet, onLongPress: 打开 AI 弹层)`（FAB 换 `InkWell` 包装或 `FloatingActionButton.extended` 不支持长按 → 自绘 Containder 或用 `LongPressGestureDetector` 包 FAB；由实现者选最简可测方式）。记录提示：SnackBar('长按 = AI 记账')？不加提示避免噪音——在 FAB 下方小字常驻提示（桌面）或省略。测试：widget 测试——tap FAB → 显示「记一笔」Sheet；长按 FAB → 显示 AI 弹层（若弹层需注入 client，测试注入 mock client）。
- [ ] **Step 2: 提交** `feat(ui): 记一笔长按 = AI 记账 双入口`

---

### Task 8: 验收

- [ ] **Step 1: 全量** `flutter analyze && flutter test` → 0 issues；全绿（97 基线 + 各任务新增 ≈ **120+**）
- [ ] **Step 2: 构建** `flutter build windows --debug` → Built；重启 exe
- [ ] **Step 3: 更新 qa_report.md**：新增「三项目优化包」节（8 项状态 + commit）
- [ ] **Step 4: 提交** `docs: 三项目优化包验收记录`

---

## Self-Review 结论

- **覆盖（用户 8 选）**：算式+默认账户 → T1；无账户+提醒 → T2；批量 → T3；导入确认列表 → T4；预算默认/覆盖 → T5；发薪日周期 → T6；长按 AI → T7。
- **占位扫描**：无 TBD；每任务含关键实现与测试要点。T2 的 zonedSchedule 依赖可用性由实现者裁定并注明退化路径；T6 范围控制（预算页/总览接入周期，统计/小结保持自然月）已写明。
- **类型一致性**：`parseArithmeticToCents`(T1)/`periodRangeFor`(T6) 在 formats/helper 定义并与调用方一致；`bulkUpdateCategory/bulkDelete`(T3) repo 定义、UI 调用一致；`scheduleDaily`(T2) service 定义、设置页调用一致；默认账户/默认预算 kv 读写方法命名统一（实现者保持语义一致）。
- 测试计数：T8 预期 ≈120+（以实际为准）。