import 'package:intl/intl.dart';

class QuickAddDraft {
  const QuickAddDraft({
    required this.title,
    this.project,
    this.estimateMinutes = 25,
    this.tags = const [],
    this.dueDate,
  });
  final String title;
  final String? project;
  final int estimateMinutes;
  final List<String> tags;
  final DateTime? dueDate;
}

/// 短语法：`标题 [+项目] [25m|1h|2.5h] [#tag...] [@今天|明天|周X]`
QuickAddDraft parseQuickAdd(String raw) {
  final parts = raw.trim().split(RegExp(r'\s+'));
  final titleParts = <String>[];
  String? project;
  int minutes = 25;
  final tags = <String>[];
  DateTime? due;

  for (final p in parts) {
    if (p.startsWith('+') && p.length > 1) {
      project = p.substring(1);
    } else if (p.startsWith('#') && p.length > 1) {
      tags.add(p.substring(1));
    } else if (RegExp(r'^\d+(\.\d+)?m$').hasMatch(p)) {
      minutes = (double.parse(p.substring(0, p.length - 1))).round();
    } else if (RegExp(r'^\d+(\.\d+)?h$').hasMatch(p)) {
      minutes = (double.parse(p.substring(0, p.length - 1)) * 60).round();
    } else if (p.startsWith('@')) {
      due = _parseDate(p.substring(1));
    } else {
      titleParts.add(p);
    }
  }

  return QuickAddDraft(
    title: titleParts.join(' '),
    project: project,
    estimateMinutes: minutes <= 0 ? 25 : minutes,
    tags: tags,
    dueDate: due,
  );
}

DateTime? _parseDate(String token) {
  final now = DateTime.now();
  switch (token) {
    case '今天':
      return DateTime(now.year, now.month, now.day);
    case '明天':
      return DateTime(now.year, now.month, now.day + 1);
    case '后天':
      return DateTime(now.year, now.month, now.day + 2);
  }
  if (token.startsWith('周') || token.startsWith('星期')) {
    const names = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '日': 7,
      '天': 7,
    };
    final day = names[token.substring(1)];
    if (day != null) {
      final cur = DateTime(now.year, now.month, now.day);
      final delta = (day - cur.weekday + 7) % 7;
      return cur.add(Duration(days: delta == 0 ? 7 : delta));
    }
  }
  final parsed = DateFormat('yyyy-MM-dd').tryParse(token);
  return parsed;
}