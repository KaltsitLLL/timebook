import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/bookkeeping/data/rule_classifier.dart';

void main() {
  test('高 priority 规则优先命中', () {
    final r = RuleClassifier.classify(
        text: '美团外卖',
        rules: [
          ('美团', 1, 1),
          ('外卖', 2, 9), // priority 更高 → 优先
        ]);
    expect(r, 2);
  });

  test('包含命中：counterparty/remark 拼合文本含关键词即命中', () {
    final r = RuleClassifier.classify(
        text: '星巴克·咖啡油菜' /* 伪 */,
        rules: [('咖啡', 7, 3)]);
    expect(r, 7);
  });

  test('未命中返回 null', () {
    final r = RuleClassifier.classify(
        text: '滴滴出行',
        rules: [('美团', 1, 5), ('饿了么', 2, 4)]);
    expect(r, isNull);
  });

  test('priority 相同时按出现顺序取先者（稳定排序）', () {
    final r = RuleClassifier.classify(
        text: '美团外卖',
        rules: [
          ('美团', 1, 2),
          ('外卖', 2, 2), // 同 priority → 保留原顺序，优先第一个
        ]);
    expect(r, 1);
  });
}