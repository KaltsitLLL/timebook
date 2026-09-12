# 时账 TimeBook — 全功能 QA 自检报告

日期：2026-09-12
基线：`flutter analyze` 0 issue · `flutter test` 73 全绿（自检前）

核实方式：逐功能域读 `lib/features/*` + `test/features/*` 源码核对，重点查接线/状态/类型/生命周期/数据一致性。

---

## 一、逐功能状态表

| 功能域 | 关键文件 | 状态 | 说明 |
|---|---|---|---|
| **bookkeeping 记账** | `bookkeeping_repository.dart` / `add_transaction_sheet.dart` | ✅ | 金额全链路按「分」存储；增/查/删 CRUD 接线正常；FAB「记一笔」可达 |
| 金额/退款净额 | `monthlySummary`/`categorySpending`/`budgetProgress`/`dailySummaryService` | ✅ | 统计、预算、总览、每日小结、最近流水均以 `amountCents - refundedCents` 计算净额，退款冲抵贯穿所有生效口径 |
| 预算 | `budget_screen.dart` / `budget_setting_sheet.dart` | ✅ | upsert/删除/进度/剩余日均/超支标记正常；设置 Sheet 可达 |
| 统计页 | `stats_screen.dart` / `category_donut.dart` | ✅ | 6 月柱状 + 本月分类环形 + 排行；空态/图例/Top4 正常 |
| 流水列表 | `transaction_list_screen.dart` | ✅ | 全部/本月/上月筛选、空态正常；→导入入口可达 |
| 导出 CSV | `exportCsv` | ✅ | 表头含净额列、字段转义（逗号/引号/换行）正确 |
| **focus 专注** | `focus_screen.dart` / `focus_timer_widget.dart` | ✅ | 三模式绝对时间戳番茄钟、四象限、短语法、任务绑定、完成确认、时间线、每日小结均接线；Timer 在 dispose cancel，AppShell 用 IndexedStack 保活 |
| **import 导入** | `csv_parser` / `template_engine` / `import_service` | ✅ | CSV 状态机、YAML 模板（错误行显式 collect）、去重/退款/批次留痕/事务、file_picker + UTF-8/GBK 自识别、粘贴导入均正常 |
| 周期记账 | `recurring_service.dart` | ⚠️ | 领域服务+单测存在，但**未接线到任何 UI/provider**（无调用方），UI 不可触达 |
| **ai 对话记账** | `glm_chat_client` / `confirm_screen` / `ai_settings_screen` | ✅ | 可注入 client、确认页、secure storage 设置均可达 |
| **core 主题/壳/工具** | `app_theme` / `app_shell` / `formats` | ✅ | 蓝白/暗色、Rail/Bar 响应式、formats 工具正确 |

---

## 二、问题清单

### 已修复（明确 bug，TDD：先红→修→绿）

| 严重度 | 域 | 问题 | 修复 | commit |
|---|---|---|---|---|
| 重要 | ai | `ConfirmScreen._save` 用 `double.parse(_amount).round()` 作校验，**金额 <0.5 元被 round 为 0 而拒收**（如 0.40 元），且对非法金额可入账 | 改为按分校验：`parsed == null \|\| parsed <= 0` 才拒，`amountCents = (parsed*100).round()` | `a527652` |
| 重要 | focus | **短/长休结束误记 focus 会话**：`onComplete` 不带模式，休息结束同样弹「专注完成」对话框，且按 `focusMinutes` 记录 `kind=focus`（污染今日专注分钟/每日小结） | `onComplete` 传入完成时的 `TimerMode`，休息直接按 `short/long` + 各自时长落库、不弹确认框 | `0f685eb` |
| 次要 | focus | 修复引入的 `use_build_context_synchronously` info（异步后未守卫 context） | `showDialog` 前加 `if (!mounted) return;` | `e460651` |

### 遗留 ⚠️（不确定/不擅自改，供后续评估）

