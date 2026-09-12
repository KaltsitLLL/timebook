import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/ai_models.dart';

class GlmChatClient {
  GlmChatClient(
      {required http.Client client,
      required this.apiKey,
      required this.endpoint}) {
    _client = client;
  }

  late final http.Client _client;
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