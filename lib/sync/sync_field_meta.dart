import 'package:intl/intl.dart';

import '../domain/enums.dart';
import 'conflict_models.dart';

/// 同步冲突解决页的「字段中文标签 / 值格式化」元信息。
///
/// 端侧同步只有 12 张业务表，字段总量有限，因此这里用一张**显式映射表**把
/// 每个用户可见字段翻译成可读标签，并提供「金额 / 布尔 / 枚举 / 时间」四类
/// 格式化器，避免冲突页直接展示 `amountMinor = 12345` 这类机器字段。
///
/// 纯函数、无数据库依赖，可在没有 Flutter 运行时的环境下断言测试。
class SyncFieldMeta {
  SyncFieldMeta._();

  /// 结构性字段：不参与冲突选择（它们是同步框架的元数据，不是业务内容）。
  static const Set<String> _structural = <String>{
    'id',
    'bookId',
    'updatedAt',
    'createdAt',
    'deleted',
    'dirty',
    'syncedAt',
  };

  /// 字段中文标签（键为 `表名.字段名`，表名用下划线形式）。
  static const Map<String, String> _labels = <String, String>{
    // books
    'books.name': '名称',
    'books.currency': '币种',
    'books.sortOrder': '排序',
    // transactions
    'transactions.type': '类型',
    'transactions.amountMinor': '金额',
    'transactions.accountId': '账户',
    'transactions.occurredAt': '发生时间',
    'transactions.sourceModule': '来源模块',
    'transactions.currency': '币种',
    'transactions.toAccountId': '转入账户',
    'transactions.categoryId': '分类',
    'transactions.subcategory': '子分类',
    'transactions.note': '备注',
    'transactions.attachmentUrls': '附件',
    'transactions.tags': '标签',
    'transactions.relatedId': '关联ID',
    'transactions.transferGroupId': '转账组',
    'transactions.feeMinor': '手续费',
    'transactions.discountMinor': '优惠',
    'transactions.excludeFromStats': '不计入收支',
    'transactions.excludeFromBudget': '不计入预算',
    'transactions.isReimbursable': '可报销',
    'transactions.reimbursementAccountId': '报销账户',
    'transactions.latitude': '纬度',
    'transactions.longitude': '经度',
    'transactions.placeName': '地点',
    // accounts
    'accounts.name': '名称',
    'accounts.type': '类型',
    'accounts.balanceMinor': '余额',
    'accounts.currency': '币种',
    'accounts.creditLimitMinor': '信用额度',
    'accounts.iconKey': '图标',
    'accounts.colorValue': '颜色',
    'accounts.billingDay': '账单日',
    'accounts.dueDay': '还款日',
    'accounts.note': '备注',
    'accounts.cardNumber': '卡号',
    'accounts.status': '状态',
    'accounts.includeInTotal': '计入总额',
    'accounts.isArchived': '已归档',
    'accounts.sortOrder': '排序',
    // categories
    'categories.name': '名称',
    'categories.type': '类型',
    'categories.parentId': '父分类',
    'categories.iconKey': '图标',
    'categories.colorValue': '颜色',
    'categories.sortOrder': '排序',
    'categories.isArchived': '已归档',
    'categories.isSystem': '系统分类',
    // lend_records
    'lend_records.direction': '方向',
    'lend_records.status': '状态',
    'lend_records.counterparty': '对方',
    'lend_records.amountMinor': '金额',
    'lend_records.occurredAt': '发生时间',
    'lend_records.repaidMinor': '已还',
    'lend_records.currency': '币种',
    'lend_records.dueAt': '到期日',
    'lend_records.note': '备注',
    'lend_records.accountId': '账户',
    'lend_records.toAccountId': '转入账户',
    'lend_records.feeMinor': '手续费',
    'lend_records.discountMinor': '优惠',
    'lend_records.graceDays': '宽限期',
    // reimbursements
    'reimbursements.title': '标题',
    'reimbursements.status': '状态',
    'reimbursements.amountMinor': '金额',
    'reimbursements.payer': '付款方',
    'reimbursements.occurredAt': '发生时间',
    'reimbursements.currency': '币种',
    'reimbursements.target': '报销对象',
    'reimbursements.receivedAt': '收款时间',
    'reimbursements.note': '备注',
    'reimbursements.attachmentUrls': '附件',
    'reimbursements.transactionId': '关联流水',
    'reimbursements.excludeFromStats': '不计入收支',
    'reimbursements.accountId': '账户',
    'reimbursements.toAccountId': '转入账户',
    'reimbursements.incomeTransactionId': '收入流水',
    'reimbursements.incomeAllocs': '抵扣台账',
    // savings_goals
    'savings_goals.name': '名称',
    'savings_goals.targetMinor': '目标金额',
    'savings_goals.currentMinor': '当前金额',
    'savings_goals.currency': '币种',
    'savings_goals.accountId': '账户',
    'savings_goals.deadlineAt': '截止日',
    'savings_goals.note': '备注',
    'savings_goals.isAchieved': '已达成',
    'savings_goals.isArchived': '已归档',
    'savings_goals.mode': '模式',
    'savings_goals.repeatCycle': '周期',
    'savings_goals.endNote': '结束备注',
    'savings_goals.depositCount': '存入次数',
    'savings_goals.startedAt': '开始日',
    'savings_goals.elasticMode': '弹性模式',
    'savings_goals.elasticBaseMinor': '弹性基础额',
    'savings_goals.elasticStepMinor': '弹性步长',
    'savings_goals.elasticPercentHundred': '弹性比例',
    'savings_goals.sourceAccountId': '扣款账户',
    // installment_plans
    'installment_plans.title': '标题',
    'installment_plans.totalMinor': '总额',
    'installment_plans.totalPeriods': '总期数',
    'installment_plans.firstDueAt': '首期日',
    'installment_plans.paidPeriods': '已还期数',
    'installment_plans.feePerPeriodMinor': '每期手续费',
    'installment_plans.feeByPeriodMinor': '分期手续费明细',
    'installment_plans.repeatRule': '重复规则',
    'installment_plans.currency': '币种',
    'installment_plans.accountId': '账户',
    'installment_plans.note': '备注',
    'installment_plans.isFinished': '已完成',
    // installment_periods
    'installment_periods.planId': '计划ID',
    'installment_periods.periodIndex': '期次',
    'installment_periods.amountMinor': '金额',
    'installment_periods.dueAt': '到期日',
    'installment_periods.paidAt': '还款时间',
    'installment_periods.transactionId': '关联流水',
    // budgets
    'budgets.scope': '范围',
    'budgets.period': '周期',
    'budgets.amountMinor': '预算金额',
    'budgets.year': '年份',
    'budgets.periodIndex': '期次索引',
    'budgets.currency': '币种',
    'budgets.categoryId': '分类',
    'budgets.alertEnabled': '超支提醒',
    'budgets.alertThreshold': '提醒阈值',
    // investment_holdings
    'investment_holdings.symbol': '代码',
    'investment_holdings.name': '名称',
    'investment_holdings.type': '类型',
    'investment_holdings.quantityMicros': '持仓数量',
    'investment_holdings.avgCostMinor': '持仓成本价',
    'investment_holdings.currentPriceMinor': '当前价',
    'investment_holdings.realizedProfitMinor': '已实现盈亏',
    'investment_holdings.currency': '币种',
    'investment_holdings.accountId': '账户',
    'investment_holdings.priceUpdatedAt': '价格更新时间',
    'investment_holdings.note': '备注',
    // inventory_items
    'inventory_items.name': '名称',
    'inventory_items.purchasedAt': '购买时间',
    'inventory_items.category': '分类',
    'inventory_items.purchasePriceMinor': '购买价',
    'inventory_items.currentValueMinor': '当前估值',
    'inventory_items.currency': '币种',
    'inventory_items.warrantyUntil': '保修截止',
    'inventory_items.photoUrl': '照片',
    'inventory_items.location': '存放位置',
    'inventory_items.note': '备注',
    'inventory_items.transactionId': '关联流水',
  };

