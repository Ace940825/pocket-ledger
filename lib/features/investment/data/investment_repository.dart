import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../categories/data/category_repository.dart';
import '../../ledger/data/transaction_repository.dart';
import 'market/market_service.dart';
import 'market/quote_models.dart';
import 'market/security_meta_repository.dart';

/// 投资持仓仓储。
///
/// 精度约定（很关键，写错就是账目对不上）：
/// - 份额 [InvestmentHoldings.quantityMicros] 放大 1e6 倍存整数，
///   支撑基金的四位小数份额；
/// - 单价 avgCostMinor / currentPriceMinor 以「分」存整数；
/// - 市值 = quantityMicros × priceMinor ÷ 1e6，先乘后除，避免先除丢精度。
class InvestmentRepository {
  /// 注册通用流水编辑/删除后的派生列重算钩子（见
  /// [TransactionRepository.onInvestmentFlowChanged]）：投资买卖流水被
  /// 通用编辑器改动或删除时，自动重算受影响持仓的 realizedProfitMinor，
  /// 堵住「缓存列只随 recordBuy/recordSell/updateTrade 更新」的时效缺口。
  InvestmentRepository(this._db, this._txnRepo) {
    TransactionRepository.onInvestmentFlowChanged = _recomputeRealized;
  }

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

  /// 全部未删持仓（跨账本），供每日行情刷新遍历。
  Future<List<InvestmentHolding>> listAllActive() {
    return (_db.select(_db.investmentHoldings)
          ..where((InvestmentHoldings t) => t.deleted.equals(false)))
        .get();
  }

