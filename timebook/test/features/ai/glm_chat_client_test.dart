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
          '"counterparty":"滴滴出行","remark":"打车","category":"交通"}';
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
    await expectLater(chat.bookkeepingDraft('x'), throwsA(isA<AiException>()));
  });

  test('JSON 缺字段时金额解析失败进 AiException', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content': '{"direction":"expense"}'}}]}), 200));
    final chat = GlmChatClient(client: client, apiKey: 'sk',
        endpoint: 'https://example.com/v1');
    await expectLater(chat.bookkeepingDraft('x'), throwsA(isA<AiException>()));
  });
}