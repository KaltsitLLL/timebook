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

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      final draft = await widget.client.bookkeepingDraft(text);
      if (!mounted) return;
      nav.pop(); // 关弹层
      await nav.push(MaterialPageRoute(
          builder: (_) => ConfirmScreen(draft: draft, service: widget.service)));
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('AI 记账', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            key: const Key('ai_input'),
            controller: _input,
            decoration: const InputDecoration(
              hintText: '一句话记账，例如「昨天打车 32」',
              labelText: '记账内容',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('ai_go'),
            onPressed: _loading ? null : _go,
            child: _loading
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('识别并记账'),
          ),
        ],
      ),
    );
  }
}