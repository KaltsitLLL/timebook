# 时账 TimeBook · 三项目源码精读报告（更优实现清单）

> 日期：2026-09-12
> 方法：三个目标仓库均 `git clone --depth 1` 到 `d:\AIagentWorkSpace\TareWorkSpace\benchmarks`，逐功能精读源码。
> 对比基线：`timebook/`（Flutter + Riverpod + Drift，见 `docs/superpowers/specs/2026-09-12-timebook-design.md` 与 `docs/superpowers/plans/2026-09-12-benchmark-optimization.md`）。
> 结论方向：三项目的「预算 / 退款 / 番茄钟状态机」三处设计显著优于 timebook 当前/计划实现，建议优先吸收。

---

## 0. 仓库落位与获取方式

| 仓库 | 克隆路径 | 技术栈 | 关键目录 |
|---|---|---|---|
| **Veri Fin**（LumiDesk/verifin） | `benchmarks\verifin` | Flutter + sqflite（手写 SQL 迁移，非 Drift），自研 ChangeNotifier/InheritedNotifier 状态 | `lib\data\app_database.dart`（schema+迁移）、`lib\app\models\`（领域模型）、`lib\app\backup\import\`（导入）、`lib\app\budget_cycle.dart`+`lib\pages\budget_pages.dart`（预算）、`lib\app\ledger_math.dart`（金额/日期）、`lib\app\reminder\`（提醒） |
| **Super Productivity**（johannesjo/super-productivity） | `benchmarks\super-productivity` | TypeScript + Angular + NgRx（Web/Electron） | `src\app\features\focus-mode\`（番茄钟）、`src\app\features\reminder\`（提醒）、`src\app\imex\`（导入导出/同步）、`src\app\features\metric\`（统计） |
| **BeeCount 蜜蜂记账**（TNT-Likely/BeeCount） | `benchmarks\beecount` | Flutter + Riverpod + Drift（同栈） | `lib\data\db.dart`（Drift 表）、`lib\data\repositories\local\`（DAO）、`lib\utils\month_range.dart`（周期）、`lib\cloud\sync\`（增量同步）、`lib\widgets\charts\`（图表） |

> 注：任务原始候选 `redpeppertech/veri-fin` 已 404，正主为 `LumiDesk/verifin`（已克隆）；`beecount` 正主为 `TNT-Likely/BeeCount`（Flutter 记账，已克隆），未降级到 beancount CLI 工具链。

---

## 1. 更优实现清单

### 1.1 预算（精读重点 01）

| 功能 | timebook 现状 | 参考实现（仓库文件+行） | 建议落地方案 | 优先级 |
|---|---|---|---|---|
| 预算「默认值 + 单期覆盖」两层模型 | 计划 Task5 才加 `defaultTotalBudgetCents` kv + `budgets` 表覆盖，尚未定型 | Veri Fin：默认值全存 KV，覆盖才写库，库表用 `scope_key` 主键——`monthly_budgets/category_budgets/daily_budgets`（`app_database.dart:565-576`），`daily_budgets` 键 `bookId:yyyy-MM-dd`（`:408-413`） | `budgets` 表改为「键主键 + 金额」，默认值走 `settings` kv（`defaultBudgetCents`/`defaultCategoryBudget_{id}`）；`budgetProgress()` 当日月无库记录时回退默认（Task5 已含此意，照 Veri Fin 固化：覆盖优先、默认兜底、不自动写库） | P0 |
| 发薪日预算周期 | Task6 计划 `budget_period_helper.dart` | **Veri Fin `budget_cycle.dart:15-43`**：startDay 1–28，键月 =「周期起始日所在月」，`budgetCycleKeyMonthFor` 用 `date.day >= startDay ? 当月 : 上月`；改起始日**零迁移**（各键月金额原地有效）。BeeCount `month_range.dart:19-57` 同思路，统一**半开区间 `[start,end)`** | 周期纯函数落在共享 helper，键月机制照抄（比 timebook 计划的 `periodRangeFor` 更进一步：以「起始日所在月」做存储键，改口径不搬数据）；**只让预算页/总览按周期取数，统计页保持自然月**（Veri Fin `budget_cycle.dart:10-11` 明确同一原则） | P0 |
| 超支预警阈值与排序 | 无（仅「超支提醒」泛化表述） | Veri Fin `budget_snapshots.dart:68-94`：`nearLimit = ratio>=0.85`、`overBudget`、`needsAttention`；排序 rank `:229-243`（超支>近限>有预算>有花费>无） | `CategoryBudgetSnapshot` 增加 `ratio/nearLimit/needsAttention` 派生字段；预算卡片「85% / 超支」两档文案（对应 `budget_pages.dart:44-53` 的 `_budgetInsight`） | P1 |
| 剩余日均 | 无 | Veri Fin `budget_pages.dart:95-105`：`remaining / remainingDays`（含今天），过去月=0，剩余<=0 时=0 | 预算页加「剩余日均」指标块，公式照搬 | P1 |
| 分类预算父子聚合 | 分类父子两级已建模，聚合口径未定义 | Veri Fin `budget_snapshots.dart:143-195`：每笔支出往 `categoryId + 所有祖先` 累加（`accumulate`+`ancestorIds`），分类索引只建一次；BeeCount `local_budget_repository.dart:193-204` 用 `LEFT JOIN categories ON (t.category_id=? OR c.parent_id=?)` SQL 端聚合 | 父分类预算 = 自身 + 子分类支出；优先 SQL 端（Drift join）聚合，避免逐行 ancestor 展开 | P1 |
| 预算设置草稿/防丢 | 覆盖/默认直接写 | Veri Fin `budget_settings_page.dart:337-371`：局部 draft + `_isDirty` 脏检测 + `UnsavedChangesGuard` 离开确认 | 预算设置页改草稿态，离开页面前提示未保存 | P2 |

### 1.2 收付款 / 交易

| 功能 | timebook 现状 | 参考实现 | 建议落地方案 | 优先级 |
|---|---|---|---|---|
| **退款模型（独立退款条目 + 派生净额）** | `transactions.refunded_cents` 直接改原行，无「待到账/退到不同账户」概念 | Veri Fin `ledger_entry.dart:9-18,146-158`：退款是独立 `EntryType.refund`（`refund_of` 指原支出、`settled_at`=到账日，NULL=待到账）；`refundedBaseAmount` 是**派生缓存**由 `_syncRefundData()` 重算；净额 `netBaseAmount = clamp(0, baseAmount)` 防负（`:151-158`）；账户余额「支出扣全额 + 退款条目入到账账户」（`ledger_math.dart:28-52`），**天然支持部分退款/退不同账户** | v1 保留 `refunded_cents` 冲抵原行；预留独立退款条目（`refund_of`/`settled_at`）以支持「待到账退款」与「退到另一账户」；统计一律读净额并 clamp 防负 | P1 · **已吸收（B2：退款独立条目）** |
| 账户匹配去重规则（导入/自动分类） | 计划 `import_rules`（keyword→category）；账户匹配未定义 | Veri Fin `plan_builder.dart:108-152`：账户按「**去空格名 + 币种**」匹配，恰好一个同名才复用，多个同名**不猜归属**→交用户映射；`resolveCategory` 按归一化名（容忍大小写/空白/全半角）且**同一父级下**才复用（`:197-244`） | 自动分类/导入映射的匹配键统一为「归一化名 + 归属范围」，模糊不猜；多候选进人工映射区 | P1 |
| 搜索/过滤 | 无系统化搜索（Task 未覆盖） | Veri Fin `transactions_pages.dart:147-205,156,274-280`：搜索**220ms debounce**、`_filterSignature` 派生缓存避免重复过滤、时间过滤器（月/季/年/近30天/近6周）+ 报销过滤器 + 排序 | 流水页加搜索框（debounce）+ 时间/方向/账户/分类过滤器，过滤签名缓存 | P2 |
| 批量操作 | Task3 计划多选改分类/删除 | Veri Fin 无专门批量，但 BeeCount `LocalChanges` 操作日志模式（见 1.7） | 维持 Task3；批量改分类/删除走单事务 | P1 |

### 1.3 导入 / 导出

| 功能 | timebook 现状 | 参考实现 | 建议落地方案 | 优先级 |
|---|---|---|---|---|
| 三层导入管道（Parser → 强类型记录 → 统一落库） | 已「来源适配 + 统一 NormalizedTransaction + 规范化管道」，接近 Veri Fin | **Veri Fin `raw_import.dart:18-42`**：`RawImportRecord` 字段直接是领域值（date/amount/type 已解析），**禁止「类型→字符串→类型」往返**（注释点名这是历史 bug 温床）；`plan_builder.dart:76-75` 唯一共享落库生成器 | 保持现有；确认 `NormalizedTransaction` 只承载强类型值，字符串 decode 只停在 parser 层 | P2（对齐确认） |
| 逐行错误 + 兜底「未分类」 | 有错误行清单 | Veri Fin `plan_builder.dart:161-192`：空/缺失分类兜底到固定 id「未分类」，**绝不落空 categoryId**（空 id 会变「已删除分类」且无法筛选） | 导入管道对缺失分类强制兜底分类，不留空 categoryId | P1 |
| 退款导入 | `refunded_cents` 更新原行 | Veri Fin `plan_builder.dart:597-654`：退款钳到 `[0,amount]`，按比例生成独立退款条目，`refundOf` 指向原支出 | 与 1.2 退款模型联动 | P2 |
| 备份格式与校验 | 无备份（未来扩展池） | Veri Fin `backup_service.dart:204-222`：写后**立即回读逐字节比对**，防「写坏却以为成功」（`BackupVerificationException`）；`:236-245` 自动备份按保留份数清理；zip 存附件不膨胀 | 未来 JSON 备份：写后回读校验 + 版本字段 + 保留份数清理 | P2 |
| 冲突处理（rev / changedSince） | 无同步 | SP `sync\sync.model.ts:37-44,54-62,83`：主文件带 `archiveRev`（云端版本标识字符串）+ `lastLocalSyncModelChange`；每 provider 独立 `rev/revTaskArchive/lastSync`；冲突三选 `USE_LOCAL/USE_REMOTE/取消`；BeeCount `LocalChanges`+`SyncState.cursor`（LWW，见 1.7） | 未来云同步：实体带 `syncId(UUID)` + `rev`/`cursor`，冲突默认 LWW + 少数人工二选 | P2 |

### 1.4 番茄钟 / 专注（SP 核心，精读重点 04）

| 功能 | timebook 现状 | 参考实现 | 建议落地方案 | 优先级 |
|---|---|---|---|---|
| 计时状态机（暂停/恢复） | `idle→focusing→paused`，绝对时间戳 `endAt`（已正确） | **SP `focus-mode.model.ts:1-9`**：`TimerState { isRunning, startedAt(绝对), elapsed, duration, purpose:'work'|'break', isLongBreak }`；**_暂停保留 elapsed，恢复重建 `startedAt = now - elapsed`_**（`reducer.ts:156-174`），等价但语义更清晰；`getBreakCycle = max(cycle-1,1)` 修 cycle 偏移（`model.ts:80-81`） | timebook `endAt` 已对；补 `elapsed` 累积字段使暂停/恢复/被杀恢复共用同一套 `startedAt - elapsed` 推算，避免 endAt 与 elapsed 双源不一致 | P0 |
| 三模式 + 策略接口 | 仅固定专注/短休/长休 | SP `model.ts:24-28,56-61`：`FocusModeMode = Flowtime|Pomodoro|Countdown`，`FocusModeStrategy`（初始时长/是否自动接休息/是否自动开始下一段/按 cycle 给休息） | 引出策略接口，未来 Flowtime（无限时）零改动接入 | P2 |
| **跳过/延长休息 + overtime** | 仅「4 个番茄建议长休，跳过不阻塞」 | SP `reducer.ts:240-246`（skipBreak/completeBreak 共路）、`:322-349`（`adjustRemainingTime` 改 goal 时长加/减剩余）、`:219-222`（`setOvertimeEnabled`，超时继续计时） | 增加「跳过休息」「休息延长」「专注到时后可选继续（overtime）」动作，纯 reducer 层加标志位 | P1 |
| 空闲检测暂停 | 无 | SP `idle.service.ts` + `effects.ts:723-731`：检测空闲 → 弹 idle 对话框 → 自动 `pauseFocusSession` | 桌面端接入空闲检测，空闲即暂停并保留 elapsed | P2 |
| 会话完成日志 & 任务联动 | `pomodoro_sessions` 记 start/end/duration/interrupted | SP `effects.ts:733-747`：每一次完成经 `logFocusSession` 写 metric；任务追踪（time-tracking）与番茄钟**双向同步**：开始会话→开始追踪、暂停→停追踪、休息结束→恢复追踪（`effects.ts:154-232`） | 完成会话即落 `pomodoro_sessions` 并触发今日小结聚合；任务绑定解绑走统一 action | P1 |
| 移动端前台服务恢复 | 后台/被杀已计划补偿 | SP `reducer.ts:356-400`：Android 前台服务为真相源，`restoreFocusSessionFromNative(durationMs, remainingMs, isBreak, isPaused)` 重建绝对 `startedAt`，按 duration 推断 Flowtime，**不强制弹全屏** | 若做移动端前台服务，恢复入口照此「native 为真相源」重建时间基准 | P2 |

### 1.5 提醒 / 通知

| 功能 | timebook 现状 | 参考实现 | 建议落地方案 | 优先级 |
|---|---|---|---|---|
| 每日记账提醒模型 | Task2 计划 `scheduleDaily`（未定义数据结构） | **Veri Fin `reminder_settings.dart:5-43`**：`ReminderSettings { enabled, hour, minute }` 存 KV、不进备份；`nextFireTime` 顺延用「**日历日 +1 按日构造**」而非 `add(Duration(days:1))`，规避 DST 使提醒偏移 1h（`:37-43`） | 提醒配置存 kv（enabled/hour/minute），下一次触发时间用日历日构造；hour/minute `clamp` 防脏值 | P0 |
| 提醒调度器 | 直接 `zonedSchedule` | SP `reminder.worker.ts:7,45-50`：Web Worker **10s 轮询**，`getDueReminders` 过滤 `remindAt < now` 排序；UI 层 `reminder.service.ts:25` 用「taskId+remindAt」occurrence 键做 **5min dismiss 冷却**防模态框反复抢屏 | Flutter 侧无需 worker；但吸收「dismiss 冷却按 occurrence 键控」避免提醒重发轰炸；`nextFireTime` + 单次 `zonedSchedule` 落库记录已触发 | P2 |

### 1.6 统计可视化

| 功能 | timebook 现状 | 参考实现 | 建议落地方案 | 优先级 |
|---|---|---|---|---|
| SQL 端聚合（避免全量遍历） | 未明确（M2 fl_chart） | BeeCount `local_statistics_repository.dart:285-311,327-357`：`SUM(CASE WHEN type='income'…)` 单次 SQL 出收支合计；分类聚合 `LEFT JOIN categories` + 子类 `OR c.parent_id=?`；Veri Fin 分类快照「一次遍历按键月分桶 + 父类聚合」 | 统计走 Drift `customSelect` SQL 聚合，少全表拉回 Dart 累加 | P1 |
| 图表类型选择 | 饼/柱/趋势 | Veri Fin `reports/` + `budget_trend_chart.dart`（近 6 月预算执行趋势）、`ledger_math.dart:133-174`（累积展开趋势窗口、周/月/季/年窗口）、`:232-255`（稀疏日期标签防挤） | 「近 N 月趋势」取模版；日期窗口纯函数进 `core/util`，图表标签稀疏化 | P2 |
| 统计口径（净额/排除标志） | 退款冲抵按净额 | BeeCount `db.dart:138-145`：**`excludeFromStats` 与 `excludeFromBudget` 两个独立布尔**（不进统计 vs 不进预算，可分别勾选）；统计读 `COALESCE(native_amount, amount)` | 交易表加可选 `exclude_from_stats/exclude_from_budget` 标志，统计/预算各自过滤 | P2 |

### 1.7 数据一致性

| 功能 | timebook 现状 | 参考实现 | 建议落地方案 | 优先级 |
|---|---|---|---|---|
| 金额存储 | `amount_cents` 整数「分」（**优于**两仓库的 REAL 浮点，保持） | 反例：Veri Fin/BeeCount 均 `REAL`，靠 `normalizeCurrencyAmount` 归整消浮点残差（`ledger_math.dart:98-100`） | 维持 amount_cents；若未来多币种，吸收 BeeCount「`currencyCode` + `nativeAmount`（折算本位币快照，保存即定）」思路预留，不作 v1 | P2 |
| 时区/日期 | Drift DateTimeColumn | Veri Fin 时间统一存**毫秒时间戳**（`occurred_at INTEGER`，`app_database.dart:488-524`）；所有日期窗口「按日构造」避 DST（`ledger_math.dart:108-116`、`budget_cycle.dart:31-33`）；BeeCount `month_range.dart:29` 明确「传 UTC 会错一天，用本地时间」 | 存储统一 epoch（毫秒）排序/区间安全；日期边界统一半开区间 + 本地时间语义，杜绝 DST 偏移 | P1 |
| 分类唯一性约束 | 未建唯一索引 | Veri Fin `app_database.dart:403-406`：`UNIQUE(label, type, IFNULL(parent_id,''))`，迁移**先去重再建索引**（`:165-172,353-401` 去重合并幽灵分类） | 分类表加唯一索引（ledger_id+parent_id+归一化名），迁移先去重 | P1 |
| 迁移策略 | Drift 自动迁移 | Veri Fin `app_database.dart:55-93`：**逐版本迁移注册表 + 升序执行 + 缺失段立即抛错**（不静默跳过）；`_schemaCurrent` 冻结完整建表；迁移矩阵测试推进到任意中间版本 | Drift 自动迁移为主；对无法表达的数据清洗（去重、回填字段）留显式 `onUpgrade` 步骤并配中间版本测试 | P1 |
| 离线操作日志/增量同步 | 无同步 | BeeCount `LocalChanges`（`db.dart:279-289`：entityType/entitySyncId/action/payloadJson/pushedAt）+ `SyncState.cursor`；`SyncPullErrors`（`:327-345`）持久化 pull 失败供重试/诊断 | 未来同步基建：本地 CRUD 记 `LocalChanges` 增量，实体带 `syncId`；失败持久化可重试 | P2 |

---

## 2. 结论（值得立即做的 Top 3）

1. **预算「默认值(KV) + 键月覆盖 + 发薪日周期」** —— 照抄 Veri Fin `budget_cycle.dart` 的「键月=起始日所在月、改口径零迁移」，并落「默认值回退、覆盖优先」的两层模型；这直接定档 Task5/Task6 的数据结构，避免返工。
2. **退款改「独立退款条目 + 派生净额」** —— Veri Fin 的 `refund_of`/`settled_at` + `netBaseAmount = clamp(0, baseAmount)` 比 timebook 的 `refunded_cents` 原地改行更能覆盖「部分退款 / 退到不同账户 / 待到账退款」，统计口径更稳。
3. **番茄钟状态机补「elapsed 累积 + startedAt 重建」与 skip/overtime/idle** —— SP 的暂停恢复、跳过休息、空闲暂停、完成日志已经过大量 bug-fix（reducer 内多处 `#5995/#7855` 注释），timebook 的绝对时间戳方向正确，补齐该细分状态机即可达到同等健壮度。

> 附注：timebook 的 `amount_cents`（分整数）优于三仓库的浮点方案，是既有优势，无需改动；上文仅取其「多币种/净额」思路作未来预留。