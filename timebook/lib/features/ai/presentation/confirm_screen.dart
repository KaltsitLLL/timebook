import 'package:flutter/material.dart';
import '../domain/ai_bookkeeping_service.dart';
import '../domain/ai_models.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.draft, this.service});
  final AiDraft draft;
  final AiBookkeepingService? service;
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
    final svc = widget.service;
    if (svc == null) return;
    final draft = AiDraft(
      direction: widget.draft.direction,
      amountCents: (double.parse(_amount.text) * 100).round(),
      counterparty: _counterparty.text,
      remark: widget.draft.remark,
      category: widget.draft.category,
      bookAt: widget.draft.bookAt,
    );
    await svc.confirm(draft);
    if (!mounted) return;
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