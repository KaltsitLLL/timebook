# TimeBook 后续功能包 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地五个后续功能：①周期记账 UI 与 nextRun 边界修复 ②番茄钟完成系统通知 ③规则引擎自动分类 ④专注热力图 ⑤Flowtime 模式。**硬约束：既有 75 测试全程保持全绿。**

**Architecture:** 各功能落点独立：周期记账在 import 域（复用 `recurring_transactions` 表 + `generateDue`）+ 设置页新入口 + 流水行 `isPending` 徽标；通知在 focus 域新增可注入 `NotificationService` 抽象（生产走 flutter_local_notifications）；规则引擎在 bookkeeping 域（`import_rules` 表 + 纯函数 `RuleClassifier` + 设置页规则管理）；热力图为 focus 域聚合 + 专注页周热力条；Flowtime 扩展 `TimerMode` + chip + 实际时长落库。

**Tech Stack:** Flutter/Dart · flutter_riverpod · drift 2.31 · flutter_local_notifications（新增）· fl_chart（可视复用可选）

**依据：** `docs/superpowers/qa_report.md` 遗留 ⚠️ 1/2 项 + spec §11 未来扩展池（用户五选）+ 已交付代码。

---

## 文件结构（新增/修改）

```
timebook/
├── pubspec.yaml                                   # + flutter_local_notifications
├── lib/features/import/
│   ├── domain/recurring_service.dart              # Modify: nextRun 月末裁剪修复
│   └── presentation/recurring_rules_screen.dart   # Create: 周期规则列表/新增/启用
├── lib/features/bookkeeping/
│   ├── data/rule_classifier.dart                  # Create: 关键词→分类（纯函数）
│   ├── data/bookkeeping_repository.dart           # Modify: importRules CRUD + 应用规则
│   ├── presentation/rules_screen.dart             # Create: 分类规则管理
│   ├── presentation/placeholder_screens.dart      # Modify: 设置页增「周期记账」「分类规则」入口
│   └── presentation/transaction_list_screen.dart  # Modify: isPending 徽标「待确认」
├── lib/features/focus/
│   ├── domain/focus_timer.dart                    # Modify: TimerMode.flowtime + 时长逻辑
│   ├── data/focus_repository.dart                 # Modify: focusMinutesByDay 聚合
│   ├── notifications/notification_service.dart    # Create: 抽象 + FlutterLocalNotifications 实现(mock 可注入)
│   └── presentation/focus_screen.dart             # Modify: 完成通知 hook + 周热力条 + Flowtime chip
└── test/features/**                               # 各功能对应测试（见任务）
```

---

### Task 1: 周期记账 UI + nextRun 边界

**Files:** `recurring_service.dart`(M) · `recurring_rules_screen.dart`(C) · `placeholder_screens.dart`(M) · `transaction_list_screen.dart`(M) · 测试(C/M)

- [ ] **Step 1: 失败测试（nextRun 月末溢出）**

`test/features/import/recurring_service_test.dart` 追加：

```dart
test('nextRun 31 号到小月裁剪为月末（1-31 → 2-28）', () async {
  await db.into(db.ledgers).insert(LedgersCompanion.insert(name: '生活'));
  await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
  await db.into(db.recurringTransactions).insert(RecurringTransactionsCompanion.insert(
      ledgerId: 1, accountId: 1, direction: 'expense', amountCents: 100,
      counterparty: '月租', dayOfMonth: 31, nextRun: '2026-01-31'));
  final n = await svc.generateDue(today: DateTime(2026, 1, 31));
  expect(n, 1);
  final rt = (await db.recurringTransactions.get()).single;
  expect(rt.nextRun, '2026-02-28'); // 小月月末不溢出
});
```

- [ ] **Step 2: 跑测试确认失败** → `flutter test test/features/import/recurring_service_test.dart`（FAIL）
- [ ] **Step 3: 修复 `recurring_service.dart` 的推进逻辑**

```dart
// 推进：下月同日，若该日超过下月天数则裁剪为月末
DateTime next;
if (rt.dayOfMonth >= 28) {
  next = DateTime(base.year, base.month + 2, 0); // 下月最后一天
} else {
  next = DateTime(base.year, base.month + 1, rt.dayOfMonth);
}
final nextKey = _key(next);
```

（`_key(DateTime)` 同现有私有方法格式 yyyy-MM-dd。）

- [ ] **Step 4: 转绿** → Step 1 测试 PASS（含既有 2 用例）
- [ ] **Step 5: 周期规则页**

`recurring_rules_screen.dart`（ConsumerWidget）：AppBar「周期记账」；`FutureBuilder(repo 查询 recurringTransactions + generateDue(today) 先跑一次)`；列表项：`对方 · ¥xx/月 · 每月{dayOfMonth}号` + Switch(active) + 删除（IconButton）；底部「+ 新增规则」→ BottomSheet：
- Key('rr_amount') 金额元、Key('rr_counterparty') 对方、Key('rr_remark') 备注、Key('rr_day') 每月几号(默认1)、SegmentedButton(支出/收入)、Key('rr_save') 保存
- FocusRepository 无关：用 ImportService 同级的新 repo 方法？**由子代理决定**：在 `import_service.dart` 或 Repository 增加 recurring CRUD（`upsertRecurring/deleteRecurring/recurringAll/toggleRecurring`）——直接操作 `/recurring_transactions` 表，复用 `AddTransaction` 式插入（accountId 取账本首账户）。
- 设置页（`placeholder_screens.dart`）在「导入导出」下加「周期记账」行（Key('recurring_entry')）→ push 该页。

