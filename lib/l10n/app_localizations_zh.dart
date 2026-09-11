// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '口袋账本';

  @override
  String get tabHome => '首页';

  @override
  String get tabLedger => '流水';

  @override
  String get tabAccounts => '账户';

  @override
  String get tabBudget => '预算';

  @override
  String get tabReport => '报表';

  @override
  String get commonSave => '保存';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDelete => '删除';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonAdd => '添加';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonEmpty => '暂无数据';

  @override
  String get commonRetry => '重试';

  @override
  String get commonAll => '全部';

  @override
  String get ledgerTitle => '流水';

  @override
  String get ledgerAdd => '记一笔';

  @override
  String get ledgerEdit => '编辑流水';

  @override
  String get ledgerAmount => '金额';

  @override
  String get ledgerCategory => '分类';

  @override
  String get ledgerAccount => '账户';

  @override
  String get ledgerDate => '日期';

  @override
  String get ledgerNote => '备注';

  @override
  String get ledgerEmpty => '还没有记账记录，点右下角记一笔吧';

  @override
  String get accountTitle => '账户';

  @override
  String get accountAdd => '新增账户';

  @override
  String get accountBalance => '余额';

  @override
  String get accountNetAssets => '净资产';

  @override
  String get accountTotalAssets => '总资产';

  @override
  String get accountTotalLiabilities => '总负债';

  @override
  String get budgetTitle => '预算';

  @override
  String get budgetAdd => '新增预算';

  @override
  String get budgetUsed => '已用';

  @override
  String get budgetRemaining => '剩余';

  @override
  String get budgetOver => '已超支';

  @override
  String get reportTitle => '报表';

  @override
  String get reportIncome => '收入';

  @override
  String get reportExpense => '支出';

  @override
  String get reportBalance => '结余';

  @override
  String get reportCategoryBreakdown => '分类占比';

  @override
  String get reportTrend => '收支趋势';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSync => '云备份与同步';

  @override
  String get settingsSyncOff => '已关闭（纯本地）';

  @override
  String get settingsSyncNow => '立即同步';

  @override
  String get settingsExport => '导出 CSV';

  @override
  String get settingsAbout => '关于';

  @override
  String get syncIdle => '未同步';

  @override
  String get syncRunning => '同步中';

  @override
  String get syncSuccess => '同步完成';

  @override
  String get syncFailed => '同步失败';

  @override
  String syncPendingCount(int count) {
    return '$count 条待同步';
  }
}
