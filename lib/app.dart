import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Flutter 3.10+ 的合成包模式（l10n.yaml + pubspec.yaml `generate: true`），
// 生成文件直接放在 lib/l10n/app_localizations.dart，按 package 名导入即可。
import 'package:pocket_ledger/l10n/app_localizations.dart';

import 'core/config/env.dart';
import 'features/ledger/presentation/screenshot_inbox_bootstrapper.dart';
import 'features/lend/presentation/lend_reminder_bootstrapper.dart';
import 'routing/app_router.dart';
import 'theme/theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);

    // 截图收件箱引导器挂在最外层：快捷指令截图 → 识别 → 顶部通知条
    // （Overlay 挂根导航，需在 MaterialApp 外围才能拿到 rootNavigatorKey）。
    return ScreenshotInboxBootstrapper(
      child: LendReminderBootstrapper(
        child: MaterialApp.router(
          title: Env.appName,
          theme: AppThemeData.light,
          darkTheme: AppThemeData.dark,
          themeMode: ThemeMode.system,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
