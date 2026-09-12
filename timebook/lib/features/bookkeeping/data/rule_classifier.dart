/// 纯函数规则引擎：按关键词自动分类。
class RuleClassifier {
  RuleClassifier._();

  /// 按 priority 降序，取首个「关键词包含命中」的规则 → categoryId；未命中返回 null。
  static int? classify({
    required String text,
    required List<(String keyword, int categoryId, int priority)> rules,
  }) {
    final sorted = [...rules]..sort((a, b) => b.$3.compareTo(a.$3));
    for (final r in sorted) {
      if (text.contains(r.$1)) return r.$2;
    }
    return null;
  }
}