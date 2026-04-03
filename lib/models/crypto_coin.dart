/// Binance 24hr ticker verisinden türetilen kripto para modeli.
/// Sembol 'BTCUSDT' şeklinde gelir; UI'da 'BTC' olarak gösterilir.
class CryptoCoin {
  final String symbol; // Binance formatı: BTCUSDT
  final double price;
  final double changePercent;
  final double volume;

  CryptoCoin({
    required this.symbol,
    required this.price,
    required this.changePercent,
    required this.volume,
  });

  /// Kullanıcıya gösterilen sembol (USDT kaldırılmış): BTC, ETH, vb.
  String get displaySymbol {
    if (symbol.toUpperCase().endsWith('USDT')) {
      return symbol.substring(0, symbol.length - 4);
    }
    return symbol;
  }
}
