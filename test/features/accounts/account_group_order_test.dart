import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/accounts/data/account_group_order.dart';

/// 账户分组拖拽排序的下标语义回归测试。
///
/// 历史 bug：账户页从 `ReorderableListView.onReorder`（旧回调，需要手动
/// `newIndex -= 1`）迁移到 `SliverReorderableList.onReorderItem`（新回调，
/// newIndex 已自动修正）时，`reorder()` 里残留了手动 `-1`，导致**往下拖时
/// 落点偏一格**。这个测试把语义钉死。
void main() {
  const List<String> base = <String>[
    '资金类',
    '负债类',
    '投资类',
    '应收类',
    '应付类',
  ];

  group('AccountGroupOrderNotifier.applyReorder', () {
    test('默认顺序与常量一致（防止分组增删后测试静默失效）', () {
      expect(kAccountGroupOrderDefault, base);
    });

    test('往下拖：0 -> 2（onReorderItem 语义，不再额外 -1）', () {
      final List<String> result =
          AccountGroupOrderNotifier.applyReorder(base, 0, 2);
      expect(result, <String>['负债类', '投资类', '资金类', '应收类', '应付类']);
    });

    test('往下拖到末尾：0 -> 4', () {
      final List<String> result =
          AccountGroupOrderNotifier.applyReorder(base, 0, 4);
      expect(result, <String>['负债类', '投资类', '应收类', '应付类', '资金类']);
    });

    test('往上拖：3 -> 1', () {
      final List<String> result =
          AccountGroupOrderNotifier.applyReorder(base, 3, 1);
      expect(result, <String>['资金类', '应收类', '负债类', '投资类', '应付类']);
    });

    test('往上拖到头部：4 -> 0', () {
      final List<String> result =
          AccountGroupOrderNotifier.applyReorder(base, 4, 0);
      expect(result, <String>['应付类', '资金类', '负债类', '投资类', '应收类']);
    });

    test('相邻互换：1 <-> 2', () {
      expect(
        AccountGroupOrderNotifier.applyReorder(base, 1, 2),
        <String>['资金类', '投资类', '负债类', '应收类', '应付类'],
      );
      expect(
        AccountGroupOrderNotifier.applyReorder(base, 2, 1),
        <String>['资金类', '投资类', '负债类', '应收类', '应付类'],
      );
    });

    test('原地不动：2 -> 2 顺序不变', () {
      expect(AccountGroupOrderNotifier.applyReorder(base, 2, 2), base);
    });

    test('newIndex 超出长度时 clamp 到末尾，不抛异常', () {
      expect(
        AccountGroupOrderNotifier.applyReorder(base, 0, 99),
        <String>['负债类', '投资类', '应收类', '应付类', '资金类'],
      );
    });

    test('oldIndex 越界时原样返回，不抛异常', () {
      expect(AccountGroupOrderNotifier.applyReorder(base, -1, 2), base);
      expect(AccountGroupOrderNotifier.applyReorder(base, 5, 0), base);
    });

    test('不修改入参，返回的是新列表', () {
      final List<String> source = List<String>.from(base);
      final List<String> result =
          AccountGroupOrderNotifier.applyReorder(source, 0, 3);
      expect(source, base, reason: '入参必须保持不变');
      expect(identical(source, result), isFalse, reason: '必须是新列表');
    });

    test('连续拖拽累积生效（模拟用户拖两次）', () {
      List<String> state = List<String>.from(base);
      state = AccountGroupOrderNotifier.applyReorder(state, 4, 0); // 应付类提到最前
      state = AccountGroupOrderNotifier.applyReorder(state, 2, 4); // 投资类挪到最后
      expect(state, <String>['应付类', '资金类', '投资类', '应收类', '负债类']);
    });
  });

  /// 账户页会**隐藏空分组**（「应收这种没有设置的账户不显示」），
  /// 于是 `SliverReorderableList` 的下标是「可见序列」的下标，
  /// 而持久化用的是「完整序列」。两者错位时若直接套用可见下标
  /// 就会**移动错分组**，甚至把隐藏分组弄丢。
  group('AccountGroupOrderNotifier.applyVisibleReorder', () {
    // 隐藏「投资类」「应收类」（空分组）后的可见序列。
    const List<String> visibleNoInvest = <String>['资金类', '负债类', '应付类'];


    test('可见项往前挪：隐藏分组保持原位、被移动项落到锚点之前', () {
      final List<String> result = AccountGroupOrderNotifier.applyVisibleReorder(
        base,
        visibleNoInvest,
        0, // 资金类
        1, // 挪到「负债类」之后
      );
      // 还原成可见序列应是 [负债类, 资金类, 应付类]，
      // 完整序列里「资金类」紧跟在「负债类」之前。
      expect(result, <String>['负债类', '投资类', '应收类', '资金类', '应付类']);
    });

    test('可见项往前挪到头部：插到锚点前，隐藏分组留在原处', () {
      final List<String> result = AccountGroupOrderNotifier.applyVisibleReorder(
        base,
        visibleNoInvest,
        2, // 应付类
        0, // 提到可见序列最前
      );
      // 完整序列里「应付类」插到「资金类」之前；投资 / 应收这两个隐藏分组不动。
      expect(result, <String>['应付类', '资金类', '负债类', '投资类', '应收类']);
    });

    test('挪到可见末尾：追加到完整序列末尾，且不丢任何分组', () {
      final List<String> result = AccountGroupOrderNotifier.applyVisibleReorder(
        base,
        visibleNoInvest,
        0, // 资金类
        2, // 挪到可见序列最后
      );
      expect(result, <String>['负债类', '投资类', '应收类', '应付类', '资金类']);
      expect(
        result.toSet(),
        base.toSet(),
        reason: '隐藏分组绝不能被丢弃',
      );
      expect(result.length, base.length);
    });

    test('隐藏分组在可见项之后时，尾部隐藏分组保持相对顺序', () {
      // 隐藏「负债类」「应付类」
      const List<String> visibleHead = <String>['资金类', '投资类', '应收类'];
      final List<String> result = AccountGroupOrderNotifier.applyVisibleReorder(
        base,
        visibleHead,
        2, // 应收类
        0, // 提到最前
      );
      expect(result, <String>['应收类', '资金类', '负债类', '投资类', '应付类']);
    });

    test('原地不动（oldIndex == newIndex）不改变任何东西', () {
      expect(
        AccountGroupOrderNotifier.applyVisibleReorder(
          base,
          visibleNoInvest,
          1,
          1,
        ),
        base,
      );
    });

    test('只有一项可见时，无位移的落点不会把它甩到末尾', () {
      // 回归：visible 长度为 1 时，insertAt(0) >= length-1(0) 恒成立，
      // 若不加 oldIndex == newIndex 短路，0 -> 0 会把该项追加到完整末尾。
      const List<String> onlyCapital = <String>['资金类'];
      expect(
        AccountGroupOrderNotifier.applyVisibleReorder(
          base,
          onlyCapital,
          0,
          0,
        ),
        base,
      );
    });

    test('全部可见时与 applyReorder 完全等价（向后兼容）', () {
      for (int from = 0; from < base.length; from++) {
        for (int to = 0; to < base.length; to++) {
          expect(
            AccountGroupOrderNotifier.applyVisibleReorder(base, base, from, to),
            AccountGroupOrderNotifier.applyReorder(base, from, to),
            reason: 'from=$from to=$to 时必须与旧逻辑一致',
          );
        }
      }
    });

    test('oldIndex 越界时原样返回，不抛异常', () {
      expect(
        AccountGroupOrderNotifier.applyVisibleReorder(
            base, visibleNoInvest, -1, 0),
        base,
      );
      expect(
        AccountGroupOrderNotifier.applyVisibleReorder(
            base, visibleNoInvest, 3, 0),
        base,
      );
    });

    test('newIndex 超出长度时 clamp 到可见末尾，不抛异常', () {
      final List<String> result = AccountGroupOrderNotifier.applyVisibleReorder(
        base,
        visibleNoInvest,
        0,
        99,
      );
      expect(result, <String>['负债类', '投资类', '应收类', '应付类', '资金类']);
    });

    test('不修改入参，返回的是新列表', () {
      final List<String> full = List<String>.from(base);
      final List<String> visible = List<String>.from(visibleNoInvest);
      final List<String> result =
          AccountGroupOrderNotifier.applyVisibleReorder(full, visible, 0, 2);
      expect(full, base, reason: 'full 入参必须保持不变');
      expect(visible, visibleNoInvest, reason: 'visible 入参必须保持不变');
      expect(identical(full, result), isFalse, reason: '必须是新列表');
    });

    test('任意可见子集 + 任意落点：永不丢分组、永不重复', () {
      // 穷举所有「保持相对顺序」的可见子集（共 2^5 - 1 = 31 个），
      // 以及所有 (oldIndex, newIndex) 组合，验证核心不变量。
      for (int mask = 1; mask < (1 << base.length); mask++) {
        final List<String> visible = <String>[
          for (int i = 0; i < base.length; i++)
            if (mask & (1 << i) != 0) base[i],
        ];
        for (int from = 0; from < visible.length; from++) {
          for (int to = -1; to <= visible.length; to++) {
            final List<String> result =
                AccountGroupOrderNotifier.applyVisibleReorder(
              base,
              visible,
              from,
              to,
            );
            expect(
              result.toSet(),
              base.toSet(),
              reason: 'mask=$mask from=$from to=$to 丢了分组：$result',
            );
            expect(
              result.length,
              base.length,
              reason: 'mask=$mask from=$from to=$to 出现重复：$result',
            );
            // 被移动项必须出现在它应有的锚点位置（可见语义）
            if (from != to) {
              final List<String> afterMove =
                  AccountGroupOrderNotifier.applyReorder(visible, from, to);
              final String moved = visible[from];
              final int at = afterMove.indexOf(moved);
              if (at < afterMove.length - 1) {
                expect(
                  result.indexOf(moved) < result.indexOf(afterMove[at + 1]),
                  isTrue,
                  reason: 'mask=$mask from=$from to=$to 锚点顺序错了：$result',
                );
              }
            }
          }
        }
      }
    });
  });
}
