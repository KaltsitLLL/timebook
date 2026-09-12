/// 逐行 CSV 解析：支持引号包裹/逗号转义/CRLF 与 LF；剥离 UTF-8 BOM；
/// 跳过空行；返回 `List<Map<String,String>>`（第一行为表头）。
class CsvRowParser {
  static List<Map<String, String>> parse(String raw) {
    var text = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = <String>[];
    final buf = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '\n' && !inQuote) {
        lines.add(buf.toString());
        buf.clear();
        continue;
      }
      // 行内保留原始引号结构，交由 _split 二次解释，避免破坏列内逗号/转义引号。
      buf.write(ch);
      if (ch == '"') {
        if (inQuote && i + 1 < text.length && text[i + 1] == '"') {
          i++; // 保留 `""`（两字符）作为转义引号
          buf.write('"');
        } else {
          inQuote = !inQuote;
        }
      }
    }
    if (buf.isNotEmpty) lines.add(buf.toString());

    if (lines.isEmpty) return const [];
    final headers = _split(lines.first);
    final result = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final cells = _split(line);
      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i]] = i < cells.length ? cells[i].trim() : '';
      }
      result.add(row);
    }
    return result;
  }

  static List<String> _split(String line) {
    final cells = <String>[];
    final buf = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuote && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuote = !inQuote;
        }
      } else if (ch == ',' && !inQuote) {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    cells.add(buf.toString());
    return cells;
  }
}