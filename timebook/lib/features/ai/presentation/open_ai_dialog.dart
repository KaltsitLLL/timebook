import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/db/app_database.dart';
import '../../bookkeeping/presentation/bookkeeping_providers.dart';
import '../data/ai_settings_service.dart';
import '../data/glm_chat_client.dart';
import '../domain/ai_bookkeeping_service.dart';
import 'ai_dialog.dart';
import 'ai_settings_screen.dart' show SecureStorage;

/// 打开「AI 记账」弹层。手动记账 Sheet 的 AI 按钮与首页 FAB 长按共用此入口。
///
/// 未配置 API Key 时弹出 SnackBar 提示去设置；已配置则拉起 [AiDialog]。
/// 测试可注入 [client]/[service]/[db]，此时跳过设置读取直接展示弹层。
Future<void> openAiDialog(
  BuildContext context,
  WidgetRef ref, {
  AppDatabase? db,
  GlmChatClient? client,
  AiBookkeepingService? service,
}) async {
  final GlmChatClient resolvedClient;
  if (client == null) {
    final svc = AISettingsService(const SecureStorage());
    final key = await svc.apiKey();
    if (key == null || key.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('请先在「设置 → AI 设置」配置 API Key')));
      return;
    }
    final endpoint = await svc.endpoint();
    resolvedClient = GlmChatClient(
        client: http.Client(), apiKey: key, endpoint: endpoint);
  } else {
    resolvedClient = client;
  }
  final effService =
      service ?? AiBookkeepingService(db ?? ref.read(databaseProvider));
  if (!context.mounted) return;
  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AiDialog(client: resolvedClient, service: effService));
}