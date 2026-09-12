class AiDraft {
  const AiDraft({
    required this.direction,
    required this.amountCents,
    this.counterparty = '',
    this.remark = '',
    this.category,
    this.bookAt,
  });
  final String direction; // income / expense
  final int amountCents;
  final String counterparty;
  final String remark;
  final String? category; // AI 建议分类名
  final DateTime? bookAt;
}

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}