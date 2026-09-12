import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00');

/// 金额（分）→ 千分位字符串，如 846750 → '8,467.50'
String formatCents(int cents) => _money.format(cents / 100);

/// DateTime → 'yyyy-MM'
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// 'yyyy-MM' → '9月'
String monthShort(String key) {
  final parts = key.split('-');
  return '${int.parse(parts[1])}月';
}

/// 'yyyy-MM' 的上月（跨年正确）
String prevMonthKey(String key) {
  final parts = key.split('-');
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final shifted = DateTime(y, m - 1, 1);
  return monthKey(shifted);
}