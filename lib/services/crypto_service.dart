import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/crypto_coin.dart';

/// Binance API ile kripto para piyasası verisi çeker.
/// Hisse servisinden bağımsız çalışır.
class CryptoService {
  static const _baseUrl = 'https://api.binance.com/api/v3/ticker/24hr';

  /// Popüler USDT çiftleri – genişletilebilir liste.
  /// Yeni kripto eklemek için bu listeye 'XXXUSDT' formatında ekleyin.
  static const List<String> defaultUsdtSymbols = [
    'BTCUSDT',
    'ETHUSDT',
    'BNBUSDT',
    'SOLUSDT',
    'AVAXUSDT',
    'XRPUSDT',
    'ADAUSDT',
    'DOGEUSDT',
    'DOTUSDT',
    'MATICUSDT',
    'LINKUSDT',
    'UNIUSDT',
    'ATOMUSDT',
    'LTCUSDT',
  ];

  /// İsteğe bağlı özel sembol listesi. null ise [defaultUsdtSymbols] kullanılır.
  static List<String>? customSymbols;

  static List<String> get _targetSymbols =>
      customSymbols ?? defaultUsdtSymbols;

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  /// Binance 24hr ticker'dan kripto piyasası verisini çeker.
  /// Filtreye uyan coin'leri [CryptoCoin] listesi olarak döner.
  /// Hata/İnternet yoksa boş liste döner (hata fırlatmaz).
  static Future<List<CryptoCoin>> getCryptoMarket() async {
    try {
      final response = await http
          .get(Uri.parse(_baseUrl), headers: _headers)
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw CryptoServiceException('İstek zaman aşımına uğradı.'),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final list = jsonDecode(response.body) as List<dynamic>?;
      if (list == null || list.isEmpty) return [];

      final targetSet = _targetSymbols.map((s) => s.toUpperCase()).toSet();
      final results = <CryptoCoin>[];

      double? parseNum(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final sym = (item['symbol'] as String? ?? '').toUpperCase();
        if (!targetSet.contains(sym)) continue;

        final price = parseNum(item['lastPrice']);
        if (price == null || price <= 0) continue;

        final changePercent = parseNum(item['priceChangePercent']) ?? 0.0;
        final volume = parseNum(item['volume']) ?? 0.0;

        results.add(CryptoCoin(
          symbol: sym,
          price: price,
          changePercent: changePercent,
          volume: volume,
        ));
      }

      // Hedef sıraya göre sırala (defaultUsdtSymbols sırası)
      final orderMap = {for (var i = 0; i < _targetSymbols.length; i++) _targetSymbols[i]: i};
      results.sort((a, b) =>
          (orderMap[a.symbol] ?? 999).compareTo(orderMap[b.symbol] ?? 999));

      return results;
    } on CryptoServiceException {
      return [];
    } on FormatException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Tek sembol için güncel fiyat (Binance ticker'dan)
  static Future<double?> getPrice(String symbol) async {
    final sym = symbol.toUpperCase();
    if (!sym.endsWith('USDT')) {
      return getPrice('${sym}USDT');
    }
    try {
      final response = await http
          .get(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=$sym'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      final p = json?['price'];
      if (p == null) return null;
      return (p is num) ? p.toDouble() : double.tryParse(p.toString());
    } catch (_) {
      return null;
    }
  }

  /// Tarihsel kapanış fiyatı (Binance klines - 1d)
  static Future<double?> getHistoricalPrice(String symbol, DateTime date) async {
    final sym = symbol.toUpperCase();
    final s = sym.endsWith('USDT') ? sym : '${sym}USDT';
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      final startMs = start.millisecondsSinceEpoch;
      final endMs = end.millisecondsSinceEpoch;
      final url = 'https://api.binance.com/api/v3/klines?symbol=$s&interval=1d&startTime=$startMs&endTime=$endMs&limit=1';
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final list = jsonDecode(response.body) as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      final k = list.first as List<dynamic>?;
      if (k == null || k.length < 5) return null;
      final close = k[4];
      return (close is num) ? close.toDouble() : double.tryParse(close.toString());
    } catch (_) {
      return null;
    }
  }

  /// Binance 24hr ticker'dan tüm USDT çiftlerini çeker (arama için).
  /// Sorgu ile başlayan veya içeren semboller döner; en fazla [limit] adet.
  static Future<List<CryptoCoin>> cryptoAraBinanceTum(String sorgu, {int limit = 60}) async {
    final q = sorgu.trim().toUpperCase().replaceAll(' ', '');
    if (q.isEmpty) return [];

    try {
      final response = await http
          .get(Uri.parse(_baseUrl), headers: _headers)
          .timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw CryptoServiceException('İstek zaman aşımına uğradı.'),
      );
      if (response.statusCode != 200) return [];

      final list = jsonDecode(response.body) as List<dynamic>?;
      if (list == null || list.isEmpty) return [];

      double? parseNum(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      final results = <CryptoCoin>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final sym = (item['symbol'] as String? ?? '').toUpperCase();
        if (!sym.endsWith('USDT')) continue;
        final displaySym = sym.substring(0, sym.length - 4);
        if (q.isNotEmpty && !displaySym.contains(q) && !sym.contains(q)) continue;

        final price = parseNum(item['lastPrice']);
        if (price == null || price <= 0) continue;
        final changePercent = parseNum(item['priceChangePercent']) ?? 0.0;
        final volume = parseNum(item['volume']) ?? 0.0;
        results.add(CryptoCoin(symbol: sym, price: price, changePercent: changePercent, volume: volume));
        if (results.length >= limit) break;
      }
      return results;
    } on CryptoServiceException {
      return [];
    } on FormatException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Arama için kripto listesi: önce tüm Binance USDT çiftlerinde ara; yoksa popüler listeyi kullan.
  static Future<List<CryptoCoin>> cryptoAra(String sorgu) async {
    final q = sorgu.trim().toUpperCase();
    if (q.isEmpty) return [];

    final fromBinance = await cryptoAraBinanceTum(q, limit: 60);
    if (fromBinance.isNotEmpty) return fromBinance;

    final all = await getCryptoMarket();
    return all
        .where((c) =>
            c.displaySymbol.toUpperCase().contains(q) ||
            c.symbol.toUpperCase().contains(q))
        .toList();
  }
}

class CryptoServiceException implements Exception {
  final String message;
  CryptoServiceException(this.message);

  @override
  String toString() => message;
}
