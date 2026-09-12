import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:timebook/features/import/domain/csv_codec.dart';

void main() {
  test('UTF-8 字节正常解码', () {
    final text = '交易时间,交易对方\n2026-09-12,美团外卖';
    expect(decodeCsvBytes(utf8.encode(text)), text);
  });

  test('GBK 字节（中文）按 GBK 解码', () {
    final gbkBytes = gbk.encode('交易时间,交易对方\n2026-09-12,美团外卖');
    final decoded = decodeCsvBytes(gbkBytes);
    expect(decoded, contains('美团外卖'));
  });
}