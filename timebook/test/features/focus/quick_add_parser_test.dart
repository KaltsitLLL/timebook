import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/focus/domain/quick_add_parser.dart';

void main() {
  test('解析 标题+项目+时长+标签+日期', () {
    final d = parseQuickAdd('整理周报 +work 45m @明天 #汇总');
    expect(d.title, '整理周报');
    expect(d.project, 'work');
    expect(d.estimateMinutes, 45);
    expect(d.tags, ['汇总']);
    expect(d.dueDate, isNotNull);
  });

  test('无修饰符仅标题', () {
    final d = parseQuickAdd('就买点水果');
    expect(d.title, '就买点水果');
    expect(d.project, isNull);
    expect(d.estimateMinutes, 25);
  });

  test('时长货币 1h/2.5h 与缺省', () {
    expect(parseQuickAdd('写代码 1h').estimateMinutes, 60);
    expect(parseQuickAdd('画图 2.5h').estimateMinutes, 150);
    expect(parseQuickAdd('无时长的任务').estimateMinutes, 25);
  });

  test('中文日期 @今天/明天/周五', () {
    expect(parseQuickAdd('a @今天').dueDate, isNotNull);
    expect(parseQuickAdd('b @明天').dueDate, isNotNull);
    expect(parseQuickAdd('c @周五').dueDate, isNotNull);
    expect(parseQuickAdd('d').dueDate, isNull);
  });
}