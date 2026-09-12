# TimeBook 对标源码吸收轮（B1）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development / executing-plans。**硬约束：既有 146 测试全程保持全绿；每任务 TDD 先红后绿。**

**Goal:** 依据 `docs/superpowers/benchmarks/benchmark-study-2026-09-12.md` 吸收参考项目更优实现，本轮做三件：①预算键月周期口径（Veri Fin，零迁移）+ 剩余日均 + 85% 预警 ②番茄钟跳过休息/延长/overtime（SP 状态机）③导入分类兜底「未分类」（Veri Fin）。

**依据文件：**
- 报告：`d:\AIagentWorkSpace\TareWorkSpace\clock\docs\superpowers\benchmarks\benchmark-study-2026-09-12.md`
- 参考源码：`benchmarks\verifin\lib\app\budget_cycle.dart`、`budget_snapshots.dart`、`plan_builder.dart`；`benchmarks\super-productivity\src\app\features\focus-mode\focus-mode.reducer.ts`

---

### Task 1: 预算键月周期 + 剩余日均 + 85% 预警（P0/P1）

**Files:** `budget_period_helper.dart`(M) · `bookkeeping_repository.dart`(M) · `budget_screen.dart`(M) · 测试

- [ ] **1.1 键月函数（TDD）**：`budget_period_helper.dart` 增 `String budgetCycleKeyMonth(DateTime date, int startDay)`——`date.day >= startDay ? 当月 : 上月`（yyyy-MM）。测试：startDay=22：9/12→`2026-08`、9/25→`2026-09`；startDay=1 恒当月。
- [ ] **1.2 接入**：预算页/设置读取预算时，用 `budgetCycleKeyMonth(now, kv 周期起始日)` 替代自然月 `monthKey(now)`（`budgetProgress`/`budgetsForMonth` 的 key 传入处）；`periodRangeFor` 仍用于支出窗口（已实现）；**改起始日零迁移**（键月随起始日所在月，已有覆盖数据原地有效）。预算设置保存时同样用键月写 kv/表——注意设置 Sheet 内「本月预算」语义改为「本期预算」展示（文本小改）。
- [ ] **1.3 剩余日均（TDD）**：`budgetProgress` 返回对象增 `remainingDailyCents`（剩余/含今日剩余天数；过去期→0；剩余<=0→0）。测试补断言。
- [ ] **1.4 85% 预警**：`budgetProgress` 增 `nearLimit`（ratio>=0.85 && <1）派生布尔；预算页副标题两档文案（`已用 85%` 预警色 #C8891A / `超支` error）——现有一档「超支」保留。测试断言。
- [ ] **提交**：`feat(budget): 键月周期口径（零迁移）+ 剩余日均 + 85% 预警（吃 Veri Fin）`

### Task 2: 番茄钟跳过休息 / 延长 / overtime（SP）

**Files:** `focus_timer.dart`(M) · `focus_timer_widget.dart`(M) · `focus_screen.dart`(M) · 测试

- [ ] **2.1 域层（TDD）**：`FocusTimer` 增 `extend(Duration d, {DateTime? now})`（focusing 时 endAt 后移 d；非 focusing 抛 StateError 或忽略——照 SP `adjustRemainingTime`，选忽略+返回 bool）；`skipRest({DateTime? now})`（休息中直接置参与；即 phase=idle 且保留下次 cycle）。测试：extends 后 remainingSeconds 增加；skipRest 后 isFinished/phase==idle。
- [ ] **2.2 Widget**：focusing 主按钮旁加「+5 分」小按钮（Key('focus_extend')，仅 focusing 显示，点击 `_timer.extend(5min)+setState`）；short/long 计时中显示「跳过休息」按钮（Key('skip_break')，点击 `_timer.skipRest()`+`onComplete` 流程按休息完成落库（kind=short/long，duration=已用时长）——`focus_screen` 已有休息完成落库逻辑，复用）。
- [ ] **2.3 Overtime**：专注到 0 后不自动 reset，phase 进新态 `overtime`（FocusTimer 加 TimerPhase.overtime，remaining 归零后 保持 focusing 但 `overdue=true`；`isFinished` 语义不变由 widget 决定）；widget 到时弹「已完成，继续专注？」SnackBar 动作（Key 按钮 `overtime_continue`：`_timer.extend(5min)` 自选）/「完成」走原完成流程。**允许最小化**：若 overtime 态涉及面大，退化为「到 0 后显示『继续 +5 分』按钮 3 秒内可点，否则自动走完成」并报告说明。
- [ ] **提交**：`feat(focus): 延长/跳过休息/overtime（吃 SP 状态机）`

### Task 3: 导入分类兜底「未分类」（Veri Fin plan_builder）

**Files:** `bookkeeping_repository.dart`(M) · `import_service.dart`(M) · 测试

- [ ] **3.1 repo（TDD）**：`ensureCategoryByName(ledgerId, name)` 幂等（存在返回 id，不存在创建 icon='category' sortOrder=999）；测试幂等。
- [ ] **3.2 importRows**：落库时 categoryId 为 null（规则引擎未命中/无分类）→ 用 `ensureCategoryByName(ledgerId, '未分类')` 兜底，**绝不落空**。测试：无规则导入 → 行 categoryId=「未分类」id。既有导入测试若断言 categoryId 为 null 需最小修正并报告。
- [ ] **提交**：`feat(import): 分类兜底「未分类」（吃 Veri Fin plan_builder）`

### Task 4: 验收

- [ ] 全量 `flutter analyze` 0；`flutter test` 全绿（146 基线 + 新增 ≈ 10）
- [ ] `flutter build windows --debug` 成功；重启 exe
- [ ] `qa_report.md` 增「对标吸收 B1」节；提交 `docs: 对标吸收 B1 验收`

## Self-Review

- 覆盖：报告 Top3/P0/P1 中「用户可见且原型无冲突」三项；退款模型重做（独立条目）与提醒 zonedSchedule 因改动面大/依赖重，明确延后（报告里注明）。
- 类型一致：`budgetCycleKeyMonth`（T1）签名在 helper/repo/UI 一致；`extend/skipRest`（T2）域层定义、widget/focus_screen 调用一致；`ensureCategoryByName`（T3）repo 定义、import 调用一致。
- 时间语义：T1 键月用本地时间构造（Veri Fin 原则），半开区间沿用既有 helper。