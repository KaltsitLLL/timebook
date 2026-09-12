import 'package:flutter/material.dart';
import '../../../core/db/app_database.dart';
import '../data/import_service.dart';
import '../domain/template_engine.dart';

/// 微信账单模板（内联 YAML，测试与运行不依赖资源 IO）。
const String _wechatTemplate = '''
source: wechat
skip_rows:
  - {contains: "合计"}
  - {contains: "本交易为推广"}
columns:
  - {header: "交易时间", target: bookAt, parse: datetime}
  - {header: "交易类型", target: transKind}
  - {header: "交易对方", target: counterparty, clean: [trim]}
  - {header: "商品", target: remark}
  - {header: "收/支", target: direction, map: {收入: income, 支出: expense, "/": unknown}}
  - {header: "金额(元)", target: amount, parse: decimal}
  - {header: "支付方式", target: payMethod}
  - {header: "交易单号", target: orderId}
refund_markers: ["退款", "已退款"]
''';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.database});
  final AppDatabase database;
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _csv = TextEditingController();
  String? _previewSummary;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _preview() {
    final engine = TemplateEngine(templateYaml: _wechatTemplate);
    final result = engine.parse(_csv.text);
    setState(() {
      _previewSummary =
          '成功 ${result.rows.length} · 错误 ${result.errors.length} · 退款行 ${result.rows.where((r) => r.isRefund).length}';
    });
  }

  Future<void> _confirm() async {
    final engine = TemplateEngine(templateYaml: _wechatTemplate);
    final result = engine.parse(_csv.text);
    final svc = ImportService(widget.database);
    try {
      final outcome = await svc.importRows(
          source: 'wechat', fileName: '粘贴导入', rows: result.rows);
      _showMessage('已保存 ${outcome.saved} 笔 · 重复 ${outcome.duplicated}'
          ' · 退款冲抵 ${outcome.refunded} · 未匹配退款 ${outcome.refundUnmatched}');
    } on StateError catch (e) {
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账单导入')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('粘贴微信/支付宝导出的 CSV（当前支持微信格式）',
            style: TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
        TextField(
          key: const Key('csv_input'),
          controller: _csv,
          maxLines: 8,
          decoration: const InputDecoration(
              hintText: '粘贴 CSV 文本…', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, children: [
          FilledButton.tonal(
              key: const Key('preview_button'),
              onPressed: _preview,
              child: const Text('预览')),
          FilledButton(
              key: const Key('confirm_button'),
              onPressed: _confirm,
              child: const Text('确认入库')),
        ]),
        if (_previewSummary != null) ...[
          const SizedBox(height: 14),
          Text(_previewSummary!, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}