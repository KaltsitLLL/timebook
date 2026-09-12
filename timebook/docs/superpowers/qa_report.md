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

## 四、结论

- 核心记账/专注/导入/统计的金额一致性（按分 + 退款净额）贯穿正确，生命周期（Timer/dispose/IndexedStack 保活）无误。
- 发现并修复 2 处明确 bug（AI 确认页金额校验、休息误记 focus），均以 TDD 完成并单独 commit；analyze/test 保持全绿。
- 主要 ⚠️：周期记账未接线 UI、月末推进边界、首页负余显示、微信退款单号匹配、FutureBuilder 错误态（均为设计取舍/待确认项，未擅自改动）。