import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';

/// 投资持仓仓储。
///
/// 精度约定（很关键，写错就是账目对不上）：
/// - 份额 [InvestmentHoldings.quantityMicros] 放大 1e6 倍存整数，
///   支撑基金的四位小数份额；
/// - 单价 avgCostMinor / currentPriceMinor 以「分」存整数；
/// - 市值 = quantityMicros × priceMinor ÷ 1e6，先乘后除，避免先除丢精度。
class InvestmentRepository {
  const InvestmentRepository(this._db);

  final AppDatabase _db;

  /// 份额放大倍数
  static const int quantityScale = 1000000;

  Stream<List<InvestmentHolding>> watch(String bookId) {
    return (_db.select(_db.investmentHoldings)
          ..where(
            (InvestmentHoldings t) =>
                t.bookId.equals(bookId) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<InvestmentHoldings>>[
            (InvestmentHoldings t) => OrderingTerm.asc(t.type),
            (InvestmentHoldings t) => OrderingTerm.asc(t.symbol),
          ]))
        .watch();
  }

  Future<String> add({
    required String bookId,
    required String symbol,
    required String name,
    required InvestmentType type,
    required int quantityMicros,
    required int avgCostMinor,
    int? currentPriceMinor,
    String? accountId,
    String? note,
  }) {
    _validate(
      symbol: symbol,
      name: name,
      quantityMicros: quantityMicros,
      avgCostMinor: avgCostMinor,
    );

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    // 未填现价时先用成本价占位，让盈亏显示为 0 而不是 -100%。
    final int price = currentPriceMinor ?? avgCostMinor;

    return _db.transaction<String>(() async {
      await _db.into(_db.investmentHoldings).insert(
            InvestmentHoldingsCompanion(
              id: Value<String>(id),
              bookId: Value<String>(bookId),
              symbol: Value<String>(symbol.trim().toUpperCase()),
              name: Value<String>(name.trim()),
              type: Value<InvestmentType>(type),
              quantityMicros: Value<int>(quantityMicros),
              avgCostMinor: Value<int>(avgCostMinor),
              currentPriceMinor: Value<int>(price),
              priceUpdatedAt: Value<int?>(now),
              accountId: Value<String?>(accountId),
              note: Value<String?>(note),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
      await enqueueSyncOp(
        _db,
        table: 'investment_holdings',
        recordId: id,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: <String, Object?>{
          'symbol': symbol.trim().toUpperCase(),
          'name': name.trim(),
          'type': type.index,
          'quantityMicros': quantityMicros,
          'avgCostMinor': avgCostMinor,
          'currentPriceMinor': price,
          'accountId': accountId,
          'note': note,
        },
      );
      return id;
    });
  }

  Future<void> update({
    required String id,
    required String symbol,
    required String name,
    required InvestmentType type,
    required int quantityMicros,
    required int avgCostMinor,
    required int currentPriceMinor,
    String? accountId,
    String? note,
  }) {
    _validate(
      symbol: symbol,
      name: name,
      quantityMicros: quantityMicros,
      avgCostMinor: avgCostMinor,
    );

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return _db.transaction<void>(() async {
      await (_db.update(_db.investmentHoldings)
            ..where((InvestmentHoldings t) => t.id.equals(id)))
          .write(
        InvestmentHoldingsCompanion(
          symbol: Value<String>(symbol.trim().toUpperCase()),
          name: Value<String>(name.trim()),
          type: Value<InvestmentType>(type),
          quantityMicros: Value<int>(quantityMicros),
          avgCostMinor: Value<int>(avgCostMinor),
          currentPriceMinor: Value<int>(currentPriceMinor),
          priceUpdatedAt: Value<int?>(now),
          accountId: Value<String?>(accountId),
          note: Value<String?>(note),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'investment_holdings',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{
          'symbol': symbol.trim().toUpperCase(),
          'name': name.trim(),
          'type': type.index,
          'quantityMicros': quantityMicros,
          'avgCostMinor': avgCostMinor,
          'currentPriceMinor': currentPriceMinor,
          'accountId': accountId,
          'note': note,
        },
      );
    });
  }

  /// 只更新现价。手动录入行情时用，不触碰份额与成本。
  Future<void> updatePrice(String id, int priceMinor) async {
    if (priceMinor < 0) throw const ValidationFailure('价格不能为负');
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.investmentHoldings)
            ..where((InvestmentHoldings t) => t.id.equals(id)))
          .write(
        InvestmentHoldingsCompanion(
          currentPriceMinor: Value<int>(priceMinor),
          priceUpdatedAt: Value<int?>(now),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'investment_holdings',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: <String, Object?>{
          'currentPriceMinor': priceMinor,
          'priceUpdatedAt': now,
        },
      );
    });
  }

  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.investmentHoldings)
            ..where((InvestmentHoldings t) => t.id.equals(id)))
          .write(
        const InvestmentHoldingsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'investment_holdings',
        recordId: id,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
    });
  }

  void _validate({
    required String symbol,
    required String name,
    required int quantityMicros,
    required int avgCostMinor,
  }) {
    if (symbol.trim().isEmpty) throw const ValidationFailure('代码不能为空');
    if (name.trim().isEmpty) throw const ValidationFailure('名称不能为空');
    if (quantityMicros <= 0) throw const ValidationFailure('份额必须大于 0');
    if (avgCostMinor < 0) throw const ValidationFailure('成本价不能为负');
  }
}

/// 单个持仓的盈亏计算结果。
///
/// 放在 data 层而不是 UI 层：报表、首页净资产卡片都要用同一套口径，
/// 算法只允许存在一份。
extension InvestmentMath on InvestmentHolding {
  /// 市值（分）
  int get marketValueMinor =>
      (quantityMicros * currentPriceMinor) ~/
      InvestmentRepository.quantityScale;

  /// 总成本（分）
  int get costValueMinor =>
      (quantityMicros * avgCostMinor) ~/ InvestmentRepository.quantityScale;

  /// 浮动盈亏（分），正数为盈利
  int get profitMinor => marketValueMinor - costValueMinor;

  /// 盈亏比例，成本为 0 时返回 0 而不是无穷大
  double get profitRatio =>
      costValueMinor == 0 ? 0 : profitMinor / costValueMinor;

  /// 实际份额（用于展示）
  double get quantity => quantityMicros / InvestmentRepository.quantityScale;
}
