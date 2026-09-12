# 时账 TimeBook · 设计文档

> 日期：2026-09-12
> 状态：已与用户逐部分确认（总体架构 / 数据模型 / 里程碑 / 账单导入 / 待办·番茄钟 UI 交互 / M3 记账 UI 原型）
> 关联原型：[Timebook M3 记账原型.html](../../../prototype/Timebook%20M3%20记账原型.html)

---

## 1. 背景与目标

为**研究生入学复试面试**打造一个完全自研、可完整演示、可开源的个人项目，同时这个项目也是**自己日常真实使用**的工具。

- 定位：全平台「记账 + 预算 + AI 记账 + 待办 + 番茄钟」一体化应用
- 原则：**从零编写**（代码 100% 自研，不携带任何第三方仓库代码；可在面试时公开 commit 历史作为证据）
- 关键约束：**必须包含 AI 记账（含 OCR）**，这是用户自用的刚需，也是选择高星项目调研的原因
- 扩展性：未来可随时「新增自己喜欢的功能」，架构必须支持按 feature 即插即用

### 决策记录（为什么从零，而不是以 BeeCount 为基座）

| 维度 | 结论 |
|---|---|
| 技术栈差异 | Super Productivity（Angular/Electron）与 BeeCount（Flutter）无法代码级合并，只能统一框架重建 |
| 许可证 | BeeCount 开源 + 商业授权 + CLA，商用受限；从零写彻底规避 |
| 面试价值 | 面试官问"这是你写的吗"时，fork 基座会露馅并减分；自研代码、架构决策、错误处理才是加分项 |
| 扩展性 | BeeCount 纵向围绕记账设计，硬塞新领域会和架构打架；从零 + feature 模块化天然支持未来扩展 |

### 复刻范围的诚实修正

"完美复刻 BeeCount 且不出错"不成立（任何软件皆然，含原版 102 个 open issues）。目标定义为：**功能对标 + 覆盖个人使用 90% 场景 + 识别结果人工确认兜底**。OCR/账单识别的准确性由"识别 → 解析 → 确认 → 入库"流程兜底，而不是追求绝对正确。

---

## 2. 产品形态与技术栈

- 名称：时账 TimeBook（占位名，可在规格定稿时替换）
- 形态：手机（Android/iOS 优先）+ 桌面（Windows/macOS），PWA 可选
- 语言：Flutter + Dart（复用调研结论：Flutter 是唯一能一套代码覆盖全平台的候选）

| 领域 | 选型 | 理由 |
|---|---|---|
| 状态管理 | Riverpod 2.x | BeeCount 同栈、可测性强、无代码耦合 |
| 数据库 | Drift (SQLite) | 本地优先、类型安全、支持迁移与索引 |
| 图表 | fl_chart | 流水/预算/统计三场景全覆盖 |
| OCR | google_mlkit_text_recognition（Android/iOS 中文包） | 本地离线、免费、实测中文识别率约 99% |
| LLM | 智谱 GLM-4-Flash（OpenAI 兼容接口） | 完全免费（128K 上下文、30 并发；新用户另赠 2000 万 token），个人记账量成本≈0 |
| 敏感存储 | flutter_secure_storage | API Key 不入 SQLite |

---

## 3. 架构（按 feature 模块化，支撑未来扩展）

```
lib/
├── core/            # 底座：路由、主题(M3 tokens)、本地化、错误处理、共享工具
├── features/
│   ├── bookkeeping/  # 记账+预算+流水
│   ├── import/       # 账单导入模板引擎
│   ├── ai/           # AI 记账（对话/OCR/语音）→ 产出待确认流水
│   ├── focus/        # 待办+番茄钟
│   └── stats/        # 跨域聚合统计
└── app.dart
```

- 每 feature 内部分层：`data (Drift DAO)` / `domain (服务) / presentation (Riverpod + UI)`
- **未来加功能 = 新增一个 features/ 目录**，通过导航注册即可，不触碰既有模块
- 数据一致性：记账与待办/番茄钟共用同一 Drift 数据库实例，但表域物理隔离

