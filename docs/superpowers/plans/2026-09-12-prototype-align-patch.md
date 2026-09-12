# TimeBook 原型完全对齐补丁 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 逐屏对齐定稿原型（`prototype/Timebook M3 记账原型.html`）剩余差异：①设置页补「账本管理」「关于」②`currentLedger` 全局当前账本接入 ③专注页摘要卡补全（待办完成比 + 番茄数与分钟）④记一笔 Sheet 补日期行。**硬约束：既有 131 测试全程保持全绿。**

**Architecture:** 设置页补两行 + 新建 `ledger_manage_screen.dart` 与 `about_screen.dart`；新增 `currentLedgerProvider`（kv `currentLedgerId` fallback 首账本，`lib/core/kv_settings.dart` 已存在）并把 home/预算/统计/导入/每日小结/导出中「首账本」读取统一替换；专注摘要补今日待办计数与番茄计数（repo 聚合）；记一笔 Sheet 加日期 chip。

**Tech Stack:** Flutter/Dart · flutter_riverpod · drift 2.31 · kv_settings（既有）

---

### Task 1: 设置页补齐 + 两页（账本管理 / 关于）

**Files:** `placeholder_screens.dart`(M) · `ledger_manage_screen.dart`(C) · `about_screen.dart`(C) · kv(M) · 测试

- [ ] **Step 1（TDD）** kv 增 `currentLedgerId` 读写（`KvSettings` 已支持 getInt/setInt——确认后用）。
- [ ] **Step 2** `ledger_manage_screen.dart`（ConsumerWidget）：AppBar「账本管理」；当前账本列表（`ledgers()`，当前项高亮/`当前` tag，Key('ledger_<id>')）；点击行→设为当前（kv setInt + SnackBar）；「+ 新建账本」Key('ledger_add') → 名称输入 Sheet（Key('ledger_name')，Key('ledger_save')）→ createLedger 并设为当前。测试：seeded 两账本 → 点第二行 → kv currentLedgerId==id；新建后列表+1。
- [ ] **Step 3** `about_screen.dart`：版本（package_info_plus 若已依赖则用；否则硬编码 '1.0.0' + 说明）、GitHub 链接（url_launcher 若已依赖；否则文本显示仓库地址）、MIT 说明。测试：渲染 '关于' 与仓库地址文本。
- [ ] **Step 4** 设置页（SettingsScreen）在「导入导出」与「AI 设置」之间插：
  - 账本管理（Key('ledger_entry')，icon wallet，副标题 '多账本 · 当前账本切换 · 新建'）
  - 关于（Key('about_entry')，icon info_outline，副标题 '版本 · 开源许可'）
- [ ] **Step 5** 提交：`feat(settings): 账本管理与关于页（对齐原型）`

---

### Task 2: currentLedger 全局接入

**Files:** `bookkeeping_providers.dart`(M) · home/budget/stats/import/daily/export 读取点(M) · 测试

- [ ] **Step 1（TDD）** `bookkeeping_providers.dart` 增 `currentLedgerProvider = FutureProvider<int?>`：读 kv `currentLedgerId`；无则取 `ledgers().first.id`；均无 → null（并提示先建账本）。
- [ ] **Step 2** 替换「首账本」读取点（各文件里 `ledgers.first.id` 处 → `await ref.read(currentLedgerProvider.future)`；为保既有测试不炸，保留 provider 可 override）：home 结余/最近/预算、budget_screen、stats_screen、import 确认（ImportService 传入 ledgerId 改为 current）、daily 小结、export 导出——**范围控制**：home + budget + stats + export 必改；import/daily 若改动面大可保留首账本并在报告中说明（优先级：home/budget/stats/export）。
- [ ] **Step 3** 测试：kv 设 currentLedgerId=2 → home 显示账本 2 数据；无 kv → fallback 账本 1。
- [ ] **Step 4** 提交：`feat(core): 当前账本全局接入（home/预算/统计/导出）`

---

### Task 3: 专注页摘要卡补全

**Files:** `focus_repository.dart`(M) · `focus_screen.dart`(M) · 测试

- [ ] **Step 1（TDD）** repo 增 `todayPomodoro()` → 今日 focus 会话数（kind=='focus' && !interrupted，当日）；测试：一条会话→1。
- [ ] **Step 2** focus_screen 摘要卡改两列（对齐原型）：
  - 左：`今日待办` → 大号 `{done}/{total}` + 小字 `已完成`
  - 右：`今日专注` → `{n} 🍅 · {minutes} 分钟`
  （done/total 来自 tasks completed/uncompleted 当日统计——用 openTasks/completedTasks 或当日完成数；total 用 open+当日完成。）测试：seeded（1 任务完成 + 1 会话）→ 断言 '1/1' 与 '1 🍅'。
- [ ] **Step 3** 提交：`feat(focus): 专注摘要卡补全（待办完成比 + 番茄数）`

---

### Task 4: 记一笔 Sheet 日期行

**Files:** `add_transaction_sheet.dart`(M) · 测试

- [ ] **Step 1（TDD）** Sheet 账户 chips 行下加日期 chip：`今天 HH:mm`（DateTime.now 格式化，Key('book_at_chip')，只读展示——原型为可点选日期，本轮做只读展示+后续扩展）。测试：显示 `今天` 前缀文本。
- [ ] **Step 2** 提交：`feat(bookkeeping): 记一笔日期行（今天 HH:mm 对齐原型）`

---

### Task 5: 验收

- [ ] 全量 `flutter analyze && flutter test`（131 基线 + 新增 ≈ 138+）0 问题
- [ ] `flutter build windows --debug` 成功；重启 exe
- [ ] 打开原型 HTML 与新版 exe 逐屏对照（设置页四项全齐/专注摘要/记一笔日期），截图复核
- [ ] 提交：`docs: 原型对齐补丁验收（qa_report 增补）`

---

## Self-Review

- 覆盖：①④对齐原型硬差异；③摘要补全；②为「账本管理」落地语义（切换生效）。范围控制：import/daily 若改动面大保留首账本并在报告说明；日期 chip 只读（点选后置）。
- 类型：currentLedgerProvider 定义（T2）被各页消费一致；todayPomodoro（T3）签名一致。
- 测试计数：T5 预期 ≈138+。