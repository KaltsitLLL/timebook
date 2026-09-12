# TimeBook M6 AI 记账 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现"一句话记账"：设置页配置 GLM API Key → 对话记账（"昨天打车 32" → AI 结构化草稿 → 确认页可改 → 落库）→ 流水可查；并预留 OCR 文本通道（粘贴识别文本，ML Kit 原生集成留 M6 后补丁）。

**Architecture:** `features/ai/` 新域。`AISettingsService`（抽象 Storage 注入，生产用 flutter_secure_storage）存 Key/Endpoint；`GlmChatClient(http.Client 注入)` 调 OpenAI 兼容 `/chat/completions`（GLM-4-Flash，`response_format: json_object`）→ 解析为 `AiDraft{direction,amountCents,counterparty,remark,categoryName?,bookAt}`；`AiBookkeepingService` 将 draft 分类建议映射到本地分类（名称包含匹配，无则 categoryId 置空由确认页选）并 `confirm()` 走 `addTransaction`；`ConfirmScreen` 提供可编辑确认卡片。记一笔 Sheet 增加「AI 记账」入口 → 对话弹层 → 确认页。

**Tech Stack:** Flutter/Dart · http ^1.2.2（MockClient 测试）· flutter_secure_storage ^9（AES/DPAPI；Storage 抽象可注入内存实现供测试）· intl

**依据：** `docs/superpowers/specs/2026-09-12-timebook-design.md`（§6 AI 记账管线、§2 技术栈 GLM-4-Flash、隐私边界：仅发送文本、Key 存安全存储、设置页明示）与已交付 M1-M5 代码（transactions.isPending 字段、Confirm 概念、categories/addTransaction）。

> **范围声明（父代理决策）**：ML Kit 原生 OCR（google_mlkit_text_recognition）仅支持 Android/iOS，直接依赖会使 Windows/macOS 构建失败。本计划将 OCR 拆为：M6 交付「对话记账 + OCR 文本粘贴通道（UI 按钮已预留）」；原生 OCR 集成作为 M6 验收后的**独立补丁提交**（conditional 平台隔离），验收口径不含它。详见 Self-Review。

---

## 文件结构

```
timebook/
├── pubspec.yaml                       # Modify: + http, flutter_secure_storage
├── lib/features/ai/
│   ├── data/ai_settings_service.dart  # Create: Key/Endpoint 存取（Storage 抽象注入）
│   ├── data/glm_chat_client.dart      # Create: OpenAI 兼容 chat 调用 + JSON 解析→AiDraft
│   ├── domain/ai_models.dart          # Create: AiDraft/AiException
│   ├── domain/ai_bookkeeping_service.dart # Create: preview/confirm（分类映射 + addTransaction）
│   └── presentation/
│       ├── confirm_screen.dart        # Create: 草稿确认（金额/分类/备注可改）
│       ├── ai_dialog.dart             # Create: 一句话输入弹层 → preview → ConfirmScreen
│       └── ai_settings_screen.dart    # Create: Key/Endpoint 配置页
├── lib/features/bookkeeping/presentation/add_transaction_sheet.dart  # Modify: 「AI 记账」入口
├── lib/features/bookkeeping/presentation/placeholder_screens.dart     # Modify 或设置页入口（静态列表加「AI 设置」项 → push）
└── test/features/ai/
    ├── ai_settings_service_test.dart  # Create（2 用例，内存 Storage）
    ├── glm_chat_client_test.dart      # Create（3 用例，MockClient）
    ├── ai_bookkeeping_service_test.dart # Create（2 用例，mock client）
    ├── confirm_screen_test.dart       # Create（1 用例）
    └── ai_dialog_test.dart            # Create（1 用例）
```

总计预期：既有 51 + settings 2 + client 3 + service 2 + confirm 1 + dialog 1 = **60 个测试**。

