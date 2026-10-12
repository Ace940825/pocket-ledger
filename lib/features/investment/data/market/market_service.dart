import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../domain/enums.dart';
import 'quote_models.dart';
import 'security_meta_repository.dart';

/// 行情服务：按品种路由到免费第三方源，统一 [Quote] / [SecurityCandidate]。
///
/// 一期仅接 **基金（天天基金）+ 加密货币（Binance）** 两类最稳、无 GBK 困扰的源；
/// 股票/ETF（需新浪 GBK+Referer）、外汇等留待二期。任何源失败都抛异常，
/// 由调用方（刷新/补全）try-catch 后跳过，**绝不中断整体流程**。
///
/// 合规提示：天天基金/新浪/Binance 均非官方或 ToS 灰色、限流无 SLA；本服务
/// 仅对个人持仓拉取行情、不上传任何数据，失败时保留旧价——见各调用点。
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
      default:
        return;
    }
  }

  /// 抓取单个持仓的现价（分）。非一期品种 / 解析失败返回 null。
  ///
  /// [cnyRate] 仅加密货币用：把 USDT 价折算成 CNY（与基金同币种，组合汇总不串币种）。
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
      default:
        return null;
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
    if (start < 0 || end < 0 || end <= start)
      return const <SecurityCandidate>[];
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
}
