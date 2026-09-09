import '../../../database/daos/transactions_dao.dart';
import '../../../domain/enums.dart';

/// 报表数据聚合。
///
/// 全部走本地 SQLite 聚合，**不依赖任何云端计算** ——
/// 既省掉服务端费用，也保证离线可用与毫秒级响应。
class ReportRepository {
  const ReportRepository(this._dao);

  final TransactionsDao _dao;

  Stream<List<MonthTotal>> watchMonthlyTotals({
    required String bookId,
    required int startAt,
    required int endAt,
  }) =>
      _dao.watchMonthlyTotals(
        bookId: bookId,
        startAt: startAt,
        endAt: endAt,
      );

  Stream<List<ModuleTotal>> watchModuleTotals({
    required String bookId,
    required int startAt,
    required int endAt,
  }) =>
      _dao.watchModuleTotals(
        bookId: bookId,
        startAt: startAt,
        endAt: endAt,
        type: TxnType.expense,
      );
}
