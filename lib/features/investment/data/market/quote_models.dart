/// 单次行情抓取结果（统一口径，屏蔽各源差异）。
class Quote {
  const Quote({
    required this.priceMinor,
    required this.currency,
    required this.updatedAt,
  });

  /// 现价（分，与持仓 [InvestmentHoldings.currentPriceMinor] 同精度）。
  final int priceMinor;

  /// 计价币种：CNY / USDT。
  final String currency;

  final int updatedAt;
}