- [ ] **Step 6: 流水待确认徽标**

`transaction_list_screen.dart`：行 trailing 前（或 subtitle）若 `t.isPending` 显示 `Badge/Label「待确认」`（小灰底）；测试：导入/周期生成的 pending 行显示徽标，正常行为无。

- [ ] **Step 7: 测试（规则页 + 徽标）**

`test/features/import/recurring_rules_screen_test.dart`：seeded（账本+账户+一笔 recurring）→ pump → 列表显示对方文案 + 新增 Sheet 保存后行数+1；`transaction_list_test.dart` 追加 isPending 徽标用例。

- [ ] **Step 8: 提交** `feat(import): 周期记账 UI（规则管理/自动生成/待确认徽标）+ nextRun 月末修复`

---

### Task 2: 番茄钟完成通知

**Files:** `notification_service.dart`(C) · `focus_screen.dart`(M) · `pubspec.yaml`(M) · 测试(C)

- [ ] **Step 1: 依赖** `flutter_local_notifications: ^17.2.2`（解析失败用可用版本）
- [ ] **Step 2: 服务抽象（可测试）**

`lib/features/focus/notifications/notification_service.dart`：

```dart
abstract class NotificationService {
  Future<void> initialize();
  Future<void> show({required int id, required String title, required String body});
}

/// 生产实现：flutter_local_notifications（桌面/移动）。
class FlutterNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  @override
  Future<void> initialize() async {
    const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(appName: '时账'),
        iOS: DarwinInitializationSettings());
    await _plugin.initialize(settings);
  }
  @override
  Future<void> show({required int id, required String title, required String body}) =>
      _plugin.show(id, title, body, const NotificationDetails(
          android: AndroidNotificationDetails('focus', '专注提醒'),
          windows: WindowsNotificationDetails(),
          iOS: DarwinNotificationDetails()));
}
```

- [ ] **Step 3: 接线（可注入）**

`focus_screen.dart`（ConsumerStatefulWidget）加可选 `notification: NotificationService?` 参数（默认 FlutterNotificationService 实例，测试注入 mock）；`initState` 调 `initialize()`；`_onComplete()` 完成一次专注时：`notification.show(id: 1, title: '番茄完成 🍅', body: '休息一下吧')`；短休/长休结束（mode 非 focus 完成）同样提示（title 按模式）。
- [ ] **Step 4: 测试** `test/features/focus/notification_service_test.dart`：`FakeNotificationService implements NotificationService`（记录调用）；widget 测试用轻量方式触发完成较难（计时器长）——**改为对 `_onComplete` 路径做 unit 级验证**：将完成通知触发抽为可在测试直接调用的方法/或仅对 service 做 mock 断言（若 widget 计时模拟不可行，测试覆盖「service 抽象可注入 + 完成路径调用」以注入 fake 完成器为准；子代理可把完成逻辑抽为 `onCompleted(kind)` 可测函数）。至少保证：fake 被调用记录存在。
- [ ] **Step 5: 提交** `feat(focus): 番茄完成系统通知（可注入服务）`

---

### Task 3: 规则引擎自动分类

**Files:** `rule_classifier.dart`(C) · `bookkeeping_repository.dart`(M) · `rules_screen.dart`(C) · `placeholder_screens.dart`(M) · 测试(C)

- [ ] **Step 1: 纯函数 + 测试**

`rule_classifier.dart`：

```dart
class RuleClassifier {
  /// 按 priority 降序，取首个「关键词包含命中」的规则 → categoryId。
  static int? classify({required String text, required List<(String keyword, int categoryId, int priority)> rules}) {
    final sorted = [...rules]..sort((a, b) => b.$3.compareTo(a.$3));
    for (final r in sorted) {
      if (text.contains(r.$1)) return r.$2;
    }
    return null;
  }
}
```

测试：多规则优先级、包含命中、未命中 null、优先级相同时先出现者。

- [ ] **Step 2: importRules CRUD + 应用点**（`bookkeeping_repository.dart`）

`upsertRule({keyword, categoryId, priority})/rules()/deleteRule(id)`（表 `importRules` 已建，drift 标准 API）；`addTransaction` 增加可选 `applyRules: bool = false`：为 true 时用 `rules()` + classify(对方+备注) 填 categoryId（仅原 categoryId 为 null 时）；`ImportService.importRows` 落库时开启 applyRules。
- [ ] **Step 3: 规则管理页** `rules_screen.dart`：AppBar「分类规则」；规则列表（关键词 → 分类名）；「+ 新增规则」Sheet（Key('rule_keyword')/Key('rule_category') 分类下拉（账本分类）/Key('rule_save')）；设置页加「分类规则」入口（Key('rules_entry')）。
- [ ] **Step 4: 测试** `rule_classifier_test.dart` + `rules_screen_test.dart`（列表展示 + 新增落库）；ImportService 应用规则用例（有规则→自动分类入库）。
- [ ] **Step 5: 提交** `feat(bookkeeping): 规则引擎自动分类（规则管理/导入自动应用）`

