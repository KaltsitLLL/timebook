class ImportedRow {
  const ImportedRow({
    required this.bookAt,
    required this.direction,
    required this.amountCents,
    this.counterparty = '',
    this.remark = '',
    this.payMethod = '',
    this.orderId,
    this.isRefund = false,
  });
  final DateTime bookAt;
  final String direction; // income / expense / unknown
  final int amountCents;
  final String counterparty;
  final String remark;
  final String payMethod;
  final String? orderId;
  final bool isRefund;
}

class ParseErrorRow {
  const ParseErrorRow({required this.lineNo, required this.raw, required this.reason});
  final int lineNo;
  final String raw;
  final String reason;
}

class ParsedResult {
  ParsedResult({List<ImportedRow>? rows, List<ParseErrorRow>? errors})
      : rows = rows ?? [], errors = errors ?? [];
  final List<ImportedRow> rows;
  final List<ParseErrorRow> errors;
}