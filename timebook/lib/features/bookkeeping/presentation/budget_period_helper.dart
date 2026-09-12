/// 自定义起始日的预算期范围（闭区间：end 为期最后一天 23:59:59.999）。
class PeriodRange {
  const PeriodRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// 按「发薪日」起始日计算当前预算期（startDay 1-28）。
/// now.day < startDay → 本期 = 上月 startDay .. 本月 startDay-1；
/// 否则本期 = 本月 startDay .. 下月 startDay-1。end 为闭区间最后时刻。
PeriodRange periodRangeFor(DateTime now, int startDay) {
  final anchor = DateTime(now.year, now.month, startDay);
  if (now.isBefore(anchor)) {
    return PeriodRange(
      DateTime(now.year, now.month - 1, startDay),
      DateTime(now.year, now.month, startDay - 1, 23, 59, 59, 999),
    );
  }
  return PeriodRange(
    anchor,
    DateTime(now.year, now.month + 1, startDay - 1, 23, 59, 59, 999),
  );
}

/// 预算存储键月 = 周期起始日所在月（零迁移口径）。
/// date.day >= startDay → 当月，否则上月（yyyy-MM）。
String budgetCycleKeyMonth(DateTime date, int startDay) {
  final y = date.year;
  final m = date.month;
  if (date.day >= startDay) {
    return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
  }
  final prev = DateTime(y, m - 1);
  return '${prev.year.toString().padLeft(4, '0')}-'
      '${prev.month.toString().padLeft(2, '0')}';
}