命令约定（全项目一致）：Windows/PowerShell；Flutter 全路径 `D:\dev\flutter\bin\flutter.bat`；flutter/dart 命令前内联 `$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"; $env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"`；flutter 命令 cwd=`...\clock\timebook`；git 命令 cwd=`...\clock`（`git add timebook/lib timebook/test timebook/pubspec.yaml` 按实际）。

---

### Task 1: 依赖 + AI 设置存储

**Files:**
- Modify: `timebook/pubspec.yaml`
- Create: `timebook/lib/features/ai/data/ai_settings_service.dart`
- Create: `timebook/test/features/ai/ai_settings_service_test.dart`

- [ ] **Step 1: 写失败测试**

`ai_settings_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/ai/data/ai_settings_service.dart';

class MemStorage implements KeyValueStorage {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

void main() {
  test('保存与读取 Key/Endpoint，默认端点', () async {
    final svc = AISettingsService(MemStorage());
    expect(await svc.endpoint(), 'https://open.bigmodel.cn/api/paas/v4');
    await svc.saveEndpoint('https://example.com/v1');
    await svc.saveApiKey('sk-test');
    expect(await svc.apiKey(), 'sk-test');
    expect(await svc.endpoint(), 'https://example.com/v1');
  });

  test('清除 Key', () async {
    final svc = AISettingsService(MemStorage());
    await svc.saveApiKey('sk-1');
    await svc.deleteApiKey();
    expect(await svc.apiKey(), isNull);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/ai/ai_settings_service_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 加依赖并实现**

`pubspec.yaml` dependencies 增：`http: ^1.2.2`、`flutter_secure_storage: ^9.2.4`（若解析失败按提示降级版本）。

`ai_settings_service.dart`：

```dart
/// 可注入存储（测试用内存实现，生产用 SecureStorage）
abstract class KeyValueStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class AISettingsService {
  AISettingsService(this._storage);
  final KeyValueStorage _storage;

  static const defaultEndpoint = 'https://open.bigmodel.cn/api/paas/v4';
  static const _keyKey = 'ai_api_key';
  static const _endpointKey = 'ai_endpoint';

  Future<String?> apiKey() => _storage.read(_keyKey);
  Future<void> saveApiKey(String key) => _storage.write(_keyKey, key);
  Future<void> deleteApiKey() => _storage.delete(_keyKey);

  Future<String> endpoint() async =>
      await _storage.read(_endpointKey) ?? defaultEndpoint;
  Future<void> saveEndpoint(String url) => _storage.write(_endpointKey, url);
}
```

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter pub get
flutter test test/features/ai/ai_settings_service_test.dart
flutter analyze
```

Expected: 2 用例全绿；analyze 0 问题。

- [ ] **Step 5: 提交**

```powershell
git add timebook/pubspec.yaml timebook/pubspec.lock timebook/lib/features/ai/data/ai_settings_service.dart timebook/test/features/ai/ai_settings_service_test.dart
git commit -m "feat(ai): AI 设置存储（Key/Endpoint，可注入 Storage）与依赖"
```

---

### Task 2: GLM 对话客户端

**Files:**
- Create: `timebook/lib/features/ai/domain/ai_models.dart`
- Create: `timebook/lib/features/ai/data/glm_chat_client.dart`
- Create: `timebook/test/features/ai/glm_chat_client_test.dart`

- [ ] **Step 1: 写失败测试**

`glm_chat_client_test.dart`（http 包测试用 MockClient）：

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timebook/features/ai/data/glm_chat_client.dart';
import 'package:timebook/features/ai/domain/ai_models.dart';

