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

final _arithToken = RegExp(r'-?\d+(\.\d+)?|[+\-*/]');

/// 解析金额算式为「分」。支持 `+ - * /`、多运算符**从左到右**、小数。
/// 非法（含除零/空/多余字符/末尾运算符）→ null。
/// 例：'500+800'→130000、'28.5*2'→5700、'100/4'→2500。
int? parseArithmeticToCents(String input) {
  final s = input.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  final toks = _arithToken.allMatches(s).map((m) => m.group(0)!).toList();
  if (toks.join('') != s) return null; // 存在无法识别的字符 → 非法
  final first = double.tryParse(toks.first);
  if (first == null) return null;
  var acc = first;
  var i = 1;
  while (i < toks.length) {
    final op = toks[i];
    final num = double.tryParse(toks[i + 1]);
    if (num == null) return null;
    switch (op) {
      case '+':
        acc += num;
      case '-':
        acc -= num;
      case '*':
        acc *= num;
      case '/':
        if (num == 0) return null;
        acc /= num;
      default:
        return null;
    }
    i += 2;
  }
  return (acc * 100).round();
}