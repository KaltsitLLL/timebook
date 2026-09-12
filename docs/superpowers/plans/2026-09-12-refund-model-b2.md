# TimeBook 退款独立条目重做（B2）实现计划

> **For agentic workers:** superpowers:subagent-driven-development。**硬约束：既有 163 测试全程保持全绿；TDD 先红后绿；schema 变更走 drift 自动迁移。**

**Goal:** 把退款从「原地改 `transactions.refunded_cents`」升级为 Veri Fin 式「独立退款条目 + 派生缓存」：
- 新增 `refund_entries` 表为**唯一事实来源**（`refundOf`→原交易、`amountCents`、`settled_at` 可空=待到账、`accountId` 收款账户、`bookAt`）
- `transactions.refunded_cents` 保留为**派生缓存**（`syncRefundData` 重算，clamp 到 `[0, amountCents]` 永不出现负净额）
- 净额口径不变：统计/预算/导出继续读 `refunded_cents`，零回归
- 导入退款改为「建条目 → 同步缓存」；悬空单号退款仍进 `refundUnmatched`（人工映射按 Veri Fin 语义）

**依据：** `docs/superpowers/benchmarks/benchmark-study-2026-09-12.md` §1.2/§1.3（Veri Fin `ledger_entry.dart:9-18,146-158`、`_syncRefundData`、`plan_builder.dart:597-654`）。

---

### Task 1: 退款条目模型 + 同步缓存（TDD）

**Files:** `app_database.dart`(M) · `bookkeeping_repository.dart`(M) · 测试

- [ ] **1.1 表定义**：`refund_entries`：id(自增 pk)、ledgerId、transactionId(→transactions)、amountCents、accountId?、bookAt(datetime)、settledAt(datetime?，null=待到账)。drift 表声明 + `flutter pub run build_runner build --delete-conflicting-outputs` 再生 `app_database.g.dart`。
- [ ] **1.2 repo（TDD，先红）**：
  - `upsertRefund({ledgerId, transactionId, amountCents, accountId?, bookAt, settledAt?})` → 插入条目并调用 `syncRefundData(transactionId)`
  - `syncRefundData(transactionId)`：`refunded_cents = min(amountCents, Σ entries.amountCents)`（clamp 防负/溢出）；无条目归零（允许重算清零）
  - `refundEntries(transactionId)` 查询
  - 测试：500+800 两笔退款于 1000 元交易 → 缓存 1000（截断）；500 于 300 元交易 → 300；entry 全删后 sync → 0；settledAt null 行保留待退款标记
- [ ] **1.3 提交**：`feat(bookkeeping): 退款独立条目表 + 派生缓存同步（吃 Veri Fin）`

### Task 2: 导入管线换新模型

**Files:** `import_service.dart`(M) · 测试

- [ ] **2.1 `_applyRefund` 改造**：命中退款时不再直接 update 原行 refundedCents，改为：先 `upsertRefund(...)` 建条目（amountCents=退款金额、accountId=落库账户、bookAt=退款行时间、settledAt=当日或 null 按解析）→ `syncRefundData` 自动冲抵；去重仍由批次/单号逻辑保证（条目幂等键：同批次同 import 单号不重复建——沿用现有 dedupe 或在 repo 加「同 batch 唯一」判断，由实现者裁定最小方案）
- [ ] **2.2 悬空单号**：独立单号（微信）无法匹配 → 保持进 `refundUnmatched`；在其上新增**金额+对方+反向**启发匹配（同账本、日期≤7 天、金额相等且方向相反、唯一候选才匹配）→ 命中则建条目并同步。启发失败才入 refundUnmatched。
- [ ] **2.3 测试**：导入退款行 → `refund_entries` 1 行且原行 `refunded_cents` 被同步；两次同批次导入不重复建条目；独立单号但金额对方相符 → 条目命中；无法匹配 → refundUnmatched 仍工作。既有退款测试最小修正并注明。
- [ ] **2.4 提交**：`feat(import): 退款走独立条目（含单号悬空启发匹配）`

### Task 3: 净额口径复查 + 报告

- [ ] **3.1** 检查所有读 `refundedCents` 的统计/UI 处是否已 clamp 或负值防护（`amountCents - refundedCents` 现在天然 ≥0，因缓存已 clamp）；导出 CSV 净额列无需改
- [ ] **3.2** qa_report 增「B2 退款独立条目」节；benchmark 报告 §1.2 划「已吸收」；提交 `docs: B2 验收`
- [ ] **3.3** 全量 `flutter analyze` 0 · `flutter test` 全绿（163 基线 + ≈8）· 构建成功重启

## Self-Review

- 迁移安全：新表纯增量，drift 自动迁移；`refunded_cents` 列保留语义（派生缓存）→ 统计/导出零回归。
- 一致性：`upsertRefund`/`syncRefundData`（T1）在 import（T2）调用一致；缓存 clamp 逻辑单点。
- 范围：不做「退到不同账户」的余额联动（时间账当前无账户余额计算），条目保留 accountId 字段以备后用；不新增 UI，报告注明。