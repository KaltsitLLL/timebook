import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/features/import/domain/template_engine.dart';

const String wechatTemplateYaml = '''
source: wechat
skip_rows:
  - {contains: "合计"}
  - {contains: "本交易为推广"}
columns:
  - {header: "交易时间", target: bookAt, parse: datetime}
  - {header: "交易类型", target: transKind}
  - {header: "交易对方", target: counterparty, clean: [trim]}
  - {header: "商品", target: remark}
  - {header: "收/支", target: direction, map: {收入: income, 支出: expense, "/": unknown}}
  - {header: "金额(元)", target: amount, parse: decimal}
  - {header: "支付方式", target: payMethod}
  - {header: "交易单号", target: orderId}
refund_markers: ["退款", "已退款"]
''';

void main() {
  test('微信模板：字段映射/方向/金额转分/错误行显式收集', () {
    const csv = '交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,交易单号\n'
        '2026-09-12 12:00:00,商户消费,美团外卖,午餐,支出,28.50,零钱,WX123\n'
        '合计,,,,\n'
        '2026-09-11 09:00:00,商户消费,瑞幸咖啡,生椰,支出,19.90,零钱,WX124\n'
        '2026-09-10 08:00:00,退款,美团外卖,退款,收入,-28.50,零钱,WX125\n';
    final engine = TemplateEngine(templateYaml: wechatTemplateYaml);
    final result = engine.parse(csv);

    // 合计行被跳过；退款行仍进入 rows 且 isRefund=true（供 ImportService 冲抵）。
    expect(result.rows, hasLength(3));
    expect(result.errors, isEmpty);
    final r0 = result.rows.first;
    expect(r0.counterparty, '美团外卖');
    expect(r0.amountCents, 2850);
    expect(r0.direction, 'expense');
    expect(r0.isRefund, isFalse);
    final refund = result.rows.last;
    expect(refund.counterparty, '美团外卖');
    expect(refund.isRefund, isTrue);
    expect(refund.direction, 'income');
    expect(refund.amountCents, -2850);
  });

  test('金额/日期非法时进入 errors 而非静默丢弃', () {
    const csv = '交易时间,交易对方,金额(元),收/支\n'
        '2026-09-12,美团外卖,abc,支出\n'
        'bad-date,滴滴,10.00,支出\n';
    final engine = TemplateEngine(templateYaml: wechatTemplateYaml);
    final result = engine.parse(csv);
    expect(result.rows, isEmpty);
    expect(result.errors, hasLength(2));
    expect(result.errors.first.reason, contains('金额'));
  });

  test('合计/广告行跳过规则', () {
    const csv = '交易时间,交易类型,交易对方,金额(元),收/支\n'
        '2026-09-12,商户消费,美团,1.00,支出\n'
        '合计,,\n';
    final engine = TemplateEngine(templateYaml: wechatTemplateYaml);
    final result = engine.parse(csv);
    expect(result.rows, hasLength(1));
  });
}