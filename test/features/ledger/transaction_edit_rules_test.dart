import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/features/ledger/data/transaction_edit_rules.dart';

/// `resolveEditIdentity` 的规则测试。
///
/// 锁死的不变量（也是真实事故的教训）：
/// - `TxnType.transfer` ⟺ `SourceModule.transfer`；
/// - 非转账 ⟹ `toAccountId == null && transferGroupId == null`；
/// - `SourceModule.refund` ⟹ `TxnType.income`。
void main() {
  TransactionEditIdentity resolve({
    required TxnType newType,
    SourceModule current = SourceModule.ledger,
    String? currentToAccountId,
    String? currentTransferGroupId,
    SourceModule? override,
  }) {
    return resolveEditIdentity(
      newType: newType,
      currentSourceModule: current,
      currentToAccountId: currentToAccountId,
      currentTransferGroupId: currentTransferGroupId,
      overrideSourceModule: override,
    );
  }

  group('转账身份', () {
    test('转账 → 转账：sourceModule 归位为 transfer，两个附属字段保留', () {
      final TransactionEditIdentity r = resolve(
        newType: TxnType.transfer,
        current: SourceModule.ledger,
        currentToAccountId: 'B',
        currentTransferGroupId: 'g1',
      );
      expect(r.sourceModule, SourceModule.transfer);
      expect(r.toAccountId, 'B');
      expect(r.transferGroupId, 'g1');
    });

    test('转账 → 支出：转账标记与转入账户、分组全部清掉', () {
      final TransactionEditIdentity r = resolve(
        newType: TxnType.expense,
        current: SourceModule.transfer,
        currentToAccountId: 'B',
        currentTransferGroupId: 'g1',
      );
      expect(r.sourceModule, SourceModule.ledger, reason: '转账身份失效后回到日常记账');
      expect(r.toAccountId, isNull, reason: '否则这条支出会凭 toAccountId 出现在转入方明细里');
      expect(r.transferGroupId, isNull);
    });

    test('转账 → 收入：同样清理干净', () {
      final TransactionEditIdentity r = resolve(
        newType: TxnType.income,
        current: SourceModule.transfer,
        currentToAccountId: 'B',
        currentTransferGroupId: 'g1',
      );
      expect(r.sourceModule, SourceModule.ledger);
      expect(r.toAccountId, isNull);
      expect(r.transferGroupId, isNull);
    });
  });

  group('退款身份', () {
    test('退款保持收入：标记原样保留（它确实是退款）', () {
      final TransactionEditIdentity r = resolve(
        newType: TxnType.income,
        current: SourceModule.refund,
      );
      expect(r.sourceModule, SourceModule.refund);
    });

    test('退款改成支出：退款标记失效', () {
      final TransactionEditIdentity r = resolve(
        newType: TxnType.expense,
        current: SourceModule.refund,
      );
      expect(r.sourceModule, SourceModule.ledger);
    });

    test('显式 override 为 ledger：把误标的退款修回普通收入', () {
      final TransactionEditIdentity r = resolve(
        newType: TxnType.income,
        current: SourceModule.refund,
        override: SourceModule.ledger,
      );
      expect(r.sourceModule, SourceModule.ledger);
    });

    test('显式 override 为 refund：把普通收入标成退款', () {
      final TransactionEditIdentity r = resolve(
        newType: TxnType.income,
        current: SourceModule.ledger,
        override: SourceModule.refund,
      );
      expect(r.sourceModule, SourceModule.refund);
    });

    test('override 为 refund 但新类型是支出：仍被退款失效规则拦住', () {
      final TransactionEditIdentity r = resolve(
        newType: TxnType.expense,
        current: SourceModule.refund,
        override: SourceModule.refund,
      );
      expect(r.sourceModule, SourceModule.ledger);
    });
  });

  group('业务出处保留', () {
    test('报销流水在收支之间切换时不丢出处', () {
      for (final TxnType t in <TxnType>[TxnType.expense, TxnType.income]) {
        final TransactionEditIdentity r = resolve(
          newType: t,
          current: SourceModule.reimbursement,
        );
        expect(r.sourceModule, SourceModule.reimbursement, reason: '$t');
      }
    });

    test('借还 / 分期 / 投资等出处同样保留', () {
      for (final SourceModule m in <SourceModule>[
        SourceModule.lend,
        SourceModule.installment,
        SourceModule.investment,
        SourceModule.savings,
        SourceModule.inventory,
      ]) {
        expect(resolve(newType: TxnType.income, current: m).sourceModule, m);
        expect(resolve(newType: TxnType.expense, current: m).sourceModule, m);
      }
    });

    test('但改成转账时，转账身份覆盖任何出处', () {
      for (final SourceModule m in SourceModule.values) {
        expect(
          resolve(newType: TxnType.transfer, current: m).sourceModule,
          SourceModule.transfer,
          reason: '$m → transfer',
        );
      }
    });
  });

  group('不变量穷举（对每个「来源 × 新类型」组合）', () {
    test('三条不变量恒成立', () {
      for (final SourceModule current in SourceModule.values) {
        for (final TxnType newType in TxnType.values) {
          final TransactionEditIdentity r = resolve(
            newType: newType,
            current: current,
            currentToAccountId: 'B',
            currentTransferGroupId: 'g1',
          );
          final String where = '$current → $newType';

          if (newType == TxnType.transfer) {
            expect(r.sourceModule, SourceModule.transfer, reason: where);
          } else {
            expect(r.toAccountId, isNull, reason: '$where: 非转账不得有转入账户');
            expect(r.transferGroupId, isNull, reason: '$where: 非转账不得有转账分组');
          }

          // 退款 ⟹ 收入。注意反过来不成立：退款保持收入时**应当**继续是退款。
          if (r.sourceModule == SourceModule.refund) {
            expect(newType, TxnType.income, reason: '$where: 退款必然是收入');
          }
        }
      }
    });

    test('穷举中「退款保持收入」是唯一允许保留 refund 的组合', () {
      final List<String> kept = <String>[];
      for (final SourceModule current in SourceModule.values) {
        for (final TxnType newType in TxnType.values) {
          final TransactionEditIdentity r = resolve(
            newType: newType,
            current: current,
            currentToAccountId: 'B',
            currentTransferGroupId: 'g1',
          );
          if (r.sourceModule == SourceModule.refund) {
            kept.add('$current → $newType');
          }
        }
      }
      expect(kept, <String>['SourceModule.refund → TxnType.income']);
    });
  });
}
