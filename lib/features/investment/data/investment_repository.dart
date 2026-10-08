import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../categories/data/category_repository.dart';
import '../../ledger/data/transaction_repository.dart';

/// 投资持仓仓储。
///
/// 精度约定（很关键，写错就是账目对不上）：
/// - 份额 [InvestmentHoldings.quantityMicros] 放大 1e6 倍存整数，
///   支撑基金的四位小数份额；
/// - 单价 avgCostMinor / currentPriceMinor 以「分」存整数；
/// - 市值 = quantityMicros × priceMinor ÷ 1e6，先乘后除，避免先除丢精度。
class InvestmentRepository {
  const InvestmentRepository(this._db, this._txnRepo);

  final AppDatabase _db;
  final TransactionRepository _txnRepo;

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

  /// 按资产账户同步直查名下未删持仓（不走流）。
  ///
  /// 供「成交回执」等**写入后立即可见**的场景：StreamProvider 的 `.future`
  /// 在写库后可能拿到重发前的旧快照（竞态），直查天然读到已提交事务的最新值。
  Future<List<InvestmentHolding>> listByAccount(String accountId) {
    return (_db.select(_db.investmentHoldings)
          ..where(
            (InvestmentHoldings t) =>
                t.accountId.equals(accountId) & t.deleted.equals(false),
          ))
        .get();
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

  CategoryRepository get _catRepo => CategoryRepository(_db);

  /// 当前 UTC 毫秒时间戳（事务内多处 updatedAt / 同步队列复用）。
  int get _now => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// 投资买卖流水的固定分类：买入 → 「投资买入」(expense)、卖出 → 「投资卖出」(income)。
  /// 系统分类，无则自动创建（与借还本金流水同款口径）。
  Future<String> _investCategoryId({
    required String bookId,
    required bool isBuy,
  }) {
    return _catRepo.ensureNamed(
      bookId: bookId,
      name: isBuy ? '投资买入' : '投资卖出',
      type: isBuy ? CategoryType.expense : CategoryType.income,
      iconKey: isBuy ? 'invest_buy' : 'invest_sell',
      isSystem: true,
    );
  }

  /// 投资买卖流水备注：'买入-沪深300ETF' / '卖出-沪深300ETF'，
  /// 附「份额 / 单价 / 手续费」元信息行（与借还 _buildMetaNote 同款口径）。
  String _investNote({
    required bool isBuy,
    required String name,
    required int quantityMicros,
    required int priceMinor,
    required int feeMinor,
    String? note,
  }) {
    final String verb = isBuy ? '买入' : '卖出';
    final String meta =
        '份额 ${_fmtQty(quantityMicros)} · 单价 ${Money.fromMinor(priceMinor).format()} · 手续费 ${Money.fromMinor(feeMinor).format()}';
    final String head = '$verb-$name';
    final String? userNote = note?.trim();
    if (userNote == null || userNote.isEmpty) return '$head\n$meta';
    return '$head\n$meta\n$userNote';
  }

  /// 份额整数放大 1e6，转可读字符串：去掉尾随多余的 0（1000000 → '1'、1050000 → '1.05'）。
  String _fmtQty(int micros) {
    final double q = micros / InvestmentRepository.quantityScale;
    // 固定 4 位小数，与表单「可得份额」口径一致。
    return q.toStringAsFixed(4);
  }

  /// 记录买入：新建或增资持仓，并记一笔资金流水（支出，不计入收支统计）。
  ///
  /// 份额 = 金额 ÷ 单价 × 1e6（先乘后除，避免先除丢精度）；成本价按加权重算；
  /// 现价取本次买入价。资金账户扣款 = 金额 + 手续费。
  Future<String> recordBuy({
    required String bookId,
    String? holdingId,
    required String symbol,
    required String name,
    required InvestmentType type,
    required int amountMinor,
    required int priceMinor,
    int feeMinor = 0,
    required String accountId,
    String? note,
    required int occurredAt,
  }) async {
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');
    if (priceMinor <= 0) throw const ValidationFailure('单价必须大于 0');
    if (feeMinor < 0) throw const ValidationFailure('手续费不能为负');

    final int deltaMicros = (amountMinor * quantityScale) ~/ priceMinor;
    if (deltaMicros <= 0) throw const ValidationFailure('金额不足以买入份额');

    // 分类在事务外解析（确保命名分类，避免事务内再开查询）。
    final String buyCat = await _investCategoryId(bookId: bookId, isBuy: true);
    final String flowNote = _investNote(
      isBuy: true,
      name: name,
      quantityMicros: deltaMicros,
      priceMinor: priceMinor,
      feeMinor: feeMinor,
      note: note,
    );

    final String hid = holdingId ?? const Uuid().v7();
    return _db.transaction<String>(() async {
      if (holdingId == null) {
        await _db.into(_db.investmentHoldings).insert(
          InvestmentHoldingsCompanion(
            id: Value<String>(hid),
            bookId: Value<String>(bookId),
            symbol: Value<String>(symbol.trim().toUpperCase()),
            name: Value<String>(name.trim()),
            type: Value<InvestmentType>(type),
            quantityMicros: Value<int>(deltaMicros),
            avgCostMinor: Value<int>(priceMinor),
            currentPriceMinor: Value<int>(priceMinor),
            priceUpdatedAt: Value<int?>(_now),
            accountId: Value<String?>(accountId),
            note: Value<String?>(note),
            updatedAt: Value<int>(_now),
            dirty: const Value<bool>(true),
          ),
        );
        await enqueueSyncOp(
          _db,
          table: 'investment_holdings',
          recordId: hid,
          opType: SyncOpType.insert,
          updatedAt: _now,
          payload: <String, Object?>{
            'symbol': symbol.trim().toUpperCase(),
            'name': name.trim(),
            'type': type.index,
            'quantityMicros': deltaMicros,
            'avgCostMinor': priceMinor,
            'currentPriceMinor': priceMinor,
            'accountId': accountId,
            'note': note,
          },
        );
      } else {
        final InvestmentHolding? existing =
            await (_db.select(_db.investmentHoldings)
                  ..where((InvestmentHoldings t) => t.id.equals(holdingId)))
                .getSingleOrNull();
        if (existing == null) throw const ValidationFailure('持仓不存在');
        final int oldQty = existing.quantityMicros;
        final int oldCostMicros = oldQty * existing.avgCostMinor;
        final int newQty = oldQty + deltaMicros;
        final int newCostMicros = oldCostMicros + amountMinor * quantityScale;
        final int newAvg = newQty == 0 ? 0 : newCostMicros ~/ newQty;
        await (_db.update(_db.investmentHoldings)
              ..where((InvestmentHoldings t) => t.id.equals(holdingId)))
            .write(
          InvestmentHoldingsCompanion(
            quantityMicros: Value<int>(newQty),
            avgCostMinor: Value<int>(newAvg),
            currentPriceMinor: Value<int>(priceMinor),
            priceUpdatedAt: Value<int?>(_now),
            accountId: Value<String?>(accountId),
            note: Value<String?>(note),
            updatedAt: Value<int>(_now),
            dirty: const Value<bool>(true),
          ),
        );
        await enqueueSyncOp(
          _db,
          table: 'investment_holdings',
          recordId: holdingId,
          opType: SyncOpType.update,
          updatedAt: _now,
          payload: <String, Object?>{
            'quantityMicros': newQty,
            'avgCostMinor': newAvg,
            'currentPriceMinor': priceMinor,
            'accountId': accountId,
            'note': note,
          },
        );
      }

      // 资金流水：买入 = 支出（金额 + 手续费），不计入收支统计 / 预算
      // （类比借还本金流水，仅调资金账户余额与持仓市值）。
      await _txnRepo.add(
        bookId: bookId,
        type: TxnType.expense,
        amountMinor: amountMinor + feeMinor,
        accountId: accountId,
        occurredAt: occurredAt,
        categoryId: buyCat,
        note: flowNote,
        sourceModule: SourceModule.investment,
        relatedId: hid,
        excludeFromStats: true,
        excludeFromBudget: true,
      );
      return hid;
    });
  }

  /// 记录卖出：减仓（份额 = 金额 ÷ 单价 × 1e6，不超过持仓），并记资金流水
  /// （收入，不计入收支统计）。清仓后份额归 0，保留持仓记录（便于查看历史）。
  Future<void> recordSell({
    required String bookId,
    required String holdingId,
    required int amountMinor,
    required int priceMinor,
    int feeMinor = 0,
    required String accountId,
    String? note,
    required int occurredAt,
  }) async {
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');
    if (priceMinor <= 0) throw const ValidationFailure('单价必须大于 0');
    if (feeMinor < 0) throw const ValidationFailure('手续费不能为负');

    final int deltaMicros = (amountMinor * quantityScale) ~/ priceMinor;
    if (deltaMicros <= 0) throw const ValidationFailure('金额不足以卖出份额');

    final InvestmentHolding? existing =
        await (_db.select(_db.investmentHoldings)
              ..where((InvestmentHoldings t) => t.id.equals(holdingId)))
            .getSingleOrNull();
    if (existing == null) throw const ValidationFailure('持仓不存在');
    if (deltaMicros > existing.quantityMicros) {
      throw const ValidationFailure('卖出份额超过持仓');
    }

    final String sellCat =
        await _investCategoryId(bookId: bookId, isBuy: false);
    final String flowNote = _investNote(
      isBuy: false,
      name: existing.name,
      quantityMicros: deltaMicros,
      priceMinor: priceMinor,
      feeMinor: feeMinor,
      note: note,
    );

    final int newQty = existing.quantityMicros - deltaMicros;
    return _db.transaction<void>(() async {
      await (_db.update(_db.investmentHoldings)
            ..where((InvestmentHoldings t) => t.id.equals(holdingId)))
          .write(
        InvestmentHoldingsCompanion(
          quantityMicros: Value<int>(newQty),
          currentPriceMinor: Value<int>(priceMinor),
          priceUpdatedAt: Value<int?>(_now),
          updatedAt: Value<int>(_now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'investment_holdings',
        recordId: holdingId,
        opType: SyncOpType.update,
        updatedAt: _now,
        payload: <String, Object?>{
          'quantityMicros': newQty,
          'currentPriceMinor': priceMinor,
        },
      );

      // 资金流水：卖出 = 收入（金额 − 手续费），不计入收支统计 / 预算。
      await _txnRepo.add(
        bookId: bookId,
        type: TxnType.income,
        amountMinor: (amountMinor - feeMinor) < 0 ? 0 : amountMinor - feeMinor,
        accountId: accountId,
        occurredAt: occurredAt,
        categoryId: sellCat,
        note: flowNote,
        sourceModule: SourceModule.investment,
        relatedId: holdingId,
        excludeFromStats: true,
        excludeFromBudget: true,
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
