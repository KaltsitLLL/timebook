import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/bookkeeping/presentation/budget_period_helper.dart';

void main() {
  test('startDay=22, now=9/12 → 本期 8/22 .. 9/21（闭区间 end 23:59:59.999）', () {
    final r = periodRangeFor(DateTime(2026, 9, 12), 22);
    expect(r.start, DateTime(2026, 8, 22));
    expect(r.end, DateTime(2026, 9, 21, 23, 59, 59, 999));
  });

  test('startDay=22, now=9/25 → 本期 9/22 .. 10/21', () {
    final r = periodRangeFor(DateTime(2026, 9, 25), 22);
    expect(r.start, DateTime(2026, 9, 22));
    expect(r.end, DateTime(2026, 10, 21, 23, 59, 59, 999));
  });

  test('startDay=15, now=9/12(<15) → 本期 8/15 .. 9/14', () {
    final r = periodRangeFor(DateTime(2026, 9, 12), 15);
    expect(r.start, DateTime(2026, 8, 15));
    expect(r.end, DateTime(2026, 9, 14, 23, 59, 59, 999));
  });

  test('startDay=1（自然月）→ 期 = 整月', () {
    final r = periodRangeFor(DateTime(2026, 9, 12), 1);
    expect(r.start, DateTime(2026, 9, 1));
    expect(r.end, DateTime(2026, 9, 30, 23, 59, 59, 999));
  });

  test('跨年：startDay=22, now=1/5 → 上期 12/22 .. 1/21', () {
    final r = periodRangeFor(DateTime(2027, 1, 5), 22);
    expect(r.start, DateTime(2026, 12, 22));
    expect(r.end, DateTime(2027, 1, 21, 23, 59, 59, 999));
  });
}