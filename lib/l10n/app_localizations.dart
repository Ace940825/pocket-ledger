import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'口袋账本'**
  String get appName;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// No description provided for @tabLedger.
  ///
  /// In zh, this message translates to:
  /// **'流水'**
  String get tabLedger;

  /// No description provided for @tabAccounts.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get tabAccounts;

  /// No description provided for @tabBudget.
  ///
  /// In zh, this message translates to:
  /// **'预算'**
  String get tabBudget;

  /// No description provided for @tabReport.
  ///
  /// In zh, this message translates to:
  /// **'报表'**
  String get tabReport;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get commonAdd;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// No description provided for @commonSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get commonSearch;

  /// No description provided for @commonEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get commonEmpty;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get commonAll;

  /// No description provided for @ledgerTitle.
  ///
  /// In zh, this message translates to:
  /// **'流水'**
  String get ledgerTitle;

  /// No description provided for @ledgerAdd.
  ///
  /// In zh, this message translates to:
  /// **'记一笔'**
  String get ledgerAdd;

  /// No description provided for @ledgerEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑流水'**
  String get ledgerEdit;

  /// No description provided for @ledgerAmount.
  ///
  /// In zh, this message translates to:
  /// **'金额'**
  String get ledgerAmount;

  /// No description provided for @ledgerCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get ledgerCategory;

  /// No description provided for @ledgerAccount.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get ledgerAccount;

  /// No description provided for @ledgerDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get ledgerDate;

  /// No description provided for @ledgerNote.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get ledgerNote;

  /// No description provided for @ledgerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有记账记录，点右下角记一笔吧'**
  String get ledgerEmpty;

  /// No description provided for @accountTitle.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get accountTitle;

  /// No description provided for @accountAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增账户'**
  String get accountAdd;

  /// No description provided for @accountBalance.
  ///
  /// In zh, this message translates to:
  /// **'余额'**
  String get accountBalance;

  /// No description provided for @accountNetAssets.
  ///
  /// In zh, this message translates to:
  /// **'净资产'**
  String get accountNetAssets;

  /// No description provided for @accountTotalAssets.
  ///
  /// In zh, this message translates to:
  /// **'总资产'**
  String get accountTotalAssets;

  /// No description provided for @accountTotalLiabilities.
  ///
  /// In zh, this message translates to:
  /// **'总负债'**
  String get accountTotalLiabilities;

  /// No description provided for @budgetTitle.
  ///
  /// In zh, this message translates to:
  /// **'预算'**
  String get budgetTitle;

  /// No description provided for @budgetAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增预算'**
  String get budgetAdd;

  /// No description provided for @budgetUsed.
  ///
  /// In zh, this message translates to:
  /// **'已用'**
  String get budgetUsed;

  /// No description provided for @budgetRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩余'**
  String get budgetRemaining;

  /// No description provided for @budgetOver.
  ///
  /// In zh, this message translates to:
  /// **'已超支'**
  String get budgetOver;

  /// No description provided for @reportTitle.
  ///
  /// In zh, this message translates to:
  /// **'报表'**
  String get reportTitle;

  /// No description provided for @reportIncome.
  ///
  /// In zh, this message translates to:
  /// **'收入'**
  String get reportIncome;

  /// No description provided for @reportExpense.
  ///
  /// In zh, this message translates to:
  /// **'支出'**
  String get reportExpense;

  /// No description provided for @reportBalance.
  ///
  /// In zh, this message translates to:
  /// **'结余'**
  String get reportBalance;

  /// No description provided for @reportCategoryBreakdown.
  ///
  /// In zh, this message translates to:
  /// **'分类占比'**
  String get reportCategoryBreakdown;

  /// No description provided for @reportTrend.
  ///
  /// In zh, this message translates to:
  /// **'收支趋势'**
  String get reportTrend;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsSync.
  ///
  /// In zh, this message translates to:
  /// **'云备份与同步'**
  String get settingsSync;

  /// No description provided for @settingsSyncOff.
  ///
  /// In zh, this message translates to:
  /// **'已关闭（纯本地）'**
  String get settingsSyncOff;

  /// No description provided for @settingsSyncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get settingsSyncNow;

  /// No description provided for @settingsExport.
  ///
  /// In zh, this message translates to:
  /// **'导出 CSV'**
  String get settingsExport;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAbout;

  /// No description provided for @syncIdle.
  ///
  /// In zh, this message translates to:
  /// **'未同步'**
  String get syncIdle;

  /// No description provided for @syncRunning.
  ///
  /// In zh, this message translates to:
  /// **'同步中'**
  String get syncRunning;

  /// No description provided for @syncSuccess.
  ///
  /// In zh, this message translates to:
  /// **'同步完成'**
  String get syncSuccess;

  /// No description provided for @syncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncFailed;

  /// No description provided for @syncPendingCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条待同步'**
  String syncPendingCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
