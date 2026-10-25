import 'package:pocket_ledger/database/app_database.dart';

/// 还款日设定方式：互斥二选一。
///
/// - [fixedDay]：固定日期——每月 [Account.dueDay] 号还款。
/// - [graceDays]：免息期——账单日后 [Account.dueGraceDays] 天还款
///   （信用卡常见，如「账单日后 20 天」）。
enum RepayMode { fixedDay, graceDays }

/// 账户当前生效的还款方式：免息期优先（[Account.dueGraceDays] 非空），
/// 否则固定日期（[Account.dueDay] 非空），两都为空则固定日期兜底。
RepayMode repayModeOf(Account account) =>
    account.dueGraceDays != null ? RepayMode.graceDays : RepayMode.fixedDay;

/// 下一个「每月 [day] 号」的日期。今天即当天时归到下个月（参考稿「下期」口径）。
/// [day] 超出当月天数时收敛到当月最后一天（如 31 号在 2 月 → 28/29 号）。
DateTime nextMonthlyDate(int day, DateTime now) {
  DateTime clamp(int year, int month) {
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDay));
  }

  final DateTime today = DateTime(now.year, now.month, now.day);
  DateTime d = clamp(now.year, now.month);
  if (!d.isAfter(today)) {
    final int nm = now.month == 12 ? 1 : now.month + 1;
    final int ny = now.month == 12 ? now.year + 1 : now.year;
    d = clamp(ny, nm);
  }
  return d;
}

/// 推算账户下一次还款日（展示层 / 到期判断统一入口）。
///
/// - 免息期模式（[Account.dueGraceDays] 非空）：账单日 + N 天（账单日取
///   下一次出账日，再往后推 N 天）。
/// - 固定日期模式（[Account.dueDay] 非空）：每月 [Account.dueDay] 号。
/// - 账单日为空（无计费周期）或两模式都无值：返回 null。
DateTime? nextDueDate(Account account, DateTime now) {
  if (account.billingDay == null) return null;
  final DateTime nextBilling = nextMonthlyDate(account.billingDay!, now);
  if (account.dueGraceDays != null) {
    return nextBilling.add(Duration(days: account.dueGraceDays!));
  }
  if (account.dueDay != null) {
    return nextMonthlyDate(account.dueDay!, now);
  }
  return null;
}

/// 还款日摘要（用于卡片 / 选择器展示）：
/// 免息期模式 →「账单后N天」；固定模式 →「每月X号」；无 →「—」。
String repaySummary(Account account) {
  if (account.dueGraceDays != null) {
    return '账单后${account.dueGraceDays}天';
  }
  if (account.dueDay != null) return '每月${account.dueDay}号';
  return '—';
}
