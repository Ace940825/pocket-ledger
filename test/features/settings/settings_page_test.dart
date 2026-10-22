import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/settings/data/sync_settings.dart';
import 'package:pocket_ledger/features/settings/presentation/settings_page.dart';
import 'package:pocket_ledger/features/settings/providers/sync_settings_providers.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 设置页：移除「全部功能 / 预算」两个入口后的渲染自检（明/暗）。
///
/// 2026-10-22 用户截图反馈：设置页里的「全部功能」与「预算」入口移除。
/// 注意本测试跑在**主工程**（本地工作区）上——不是 GitHub 快照克隆。
/// 本测试锁定移除结果，并产出明暗两版真渲染图供目检。
void main() {
  testWidgets('设置页：全部功能/预算入口已移除', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final bool dark in <bool>[false, true]) {
      final ThemeData theme = dark ? AppThemeData.dark : AppThemeData.light;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            // 非 autoDispose 的 AsyncNotifierProvider 必须传 notifier 实例。
            syncSettingsProvider.overrideWith(
              _FakeSyncSettingsController.new,
            ),
          ],
          child: MaterialApp(
            theme: theme,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _drainExceptions(tester);

      // 两个入口必须不存在；「同步控制」「关于」保留。
      expect(find.text('全部功能'), findsNothing);
      expect(find.text('预算'), findsNothing);
      expect(find.text('同步控制'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);

      await expectLater(
        find.byType(SettingsPage),
        matchesGoldenFile(
          dark ? 'settings_page_entries_removed_dark.png'
                : 'settings_page_entries_removed_light.png',
        ),
      );
    }
  });
}

/// 假同步设置：非 autoDispose 的 AsyncNotifierProvider 必须传 notifier 实例。
class _FakeSyncSettingsController extends SyncSettingsController {
  @override
  Future<SyncSettings> build() async => const SyncSettings(
        enabled: true,
        baseUrl: 'https://pocket-ledger.example.workers.dev',
        token: 'test-token',
      );
}

/// 消化 MenuGroup 既有实现触发的框架断言（DecoratedBox 包 ListTile 导致
/// ink splash 可见性警告，debug 模式必现、release 不抛，与本次入口移除无关）。
void _drainExceptions(WidgetTester tester) {
  for (int i = 0; i < 10 && tester.takeException() != null; i++) {}
}