  /// 枚举字段 → 枚举 values 列表（按下标还原 label）。
  static const Map<String, List<Enum>> _enumByField = <String, List<Enum>>{
    'transactions.type': TxnType.values,
    'transactions.sourceModule': SourceModule.values,
    'accounts.type': AccountType.values,
    'accounts.status': AccountStatus.values,
    'categories.type': CategoryType.values,
    'lend_records.direction': LendDirection.values,
    'lend_records.status': LendStatus.values,
    'reimbursements.status': ReimbursementStatus.values,
    'budgets.scope': BudgetScope.values,
    'budgets.period': BudgetPeriod.values,
    'investment_holdings.type': InvestmentType.values,
  };

  /// 表名中文标签。
  static String tableLabel(String table) => const <String, String>{
        'books': '账本',
        'transactions': '交易流水',
        'accounts': '账户',
        'categories': '分类',
        'lend_records': '借还记录',
        'reimbursements': '报销单',
        'savings_goals': '储蓄目标',
        'installment_plans': '分期计划',
        'installment_periods': '分期期次',
        'budgets': '预算',
        'investment_holdings': '投资持仓',
        'inventory_items': '物品',
      }[table] ?? table;

  /// 字段中文标签；未登记时退化为驼峰美化（首字母大写、驼峰加空格）。
  static String labelFor(String table, String field) =>
      _labels['$table.$field'] ?? _prettify(field);

