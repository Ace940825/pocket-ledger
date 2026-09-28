import 'package:flutter/material.dart';
// Flutter 3.10+ 的合成包模式（l10n.yaml + pubspec.yaml `generate: true`），
// 生成文件直接放在 lib/l10n/app_localizations.dart，按 package 名导入即可。
import 'package:pocket_ledger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/env.dart';
import 'theme/theme.dart';
import 'routing/app_router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: Env.appName,
      theme: AppThemeData.light,
      darkTheme: AppThemeData.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}
