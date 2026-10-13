import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../../domain/enums.dart';
import 'quote_models.dart';
import 'security_meta_repository.dart';

/// 行情服务：按品种路由到免费第三方源，统一 [Quote] / [SecurityCandidate]。
///
/// 一期接 **基金（天天基金）+ 加密货币（Binance）**；二期接 **股票/ETF（东方财富
/// push2，UTF-8 JSON 免 GBK 依赖）+ 外汇（open.er-api.com 经 USD 交叉换算）**；
/// 债券复用股票同套东方财富 secid；期货/期权/其他在 symbol 为东方财富 secid（期货/期权
/// 原始代码如 `AG2501` 自动补全为 `114.AG2501`）时取价；贵金属额外支持金/银现货代码
/// （XAU/黄金、XAG/白银）与 COMEX secid（119.XAU）。任何源失败都抛异常，由调用方
/// （刷新/补全）try-catch 后跳过，**绝不中断整体流程**。A股/港股/美股价格按各自市场
/// 币种折算成 CNY 聚合。
///
/// 合规提示：天天基金/Binance/东方财富/er-api/gold-api 均非官方或 ToS 灰色、限流无
/// SLA；本服务仅对个人持仓拉取行情、不上传任何数据，失败时保留旧价——见各调用点。
class MarketService {
  MarketService(this._meta, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: <String, String>{'User-Agent': 'Mozilla/5.0'},
              ),
            );

  final SecurityMetaRepository _meta;
  final Dio _dio;

  /// 确保某品种的候选库已加载（首拉/每周刷新），供自动补全本地查询。
  Future<void> ensureCandidates(InvestmentType type) async {
    switch (type) {
      case InvestmentType.fund:
        await _meta.ensureLoaded(type, _fetchFundList);
      case InvestmentType.crypto:
        await _meta.ensureLoaded(type, _fetchCryptoList);
      case InvestmentType.stock:
        await _meta.ensureLoaded(type, _fetchStockList);
      case InvestmentType.bond:
        await _meta.ensureLoaded(type, _fetchBondList);
      case InvestmentType.metal:
        await _meta.ensureLoaded(type, _fetchMetalList);
      case InvestmentType.forex:
        await _meta.ensureLoaded(type, _fetchForexList);
      case InvestmentType.futures:
        await _meta.ensureLoaded(type, _fetchFuturesList);
      case InvestmentType.option:
        await _meta.ensureLoaded(type, _fetchOptionList);
      case InvestmentType.other:
        await _meta.ensureLoaded(type, _fetchOtherList);
    }
  }

  /// 抓取单个持仓的现价（分）。未接品种 / 解析失败返回 null。
  ///
  /// [cnyRate] 加密货币 / 美股 / 港股 / 外汇折算用：把 USD 价折算成 CNY
  /// （与基金同币种，组合汇总不串币种）。
  Future<Quote?> fetchQuote(
    InvestmentType type,
    String symbol, {
    double cnyRate = 7.2,
  }) async {
    switch (type) {
      case InvestmentType.fund:
        return _fundQuote(symbol);
      case InvestmentType.crypto:
        return _cryptoQuote(symbol, cnyRate);
      case InvestmentType.stock:
        return _stockQuote(symbol, cnyRate);
      case InvestmentType.bond:
        // 债券与股票同套东方财富 secid 体系（1/0 前缀），直接复用。
        return _stockQuote(symbol, cnyRate);
      case InvestmentType.forex:
        return _forexQuote(symbol, cnyRate);
      case InvestmentType.metal:
        // 贵金属：secid（如 119.XAU）或常用金/银代码（XAU/黄金…）均尝试。
        return _metalQuote(symbol, cnyRate);
      case InvestmentType.futures:
      case InvestmentType.option:
        // 期货/期权：原始代码（如 `AG2501`）自动补全为东方财富 secid（114.…）后取价。
        return _secidQuote(_futuresSecid(symbol), cnyRate);
      case InvestmentType.other:
        // 其他：仅当 symbol 已是东方财富 secid 时取价，否则留手动价。
        return _secidQuote(symbol, cnyRate);
    }
  }

  /// USD→CNY 实时汇率（加密货币折算用）。失败返回兜底常量。
  Future<double> fetchUsdCnyRate() async {
    try {
      final Response<dynamic> resp =
          await _dio.get('https://open.er-api.com/v6/latest/USD');
      final Map<String, dynamic> j = resp.data is String
          ? jsonDecode(resp.data as String) as Map<String, dynamic>
          : resp.data as Map<String, dynamic>;
      final double? cny = (j['rates'] is Map ? j['rates']['CNY'] : null) == null
          ? null
          : (j['rates']['CNY'] as num).toDouble();
      if (cny != null && cny > 0) return cny;
    } catch (_) {
      // 忽略：用兜底汇率。
    }
    return 7.2;
  }

  // ── 基金：天天基金 ──

  Future<List<SecurityCandidate>> _fetchFundList() async {
    final Response<dynamic> resp =
        await _dio.get('https://fund.eastmoney.com/js/fundcode_search.js');
    final String body =
        resp.data is String ? resp.data as String : resp.data.toString();
    final int start = body.indexOf('[');
    final int end = body.lastIndexOf(']');
    if (start < 0 || end < 0 || end <= start) {
      return const <SecurityCandidate>[];
    }
    final List<dynamic> parsed =
        jsonDecode(body.substring(start, end + 1)) as List<dynamic>;
    final List<SecurityCandidate> out = <SecurityCandidate>[];
    for (final dynamic e in parsed) {
      if (e is! List || e.length < 3) continue;
      final String code = e[0].toString();
      final String name = e[2].toString();
      if (code.isEmpty || name.isEmpty) continue;
      out.add(
        SecurityCandidate(
          symbol: code,
          name: name,
          type: InvestmentType.fund,
        ),
      );
    }
    return out;
  }

  Future<Quote?> _fundQuote(String code) async {
    try {
      final Response<dynamic> resp = await _dio.get(
        'https://fundgz.1234567.com.cn/js/$code.js'
        '?rt=${DateTime.now().millisecondsSinceEpoch}',
      );
      final String body =
          resp.data is String ? resp.data as String : resp.data.toString();
      final int s = body.indexOf('(');
      final int e = body.lastIndexOf(')');
      if (s < 0 || e < 0 || e <= s) return null;
      final Map<String, dynamic> j =
          jsonDecode(body.substring(s + 1, e)) as Map<String, dynamic>;
      final String? raw = (j['gsz']?.toString().isNotEmpty == true
              ? j['gsz']?.toString()
              : null) ??
          j['dwjz']?.toString();
      final double? v = raw == null ? null : double.tryParse(raw);
      if (v == null) return null;
      return Quote(
        priceMinor: (v * 100).round(),
        currency: 'CNY',
        updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  // ── 加密货币：Binance ──

  Future<List<SecurityCandidate>> _fetchCryptoList() async {
    final Response<dynamic> resp =
        await _dio.get('https://api.binance.com/api/v3/exchangeInfo');
    final Map<String, dynamic> j = resp.data is String
        ? jsonDecode(resp.data as String) as Map<String, dynamic>
        : resp.data as Map<String, dynamic>;
    final List<dynamic> symbols =
        (j['symbols'] as List<dynamic>?) ?? <dynamic>[];
    final List<SecurityCandidate> out = <SecurityCandidate>[];
    for (final dynamic s in symbols) {
      if (s is! Map) continue;
      if (s['quoteAsset'] != 'USDT' || s['status'] != 'TRADING') continue;
      final String symbol = s['symbol']?.toString() ?? '';
      final String base = s['baseAsset']?.toString() ?? '';
      if (symbol.isEmpty || base.isEmpty) continue;
      out.add(
        SecurityCandidate(
          symbol: symbol,
          name: base,
          type: InvestmentType.crypto,
        ),
      );
    }
    return out;
  }

  Future<Quote?> _cryptoQuote(String symbol, double cnyRate) async {
    try {
      final Response<dynamic> resp = await _dio
          .get('https://api.binance.com/api/v3/ticker/price?symbol=$symbol');
      final Map<String, dynamic> j = resp.data is String
          ? jsonDecode(resp.data as String) as Map<String, dynamic>
          : resp.data as Map<String, dynamic>;
      final double? v = double.tryParse(j['price']?.toString() ?? '');
      if (v == null) return null;
      return Quote(
        priceMinor: (v * cnyRate * 100).round(),
        currency: 'CNY',
        updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  // ── 股票 / ETF：东方财富 push2（UTF-8 JSON，免 GBK 依赖） ──

  /// 候选库：拉取全部股票/ETF（A股沪·深 + 港股通 + 美股），供新建持仓自动补全。
  /// 三个市场经东方财富 clist 一并补齐；单个市场失败静默跳过（绝不阻塞）。
  Future<List<SecurityCandidate>> _fetchStockList() async {
    final List<SecurityCandidate> out = <SecurityCandidate>[];
    out.addAll(await _clistCandidates('m:0+t:6,m:0+t:80,m:1+t:2,m:1+t:23'));
    out.addAll(await _clistCandidates('m:116+t:1')); // 港股通
    out.addAll(await _clistCandidates('m:105+t:1')); // 美股
    return out;
  }

  /// 东方财富 clist 通用拉取：按 [fs] 取代码(f12)/市场(f13)/名称(f14)，依市场前缀补
  /// `.SH/.SZ/.HK` 后缀（美股保留裸字母），便于 [_stockSecid] 反解成 secid。
  Future<List<SecurityCandidate>> _clistCandidates(String fs) async {
    try {
      final Response<dynamic> resp = await _dio.get(
        'https://push2.eastmoney.com/api/qt/clist/get'
        '?pn=1&pz=8000&fs=$fs&fields=f12,f13,f14',
        options: Options(
          headers: <String, String>{'Referer': 'https://quote.eastmoney.com/'},
        ),
      );
      final Map<String, dynamic> j = resp.data is String
          ? jsonDecode(resp.data as String) as Map<String, dynamic>
          : resp.data as Map<String, dynamic>;
      final dynamic diff = j['data'] is Map ? j['data']['diff'] : null;
      if (diff is! List) return const <SecurityCandidate>[];
      final List<SecurityCandidate> out = <SecurityCandidate>[];
      for (final dynamic e in diff) {
        if (e is! Map) continue;
        final String code = e['f12']?.toString() ?? '';
        final String name = e['f14']?.toString() ?? '';
        if (code.isEmpty || name.isEmpty) continue;
        final int? market = int.tryParse(e['f13']?.toString() ?? '');
        String symbol = code;
        if (market == 1) {
          symbol = '$code.SH';
        } else if (market == 0) {
          symbol = '$code.SZ';
        } else if (market == 116) {
          symbol = '$code.HK';
        }
        // 美股(market 105)及未知市场：保留裸代码，由 [_stockSecid] 兜底。
        out.add(
          SecurityCandidate(
            symbol: symbol,
            name: name,
            type: InvestmentType.stock,
          ),
        );
      }
      return out;
    } catch (_) {
      return const <SecurityCandidate>[];
    }
  }

  /// 候选库：可转债（东方财富 datacenter 报表，散户最常持的债券类型）。
  /// 代码补 `.SH/.SZ` 后缀（沪 11xxxx / 深 12xxxx），便于 [_stockSecid] 反解；
  /// 失败返回空（绝不阻塞）。国债 / 企债暂无稳定免费源，留手输。
  Future<List<SecurityCandidate>> _fetchBondList() async {
    try {
      final Response<dynamic> resp = await _dio.get(
        'https://datacenter-web.eastmoney.com/api/data/v1/get'
        '?reportName=RPT_BOND_CB_LIST'
        '&columns=SECURITY_CODE,SECURITY_NAME_ABBR'
        '&pageSize=2000&sortColumns=SECURITY_CODE&sortTypes=1',
      );
      final Map<String, dynamic> j = resp.data is String
          ? jsonDecode(resp.data as String) as Map<String, dynamic>
          : resp.data as Map<String, dynamic>;
      final dynamic data =
          j['result'] is Map ? (j['result'] as Map)['data'] : null;
      if (data is! List) return const <SecurityCandidate>[];
      final List<SecurityCandidate> out = <SecurityCandidate>[];
      for (final dynamic e in data) {
        if (e is! Map) continue;
        final String code = e['SECURITY_CODE']?.toString() ?? '';
        final String name = e['SECURITY_NAME_ABBR']?.toString() ?? '';
        if (code.length != 6 || name.isEmpty) continue;
        final String symbol = code.startsWith('12') ? '$code.SZ' : '$code.SH';
        out.add(
          SecurityCandidate(
            symbol: symbol,
            name: name,
            type: InvestmentType.bond,
          ),
        );
      }
      return out;
    } catch (_) {
      return const <SecurityCandidate>[];
    }
  }

  /// 候选库：贵金属现货（品类固定，内置静态列表，离线可用、无需网络拉取）。
  /// 代码 XAU=黄金 / XAG=白银，与 [_metalQuote] 的现货识别一致。
  Future<List<SecurityCandidate>> _fetchMetalList() async =>
      const <SecurityCandidate>[
        SecurityCandidate(
          symbol: 'XAU',
          name: '黄金（现货）',
          type: InvestmentType.metal,
        ),
        SecurityCandidate(
          symbol: 'XAG',
          name: '白银（现货）',
          type: InvestmentType.metal,
        ),
      ];

  /// 候选库：主流外汇货币对（品类固定，内置静态列表，离线可用）。
  /// 代码形如 `USD/CNY`，与 [_forexBase] 解析一致（基础/报价货币）。
  Future<List<SecurityCandidate>> _fetchForexList() async =>
      const <SecurityCandidate>[
        SecurityCandidate(
          symbol: 'USD/CNY',
          name: '美元/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'EUR/CNY',
          name: '欧元/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'JPY/CNY',
          name: '日元/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'GBP/CNY',
          name: '英镑/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'HKD/CNY',
          name: '港币/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'AUD/CNY',
          name: '澳元/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'CAD/CNY',
          name: '加元/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'CHF/CNY',
          name: '瑞郎/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'SGD/CNY',
          name: '新加坡元/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'NZD/CNY',
          name: '新西兰元/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'KRW/CNY',
          name: '韩元/人民币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'USD/HKD',
          name: '美元/港币',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'EUR/USD',
          name: '欧元/美元',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'GBP/USD',
          name: '英镑/美元',
          type: InvestmentType.forex,
        ),
        SecurityCandidate(
          symbol: 'USD/JPY',
          name: '美元/日元',
          type: InvestmentType.forex,
        ),
      ];

  /// 候选库：内盘期货（品类相对固定，内置静态列表，离线可用、无需网络）。
  /// symbol 直接用东方财富 secid（market 114），与新建持仓自动补全回填一致；
  /// 选完保存 → 刷新行情即走 [_secidQuote] 取到价。某个 secid 失效仅该合约取不到价
  /// （留手动价），绝不中断。
  Future<List<SecurityCandidate>> _fetchFuturesList() async =>
      const <SecurityCandidate>[
        SecurityCandidate(
          symbol: '114.AU2501',
          name: '沪金2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.AG2501',
          name: '沪银2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.CU2501',
          name: '沪铜2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.SC2501',
          name: '原油2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.RB2501',
          name: '螺纹钢2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.I2501',
          name: '铁矿石2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.M2501',
          name: '豆粕2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.C2501',
          name: '玉米2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.SR2501',
          name: '白糖2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.CF2501',
          name: '棉花2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.TA2501',
          name: 'PTA2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.IF2501',
          name: '沪深300指数2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.IC2501',
          name: '中证500指数2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.IH2501',
          name: '上证50指数2501',
          type: InvestmentType.futures,
        ),
        SecurityCandidate(
          symbol: '114.T2501',
          name: '10年国债2501',
          type: InvestmentType.futures,
        ),
      ];

  /// 候选库：场内期权（内置静态列表，离线可用）。symbol 为东方财富 secid（114.…）。
  Future<List<SecurityCandidate>> _fetchOptionList() async =>
      const <SecurityCandidate>[
        SecurityCandidate(
          symbol: '114.CU2501C70000',
          name: '沪铜期权2501购70000',
          type: InvestmentType.option,
        ),
        SecurityCandidate(
          symbol: '114.AU2501C56000',
          name: '沪金期权2501购56000',
          type: InvestmentType.option,
        ),
        SecurityCandidate(
          symbol: '114.IO2501C4000',
          name: '沪深300股指期权2501购4000',
          type: InvestmentType.option,
        ),
        SecurityCandidate(
          symbol: '114.M2501C3200',
          name: '豆粕期权2501购3200',
          type: InvestmentType.option,
        ),
        SecurityCandidate(
          symbol: '114.CF2501C15000',
          name: '棉花期权2501购15000',
          type: InvestmentType.option,
        ),
        SecurityCandidate(
          symbol: '114.SC2501C600',
          name: '原油期权2501购600',
          type: InvestmentType.option,
        ),
      ];

  /// 候选库：其他（非标/小众品种示例，内置静态列表）。这些在东方财富也走 secid（114.…），
  /// 归类为用户口径的「其他」，按需可继续补充。
  Future<List<SecurityCandidate>> _fetchOtherList() async =>
      const <SecurityCandidate>[
        SecurityCandidate(
          symbol: '114.LC2501',
          name: '碳酸锂2501（其他）',
          type: InvestmentType.other,
        ),
        SecurityCandidate(
          symbol: '114.SI2501',
          name: '工业硅2501（其他）',
          type: InvestmentType.other,
        ),
        SecurityCandidate(
          symbol: '114.EC2501',
          name: '集运指数欧线2501（其他）',
          type: InvestmentType.other,
        ),
      ];

  /// 把用户输入的 symbol 解析成东方财富 secid（market.code）：
  /// 1=沪 / 0=深·京 / 116=港股 / 105=美股。
  String _stockSecid(String symbol) {
    final String s = symbol.trim().toUpperCase();
    if (s.isEmpty) return '';
    if (s.endsWith('.SH')) return '1.${s.substring(0, s.length - 3)}';
    if (s.endsWith('.SZ') || s.endsWith('.BJ')) {
      return '0.${s.substring(0, s.length - 3)}';
    }
    if (s.endsWith('.HK')) {
      final String code = s.substring(0, s.length - 3).padLeft(5, '0');
      return '116.$code';
    }
    final String body = s.contains('.') ? s.split('.').first : s;
    if (!RegExp(r'^\d+$').hasMatch(body)) return '105.$body'; // 美股纯字母
    if (body.length == 4 || body.length == 5) {
      return '116.${body.padLeft(5, '0')}'; // 港股 4~5 位
    }
    if (body.startsWith('6')) return '1.$body'; // 沪市 60/68 开头
    return '0.$body'; // 深市 00/30、京市 8/4 开头
  }

  Future<Quote?> _stockQuote(String symbol, double cnyRate) async {
    final String secid = _stockSecid(symbol);
    return _eastmoneyQuote(secid, cnyRate);
  }

  /// 东方财富 push2 通用取价（A股/债券/港股/美股/期货/期权/贵金属 secid 通吃）。
  /// [secid] 非法或源失败返回 null；按 market 前缀做币种换算并统一为 CNY。
  ///
  /// 注意：f43 是**定点整数**（真实价 × 10^f59，A股 f59=2），必须按精度还原，
  /// 否则 ¥28.02 会被读成 ¥2,802（2026-10-13 真机事故：中兴通讯 000063）。
  Future<Quote?> _eastmoneyQuote(String secid, double cnyRate) async {
    if (secid.isEmpty) return null;
    try {
      final Response<dynamic> resp = await _dio.get(
        'https://push2.eastmoney.com/api/qt/stock/get'
        '?secid=$secid&fields=f43,f59',
      );
      final Map<String, dynamic> j = resp.data is String
          ? jsonDecode(resp.data as String) as Map<String, dynamic>
          : resp.data as Map<String, dynamic>;
      final dynamic data = j['data'];
      if (data is! Map) return null;
      final double? raw = double.tryParse(data['f43']?.toString() ?? '');
      if (raw == null) return null;
      // f43 为定点整数：真实价 = f43 / 10^f59（f59 缺失时按 A股最常见的 2 位）。
      final int digits =
          (data['f59'] is num) ? (data['f59'] as num).toInt() : 2;
      final double v = raw / math.pow(10, digits).toDouble();
      final String market = secid.split('.').first;
      double cny = v;
      if (market == '116') {
        // 港股：本币 HKD，经 USD 交叉换算成 CNY。
        final double hkdPerUsd = await _fxPerUsd('HKD');
        if (hkdPerUsd > 0) cny = v * cnyRate / hkdPerUsd;
      } else if (market == '105' || market == '119') {
        cny = v * cnyRate; // 美股 / COMEX 美元品种 → CNY
      }
      // 1/0/114 等视为 CNY（A股 / 债券 / 内盘期货）
      return Quote(
        priceMinor: (cny * 100).round(),
        currency: 'CNY',
        updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  /// 期货 / 期权 / 其他：仅当 symbol 已是东方财富 secid（market.code）时取价。
  Future<Quote?> _secidQuote(String symbol, double cnyRate) async {
    final String s = symbol.trim().toUpperCase();
    if (!RegExp(r'^\d+\.[A-Z0-9]+$').hasMatch(s)) return null;
    return _eastmoneyQuote(s, cnyRate);
  }

  /// 期货/期权原始代码（如 `AG2501`）自动补全为东方财富 secid（market 114）。
  /// 已是 secid（含 `.`）则原样返回，便于直接粘贴 `114.AG2501`。
  String _futuresSecid(String symbol) {
    final String s = symbol.trim().toUpperCase();
    if (s.isEmpty || s.contains('.')) return s;
    return '114.$s';
  }

  /// 贵金属：secid（如 119.XAU）或常用金/银代码（XAU/GOLD/黄金、XAG/SILVER/白银）。
  /// 现货价来自公开免 key 接口（USD/oz），折 CNY 后返回；失败则尝试 secid。
  Future<Quote?> _metalQuote(String symbol, double cnyRate) async {
    final String s = symbol.trim().toUpperCase();
    if (s.isEmpty) return null;
    String? spot; // XAU / XAG
    if (RegExp(r'^(XAU|GOLD|黄金|金)$').hasMatch(s)) {
      spot = 'XAU';
    } else if (RegExp(r'^(XAG|SILVER|白银|银)$').hasMatch(s)) {
      spot = 'XAG';
    }
    if (spot != null) {
      try {
        final Response<dynamic> resp =
            await _dio.get('https://api.gold-api.com/price/$spot');
        final Map<String, dynamic> j = resp.data is String
            ? jsonDecode(resp.data as String) as Map<String, dynamic>
            : resp.data as Map<String, dynamic>;
        final double? v =
            (j['price'] is num) ? (j['price'] as num).toDouble() : null;
        if (v != null && v > 0) {
          return Quote(
            priceMinor: (v * cnyRate * 100).round(),
            currency: 'CNY',
            updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          );
        }
      } catch (_) {
        // 忽略：回落 secid 或返回 null。
      }
    }
    if (RegExp(r'^\d+\.[A-Z0-9]+$').hasMatch(s)) {
      return _eastmoneyQuote(s, cnyRate);
    }
    return null;
  }

  // ── 外汇：open.er-api.com 经 USD 交叉换算 ──

  /// 从外汇 symbol 解析基础货币（如 `USD/CNY`、`USDCNY`、`FXEURUSD` → USD）。
  String _forexBase(String symbol) {
    final String s = symbol.trim().toUpperCase();
    if (s.isEmpty) return '';
    if (s.contains('/')) return s.split('/').first.trim();
    if (s.startsWith('FX') && s.length >= 5) return s.substring(2, 5);
    if (s.length >= 6) return s.substring(0, 3);
    return s.length >= 3 ? s.substring(0, 3) : s;
  }

  /// 价格统一折算成 CNY：CNY per 1 单位 base = cnyRate / (base per USD)。
  Future<Quote?> _forexQuote(String symbol, double cnyRate) async {
    final String base = _forexBase(symbol);
    if (base.isEmpty) return null;
    try {
      final Response<dynamic> resp =
          await _dio.get('https://open.er-api.com/v6/latest/USD');
      final Map<String, dynamic> j = resp.data is String
          ? jsonDecode(resp.data as String) as Map<String, dynamic>
          : resp.data as Map<String, dynamic>;
      final dynamic rate = j['rates'] is Map ? j['rates'][base] : null;
      final double? perUsd = rate == null ? null : (rate as num).toDouble();
      if (perUsd == null || perUsd <= 0) return null;
      final double cny = cnyRate / perUsd;
      return Quote(
        priceMinor: (cny * 100).round(),
        currency: 'CNY',
        updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  /// 取某币种相对 USD 的汇率（er-api 给出的 rates 即「每 1 USD 多少该币种」）。
  Future<double> _fxPerUsd(String code) async {
    try {
      final Response<dynamic> resp =
          await _dio.get('https://open.er-api.com/v6/latest/USD');
      final Map<String, dynamic> j = resp.data is String
          ? jsonDecode(resp.data as String) as Map<String, dynamic>
          : resp.data as Map<String, dynamic>;
      final dynamic rate = j['rates'] is Map ? j['rates'][code] : null;
      final double? v = rate == null ? null : (rate as num).toDouble();
      if (v != null && v > 0) return v;
    } catch (_) {
      // 忽略：调用方用兜底。
    }
    return 0;
  }
}
