import 'package:yaml/yaml.dart';

import 'csv_parser.dart';
import 'import_models.dart';

class _ColSpec {
  String header = '';
  String target = '';
  String parse = '';
  List<String> clean = const [];
  Map<String, String> map = const {};
}

/// 声明式 YAML 模板引擎：解析 CSV → 按列映射 + 字段管道（map/clean/decimal）→ ImportedRow。
/// 任何字段解析异常都会进入 [ParsedResult.errors]，绝不静默丢行。
class TemplateEngine {
  TemplateEngine({required String templateYaml}) {
    final doc = loadYaml(templateYaml) as YamlMap;
    for (final raw in (doc['columns'] as YamlList).cast<YamlMap>()) {
      final c = _ColSpec()
        ..header = raw['header'] as String
        ..target = raw['target'] as String;
      if (raw.containsKey('parse')) c.parse = raw['parse'] as String;
      if (raw.containsKey('clean')) {
        c.clean = (raw['clean'] as YamlList).map((e) => e.toString()).toList();
      }
      if (raw.containsKey('map')) {
        c.map = (raw['map'] as YamlMap)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      _cols.add(c);
    }
    final skips = doc['skip_rows'] as YamlList? ?? const [];
    _skipTexts = skips.map((s) => (s as YamlMap)['contains'] as String).toList();
    final refunds = doc['refund_markers'] as YamlList? ?? const [];
    _refundMarkers = refunds.map((e) => e.toString()).toList();
  }

  final List<_ColSpec> _cols = [];
  late final List<String> _skipTexts;
  late final List<String> _refundMarkers;

  ParsedResult parse(String csv) {
    final rawRows = CsvRowParser.parse(csv);
    final result = ParsedResult();
    var lineNo = 0;
    for (final raw in rawRows) {
      lineNo++;
      final joined = raw.values.join(',');
      if (_skipTexts.any(joined.contains)) continue;

      final values = <String, String>{};
      for (final c in _cols) {
        var val = raw[c.header] ?? '';
        if (c.map.isNotEmpty) val = c.map[val] ?? val;
        for (final op in c.clean) {
          if (op == 'trim') val = val.trim();
        }
        values[c.target] = val;
      }

      // 退款标记：交易类型/对方/备注任一段含标记 → isRefund
      final kindText = '${values['transKind'] ?? ''}'
          '${values['counterparty'] ?? ''}'
          '${values['remark'] ?? ''}';
      final isRefund = _refundMarkers.any(kindText.contains);

      try {
        result.rows.add(_buildRow(values, isRefund));
      } catch (e) {
        result.errors
            .add(ParseErrorRow(lineNo: lineNo, raw: joined, reason: e.toString()));
      }
    }
    return result;
  }

  ImportedRow _buildRow(Map<String, String> v, bool isRefund) {
    final amountStr = v['amount'] ?? '';
    final amount = double.tryParse(amountStr);
    if (amount == null) throw Exception('金额无法解析: $amountStr');

    final direction = v['direction'];
    final dir = direction == 'income'
        ? 'income'
        : direction == 'unknown'
            ? 'unknown'
            : 'expense';

    final bookAt = DateTime.tryParse(v['bookAt'] ?? '');
    if (bookAt == null) throw Exception('日期无法解析: ${v['bookAt']}');

    return ImportedRow(
      bookAt: bookAt,
      direction: dir,
      amountCents: (amount * 100).round(),
      counterparty: v['counterparty'] ?? '',
      remark: v['remark'] ?? '',
      payMethod: v['payMethod'] ?? '',
      orderId: (v['orderId']?.isEmpty ?? true) ? null : v['orderId'],
      isRefund: isRefund,
    );
  }
}