  /// 每日行情刷新：遍历全部持仓，按类型调免费源抓现价并落库。
  ///
  /// 节流：现价 [priceUpdatedAt] 已是「今天」（本地日）的跳过，天然每天至多一次；
  /// [force] = true 时绕过节流（手动「刷新行情」用，如修正错价后立即重取）；
  /// 加密货币价折算成 CNY（[MarketService.fetchUsdCnyRate]）以与基金同币种汇总；
  /// 单源间隔 ~150ms 限流；任意源/单笔失败均跳过，**不抛异常、不回滚其它**。
  /// 返回成功更新的持仓数。
  Future<int> refreshAllPrices({bool force = false}) async {
    final List<InvestmentHolding> holdings = await listAllActive();
    if (holdings.isEmpty) return 0;
    final MarketService svc = MarketService(SecurityMetaRepository(_db));
    final double cnyRate = await svc.fetchUsdCnyRate();
    int updated = 0;
    for (final InvestmentHolding h in holdings) {
      if (!force && _isSameLocalDay(h.priceUpdatedAt)) continue;
      final Quote? q = await svc.fetchQuote(h.type, h.symbol, cnyRate: cnyRate);
      // 价格 ≤ 0 一律视为无效行情跳过（保留旧价），绝不把 0 写进现价——
      // 否则市值归零、盈亏 -100%（2026-10-20 真机事故：东财节点返回 f43:0）。
      if (q == null || q.priceMinor <= 0) continue;
      try {
        await updatePrice(h.id, q.priceMinor);
        updated++;
      } catch (_) {
        // 单笔写库失败不阻断其余。
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return updated;
  }

  /// 持仓现价是否已在「今天」更新过（本地日，避免 UTC 跨日误判）。
  bool _isSameLocalDay(int? updatedAt) {
    if (updatedAt == null) return false;
    final DateTime now = DateTime.now();
    final DateTime ts =
        DateTime.fromMillisecondsSinceEpoch(updatedAt, isUtc: true).toLocal();
    return now.year == ts.year && now.month == ts.month && now.day == ts.day;
  }

  /// 删除持仓：软删持仓本体，并级联软删名下全部买卖流水
  /// （sourceModule=investment + relatedId=持仓id）。
  ///
  /// 流水删除走 [TransactionRepository.remove]，账户余额随之反向冲销
  /// （买入扣款加回、卖出收入扣回），账单明细同步消失，无游离数据。
  /// 全部在同一事务内完成（Drift 嵌套事务=保存点），任一步失败整体回滚。
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
      // 级联删关联买卖流水（余额冲销由 remove 自理）。
      await _txnRepo.removeAllByRelatedId(id);
    });
  }

  /// 重算某持仓的已实现盈亏（分）并写回缓存列
  /// [InvestmentHoldings.realizedProfitMinor]。
  ///
  /// 按买卖流水重放（同顶层 [realizedProfitMinorFor]），结果精确、随流水编辑/
  /// 删除自愈。值漂移时写回并 bump updatedAt + 标脏入同步队列——否则云端旧
  /// 快照会按 LWW 把重算结果盖回（同步拉取按 updatedAt 判本地行去留）。
  Future<void> _recomputeRealized(String hid) async {
    final List<Transaction> flows = await (_db.select(_db.transactions)
          ..where(
            (Transactions t) =>
                t.relatedId.equals(hid) &
                t.sourceModule.equals(SourceModule.investment.index),
          ))
        .get();
    final int realized = realizedProfitMinorFor(hid, flows);
    final InvestmentHolding? row = await (_db.select(_db.investmentHoldings)
          ..where((InvestmentHoldings t) => t.id.equals(hid)))
        .getSingleOrNull();
    // 值未漂移则不写：避免启动对账每轮都空写入 / 重复入同步队列。
    if (row == null || row.realizedProfitMinor == realized) return;
    final int now = _now;
    await (_db.update(_db.investmentHoldings)
          ..where((InvestmentHoldings t) => t.id.equals(hid)))
        .write(
      InvestmentHoldingsCompanion(
        realizedProfitMinor: Value<int>(realized),
        // 必须随写回 bump updatedAt + 标脏并入同步队列：同步引擎按
        // updatedAt LWW 应用云端行，不 bump 的话启动重算出的新值会被
        // 服务端旧快照原样盖回（表现为「重启也没变化」）。
        updatedAt: Value<int>(now),
        dirty: const Value<bool>(true),
      ),
    );
    await enqueueSyncOp(
      _db,
      table: 'investment_holdings',
      recordId: hid,
      opType: SyncOpType.update,
      updatedAt: now,
      payload: <String, Object?>{
        'realizedProfitMinor': realized,
      },
    );
  }

  /// 全量重算所有未删持仓的已实现盈亏（启动存量回填 / 数据修复用）。
  Future<void> recomputeAllRealized() async {
    final List<InvestmentHolding> holdings =
        await (_db.select(_db.investmentHoldings)
              ..where((InvestmentHoldings t) => t.deleted.equals(false)))
            .get();
    for (final InvestmentHolding h in holdings) {
      await _recomputeRealized(h.id);
    }
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

  /// 份额整数放大 1e6，转可读字符串：最多 4 位小数、去掉尾随多余的 0。
  /// 例：1000000 → '1'、1050000 → '1.05'、2500000000 → '2500'。
  String _fmtQty(int micros) =>
      formatQuantity(micros / InvestmentRepository.quantityScale);

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

  /// 从投资买卖流水备注反解「单价 / 手续费 / 份额」元信息（_investNote 同源格式：
  /// `买入-名称\n份额 x · 单价 ¥y · 手续费 ¥z[\n用户备注]`）。
  /// 返回 (priceMinor, feeMinor, qtyMicros)；旧数据/备注被改写时返回 null，
  /// 调用方须兜底（按流水金额与公式重算）。
  static (int, int, int)? parseTradeMeta(String? note) {
    if (note == null || note.isEmpty) return null;
    final RegExpMatch? m = RegExp(
      r'份额\s+([\d.]+)\s*·\s*单价\s*¥?\s*([\d,]+(?:\.\d+)?)\s*·\s*手续费\s*¥?\s*([\d,]+(?:\.\d+)?)',
    ).firstMatch(note);
    if (m == null) return null;
    final int qtyMicros =
        ((double.tryParse(m.group(1)!) ?? 0) * quantityScale).round();
    final int priceMinor =
        ((double.tryParse(m.group(2)!.replaceAll(',', '')) ?? 0) * 100).round();
    final int feeMinor =
        ((double.tryParse(m.group(3)!.replaceAll(',', '')) ?? 0) * 100).round();
    return (priceMinor, feeMinor, qtyMicros);
  }

  Future<InvestmentHolding?> getHoldingById(String id) {
    return (_db.select(_db.investmentHoldings)
          ..where((InvestmentHoldings t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 取某持仓的全部「未删」买卖流水（按时间升序），供导出遍历无损还原。
  ///
  /// 仅取未软删流水：编辑交易（[updateTrade]）会软删旧流水，若不过滤会把已
  /// 移除的成交在导出→再导入时被重新建出，导致份额/成本失真。
  Future<List<Transaction>> getFlows(String holdingId) {
    return (_db.select(_db.transactions)
          ..where(
            (Transactions t) =>
                t.relatedId.equals(holdingId) &
                t.sourceModule.equals(SourceModule.investment.index) &
                t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<Transactions>>[
            (Transactions t) => OrderingTerm.asc(t.occurredAt),
          ]))
        .get();
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
      // 卖出后重算并缓存已实现盈亏（落袋亏损从此可见）。
      await _recomputeRealized(holdingId);
    });
  }

  /// 编辑投资买卖流水：回滚原交易对持仓的影响 → 应用新值 → 删旧流水、记新流水
  /// （余额由 remove/add 自行冲销）。单事务原子提交。
  ///
  /// 原交易的份额/单价/手续费从原流水备注元信息行反解（[parseTradeMeta]），
  /// 反解失败时按「流水金额 ± 费 ÷ 原单价」公式兜底重算（与 record 同公式，
  /// 精度一致）。买入回滚 = 份额与成本同步扣减；卖出回滚 = 份额加回（成本价不动）。
  /// 支持编辑时改持仓（旧持仓回滚、新持仓应用）、改方向、改金额/单价/手续费/
  /// 账户/日期/备注。返回目标持仓 ID。
  Future<String> updateTrade({
    required Transaction original,
    required bool isBuy,
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
    if (original.sourceModule != SourceModule.investment) {
      throw const ValidationFailure('非投资流水不能走投资改单');
    }
    final String oldHid =
        original.relatedId ?? (throw const ValidationFailure('原流水缺少关联持仓'));
    if (amountMinor <= 0) throw const ValidationFailure('金额必须大于 0');
    if (priceMinor <= 0) throw const ValidationFailure('单价必须大于 0');
    if (feeMinor < 0) throw const ValidationFailure('手续费不能为负');

    final bool wasBuy = original.type == TxnType.expense;
    final (int, int, int)? meta = parseTradeMeta(original.note);
    final int oldFee = meta?.$2 ?? 0;
    final int oldPriceMinor = meta?.$1 ?? 0;
    final int oldQtyMicros = meta?.$3 ?? 0;
    // 原成交金额：买入 = 流水金额 − 手续费（费另扣）；卖出 = 流水金额 + 手续费。
    final int oldAmountMinor =
        wasBuy ? original.amountMinor - oldFee : original.amountMinor + oldFee;
    final int oldDelta = oldQtyMicros > 0
        ? oldQtyMicros
        : (oldPriceMinor > 0 && oldAmountMinor > 0)
            ? (oldAmountMinor * quantityScale) ~/ oldPriceMinor
            : 0;

    final String hid = holdingId ?? oldHid;
    final int deltaMicros = (amountMinor * quantityScale) ~/ priceMinor;
    if (deltaMicros <= 0) throw const ValidationFailure('金额不足以成交份额');

    final String catId =
        await _investCategoryId(bookId: original.bookId, isBuy: isBuy);
    final String flowNote = _investNote(
      isBuy: isBuy,
      name: name,
      quantityMicros: deltaMicros,
      priceMinor: priceMinor,
      feeMinor: feeMinor,
      note: note,
    );

    return _db.transaction<String>(() async {
      // ① 回滚原持仓的旧交易影响（编辑时改持仓则旧持仓单独回滚）。
      final InvestmentHolding? oldHolding = await (_db.select(
        _db.investmentHoldings,
      )..where((InvestmentHoldings t) => t.id.equals(oldHid)))
          .getSingleOrNull();
      if (oldHolding != null) {
        int qty = oldHolding.quantityMicros;
        int avg = oldHolding.avgCostMinor;
        if (wasBuy) {
          // 成本基数先减去原买入金额（买入的费不入成本，与 recordBuy 口径一致），
          // 再扣份额；份额被后续数据挤成负数时钳 0（成本随之近似，不回溯修史）。
          final int costMicros = qty * avg - oldAmountMinor * quantityScale;
          qty -= oldDelta;
          if (qty < 0) qty = 0;
          avg = qty == 0 ? 0 : (costMicros <= 0 ? avg : costMicros ~/ qty);
        } else {
          qty += oldDelta;
        }
        await (_db.update(_db.investmentHoldings)
              ..where((InvestmentHoldings t) => t.id.equals(oldHid)))
            .write(
          InvestmentHoldingsCompanion(
            quantityMicros: Value<int>(qty),
            avgCostMinor: Value<int>(avg),
            updatedAt: Value<int>(_now),
            dirty: const Value<bool>(true),
          ),
        );
        await enqueueSyncOp(
          _db,
          table: 'investment_holdings',
          recordId: oldHid,
          opType: SyncOpType.update,
          updatedAt: _now,
          payload: <String, Object?>{
            'quantityMicros': qty,
            'avgCostMinor': avg,
          },
        );
      }

      // ② 应用新交易到目标持仓（hid 可能等于 oldHid：读到的是①回滚后的行）。
      final InvestmentHolding? target = await (_db.select(
        _db.investmentHoldings,
      )..where((InvestmentHoldings t) => t.id.equals(hid)))
          .getSingleOrNull();
      if (target == null) throw const ValidationFailure('持仓不存在');
      int qty = target.quantityMicros;
      int avg = target.avgCostMinor;
      if (isBuy) {
        final int newQty = qty + deltaMicros;
        final int newCostMicros = qty * avg + amountMinor * quantityScale;
        final int newAvg = newQty == 0 ? 0 : newCostMicros ~/ newQty;
        await (_db.update(_db.investmentHoldings)
              ..where((InvestmentHoldings t) => t.id.equals(hid)))
            .write(
          InvestmentHoldingsCompanion(
            quantityMicros: Value<int>(newQty),
            avgCostMinor: Value<int>(newAvg),
            currentPriceMinor: Value<int>(priceMinor),
            priceUpdatedAt: Value<int?>(_now),
            updatedAt: Value<int>(_now),
            dirty: const Value<bool>(true),
          ),
        );
        await enqueueSyncOp(
          _db,
          table: 'investment_holdings',
          recordId: hid,
          opType: SyncOpType.update,
          updatedAt: _now,
          payload: <String, Object?>{
            'quantityMicros': newQty,
            'avgCostMinor': newAvg,
            'currentPriceMinor': priceMinor,
          },
        );
      } else {
        if (deltaMicros > qty) {
          throw const ValidationFailure('卖出份额超过持仓');
        }
        qty -= deltaMicros;
        await (_db.update(_db.investmentHoldings)
              ..where((InvestmentHoldings t) => t.id.equals(hid)))
            .write(
          InvestmentHoldingsCompanion(
            quantityMicros: Value<int>(qty),
            currentPriceMinor: Value<int>(priceMinor),
            priceUpdatedAt: Value<int?>(_now),
            updatedAt: Value<int>(_now),
            dirty: const Value<bool>(true),
          ),
        );
        await enqueueSyncOp(
          _db,
          table: 'investment_holdings',
          recordId: hid,
          opType: SyncOpType.update,
          updatedAt: _now,
          payload: <String, Object?>{
            'quantityMicros': qty,
            'currentPriceMinor': priceMinor,
          },
        );
      }

      // ③ 替换资金流水：删旧（余额回滚）+ 记新（余额再应用），
      //    金额口径与 recordBuy/recordSell 一致（买入另扣费、卖出费从收入扣）。
      await _txnRepo.remove(original.id);
      await _txnRepo.add(
        bookId: original.bookId,
        type: isBuy ? TxnType.expense : TxnType.income,
        amountMinor: isBuy
            ? amountMinor + feeMinor
            : (amountMinor - feeMinor) < 0
                ? 0
                : amountMinor - feeMinor,
        accountId: accountId,
        occurredAt: occurredAt,
        categoryId: catId,
        note: flowNote,
        sourceModule: SourceModule.investment,
        relatedId: hid,
        excludeFromStats: true,
        excludeFromBudget: true,
      );
      // 改单后重算并缓存相关持仓的已实现盈亏（旧/新持仓都要覆盖）。
      await _recomputeRealized(hid);
      if (oldHid != hid) await _recomputeRealized(oldHid);
      return hid;
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
    // 0 仓合法（先建标的、后由交易流水建仓）；负数才是非法。
    if (quantityMicros < 0) throw const ValidationFailure('份额不能为负');
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

  /// 浮动盈亏（分）= 市值 − 持仓成本（未摊薄口径，仅内部用），正数为盈利
  int get profitMinor => marketValueMinor - costValueMinor;

  /// 盈亏比例，成本为 0 时返回 0 而不是无穷大
  double get profitRatio =>
      costValueMinor == 0 ? 0 : profitMinor / costValueMinor;

  /// 摊薄总成本（分）= 持仓成本 − 已实现盈亏。
  ///
  /// 卖出亏损（已实现为负）摊入剩余持仓使成本升高——现价涨回摊薄成本即整体
  /// 回本；卖出盈利则摊薄成本降低。清仓（份额为 0）时无摊薄意义，返回 0
  /// （此时亏损已全部落袋，见已实现盈亏，不再折进成本）。
  int get dilutedCostValueMinor =>
      quantityMicros == 0 ? 0 : costValueMinor - realizedProfitMinor;

  /// 摊薄成本单价（分/份，四舍五入）
  int get dilutedAvgCostMinor => quantityMicros == 0
      ? 0
      : (dilutedCostValueMinor * InvestmentRepository.quantityScale +
              quantityMicros ~/ 2) ~/
          quantityMicros;

  /// 总盈亏（摊薄口径，分）= 市值 − 摊薄总成本，已包含持仓收益（已实现盈亏），
  /// 即「若现在清仓的总盈亏」。
  ///
  /// 清仓（份额为 0）时市值与成本均为 0，总盈亏回落为**全部落袋的持仓收益**，
  /// 供后期复盘（不为 0）。
  int get dilutedProfitMinor => quantityMicros == 0
      ? realizedProfitMinor
      : marketValueMinor - dilutedCostValueMinor;

  /// 摊薄口径盈亏比例，摊薄成本为 0 时返回 0
  double get dilutedProfitRatio => dilutedCostValueMinor == 0
      ? 0
      : dilutedProfitMinor / dilutedCostValueMinor;

  /// 实际份额（用于展示）
  double get quantity => quantityMicros / InvestmentRepository.quantityScale;
}

/// 累计买入成本（分）：按时间顺序重放流水，累加每笔买入的**净额**（流水金额 − 手续费）。
///
/// 与 [realizedProfitMinorFor] 同一套口径（买入净额计入成本基数）。
/// 清仓后它就是收益率的分母：收益率 = 持仓收益 ÷ 累计买入成本。
int investedCostMinorFor(List<Transaction> flows) {
  int invested = 0;
  for (final Transaction f in flows) {
    if (f.type != TxnType.expense) continue;
    final (int, int, int)? meta = InvestmentRepository.parseTradeMeta(f.note);
    // 买入流水金额含手续费，投资净额 = 流水金额 − 费（元信息缺失按 0 费兜底）。
    invested += f.amountMinor - (meta?.$2 ?? 0);
  }
  return invested;
}

/// 金额/数量格式化：最多 [maxDigits] 位小数，去除末尾多余的 0 与小数点。
///
/// 例：2500.0 → '2500'、0.5 → '0.5'、1.25 → '1.25'、0.0003 → '0.0003'。
/// 先按 [maxDigits] 四舍五入规避浮点误差（如 2500.0000001）。
String formatQuantity(double value, {int maxDigits = 4}) {
  final double rounded = double.parse(value.toStringAsFixed(maxDigits));
  final String s = rounded.toStringAsFixed(maxDigits);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// 按代码格式识别股票交易市场：A股 / 港股 / 美股；无法识别返回空串。
///
/// 规则（口径唯一，供持仓卡 / 详情 / 选择器共用）：
/// - `.HK` 后缀或 4~5 位纯数字 → 港股；
/// - `.SH` / `.SZ` / `.BJ` 后缀或 6 位纯数字（沪深京）→ A股；
/// - 纯英文字母（如 AAPL）→ 美股。
String stockMarketLabel(String symbol) {
  final String s = symbol.trim().toUpperCase();
  if (s.isEmpty) return '';
  if (s.endsWith('.HK')) return '港股';
  if (s.endsWith('.SH') || s.endsWith('.SZ') || s.endsWith('.BJ')) {
    return 'A股';
  }
  final String body = s.contains('.') ? s.split('.').first : s;
  if (RegExp(r'^\d+$').hasMatch(body)) {
    if (body.length == 4 || body.length == 5) return '港股';
    return 'A股'; // 6 位数字（沪深京）为主，其余位数的纯数字代码也归 A股
  }
  if (RegExp(r'^[A-Z]+$').hasMatch(body)) return '美股';
  return '';
}

/// 品种展示标签：股票按市场细分（A股 / 港股 / 美股 / AH股），其余用品种名。
///
/// [all] 传入当前账本全部持仓时，同名标的在 A股与港股同时持有则标「AH股」。
String investmentTypeLabel(
  InvestmentType type,
  String symbol, {
  String? name,
  Iterable<InvestmentHolding>? all,
}) {
  if (type != InvestmentType.stock) return type.label;
  final String market = stockMarketLabel(symbol);
  if ((market == 'A股' || market == '港股') && all != null) {
    final String key = (name ?? '').trim();
    final String counterpart = market == 'A股' ? '港股' : 'A股';
    if (key.isNotEmpty &&
        all.any(
          (InvestmentHolding o) =>
              o.type == InvestmentType.stock &&
              o.name.trim() == key &&
              stockMarketLabel(o.symbol) == counterpart,
        )) {
      return 'AH股';
    }
  }
  return market.isEmpty ? '股票' : market;
}

/// 从某持仓的买卖流水按时间顺序重放，核算**已实现盈亏**（分）。
///
/// 移动加权成本法：维护 (持股 qtyMicros, 成本基数 costMicros=Σ投资净额×scale)，
/// 买入把净额计入成本基数（费不计入，与 [recordBuy] 口径一致），
/// 卖出按当时均价计算 已实现 = 到账金额 − 已卖份额成本；到账金额 = 收入流水金额
/// （流水已扣手续费），已卖份额成本 = deltaMicros × 卖出时均价 ÷ scale。
///
/// 仅依赖流水备注元信息反解份额/单价/手续费（[parseTradeMeta]）；
/// 反解失败的卖出贡献 0（最差少算、绝不编造），与 [updateTrade] 兜底口径一致。
/// 本函数是 canonical 口径，[AppDatabase._replayRealizedProfit] 为其 DB 层复刻。
int realizedProfitMinorFor(String hid, List<Transaction> flows) {
  final List<Transaction> sorted = flows.toList()
    ..sort(
      (Transaction a, Transaction b) => a.occurredAt.compareTo(b.occurredAt),
    );
  int qtyMicros = 0;
  int costMicros = 0; // 单位：分·micros
  int realized = 0; // 分
  for (final Transaction f in sorted) {
    final (int, int, int)? meta = InvestmentRepository.parseTradeMeta(f.note);
    final int fee = meta?.$2 ?? 0;
    final int delta = meta?.$3 ?? 0;
    if (f.type == TxnType.expense) {
      // 买入流水金额含手续费，投资净额 = 流水金额 − 费。
      final int net = f.amountMinor - fee;
      qtyMicros += delta;
      costMicros += net * InvestmentRepository.quantityScale;
    } else if (f.type == TxnType.income && delta > 0) {
      // 卖出：到账 = 流水金额（已扣费）；已实现 = 到账 − 已卖份额成本。
      final int avg = qtyMicros == 0 ? 0 : costMicros ~/ qtyMicros;
      final int costRemoved =
          (delta * avg) ~/ InvestmentRepository.quantityScale;
      realized += f.amountMinor - costRemoved;
      qtyMicros -= delta;
    }
  }
  return realized;
}

/// 单轮（一轮 = 一次建仓到清仓/当前的完整买卖周期）重放结果。
///
/// 成本/已实现/投入均以「分」为单位（与 [InvestmentMath] 同口径，便于直接相减）。
class HoldCycle {
  const HoldCycle({
    required this.qtyMicros,
    required this.costValueMinor,
    required this.realizedMinor,
    required this.investedMinor,
    required this.startedAt,
    this.endedAt,
    this.boughtQtyMicros = 0,
  });

  /// 当前轮未平仓份额（micros）
  final int qtyMicros;

  /// 移动加权持仓成本基数（分）
  final int costValueMinor;

  /// 本轮已实现盈亏（分，卖出落袋，含本轮内部分减仓）
  final int realizedMinor;

  /// 本轮累计买入净额（分，金额 − 手续费）
  final int investedMinor;

  /// 本轮累计买入份额（micros，含其后已卖出的部分）
  final int boughtQtyMicros;

  /// 本轮建仓日
  final DateTime startedAt;

  /// 清仓日；未清仓为 null
  final DateTime? endedAt;

  /// 摊薄总成本（分）= 持仓成本 − 本轮已实现盈亏（亏损摊入剩余持仓使成本升高）。
  int get dilutedCostValueMinor =>
      qtyMicros == 0 ? 0 : costValueMinor - realizedMinor;

  /// 摊薄成本单价（分/份，四舍五入）
  int get dilutedAvgCostMinor => qtyMicros == 0
      ? 0
      : (dilutedCostValueMinor * InvestmentRepository.quantityScale +
              qtyMicros ~/ 2) ~/
          qtyMicros;

  /// 本轮总盈亏（摊薄口径，分）= 当前市值 − 摊薄总成本；清仓时为落袋收益。
  int dilutedProfitMinor(int marketValueMinor) =>
      qtyMicros == 0 ? realizedMinor : marketValueMinor - dilutedCostValueMinor;

  /// 本轮摊薄口径收益率（分母为摊薄成本）
  double dilutedProfitRatio(int marketValueMinor) => dilutedCostValueMinor == 0
      ? 0
      : dilutedProfitMinor(marketValueMinor) / dilutedCostValueMinor;

  /// 清仓后单价成本（分/份，四舍五入）= 本轮累计买入净额 ÷ 本轮累计买入份额。
  ///
  /// 完成轮（qty 已归零）即清仓时算得的单价成本；未平仓轮为该轮简单平均买价。
  int get clearedAvgCostMinor => boughtQtyMicros == 0
      ? 0
      : (investedMinor * InvestmentRepository.quantityScale +
              boughtQtyMicros ~/ 2) ~/
          boughtQtyMicros;
}

/// 某持仓的轮次划分结果：已完成轮列表 + 当前未平仓轮（可能 null）。
class HoldingCycleInfo {
  const HoldingCycleInfo({required this.completed, this.open});

  final List<HoldCycle> completed;
  final HoldCycle? open;

  /// 历史累计已实现盈亏（已完成轮合计，分）
  int get historyRealizedMinor =>
      completed.fold(0, (int a, HoldCycle c) => a + c.realizedMinor);

  /// 历史累计买入成本（已完成轮合计，分）
  int get historyInvestedMinor =>
      completed.fold(0, (int a, HoldCycle c) => a + c.investedMinor);

  /// 历史累计买入份额（已完成轮合计，micros）
  int get historyBoughtQtyMicros =>
      completed.fold(0, (int a, HoldCycle c) => a + c.boughtQtyMicros);

  /// 清仓后单价成本（分/份，四舍五入）= 历史累计投入 ÷ 历史累计买入份额。
  int get historyAvgCostMinor => historyBoughtQtyMicros == 0
      ? 0
      : (historyInvestedMinor * InvestmentRepository.quantityScale +
              historyBoughtQtyMicros ~/ 2) ~/
          historyBoughtQtyMicros;

  /// 是否含历史已完成轮（用于持仓/清仓双卡判定）
  bool get hasHistory => completed.isNotEmpty;
}

/// 按「零位穿越」切分某持仓的买卖流水为多个轮。
///
/// 份额从 0 增至正即开新一轮；落回 0 即该轮结束（清仓）。返回已完成轮 +
/// 当前未平仓轮。每轮内部用移动加权成本法（与 [realizedProfitMinorFor] 同口径）：
/// 买入净额累进成本基数，卖出按当时均价计已实现 = 到账 − 已卖份额成本。
///
/// 用于「清仓后再买入 = 新一轮」：持仓卡只看当前轮（成本/盈亏不带历史包袱），
/// 清仓卡累计历史已完成轮，再次清仓时并入并保留单一清仓卡。
(List<HoldCycle> completed, HoldCycle? open) replayHoldCycles(
  List<Transaction> flows,
) {
  final List<Transaction> sorted = flows.toList()
    ..sort(
      (Transaction a, Transaction b) => a.occurredAt.compareTo(b.occurredAt),
    );
  final List<HoldCycle> completed = <HoldCycle>[];
  int qty = 0;
  int cost = 0; // 分
  int realized = 0; // 分
  int invested = 0; // 分
  int bought = 0; // micros，本轮累计买入份额
  DateTime? startedAt;
  for (final Transaction f in sorted) {
    final (int, int, int)? meta = InvestmentRepository.parseTradeMeta(f.note);
    final int fee = meta?.$2 ?? 0;
    final int delta = meta?.$3 ?? 0;
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(
      f.occurredAt,
      isUtc: true,
    ).toLocal();
    if (f.type == TxnType.expense) {
      if (qty == 0) startedAt = d;
      final int net = f.amountMinor - fee;
      qty += delta;
      bought += delta;
      cost += net;
      invested += net;
    } else if (f.type == TxnType.income && delta > 0) {
      final int avg =
          qty == 0 ? 0 : (cost * InvestmentRepository.quantityScale) ~/ qty;
      final int costRemoved =
          (delta * avg) ~/ InvestmentRepository.quantityScale;
      realized += f.amountMinor - costRemoved;
      qty -= delta;
      cost -= costRemoved;
      if (qty == 0) {
        completed.add(
          HoldCycle(
            qtyMicros: 0,
            costValueMinor: 0,
            realizedMinor: realized,
            investedMinor: invested,
            startedAt: startedAt ?? d,
            endedAt: d,
            boughtQtyMicros: bought,
          ),
        );
        qty = 0;
        cost = 0;
        realized = 0;
        invested = 0;
        bought = 0;
        startedAt = null;
      }
    }
  }
  final HoldCycle? open = qty == 0
      ? null
      : HoldCycle(
          qtyMicros: qty,
          costValueMinor: cost,
          realizedMinor: realized,
          investedMinor: invested,
          startedAt: startedAt!,
          endedAt: null,
          boughtQtyMicros: bought,
        );
  return (completed, open);
}
