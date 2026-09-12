import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/util/formats.dart';

void main() {
  test('formatCents 千分位+两位小数', () {
    expect(formatCents(846750), '8,467.50');
    expect(formatCents(2850), '28.50');
    expect(formatCents(0), '0.00');
  });

  test('monthKey 为 yyyy-MM 且 monthShort 为中文月', () {
    expect(monthKey(DateTime(2026, 9, 12)), '2026-09');
    expect(monthShort('2026-09'), '9月');
  });

  test('prevMonthKey 返回上月', () {
    expect(prevMonthKey('2026-09'), '2026-08');
    expect(prevMonthKey('2026-01'), '2025-12');
  });
}