  static String _prettify(String field) {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < field.length; i++) {
      final String ch = field[i];
      if (i > 0 && ch == ch.toUpperCase() && ch != ch.toLowerCase()) {
        sb.write(' ');
      }
      sb.write(i == 0 ? ch.toUpperCase() : ch);
    }
    return sb.toString();
  }

  /// 把单个字段值格式化为可读字符串。
  ///
  /// 识别四类：金额（*Minor）→ ¥；布尔 → 是/否；枚举（[ _enumByField]）→ label；
  /// 时间戳（以 `At` 结尾且为毫秒整数）→ 日期；其余 → 原值 toString。
  static String format(
    String table,
    String field,
    Object? value,
  ) {
    if (value == null) return '—';

    // 布尔
    if (value is bool) return value ? '是' : '否';

    // 金额（以 Minor 结尾的分/厘整数）
    if (field.endsWith('Minor') && value is int) {
      final double yuan = value / 100;
      final String sign = yuan < 0 ? '-' : '';
      return '$sign¥${_money(yuan.abs())}';
    }

    // 枚举
    final List<Enum>? enums = _enumByField['$table.$field'];
    if (enums != null && value is int) {
      if (value >= 0 && value < enums.length) {
        final Enum e = enums[value];
        // 业务枚举都带 `label` getter
        try {
          // ignore: avoid_dynamic_calls
          return (e as dynamic).label as String;
        } catch (_) {
          return e.name;
        }
      }
      return value.toString();
    }

    // 时间戳（以 At 结尾，且量级像毫秒 epoch）
    if (field.endsWith('At') && value is int && value > 1000000000000) {
      final DateTime dt =
          DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }

    // 颜色（ARGB int）
    if (field == 'colorValue' && value is int) {
      final String hex = value.toRadixString(16).padLeft(8, '0').toUpperCase();
      return '#$hex';
    }

    if (value is String && value.isEmpty) return '—';
    return value.toString();
  }

  static String _money(double v) {
    final String s = v.toStringAsFixed(2);
    final List<String> parts = s.split('.');
    final String intPart = parts[0];
    final StringBuffer out = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      out.write(intPart[i]);
      count++;
      if (count % 3 == 0 && i != 0) out.write(',');
    }
    final String grouped = out.toString().split('').reversed.join();
    return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  }

  /// 计算两行 payload 之间**确有差异**的业务字段名列表（排除结构性字段）。
  ///
  /// 同时被引擎（判断是否真冲突）与 UI（展示差异字段）复用，保证两端口径一致。
  static List<String> differingFields(
    String table,
    Map<String, Object?> local,
    Map<String, Object?> remote,
  ) {
    final List<String> out = <String>[];
    for (final String key in local.keys) {
      if (_structural.contains(key)) continue;
      if (!remote.containsKey(key)) continue;
      if (!SyncConflictField.equal(local[key], remote[key])) {
        out.add(key);
      }
    }
    return out;
  }

  /// 构建冲突的逐字段展示列表（已按差异过滤，仅含确有差异的字段）。
  static List<SyncConflictField> buildFields(SyncConflict conflict) {
    final List<String> differing =
        differingFields(conflict.table, conflict.localPayload, conflict.remotePayload);
    return differing.map((String field) {
      final Object? lv = conflict.localPayload[field];
      final Object? rv = conflict.remotePayload[field];
      return SyncConflictField(
        field: field,
        label: labelFor(conflict.table, field),
        localValue: lv,
        remoteValue: rv,
        localDisplay: format(conflict.table, field, lv),
        remoteDisplay: format(conflict.table, field, rv),
      );
    }).toList(growable: false);
  }
}