1. **周期记账未接线 UI**（import 域）：`RecurringService.generateDue` 无任何 UI/Provider 调用，功能不可达（即便入库也无人触发）。建议补一个后台/设置入口。
2. **周期推进的月末溢出**（recurring）：`DateTime(base.year, base.month+1, rt.dayOfMonth)` 当 `dayOfMonth=31` 且进入 30 天月/2 月时溢出到次月（如 1-31 → 3-3），nextRun 会漂移。属边界设计取舍（应 clamp 到月末 vs 沿用溢出），不擅自改。
3. **home_screen 预算副标题可显示负值**：超支时 `剩 ¥ ${totalBudget - totalSpent}` 为负数（budgetProgress 内部已 clamp 0，但 home 显示处未 clamp），纯展示问题。
4. **微信退款单号匹配可能落空**：`_applyRefund` 仅匹配 `-REFUND` 后缀单号；微信反 退款行持独立「交易单号」，异型号退款大概率进 `refundUnmatched`。数据建模取舍，未确认微信单号格式前不动。
5. **FutureBuilder 无显式错误态**：各页 `snap.hasError` 未分支，data 拉取异常会停在 loading（不死锁但无提示）。当前数据源不易抛错，属健壮性增强。

---

## 三、测试覆盖统计

总数 **75**（基线 73 + 本次新增 2），`flutter analyze` 0 issue，`flutter test` 全绿。

| 域 | 用例数 | 覆盖点 |
|---|---|---|
| bookkeeping | 28 | 记账/净额/月度趋势/预算/导出/退款冲抵/总览/统计/流水筛选/环形/设置页 |
| focus | 15 | 计时器绝对时间戳/暂停/完成、短语法、四象限、专注页、休息会话（新增 1） |
| import | 15 | CSV 解析/编解码/模板/去重/退款/批次/粘导入/周期 |
| ai | 10 | GLM 解析与异常、对话流、确认页金额（新增 1）、设置 store |
| daily | 3 | 小结聚合/历史 |
| core | 4 | formats、DB 迁移 |

缺口：周期记账 30/31 天边界、FutureBuilder 错误态、home 负余显示 —— 均无测试（对应 ⚠️ 项）。

---

## 五、后续功能包（2026-09-12 追加）

| 功能 | 状态 | 说明 | commit |
|---|---|---|---|
| 周期记账 UI | ✅（关闭 ⚠️1） | 设置页「周期记账」入口 → 规则管理页（新增/启停/删除）→ `runDue` 自动生成待确认流水 → 流水行「待确认」徽标 | `dc6392a` |
| nextRun 月末边界 | ✅（关闭 ⚠️2） | dayOfMonth≥28 时推进到下月最后一天（2026-01-31 → 2026-02-28），测试覆盖 | `dc6392a` |
| 番茄完成通知 | ✅ | `NotificationService` 可注入抽象 + flutter_local_notifications；完成/休息结束触发（fake 时钟 + Fake service 断言） | `3350bfb` |
| 规则引擎自动分类 | ✅ | `RuleClassifier` 纯函数 + importRules CRUD + 规则管理页 + 导入落库自动应用（仅 categoryId 为空时） | `76e8905` |
| 本周专注热力图 | ✅ | 近 7 日色块（分钟数 + 星期标签），专注页「本周专注」卡 | `5eef085` |
| Flowtime 模式 | ✅ | TimerMode.flowtime 不自动结束、实际时长落库、chips 增「流式」 | `e39cbca` |

### 遗留 ⚠️（本轮不动，低优先）
- home 预算副标题超支显示负值（纯展示）
- 微信退款独立单号匹配可能落空（待微信单号格式确认）
- FutureBuilder 无显式错误态（健壮性增强）

### 最终质量（本轮验收）
- `flutter analyze`：0 issue
- `flutter test`：**97 全绿**（基线 75 → QA 修复 75 → 后续功能 +22）

- 核心记账/专注/导入/统计的金额一致性（按分 + 退款净额）贯穿正确，生命周期（Timer/dispose/IndexedStack 保活）无误。
- 发现并修复 2 处明确 bug（AI 确认页金额校验、休息误记 focus），均以 TDD 完成并单独 commit；analyze/test 保持全绿。
- 主要 ⚠️：周期记账未接线 UI、月末推进边界、首页负余显示、微信退款单号匹配、FutureBuilder 错误态（均为设计取舍/待确认项，未擅自改动）。

---

## 六、三项目优化包（2026-09-12 追加，对标 BeeCount/Veri Fin/Super Productivity）