---

## 4. 数据模型（Drift / SQLite）

金额一律以「分」存整数 `amount_cents`，杜绝浮点误差。三域互不干扰。

### 记账域

| 表 | 关键字段 | 要点 |
|---|---|---|
| `ledgers` 账本 | id, name, currency, icon, color, archived | 生活/工作/投资隔离 |
| `accounts` 账户 | ledger_id, name, type, sort_order, archived | type: 现金/储蓄卡/信用卡/平台 |
| `categories` 分类 | ledger_id, parent_id(可空=二级), name, icon, sort_order | 父子两级 |
| `transactions` 流水 | ledger_id, account_id, category_id, direction, amount_cents, currency, book_at, counterparty, remark, pay_method, order_id, import_key, is_pending, transfer_id(可空), raw_json, created_at, updated_at | 转账=两行共享 transfer_id；索引 `(ledger_id, book_at)`/`(account_id, book_at)`/`(category_id, book_at)`；**唯一 `(ledger_id, import_key)`** 去重 |
| `budgets` 预算 | ledger_id, category_id(可空=总预算), month, amount_cents | 月度+分类 |
| `recurring_transactions` 周期记账（吸收自 Firefly III / BeeCount） | ledger_id, account_id, category_id, direction, amount_cents, counterparty, remark, frequency(每周期: 月/周/自定义), day_of_month, next_run, active, last_generated | 到期自动生成一条**待确认**流水；复用 M5 的确认机制 |
| `import_batches` 导入批次 | source, file_name, imported_at, ok_rows, skip_rows, dup_rows, error_rows_json | 导入留痕 |
| `import_rules` 分类规则 | keyword, category_id, priority | 用户纠正回写，本地学习 |

### 待办·番茄钟域

| 表 | 关键字段 | 要点 |
|---|---|---|
| `projects` 项目 | name, color, sort_order, archived | 任务分组 |
| `tasks` 待办 | project_id, title, notes, priority, due_date, tags(json), estimate_minutes, actual_minutes, completed_at | tags 用 JSON 存字符串列表 |
| `pomodoro_sessions` 专注记录 | task_id(可空), kind(focus/short/long), start_at, end_at, duration_minutes, interrupted | 与待办联动，可统计"每日专注时长" |
| `pomodoro_settings` 设置 | 单行：focus/short/long 时长, 长休间隔 | 可配置 |

### 总结域（吸收自 Super Productivity）

| 表 | 关键字段 | 要点 |
|---|---|---|
| `day_summaries` 每日小结 | date(主键), pomodoro_count, focus_minutes, expense_total, tasks_done, rating(可空), snapshot_json | 收工一键生成当日小结并存档，历史可回看 |

### 配置域

- `settings` kv 普通配置；**GLM API Key 存 flutter_secure_storage**，不进库

---

## 5. 账单导入：字段映射模板设计（三层解耦）

**统一目标模型** `NormalizedTransaction`：direction / amount(分) / currency / book_at / counterparty / remark / category / pay_method / order_id / import_key / raw_json。

**来源适配层**：每来源一个 YAML 模板（声明式，不加代码）。示例（微信）：

```yaml
source: wechat
format: csv
encoding: GBK          # 微信 GBK，银行常为 UTF-8
delimiter: ","
header_row: 1          # 支付宝存在 2 行前置说明
columns:
  - {header: "交易时间", target: book_at, parse: datetime, pattern: "yyyy-MM-dd HH:mm:ss"}
  - {header: "交易对方", target: counterparty, clean: [trim, strip_emoji]}
  - {header: "商品",     target: remark}
  - {header: "收/支",    target: direction,
     map: {收入: income, 支出: expense, "/": unknown}}
  - {header: "金额(元)", target: amount_cents, parse: decimal}
  - {header: "交易单号", target: order_id, dedup: true}
  - {header: "支付方式", target: pay_method}
skip_rows:
  - {match: {col: "交易类型", contains: "合计"}}
  - {match: {col: "备注",     contains: "本交易为推广"}}
```