---

### Task 4: 专注热力图（周）

**Files:** `focus_repository.dart`(M) · `focus_screen.dart`(M) · 测试(M)

- [ ] **Step 1: 聚合 + 测试**

`FocusRepository.focusMinutesByDay({int days = 7})` → `List<(DateTime day, int minutes)>`（近 7 天自老到新，空日补 0；当日会话同 Task 语义：kind=='focus' 且 !interrupted）。测试：跨日两笔 + 空日补零。

- [ ] **Step 2: UI（专注页摘要卡下方「本周专注」）**

专注页摘要卡下加第 3 行：`Row(7 格，每格 Column(色块 22×22 圆角：0 分灰 0xFFD8E1EB，否则主色透明度按 (min/60).clamp(0.15,0.9)，中央写 分钟数缩写(如 '8m' 空则空白) + 下方星期缩写 一二三四五六日))`；数据来自 FutureBuilder(repo.focusMinutesByDay())。测试：seeded 当日布局 → findsOneWidget 格数与星期标签（如 '五'）。

- [ ] **Step 3: 提交** `feat(focus): 本周专注热力图（近 7 日色块）`

---

### Task 5: Flowtime 模式

**Files:** `focus_timer.dart`(M) · `focus_timer_widget.dart`(M) · `focus_screen.dart`(M) · 测试(M)

- [ ] **Step 1: 失败测试（timer）**

`focus_timer_test.dart` 追加：

```dart
test('flowtime 不自动归零，由手动停止', () {
  final t = FocusTimer(focusMinutes: 25, mode: TimerMode.flowtime);
  t.start(now: DateTime(2026, 1, 1, 10));
  t.remainingSeconds(now: DateTime(2026, 1, 1, 11)); // 1 小时后
  expect(t.isFinished, isFalse);
  expect(t.remainingSeconds(now: DateTime(2026, 1, 1, 11)), 0); // 流式只显示 0 不结束
});
```

（语义修正：flowtime 剩余恒为 0 展示、不触发完成事件；由用户手动暂停/结束。）
- [ ] **Step 2: 实现**：`enum TimerMode { focus, short, long, flowtime }`；`FocusTimer`：flowtime 时 `durationSeconds` 返回极大（如 24*60*60）或专门分支：`remainingSeconds` 对 flowtime 恒返回 0、`isFinished` 恒 false；`start` 照常置 focusing。
- [ ] **Step 3: UI**：`focus_timer_widget.dart` chips 增「流式」（Key('mode_flowtime')）；完成按钮文案 flowtime 为「结束」，点击结束 → 记录实际时长（now - startAt）→ 走完成回调 with duration；专注页 addSession 时长传实际分钟（flowtime）。
- [ ] **Step 4: 测试**：timer flowtime 用例；`focus_screen_test` 追加 flowtime chip 存在（find.byKey('mode_flowtime')）。
- [ ] **Step 5: 提交** `feat(focus): Flowtime 无限时专注模式`

---

### Task 6: 验收

- [ ] **Step 1: 全量** `flutter analyze && flutter test` → Expected: 0 issues；全绿（75 基线 + 各任务新增 ≈ **90+**）
- [ ] **Step 2: 构建** `flutter build windows --debug` → Built
- [ ] **Step 3: 更新自检报告**：q1/q2 ⚠️ 关闭，新增功能计入报告（`timebook/docs/superpowers/qa_report.md` 更新「后续功能」节）
- [ ] **Step 4: 提交** `docs: 后续功能包验收记录（qa_report 更新）`

---

## Self-Review 结论

- **覆盖（用户五选）**：周期记账 UI+边界 → T1；番茄通知 → T2；规则引擎 → T3；热力图 → T4；Flowtime → T5。qa_report ⚠️1/2 由 T1 关闭；⚠️3（预算负副标题）与 ⚠️4（退款单号格式）、⚠️5（FutureBuilder 错误态）标记为低优先持续观察，本轮不动（避免范围膨胀），在 T6 报告中注明。
- **占位扫描**：无 TBD；每任务含关键代码与测试要点。T2 完成触发抽取为可测单元（子代理裁定），T4 热力图为 UI 聚合（测试覆盖聚合与标签）。
- **类型一致性**：`TimerMode` 扩展为 4 值（T5）——`focus_timer_test` 既有 mode 默认 focus 不变；`NotificationService`（T2）定义、focus_screen 构造可注入一致；`RuleClassifier.classify`（T3）签名并在 repository/import 应用一致；`focusMinutesByDay`（T4）返回 `List<(DateTime,int)>` 被 focus_screen 消费一致；`recurringRulesScreen`/`RulesScreen` 命名贯穿设置页入口一致。
- 测试计数：T6 预期 ≈90（以实际为准，更多用例更佳）。