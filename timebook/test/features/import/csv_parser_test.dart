import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/import/domain/csv_parser.dart';

void main() {
  test('基础行与表头解析（含 BOM）', () {
    const csv = '\uFEFF交易时间,交易类型,交易对方,金额(元),收/支\n'
        '2026-09-12 12:00:00,商户消费,美团外卖,28.50,支出\n'
        '2026-09-11 09:00:00,商户消费,瑞幸咖啡,19.90,支出\n';
    final rows = CsvRowParser.parse(csv);
    expect(rows, hasLength(2));
    expect(rows.first['交易对方'], '美团外卖');
    expect(rows.first['金额(元)'], '28.50');
  });

  test('引号与逗号转义', () {
    const csv = 'a,b\n"x,1","he said ""hi"""\n';
    final rows = CsvRowParser.parse(csv);
    expect(rows.first['a'], 'x,1');
    expect(rows.first['b'], 'he said "hi"');
  });

  test('CRLF 混合换行与空行忽略', () {
    const csv = 'a,b\r\n1,2\r\n\r\n3,4\n';
    final rows = CsvRowParser.parse(csv);
    expect(rows, hasLength(2));
  });
}