**规范化管道**：字段级纯函数流水线（trim → 去 BOM → 金额解析 → 多格式日期兜底 → 方向枚举映射/借贷推断 → 符号一致性校验）；不一致**显式报错并跳行记录**，绝不静默入库。

**去重**：支付宝/微信用官方交易单号（最强）；银行无全局单号用 `hash(日期+金额+对方+摘要)`。两级比对（对账本已有、对批次内），命中"疑似重复"由用户决定。

**分类打标三层递进**：本地关键词规则表 → GLM-4-Flash 建议分类（对方+备注+金额）→ 人工确认；**纠正结果回写规则表**（越用越准）。

**测试是硬要求**：支付宝/微信/招行真实导出（脱敏）存 test fixtures，每模板 10+ 用例锁行为。

---

## 6. AI 记账管线（含 OCR）

三条输入统一汇入「待确认流水列表」，与手动/导入共用同一套确认流程：

```
对话记账（GLM-4-Flash 文本）
拍照/选图（本地 ML Kit OCR）→ LLM 结构化 → 【确认页面】→ 入库
语音记账（系统转写）→ 同上
```

**v1 验收口径：对话记账（全平台）+ 移动端 OCR 全通；语音记账与桌面 OCR 列为 v1 之后迭代**（M6 只验收前两者，避免范围拖垮里程碑）。

- 三端平台性：对话记账全平台；OCR 仅移动端（ML Kit 不覆盖桌面，桌面 OCR 后置）；语音记账接入系统转写
- 隐私与成本：OCR 本地执行、图片不出手机；仅把识别出的文本/图片描述发 GLM；GLM-4-Flash 免费，成本≈0
- 设置页需明示数据边界（哪些数据发送到云端）

---

## 7. 待办 ↔ 番茄钟联动（签名交互，重点设计）

**核心闭环**：待办解锁番茄钟，番茄钟反哺待办——任务进度与专注时长双向可统计。

### 交互流程

1. 专注页今日待办每行右侧有 🍅 按钮；点击 → 计时器立即绑定该任务并进入聚焦态（顶部常驻提示条"专注中：{任务名}"，可随时重新绑定）
2. 完成一次专注 → 弹确认页（二选一：`标记任务完成` / `仍进行中`）→ 播提示音+系统通知（flutter_local_notifications，后台/锁屏可见）
3. 中断/放弃 → 明确放弃按钮 + 确认弹窗，该次记录标记 `interrupted=true`
4. 每完成 4 个番茄建议一次长休；跳过不阻塞
5. 统计页聚合：任务维度实际投入 vs 预估；每日番茄数/专注时长热力图

### 计时状态机

```
idle ──开始──▶ focusing ──完成──▶ 确认弹窗(完成/继续)
  ▲              │
  │           暂停
  │              ▼
  └────────── paused ──继续──▶ focusing（恢复重绘圆环）
```

### 关键技术（面试亮点）

- **绝对时间戳计时**：剩余 = `endAt - now`，app 从后台/被杀恢复时补偿，而非简单 Timer 倒计数做不定性
- 时间基准统一存 SQLite（record start/end），UI 只做展示层，防切后台丢时

---

### 待办增强（吸收自 Super Productivity / 着落 / Vikunja）

- **任务短语法**：一行输入创建/修改任务，支持 `#标签 +项目 25m @明天`（标签/项目/预估时长/截止）；与快速添加入口结合
- **四象限视图**：基于 priority 与 due_date 由现有字段派生（重要紧急/重要不紧急/紧急不重要/不重要不紧急），不新增表

## 8. UI 规范（Material 3）

