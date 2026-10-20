import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/bill_import_sources.dart';
import 'package:pocket_ledger/features/ledger/data/bill_io.dart';

void main() {
  group('decodeBillFileBytes', () {
    test('UTF-8 无 BOM 原样解码', () {
      final List<int> bytes = utf8.encode('交易时间,收/支\n2026-10-01,支出');
      expect(decodeBillFileBytes(bytes), '交易时间,收/支\n2026-10-01,支出');
    });
    test('UTF-8 BOM 自动剥离', () {
      final List<int> bytes = <int>[
        0xEF, 0xBB, 0xBF, ...utf8.encode('abc'),
      ];
      expect(decodeBillFileBytes(bytes), 'abc');
    });
    test('GBK 回退解码', () {
      // 「支付宝」三字的 GBK 字节（非法 UTF-8 序列）。
      final List<int> bytes = <int>[0xD6, 0xA7, 0xB8, 0xB6, 0xB1, 0xA6];
      expect(decodeBillFileBytes(bytes), '支付宝');
    });
  });

  group('detectSource', () {
    test('微信表头', () {
      expect(
        detectSource('交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式'),
        ImportSource.wechat,
      );
    });
    test('支付宝表头', () {
      expect(
        detectSource('记账日期,交易分类,交易对方,商品说明,收/支,金额,收/付款方式'),
        ImportSource.alipay,
      );
    });
    test('云闪付表头', () {
      expect(
        detectSource('交易日期,交易金额,收/支,卡号后四位,交易描述'),
        ImportSource.unionpay,
      );
    });
    test('本 App 导出不误判', () {
      expect(detectSource('日期,模块,类型,金额,账户,备注'), isNull);
    });
  });

  group('parseSource(alipay)', () {
    const String csv = '记账日期,业务类型,交易分类,交易对方,对方账号,商品说明,收/支,'
        '金额,收/付款方式,交易状态,交易订单号,商家订单号,备注\n'
        '2026-10-01 12:00:00,消费,餐饮美食,老王饭店,,午餐,支出,25.00,余额,交易成功,,,\n'
        '2026-10-02 08:00:00,退款,餐饮美食,老王饭店,,午餐退款,不计收支,25.00,余额,'
        '退款成功,,,\n'
        '2026-10-03 08:00:00,消费,交通出行,地铁,,通勤,支出,3.00,余额宝,交易关闭,,,\n'
        '2026-10-04 08:00:00,转账,手续费,银行,,提现,不计收支,2.00,余额,交易成功,,,';
    test('支出 / 退款转收入 / 关闭跳过 / 不计收支标记', () {
      final ParseResult r = parseSource(ImportSource.alipay, csv);
      expect(r.errors, isEmpty);
      expect(r.rows.length, 3);
      expect(r.rows[0].type, TxnType.expense);
      expect(r.rows[0].amountMinor, 2500);
      expect(r.rows[0].categoryName, '餐饮美食');
      expect(r.rows[0].accountName, '余额');
      expect(r.rows[0].counterparty, '老王饭店');
      // 退款行：收入 + 退款标签。
      expect(r.rows[1].type, TxnType.income);
      expect(r.rows[1].tags, contains('退款'));
      expect(r.rows[1].amountMinor, 2500);
      // 交易关闭行被跳过（共 4 数据行 → 3 行入库）。
      // 不计收支行：支出 + 双排除。
      expect(r.rows[2].excludeFromStats, isTrue);
      expect(r.rows[2].excludeFromBudget, isTrue);
    });
  });

  group('parseSource(wechat)', () {
    const String csv = '微信支付账单明细，起始时间：2026-10-01\n'
        '——————以下是账单明细——————\n'
        '交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,'
        '商户单号,备注\n'
        '2026-10-01 21:09:11,商户消费,小区便利店,早餐,支出,¥12.50,零钱,支付成功,'
        '10001,20001,\n'
        '2026-10-02 09:00:00,微信红包,张三,红包,收入,¥88.00,零钱,已存入零钱,'
        '10002,20002,过年好\n'
        '——————以下是账单汇总——————\n';
    test('跳过前导/尾部说明行，¥ 金额解析', () {
      final ParseResult r = parseSource(ImportSource.wechat, csv);
      expect(r.errors, isEmpty);
      expect(r.rows.length, 2);
      expect(r.rows[0].type, TxnType.expense);
      expect(r.rows[0].amountMinor, 1250);
      expect(r.rows[0].accountName, '零钱');
      expect(r.rows[0].categoryName, '商户消费');
      expect(r.rows[1].type, TxnType.income);
      expect(r.rows[1].amountMinor, 8800);
    });
  });

  group('parseSource(unionpay)', () {
    const String csv = '交易日期,交易类型,交易金额,收/支,卡号后四位,交易描述\n'
        '2026-10-01 12:00:00,消费,58.00,支出,1234,超市购物\n'
        '2026-10-02 12:00:00,还款,1000.00,不计收支,1234,信用卡还款\n';
    test('卡号建户 / 中性行标记', () {
      final ParseResult r = parseSource(ImportSource.unionpay, csv);
      expect(r.errors, isEmpty);
      expect(r.rows.length, 2);
      expect(r.rows[0].accountName, '银行卡尾号1234');
      expect(r.rows[0].amountMinor, 5800);
      expect(r.rows[1].excludeFromStats, isTrue);
    });
  });

  group('buildSourceTemplate', () {
    test('各来源模板表头可被自家解析器识别', () {
      for (final ImportSource s in ImportSource.values) {
        final String tpl = buildSourceTemplate(s);
        final ParseResult r = parseSource(s, tpl);
        expect(r.errors, isEmpty, reason: '${s.label} 模板应能被解析');
        if (s == ImportSource.pocketLedger ||
            s == ImportSource.blankTemplate) {
          // 本 App 模板为表头 + 注释，无示例行。
          expect(r.rows, isEmpty, reason: '${s.label} 模板无示例行');
        } else {
          expect(r.rows.length, 1, reason: '${s.label} 模板示例行应入库');
        }
      }
    });
  });

  group('extractCardLast4', () {
    test('云闪付自动账户名提取末四位', () {
      expect(extractCardLast4('银行卡尾号1234'), '1234');
    });
    test('非卡号账户名返回 null', () {
      expect(extractCardLast4('招商银行储蓄卡'), isNull);
      expect(extractCardLast4('零钱'), isNull);
      expect(extractCardLast4('余额宝'), isNull);
      expect(extractCardLast4('花呗'), isNull);
    });
    test('支付宝/微信括号卡号提取末四位（半角）', () {
      expect(extractCardLast4('招商银行储蓄卡(1234)'), '1234');
      expect(extractCardLast4('建设银行信用卡(5678)'), '5678');
    });
    test('支付宝/微信括号卡号（全角括号）', () {
      expect(extractCardLast4('招商银行信用卡（5678）'), '5678');
    });
    test('多组括号取最后一组', () {
      expect(extractCardLast4('旧卡(1111)新卡(2222)'), '2222');
    });
  });

  group('matchAccountByCardLast4', () {
    Account acc(
      String id,
      String name, {
      String? cardNumber,
      AccountType type = AccountType.bankCard,
      bool archived = false,
    }) =>
        Account(
          updatedAt: 0,
          deleted: false,
          dirty: false,
          id: id,
          bookId: 'b1',
          name: name,
          type: type,
          balanceMinor: 0,
          currency: 'CNY',
          status: archived ? AccountStatus.hidden : AccountStatus.active,
          includeInTotal: true,
          isArchived: archived,
          sortOrder: 0,
          cardNumber: cardNumber,
        );

    test('账户名含卡号即匹配', () {
      final List<Account> accounts = <Account>[
        acc('a1', '招商银行储蓄卡1234'),
        acc('a2', '零钱'),
      ];
      expect(matchAccountByCardLast4('1234', accounts), 'a1');
    });

    test('账户名不含卡号时按 cardNumber 末四位匹配', () {
      final List<Account> accounts = <Account>[
        acc('a1', '招商银行储蓄卡', cardNumber: '6225 8801 2345 6789 1234'),
        acc('a2', '零钱'),
      ];
      expect(matchAccountByCardLast4('1234', accounts), 'a1');
    });

    test('多命中优先银行类账户', () {
      final List<Account> accounts = <Account>[
        acc('cash', '钱包1234', type: AccountType.cash),
        acc('bank', '招行尾号', cardNumber: '1234'),
      ];
      expect(matchAccountByCardLast4('1234', accounts), 'bank');
    });

    test('无匹配返回 null', () {
      final List<Account> accounts = <Account>[acc('a1', '零钱')];
      expect(matchAccountByCardLast4('9999', accounts), isNull);
    });

    test('归档账户不参与匹配', () {
      final List<Account> accounts = <Account>[
        acc('a1', '招行卡', cardNumber: '1234', archived: true),
      ];
      expect(matchAccountByCardLast4('1234', accounts), isNull);
    });
  });
}