| 优化项 | 状态 | commit |
|---|---|---|
| 记一笔算式解析（`500+800` 实时预览）+ 默认付款账户 | ✅ | `517673e` |
| 无账户模式（「不记账户」系统账户）+ 记账每日提醒（scheduleDaily 退化为 periodicallyShow） | ✅ | `bc03b78` |
| 流水批量操作（多选改分类/删除） | ✅ | `1462650` |
| 导入逐行确认列表（勾选/金额编辑/分类映射/错误灰显） | ✅ | `ae0aeb1` |
| 预算默认值沿用 + 单月覆盖（设为默认/沿用上月） | ✅ | `1382a83` |
| 发薪日预算周期（periodStartDay kv；预算页+结余卡接入，统计/小结保持自然月） | ✅ | `39ea715` |
| 记一笔 FAB：点击=手动、长按=AI（openAiDialog 可注入） | ✅ | `e5b302c` |

**本轮验收**：`flutter analyze` 0 issue · `flutter test` **131 全绿**（97 基线 + 优化 34）

---

## 七、原型完全对齐补丁（2026-09-12）

| 差异项 | 状态 | commit |
|---|---|---|
| 设置页「账本管理」（切换/新建/当前标记） | ✅ | `37d99b1` |
| 设置页「关于」（版本/仓库/MIT） | ✅ | `37d99b1` |
| currentLedger 全局接入（home/预算/统计/导出；import 落库仍首账本，注明） | ✅ | `95a98fd` |
| 专注摘要卡补全（今日待办 n/m + n 🍅 · m 分钟） | ✅ | `0f514ad` |
| 记一笔日期行「今天 HH:mm」（只读） | ✅ | `ca93a0f` |

**本轮验收**：`flutter analyze` 0 issue · `flutter test` **140 全绿**（131 基线 + 9）

---

## 八、对标源码吸收轮 B1（2026-09-12，精读 Veri Fin/SP/BeeCount 源码）

- 精读报告：[`docs/superpowers/benchmarks/benchmark-study-2026-09-12.md`](../../../docs/superpowers/benchmarks/benchmark-study-2026-09-12.md)（三仓库已克隆至 `benchmarks/`）

| 吸收项 | 来源 | commit |
|---|---|---|
| 预算键月周期口径（键月=起始日所在月，改起始日零迁移）+ 剩余日均 + 85% 预警 | Veri Fin budget_cycle/budget_snapshots | `91f11d5` |
| 番茄延长（+5 分）/跳过休息/到时 3s「继续专注」overtime | SP focus-mode.reducer | `67fb8ba` |
| 导入分类兜底「未分类」（绝不落空 categoryId） | Veri Fin plan_builder | `a0ee3a3` |
| 记账 Sheet 测试视口修正（顺序调整后折叠区用例） | — | `41d179c` |

**本轮验收**：`flutter analyze` 0 issue · `flutter test` **163 全绿**（146 基线 + 17）

**延后项**（报告已记，改动面大/依赖重）：退款独立条目模型重做、提醒 zonedSchedule 精确时点、批量/搜索筛选器、分类唯一索引迁移、同步基建。

---

## 九、B2 退款独立条目（2026-09-12，吃 Veri Fin）

- 计划：[`2026-09-12-refund-model-b2.md`](../../../docs/superpowers/plans/2026-09-12-refund-model-b2.md)
- 依据：benchmark §1.2 已标记「已吸收」。

| 项 | 状态 | commit |
|---|---|---|
| 新增 `refund_entries` 表（唯一事实来源：`refundOf`→transactionId、`amountCents`、`settled_at` 可空=待到账、`account_id` 收款账户、`book_at`、`import_key`）+ `transactions.refunded_cents` 派生缓存（`syncRefundData` clamp 到 `[0, amountCents]`） | ✅ | `2ea0fa7` |
| 导入退款改走独立条目：`-REFUND` 单号匹配 → 建条目并同步缓存；单号悬空走「金额相等 + 方向相反 + ≤7 天 + 唯一候选」启发；同账本同单号幂等不重复建条目；未命中仍进 `refundUnmatched` | ✅ | `8abcdfb` |
| 验收报告本节 + benchmark §1.2 标记 | ✅ | 本提交 |

**本轮验收**：`flutter analyze` 0 issue · `flutter test` **169 全绿**（163 基线 + 6）

**限制说明**：
- **账户余额联动未做**：退款条目保留 `account_id` 字段与 `settled_at`，但当前无账户余额计算，「退到不同账户」不驱动余额（仅派生净额缓存）。
- **无新 UI**：退款条目仅为数据层落地，无查看/编辑入口。
- **脏值迁移未做**：历史 `refunded_cents` 标量未反向合成退款条目（无真实历史数据量可迁，缓存仍按现算法 clamp 防负）。