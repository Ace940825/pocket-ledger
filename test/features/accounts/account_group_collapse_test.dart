import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/accounts/data/account_group_collapse.dart';

/// 账户分组折叠状态的持久化回归测试。
///
/// 用户要求「分组可以折叠、默认记忆、再进入时保持退出布局」，
/// 核心是 **secure storage 读得到、写进去、下次 load 能还原**。
/// 用 `FlutterSecureStorage.setMockInitialValues` 把存储换成内存桩，
/// 不用真实平台通道。
void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('默认全部展开（映射缺失即 false）', () {
    final AccountGroupCollapseNotifier n =
        AccountGroupCollapseNotifier(const FlutterSecureStorage());
    expect(n.isCollapsed('资金类'), isFalse);
    expect(n.state, isEmpty);
  });

  test('toggle 翻转并立即反映到 state', () async {
    final AccountGroupCollapseNotifier n =
        AccountGroupCollapseNotifier(const FlutterSecureStorage());
    expect(n.isCollapsed('资金类'), isFalse);
    await n.toggle('资金类');
    expect(n.isCollapsed('资金类'), isTrue, reason: '折叠后应 true');
    await n.toggle('资金类');
    expect(n.isCollapsed('资金类'), isFalse, reason: '再点应展开');
  });

  test('setCollapsed 显式设置；无变化时不应产生新 state 对象', () async {
    final AccountGroupCollapseNotifier n =
        AccountGroupCollapseNotifier(const FlutterSecureStorage());
    await n.setCollapsed('投资类', true);
    expect(n.isCollapsed('投资类'), isTrue);
    final Map<String, bool> state1 = n.state;
    await n.setCollapsed('投资类', true); // 值没变
    expect(identical(state1, n.state), isTrue, reason: '无变化不应重建 map');
  });

  test('load 解析 JSON 并恢复折叠状态', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'account_group_collapsed': '{"资金类":true,"投资类":false}',
    });
    final AccountGroupCollapseNotifier n =
        AccountGroupCollapseNotifier(const FlutterSecureStorage());
    await n.load();
    expect(n.isCollapsed('资金类'), isTrue, reason: '显式 true');
    expect(n.isCollapsed('投资类'), isFalse, reason: '显式 false');
    expect(n.isCollapsed('应收类'), isFalse, reason: '缺失 = 展开');
  });

  test('load 遇到非法内容时退回默认（全部展开）且不抛异常', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'account_group_collapsed': 'not-json',
    });
    final AccountGroupCollapseNotifier n =
        AccountGroupCollapseNotifier(const FlutterSecureStorage());
    await n.load(); // 不应抛
    expect(n.state, isEmpty);
  });

  test('toggle → 落库 → 新实例 load 还原（记忆模式端到端）', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final AccountGroupCollapseNotifier first =
        AccountGroupCollapseNotifier(const FlutterSecureStorage());
    await first.toggle('应付类'); // 折叠应付类
    expect(first.isCollapsed('应付类'), isTrue);

    // 模拟“用户退出页面再进来”：全新的 notifier 读同一份存储
    final AccountGroupCollapseNotifier second =
        AccountGroupCollapseNotifier(const FlutterSecureStorage());
    await second.load();
    expect(second.isCollapsed('应付类'), isTrue, reason: '重进页面应记住「应付类已折叠」');
    expect(second.isCollapsed('资金类'), isFalse, reason: '其余分组仍保持展开');
  });
}