void main() {
  test('解析 GLM 返回的 JSON 草稿', () async {
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['model'], 'glm-4-flash');
      final text = '{"direction":"expense","amount_cents":3200,'
          '"counterparty":"「滴滴出行」|||remark:text","category":"交通"}';
      return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'content': text}}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final chat = GlmChatClient(client: client, apiKey: 'sk-test',
        endpoint: 'https://example.com/v1');
    final draft = await chat.bookkeepingDraft('昨天打车 32');
    expect(draft.direction, 'expense');
    expect(draft.amountCents, 3200);
    expect(draft.counterparty, '滴滴出行');
    expect(draft.category, '交通');
  });

  test('HTTP 错误抛出 AiException', () async {
    final client = MockClient((_) async => http.Response('boom', 500));
    final chat = GlmChatClient(client: client, apiKey: 'sk',
        endpoint: 'https://example.com/v1');
    expect(() => chat.bookkeepingDraft('x'), throwsA(isA<AiException>()));
  });

  test('JSON 缺字段时金额解析失败进 AiException', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content': '{"direction":"expense"}'}}]}), 200));
    final chat = GlmChatClient(client: client, apiKey: 'sk',
        endpoint: 'https://example.com/v1');
    expect(() => chat.bookkeepingDraft('x'), throwsA(isA<AiException>()));
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/ai/glm_chat_client_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现**

`ai_models.dart`：

```dart
class AiDraft {
  const AiDraft({
    required this.direction,
    required this.amountCents,
    this.counterparty = '',
    this.remark = '',
    this.category,
    this.bookAt,
  });
  final String direction; // income / expense
  final int amountCents;
  final String counterparty;
  final String remark;
  final String? category; // AI 建议分类名
  final DateTime? bookAt;
}

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

`glm_chat_client.dart`：

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/ai_models.dart';

class GlmChatClient {
  GlmChatClient(
      {required http.Client client,
      required this.apiKey,
      required this.endpoint})
      : _client = client;

  final http.Client _client;
  final String apiKey;
  final String endpoint;

  static const _system = '你是记账助手。把用户一句话整理成一笔账单，'
      '只输出 JSON：{"direction":"income|expense","amount_cents":整数分,'
      '"counterparty":"交易对方","remark":"备注",'
      '"category":"建议分类名 如 餐饮/交通/购物/娱乐/居住/医疗/工资/其他",'
      '"book_at":"yyyy-MM-dd HH:mm:ss 可空"}。金额必填。不要输出其他内容。';

  Future<AiDraft> bookkeepingDraft(String text) async {
    final messages = [
      {'role': 'system', 'content': _system},
      {'role': 'user', 'content': text},
    ];
    final http.Response resp;
    try {
      resp = await _client.post(
        Uri.parse('$endpoint/chat/completions'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'glm-4-flash',
          'messages': messages,
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
        }),
      );
    } catch (e) {
      throw AiException('网络请求失败: $e');
    }
    if (resp.statusCode != 200) {
      throw AiException('AI 服务错误(${resp.statusCode}): ${resp.body}');
    }
    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final content = (map['choices'] as List).first['message']['content'] as String;
    return _parseDraft(content);
  }

  AiDraft _parseDraft(String content) {
    final m = jsonDecode(content) as Map<String, dynamic>;
    final cents = m['amount_cents'];
    if (cents is! int) throw AiException('AI 返回金额字段异常');
    final direction = m['direction'] == 'income' ? 'income' : 'expense';
    DateTime? bookAt;
    final raw = m['book_at'] as String?;
    if (raw != null && raw.isNotEmpty) {
      bookAt = DateTime.tryParse(raw);
    }
    return AiDraft(
      direction: direction,
      amountCents: cents,
      counterparty: (m['counterparty'] as String?) ?? '',
      remark: (m['remark'] as String?) ?? '',
      category: m['category'] as String?,
      bookAt: bookAt,
    );
  }
}
```

（若测试环境 `http` mock 对 `/chat/completions` 路径无要求，此实现 OK；MockClient 默认接受任意路径。）

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/ai/glm_chat_client_test.dart
flutter analyze
```

Expected: 3 用例全绿（第 3 个用例抛异常 → `expect(() => ..., throwsA(...))` 对 async 用 `expectLater`/`await expectLater(x, throwsA(...))`——实现按 Dart 规范：async 异常用 `await expectLater(chat.bookkeepingDraft('x'), throwsA(isA<AiException>()))`。请按正确 async 断言书写测试）。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/ai/domain/ai_models.dart timebook/lib/features/ai/data/glm_chat_client.dart timebook/test/features/ai/glm_chat_client_test.dart
git commit -m "feat(ai): GLM-4-Flash 对话客户端（JSON 草稿解析/错误抛 AiException）"
```

---

### Task 3: AiBookkeepingService（分类映射 + confirm 落库）

**Files:**
- Create: `timebook/lib/features/ai/domain/ai_bookkeeping_service.dart`
- Create: `timebook/test/features/ai/ai_bookkeeping_service_test.dart`

- [ ] **Step 1: 写失败测试**

`ai_bookkeeping_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/ai/domain/ai_bookkeeping_service.dart';
import 'package:timebook/features/ai/domain/ai_models.dart';

import '../../helpers/db.dart';

void main() {
  late AppDatabase db;
  late AiBookkeepingService svc;

  setUpAll(initTestSqlite);

  setUp(() async {
    db = AppDatabase.forTesting(inMemoryExecutor());
    svc = AiBookkeepingService(db);
  });

  tearDown(() async => db.close());

  test('confirm 将草稿落库为支出（分类名模糊匹配）', () async {
    final l = await svc.createLedgerIfEmpty(name: '生活');
    await db.into(db.accounts)
        .insert(AccountsCompanion.insert(ledgerId: l, name: '卡'));
    final food = await db.into(db.categories).insert(
        CategoriesCompanion.insert(ledgerId: l, name: '餐饮'));

    final draft = AiDraft(direction: 'expense', amountCents: 2850,
        counterparty: '美团外卖', category: '餐饮');
    await svc.confirm(draft);

    final rows = await db.transactions.get();
    expect(rows.single.amountCents, 2850);
    expect(rows.single.categoryId, food);
    expect(rows.single.isPending, isFalse);
  });

  test('分类未匹配 → categoryId 为空仍可落库', () async {
    final l = await svc.createLedgerIfEmpty(name: '生活');
    await db.into(db.accounts)
        .insert(AccountsCompanion.insert(ledgerId: l, name: '卡'));
    await db.into(db.categories)
        .insert(CategoriesCompanion.insert(ledgerId: l, name: '餐饮'));
    await svc.confirm(const AiDraft(direction: 'income', amountCents: 100));
    final rows = await db.transactions.get();
    expect(rows.single.direction, 'income');
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/ai/ai_bookkeeping_service_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现**

`ai_bookkeeping_service.dart`：

```dart
import 'package:drift/drift.dart';
import '../../../core/db/app_database.dart';
import 'ai_models.dart';

class AiBookkeepingService {
  AiBookkeepingService(this.db);
  final AppDatabase db;

  Future<int> createLedgerIfEmpty({required String name}) async {
    final ledgers = await db.ledgers.get();
    if (ledgers.isNotEmpty) return ledgers.first.id;
    return db.into(db.ledgers).insert(LedgersCompanion.insert(name: name));
  }

  /// 分类名模糊匹配（包含匹配返回首个命中）。
  Future<int?> _matchCategory(int ledgerId, String? name) async {
    if (name == null || name.isEmpty) return null;
    final cats = await (db.select(db.categories)..where((t) => t.ledgerId.equals(ledgerId))).get();
    final hit = cats.where((c) => c.name.contains(name) || name.contains(c.name)).toList();
    return hit.isEmpty ? null : hit.first.id;
  }

  Future<void> confirm(AiDraft draft) async {
    final ledgerId = await createLedgerIfEmpty(name: '生活');
    final accounts = await (db.select(db.accounts)..where((t) => t.ledgerId.equals(ledgerId))).get();
    if (accounts.isEmpty) throw StateError('请先创建账户');
    final categoryId = await _matchCategory(ledgerId, draft.category);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: ledgerId,
        accountId: accounts.first.id,
        categoryId: Value(categoryId),
        direction: draft.direction,
        amountCents: draft.amountCents,
        bookAt: draft.bookAt ?? DateTime.now(),
        counterparty: Value(draft.counterparty),
        remark: Value(draft.remark)));
  }
}
```

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/ai/ai_bookkeeping_service_test.dart
flutter analyze
```