- 主色 seed：`#3F77B6`（蓝白浅色调，浅色优先，避免深色）；Flutter 用 `ColorScheme.fromSeed` 生成精确 tonal ramp（原型中为近似值）
- 语义色：支出=primary 蓝，收入=tertiary 青蓝，error=红（仅错误态用）；surfaceContainer 五级做卡片层级（近白浅蓝灰）；分类图表色板全程冷色系（蓝/青/靛/灰蓝），避免暖橙残留
- 组件规范：手机底部 Navigation Bar 4 项（记账/专注/统计/设置）+ 记账页内嵌「流水」「预算」子页；桌面 Navigation Rail + 宽屏栅格；「记一笔」= Extended FAB → 全屏 Bottom Sheet
- 度量：金额一律 tabular-nums；圆角 8/12/16/28；数字信息密度按数据类 App 标准 ≥3 处差异化信息/屏
- 桌面 OCR 缺口、深色模式、无障碍对比度列入后续迭代
- 交付原型：`prototype/Timebook M3 记账原型.html`（单文件可交互，已过 Playwright 验证，0 页面错误）

---

## 9. 里程碑与验收

| 里程碑 | 内容 | 验收标准 |
|---|---|---|
| M0 脚手架 | Flutter 全平台工程、Riverpod 骨架、Drift 连库、CI | 空壳可跑、迁移可执行 |
| M1 记账核心 | 账本/账户/分类 CRUD + 手工记账 | 记账全流程可走通 |
| M2 图表仪表盘 | 月度收支、分类占比、趋势（fl_chart） | 数据正确呈现 |
| M3 预算 | 预算设置 + 月度进度 + 超支提醒 | 进度数字准确 |
| M4 待办+番茄钟 | 任务 CRUD + **短语法快速创建** + **四象限视图** + 可配置计时器 + 联动绑定 + 专注记录 | 计时/打断/补记全场景可用，短语法/四象限可演示 |
| M5 账单导入 | 模板引擎 + 微信/支付宝 CSV + 去重 + 待确认列表 + **周期记账**（到期生成待确认流水） | fixtures 全绿、正确率达标、周期账单按期生成 |
| M6 AI 记账 | 对话记账 + ML Kit OCR + 确认流程 | 三段式全通 |
| M7 打磨开源 | **每日小结报告** + 回归测试、README、GitHub 开源、面试演示脚本 | 开箱可演示 |

执行顺序说明：M5 先于 M6，先用"导入+待确认"机制兜住准确性，AI 记账只是多一条产生流水的通道，复用同一确认流程，风险最低。

---

## 10. 风险与决策

| 风险 | 应对 |
|---|---|
| OCR 识别错漏 | 三段式人工确认兜底；不追求绝对正确 |
| 桌面 OCR 能力缺口 | ML Kit 不覆盖桌面 → v1 桌面 AI 记账仅对话记账，OCR 后置 |
| 面试被追代码来源 | 全自研 + 开源 commit 历史 + 可讲清每一处设计决策 |
| API 免费额度变动 | GLM 免费档长期存在；超量时切换其他 OpenAI 兼容厂商成本也极低 |
| 范围失控 | 按里程碑推进，每个里程碑独立可演示，砍功能不砍质量 |

---

## 11. 高星项目功能吸收与未来扩展

### v1 已吸收（2026-09-12 决策）

| 功能 | 来源 | 落点 |
|---|---|---|
| 任务短语法 | Super Productivity | M4（新增 tasks 创建解析层） |
| 四象限视图 | 着落 / Vikunja | M4（由 priority+due_date 派生，无新表） |
| 周期记账 | Firefly III / BeeCount | M5（新表 recurring_transactions，汇入待确认） |
| 每日小结 | Super Productivity | M7（新表 day_summaries，收工一键归档） |

### 未来扩展池（候选，按优先级排队，不阻塞 v1）

云同步（WebDAV/iCloud/Supabase，复用 BeeCount 思路）· 多币种（Firefly III）· AI 财务问答（Maybe：自然语言查账，接 GLM 复用 AI 模块）· 储蓄目标/储蓄罐（Firefly III）· Flowtime 无限时专注（Super Productivity）· 专注热力图与深度统计 · 规则引擎自动分类 · 多皮肤主题（BeeCount）· 语音记账与桌面 OCR（v1 已明确后置）· 插件系统（Super Productivity，重）· GitHub/Jira 集成（个人场景低优）