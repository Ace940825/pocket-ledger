import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/account_io.dart';
import 'package:pocket_ledger/features/ledger/data/bill_import_sources.dart';
import 'package:pocket_ledger/features/ledger/data/bill_io.dart';
import 'package:pocket_ledger/features/ledger/data/bill_template.dart';
import 'package:pocket_ledger/features/ledger/presentation/bill_import_preview_page.dart';

/// 纯账户文件导入回归（2026-10-25 实机反馈「识别不到」）：
/// 33 张卡片截图整理的 v3 数据文件只有 `# [账户]` 段、账单段为空，
/// 旧导入链路三道门禁（开始导入 / 执行 / 校验）只看账单行，导致：
/// 选文件提示「已解析」→ 点「开始导入」却弹「请先选择账单文件」。
///
/// 本测试锁死修复后的行为：
/// ① 实机交付文件可解析出 33 个账户、0 账单行、0 错误（含免息期口径）；
/// ② hasImportableContent 纯账户文件判可导入；
/// ③ checkRows 对纯账户文件给出「新建 N 个」归集报告；
/// ④ 预览页对纯账户文件切账户口径（标题 / 总览 / 清单 / 确认按钮），
///    点确认 pop(true) 放行导入。
void main() {
  // 实机反馈的交付文件（与微信送达件字节一致，md5 相同）。
  final File delivered =
      File('deliverables/bill_import_accounts_filled_v3_2026-10-25_v2.csv');

  ParseResult parseDelivered() {
    final bytes = delivered.readAsBytesSync();
    return parseSource(
      ImportSource.blankTemplate,
      decodeBillFileBytes(bytes),
    );
  }

  TemplateCheckResult checkOf(ParseResult r) => checkRows(
        r.rows,
        accountNames: const <String>{},
        categoryNamesByType: const <Set<String>>[
          <String>{},
          <String>{},
          <String>{},
        ],
        accounts: r.accounts,
      );

  group('实机交付文件解析（复现「识别不到」现场）', () {
    test('33 账户 / 0 账单行 / 0 错误；免息期与固定还款日互斥', () {
      final ParseResult r = parseDelivered();
      expect(r.errors, isEmpty);
      expect(r.rows, isEmpty, reason: '账单段为空——正是旧门禁误拒的形态');
      expect(r.accounts, hasLength(33));
      // 固定还款日卡：还款日有值、免息期空。
      final AccountRow ic = r.accounts.firstWhere((a) => a.name == 'IC普卡');
      expect(ic.type, AccountType.creditCard);
      expect(ic.dueDay, 3);
      expect(ic.dueGraceDays, isNull);
      expect(ic.billingDay, 15);
      // 免息期卡：免息期 = 20、还款日留空（还款日期由账单日 + 免息期推算）。
      final AccountRow dream = r.accounts.firstWhere((a) => a.name == '梦卡白金卡');
      expect(dream.dueGraceDays, 20);
      expect(dream.dueDay, isNull);
      expect(dream.billingDay, 19);
      // 储蓄卡无任何日期字段。
      final AccountRow boc = r.accounts.firstWhere((a) => a.name == '中行储蓄');
      expect(boc.type, AccountType.bankCard);
      expect(boc.dueDay, isNull);
      expect(boc.dueGraceDays, isNull);
      expect(boc.cardNumber, '6216610100010608939');
    });

    test('hasImportableContent：纯账户文件判可导入（修复核心）', () {
      expect(hasImportableContent(parseDelivered()), isTrue);
      // 空文件（空白模板）仍判不可导入，门禁不会因此失灵。
      expect(
        hasImportableContent(const ParseResult(<BillRow>[], <String>[])),
        isFalse,
      );
    });

    test('checkRows：纯账户文件给出「新建 33 个」归集报告', () {
      final TemplateCheckResult c = checkOf(parseDelivered());
      expect(c.restoredAccounts, hasLength(33));
      expect(c.updatedAccounts, isEmpty);
      expect(c.errors, isEmpty);
    });
  });

  group('预览页账户口径（纯账户文件）', () {
    testWidgets('切账户口径且确认后 pop(true) 放行导入', (tester) async {
      final ParseResult r = parseDelivered();
      bool? popped;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => BillImportPreviewPage(
                          parsed: r,
                          check: checkOf(r),
                        ),
                      ),
                    );
                  },
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      // 标题切账户口径。
      expect(find.text('账户导入预览'), findsOneWidget);
      expect(find.text('账单导入预览'), findsNothing);
      // 总览：账户段 33 个 / 将新建 33 个 / 将覆盖 0 个。
      expect(find.text('33 个账户'), findsOneWidget);
      expect(find.text('33 个（已存在则跳过）'), findsOneWidget);
      // 清单：账户名 + 类型 / 尾号副标题（ListView 懒加载，滚动到可见）。
      await tester.scrollUntilVisible(
        find.text('IC普卡'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('IC普卡'), findsOneWidget);
      expect(find.textContaining('尾号1345'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('梦卡白金卡'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('梦卡白金卡'), findsOneWidget);
      // 确认按钮为账户口径（底部固定栏，不受滚动影响）。
      expect(find.text('确认导入账户'), findsOneWidget);
      expect(find.text('确认导入账单'), findsNothing);

      // 点确认 → pop(true)（真实链路里配置页据此执行导入）。
      await tester.tap(find.text('确认导入账户'));
      await tester.pumpAndSettle();
      expect(popped, isTrue);
    });

    testWidgets('账单文件仍走账单口径（不回归）', (tester) async {
      final ParseResult billsOnly = ParseResult(
        <BillRow>[
          BillRow(
            occurredAt: DateTime(2026, 10, 25, 12, 30),
            type: TxnType.expense,
            amountMinor: 2550,
            accountName: '微信',
          ),
        ],
        <String>[],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BillImportPreviewPage(parsed: billsOnly),
        ),
      );
      expect(find.text('账单导入预览'), findsOneWidget);
      expect(find.text('确认导入账单'), findsOneWidget);
      expect(find.text('账户导入预览'), findsNothing);
    });
  });
}
