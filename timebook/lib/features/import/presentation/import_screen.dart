import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_database.dart';
import '../../bookkeeping/data/bookkeeping_repository.dart';
import '../data/import_service.dart';
import '../domain/csv_codec.dart';
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
  String? _fileName;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export() async {
    try {
      final repo = BookkeepingRepository(widget.database);
      final ledgers = await repo.ledgers();
      if (ledgers.isEmpty) {
        _showMessage('尚无账本可导出');
        return;
      }
      final csv = await repo.exportCsv(ledgerId: ledgers.first.id);
      final now = DateTime.now();
      final fileName = 'timebook_export_'
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}.csv';
      // 优先「下载」目录（桌面端）；不支持的平台回退系统临时目录。
      final dir = await getDownloadsDirectory() ?? Directory.systemTemp;
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(csv);
      _showMessage('已导出到 ${file.path}');
    } catch (e) {
      _showMessage('导出失败：$e');
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null && file.path == null) return; // 桌面 path 可用
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final text = decodeCsvBytes(bytes);
    setState(() {
      _csv.text = text;
      _fileName = file.name;
      _previewSummary = null;
    });
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
    if (result.rows.isEmpty) {
      if (result.errors.isNotEmpty) {
        _showMessage('无有效行：${result.errors.first}');
      } else {
        _showMessage('请先粘贴或选择 CSV 内容');
      }
      return;
    }
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
      appBar: AppBar(
        title: const Text('账单导入'),
        actions: [
          IconButton(
            key: const Key('export_button'),
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _export,
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
            _fileName != null
                ? '已选择：$_fileName（可直接预览/确认）'
                : '选择或粘贴微信导出的 CSV 文件',
            style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 10),
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
              key: const Key('pick_file_button'),
              onPressed: _pickFile,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.attach_file, size: 18),
                SizedBox(width: 4),
                Text('选择文件'),
              ])),
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