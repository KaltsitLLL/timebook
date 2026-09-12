import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timebook/features/ai/data/glm_chat_client.dart';
import 'package:timebook/features/ai/presentation/ai_dialog.dart';

void main() {
  testWidgets('AI 弹层输入一句话后进入确认页', (tester) async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content':
                    '{"direction":"expense","amount_cents":3200,"counterparty":"滴滴","remark":"打车","category":"交通"}'
              }
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'}));
    final chat =
        GlmChatClient(client: client, apiKey: 'sk', endpoint: 'https://e/v1');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => Center(
                    child: ElevatedButton(
                        onPressed: () => showModalBottomSheet(
                            context: context,
                            builder: (_) => AiDialog(client: chat)),
                        child: const Text('open')))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ai_input')), '昨天打车 32');
    await tester.tap(find.byKey(const Key('ai_go')));
    await tester.pumpAndSettle();
    expect(find.text('确认记账'), findsWidgets); // 已 push 确认页
  });
}