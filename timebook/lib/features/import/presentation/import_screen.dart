import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_database.dart';
import '../../bookkeeping/data/bookkeeping_repository.dart';
import '../data/import_service.dart';
import '../domain/csv_codec.dart';
import '../domain/import_models.dart';
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
  String? _fileName;

  // 预览状态（仅存 State 字段，不落库）
  bool _previewed = false;
  List<_RowState> _rows = [];
  List<ParseErrorRow> _errors = [];
  List<Category> _cats = [];

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  int? _parseAmount(String text) {
    final v = double.tryParse(text.trim());
    if (v == null) return null;
    return (v * 100).round();
  }

  Future<void> _export() async {
    try {
      final repo = BookkeepingRepository(widget.database);
      final ledgers = await repo.ledgers();
      if (ledgers.isEmpty) {
        _showMessage('尚无账本可导出');
        return;
      }
      // 导出当前账本；未设置或 kv 指向不存在时回退首账本。
      var ledgerId = ledgers.first.id;
      final kvId = await repo.settings.getInt('currentLedgerId');
      if (kvId != null && ledgers.any((x) => x.id == kvId)) ledgerId = kvId;
      final csv = await repo.exportCsv(ledgerId: ledgerId);
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
      _previewed = false;
    });
  }

  Future<void> _loadCategories() async {
    final repo = BookkeepingRepository(widget.database);
    final ledgers = await repo.ledgers();
    _cats = ledgers.isEmpty ? [] : await repo.categories(ledgers.first.id);
  }

  Future<void> _preview() async {
    final engine = TemplateEngine(templateYaml: _wechatTemplate);
    final result = engine.parse(_csv.text);
    await _loadCategories();
    setState(() {
      _rows = [
        for (final r in result.rows)
          _RowState(row: r, ok: true, amountText: (r.amountCents / 100).toString())
      ];
      _errors = result.errors;
      _previewed = true;
    });
  }

  Future<void> _confirm() async {
    if (_rows.isEmpty) {
      if (_errors.isNotEmpty) {
        _showMessage('无有效行：${_errors.first.reason}');
      } else {
        _showMessage('请先粘贴或选择 CSV 内容');
      }
      return;
    }
    // 仅导入勾选且金额可解析的行（编辑后值生效）。
    final selected = <ImportedRow>[];
    final broken = <String>[];
    for (var i = 0; i < _rows.length; i++) {
      final rs = _rows[i];
      if (!rs.ok) continue;
      final cents = _parseAmount(rs.amountText);
      if (cents == null) {
        broken.add('行 ${i + 1} 金额无效');
        continue;
      }
      selected.add(ImportedRow(
        bookAt: rs.row.bookAt,
        direction: rs.row.direction,
        amountCents: cents,
        counterparty: rs.row.counterparty,
        remark: rs.row.remark,
        payMethod: rs.row.payMethod,
        orderId: rs.row.orderId,
        categoryId: rs.categoryId,
        isRefund: rs.row.isRefund,
      ));
    }
    if (selected.isEmpty) {
      _showMessage('未勾选任何可导入行');
      return;
    }
    final svc = ImportService(widget.database);
    try {
      final outcome = await svc.importRows(
          source: 'wechat', fileName: '粘贴导入', rows: selected);
      final sb = StringBuffer('已保存 ${outcome.saved} 笔 · 重复 ${outcome.duplicated}'
          ' · 退款冲抵 ${outcome.refunded} · 未匹配退款 ${outcome.refundUnmatched}');
      if (broken.isNotEmpty) sb.write(' · 跳过 ${broken.join('、')}');
      _showMessage(sb.toString());
    } on StateError catch (e) {
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checked = _rows.where((r) => r.ok).length;
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
        if (_previewed) ...[
          const SizedBox(height: 14),
          Text('已勾选 $checked / 共 ${_rows.length} · 错误 ${_errors.length}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_rows.length > 50) ...[
            const SizedBox(height: 6),
            Text('其余 ${_rows.length - 50} 行未显示',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length && i < 50; i++) ...[
            _RowCard(
                index: i,
                row: _rows[i],
                categories: _cats,
                onChanged: () => setState(() {})),
            const SizedBox(height: 8),
          ],
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('以下行解析失败（未入库）',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            for (final e in _errors)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('行 ${e.lineNo}：${e.reason}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
          ],
        ],
      ]),
    );
  }
}

/// 导入预览的单行可编辑状态（仅内存，不落库）。
class _RowState {
  _RowState({
    required this.row,
    required this.ok,
    required this.amountText,
  }) : controller = TextEditingController(text: amountText);
  final ImportedRow row;
  bool ok;
  String amountText;
  int? categoryId;
  final TextEditingController controller;
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.index,
    required this.row,
    required this.categories,
    required this.onChanged,
  });
  final int index;
  final _RowState row;
  final List<Category> categories;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final r = row.row;
    return Opacity(
      opacity: row.ok ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: row.ok ? null : const Color(0xFFF2F2F2),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Checkbox(
              key: Key('row_ok_$index'),
              value: row.ok,
              onChanged: (v) {
                row.ok = v ?? false;
                onChanged();
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                key: Key('row_amt_$index'),
                controller: row.controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixText: '¥ ',
                  labelText: '金额',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  row.amountText = v;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<int?>(
              key: Key('row_cat_$index'),
              value: row.categoryId,
              hint: const Text('分类'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('分类')),
                for (final c in categories)
                  DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) {
                row.categoryId = v;
                onChanged();
              },
            ),
          ]),
          const SizedBox(height: 6),
          Text('${r.counterparty.isEmpty ? '对方' : r.counterparty}'
              '${r.remark.isEmpty ? '' : ' · ${r.remark}'}'
              '${r.isRefund ? '（退款）' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }
}