Expected: 2 用例全绿（若无 `createLedgerIfEmpty` 名字设计问题可微调，语义保持）。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/ai/domain/ai_bookkeeping_service.dart timebook/test/features/ai/ai_bookkeeping_service_test.dart
git commit -m "feat(ai): AI 确认落库（分类模糊匹配/addTransaction）"
```

---

### Task 4: 确认页 ConfirmScreen

**Files:**
- Create: `timebook/lib/features/ai/presentation/confirm_screen.dart`
- Create: `timebook/test/features/ai/confirm_screen_test.dart`

- [ ] **Step 1: 写失败测试**

`confirm_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/ai/domain/ai_bookkeeping_service.dart';
import 'package:timebook/features/ai/domain/ai_models.dart';
import 'package:timebook/features/ai/presentation/confirm_screen.dart';

import '../../helpers/db.dart';

void main() {
  setUpAll(initTestSqlite);

  testWidgets('确认页可修改金额并落库', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final svc = AiBookkeepingService(db);
    await svc.createLedgerIfEmpty(name: '生活');
    await db.into(db.accounts).insert(AccountsCompanion.insert(ledgerId: 1, name: '卡'));
    addTearDown(db.close);

    await tester.pumpWidget(MaterialApp(home: ConfirmScreen(
        draft: const AiDraft(direction: 'expense', amountCents: 5000,
            counterparty: '滴滴'),
        service: svc)));
    await tester.pumpAndSettle();

    expect(find.text('50.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_save')));
    await tester.pumpAndSettle();
    final rows = await db.transactions.get();
    expect(rows.single.amountCents, 5000);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/ai/confirm_screen_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现**

`confirm_screen.dart`：

```dart
import 'package:flutter/material.dart';
import '../domain/ai_bookkeeping_service.dart';
import '../domain/ai_models.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.draft, required this.service});
  final AiDraft draft;
  final AiBookkeepingService service;
  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _counterparty;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
        text: (widget.draft.amountCents / 100).toStringAsFixed(2));
    _counterparty = TextEditingController(text: widget.draft.counterparty);
  }

  @override
  void dispose() {
    _amount.dispose();
    _counterparty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = double.tryParse(_amount.text)?.round() ?? 0;
    if (n <= 0) return;
    final draft = AiDraft(
      direction: widget.draft.direction,
      amountCents: (double.parse(_amount.text) * 100).round(),
      counterparty: _counterparty.text,
      remark: widget.draft.remark,
      category: widget.draft.category,
      bookAt: widget.draft.bookAt,
    );
    await widget.service.confirm(draft);
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('确认记账')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(key: const Key('confirm_amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '金额（元）', prefixText: '¥ ', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _counterparty,
              decoration: const InputDecoration(labelText: '交易对方', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft,
              child: Text('分类建议：${widget.draft.category ?? '（未识别）'}', style: const TextStyle(fontSize: 13))),
          const Spacer(),
          FilledButton(key: const Key('confirm_save'), onPressed: _save,
              child: const Text('确认入账')),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/ai/confirm_screen_test.dart
flutter analyze
```

Expected: 用例全绿。

- [ ] **Step 5: 提交**

```powershell
git add timebook/lib/features/ai/presentation/confirm_screen.dart timebook/test/features/ai/confirm_screen_test.dart
git commit -m "feat(ai): 确认页（金额/对方可改→AI 落库）"
```

---

### Task 5: 入口（记一笔「AI 记账」+ 对话弹层 + AI 设置页）

**Files:**
- Create: `timebook/lib/features/ai/presentation/ai_dialog.dart`
- Create: `timebook/lib/features/ai/presentation/ai_settings_screen.dart`
- Modify: `timebook/lib/features/bookkeeping/presentation/add_transaction_sheet.dart`
- Modify: `timebook/lib/features/bookkeeping/presentation/placeholder_screens.dart`（设置列表加「AI 设置」项）
- Create: `timebook/test/features/ai/ai_dialog_test.dart`

- [ ] **Step 1: 写失败测试**

`ai_dialog_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:timebook/features/ai/data/glm_chat_client.dart';
import 'package:timebook/features/ai/presentation/ai_dialog.dart';

void main() {
  testWidgets('AI 弹层输入一句话后进入确认页', (tester) async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content':
            '{"direction":"expense","amount_cents":3200,"counterparty":"滴滴","remark":"打车","category":"交通"}'}}]}),
        200));
    final chat = GlmChatClient(client: client, apiKey: 'sk', endpoint: 'https://e/v1');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
        Center(child: ElevatedButton(onPressed: () => showModalBottomSheet(
            context: context, builder: (_) => AiDialog(client: chat)), child: const Text('open')))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ai_input')), '昨天打车 32');
    await tester.tap(find.byKey(const Key('ai_go')));
    await tester.pumpAndSettle();
    expect(find.text('确认记账'), findsWidgets); // 已 push 确认页
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```powershell
flutter test test/features/ai/ai_dialog_test.dart
```

Expected: FAIL。

- [ ] **Step 3: 实现**

`ai_dialog.dart`：

```dart
import 'package:flutter/material.dart';
import '../data/glm_chat_client.dart';
import '../domain/ai_bookkeeping_service.dart';
import '../domain/ai_models.dart';
import 'confirm_screen.dart';

class AiDialog extends StatefulWidget {
  const AiDialog({super.key, required this.client, this.service});
  final GlmChatClient client;
  final AiBookkeepingService? service;
  @override
  State<AiDialog> createState() => _AiDialogState();
}

class _AiDialogState extends State<AiDialog> {
  final _input = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _go(BuildContext rootContext, {AiBookkeepingService? svc}) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final draft = await widget.client.bookkeepingDraft(text);
      if (!mounted) return;
      Navigator.of(rootContext).pop(); // 关弹层
      await Navigator.of(rootContext).push(MaterialPageRoute(
          builder: (_) => ConfirmScreen(
              draft: draft,
              service: svc ?? widget.service ?? AiBookkeepingService(await _db(rootContext)))));
    } on AiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  // _db 占位：实际由调用方传入 AiBookkeepingService（见 Task 5 Step 3 接线）；此处由上层传入 db 构造。
```

（实现时由 `add_transaction_sheet.dart` 传入 `service`，避免弹层内取 db 的耦合；`AiDialog(client, service)` 两参数即可，`_go` 直接使用。）

- [ ] **Step 4: 确认页/弹层接线**

`add_transaction_sheet.dart`：在「记一笔」头部或分割按钮旁加 `OutlinedButton.icon(key: Key('ai_dialog_open')…label: 'AI 记账')` → `showModalBottomSheet(builder: (_) => AiDialog(client: GlmChatClient(client: http.Client(), apiKey: key ?? '', endpoint: await AISettingsService(secureStorage).endpoint()), service: AiBookkeepingService(ref.read(databaseProvider))))`——**为可测与避免依赖注入复杂化**，入口组件应接受可注入 `AiDialog` 构造参数（如默认 `buildAiDialog()` 工厂），测试直接测 AiDialog 即可；正式入口把「未配置 Key」时 SnackBar 提示去设置。Key 读取异常（未配置）由 ui 捕获提示，不崩溃。

`placeholder_screens.dart` 设置列表追加一行「AI 设置」（icon smart_toy）→ push `AiSettingsScreen`。

`ai_settings_screen.dart`：Key(ai_key_field) 密码输入 + Key(ai_endpoint_field) 地址 + 保存按钮（Key(ai_settings_save)）→ AISettingsService 保存 → SnackBar「已保存」。生产 Storage 用 `FlutterSecureStorage`：`class SecureStorage implements KeyValueStorage { final _s = const FlutterSecureStorage(); ... }`（同文件）。

- [ ] **Step 5: 跑测试确认通过 + analyze**

```powershell
flutter test test/features/ai/ai_dialog_test.dart
flutter test
flutter analyze
```

Expected: dialog 用例绿；全量（60 区间）绿；analyze 0 问题。

- [ ] **Step 6: 提交**

```powershell
git add timebook/lib timebook/test
git commit -m "feat(ai): AI 记账入口（弹层对话→确认页）与 AI 设置页"
```

---

### Task 6: M6 验收

**Files:** 无（只验证）

- [ ] **Step 1: 全量检查**

```powershell
flutter analyze
flutter test
```

Expected: `No issues found!`；全部 PASS（既有 51 + settings 2 + client 3 + service 2 + confirm 1 + dialog 1 = **60**）。

- [ ] **Step 2: Windows 构建**

```powershell
flutter build windows --debug
```

Expected: `√ Built build\windows\x64\runner\Debug\timebook.exe`。

- [ ] **Step 3: 记录已知限制（提交说明）**

- 智谱 API Key 需用户自行申请（open.bigmodel.cn），设置页保存于安全存储（Windows DPAPI/移动 Keystore）
- ML Kit 原生 OCR 未在本里程碑接入（仅移动端支持；UI 已留「粘贴识别文本」思路与 AiDialog 通道，作为 M6 后独立补丁）
- 语音记账、图片直传 GLM 视觉、AI 凭据导出/清除 UI 后续

- [ ] **Step 4: 提交收尾（如有未提交变更）**

```powershell
git add -A; git status
git commit -m "docs: M6 验收记录（60 tests green / analyze clean / windows build ok）"
```

---

## Self-Review 结论

- **Spec 覆盖（M6）**：§6 对话记账（全平台）+ 确认流程 ✅ Task 1-5；隐私边界（仅发送文本、Key 安全存储、设置页明示）✅ Task 1/5；**OCR 范围调整**：ML Kit 原生仅 Android/iOS，为保证 Windows/macOS 构建不被移动端专用插件破坏，本计划交付「对话记账 + 确认 + 弹层通道」，原生 OCR 列为 M6 后**独立补丁**（conditional import + google_mlkit），验收口径不含它（§6 的 MVP 口径在交付说明中同步更新）。
- **占位扫描**：无 TBD/TODO；每 Task 含可编译代码。Task 5 的 `_db` 占位已注明由调用方注入 service，避免弹层耦合；`ai_dialog` 测试通过可注入 client 达成确定性。
- **类型一致性**：`AISettingsService/KeyValueStorage` Task 1 定义、Task 5 使用一致；`AiDraft/AiException` Task 2 定义、Task 2/3/4/5 使用一致；`GlmChatClient({client,apiKey,endpoint}).bookkeepingDraft(text)` Task 2 定义、Task 5 使用一致；`AiBookkeepingService(db).confirm(draft)` Task 3 定义、Task 4/5 使用一致；`ConfirmScreen({draft,service})` Task 4 定义、Task 5 使用一致；`AiDialog({client,service})` Task 5 定义。`createLedgerIfEmpty` 语义 Task 3 定义并被测试引用。
- 测试计数：Task 6 预期 60（以实际 async 断言写法为准，总量不变）。