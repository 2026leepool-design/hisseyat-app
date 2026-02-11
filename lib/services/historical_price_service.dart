import 'dart:convert';
import 'package:http/http.dart' as http;

/// Belirli bir tarihte Yahoo Finance'tan kapanış fiyatı çeker.
/// Hafta sonu ise önceki iş gününe recursive olarak gider.
class HistoricalPriceService {
  static const _baseUrl = 'https://query1.finance.yahoo.com/v8/finance/chart';
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  /// Sembole .IS ekler (Türk hisseleri). USDTRY, EURTRY vb. için dokunmaz.
  static String _yahooSymbol(String raw) {
    final s = raw.trim().toUpperCase();
    if (s.contains('=X') || s.contains('.') && !s.endsWith('.IS')) return s;
    if (s.endsWith('.IS')) return s;
    return '$s.IS';
  }

  /// Belirli tarihteki kapanış fiyatını döndürür.
  /// Hafta sonu veya tatil gününde veri yoksa bir önceki iş gününe recursive gider.
  static Future<double?> getClosePrice(String symbol, DateTime date) async {
    final yahooSymbol = _yahooSymbol(symbol);
    final result = await _fetchCloseForDate(yahooSymbol, date);
    if (result != null) return result;
    // Veri yoksa (hafta sonu vb.) bir gün geri git
    final prevDay = DateTime(date.year, date.month, date.day - 1);
    if (prevDay.isBefore(DateTime(2000))) return null;
    return getClosePrice(symbol, prevDay);
  }

  static Future<double?> _fetchCloseForDate(String yahooSymbol, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 2));
    final period1 = start.millisecondsSinceEpoch ~/ 1000;
    final period2 = end.millisecondsSinceEpoch ~/ 1000;

    final url = Uri.parse(
      '$_baseUrl/$yahooSymbol?period1=$period1&period2=$period2&interval=1d&includePrePost=false',
    );

    try {
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Zaman aşımı'),
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      final chart = json?['chart'] as Map<String, dynamic>?;
      if (chart?['error'] != null) return null;

      final resultList = chart?['result'] as List<dynamic>?;
      if (resultList == null || resultList.isEmpty) return null;

      final result = resultList.first as Map<String, dynamic>;
      final indicators = result['indicators'] as Map<String, dynamic>?;
      final quoteList = indicators?['quote'] as List<dynamic>?;
      if (quoteList == null || quoteList.isEmpty) return null;

      final quote = quoteList.first as Map<String, dynamic>;
      final closeList = quote['close'] as List<dynamic>?;
      if (closeList == null || closeList.isEmpty) return null;

      final last = closeList.last;
      if (last == null) return null;
      final price = (last as num).toDouble();
      return price > 0 ? price : null;
    } catch (_) {
      return null;
    }
  }

  /// Birden fazla sembol için fiyatları 5'erli gruplar halinde, 500ms aralarla çeker.
  static Future<Map<String, double?>> getClosePricesBatched(
    List<String> symbols,
    DateTime date,
  ) async {
    final results = <String, double?>{};
    const batchSize = 5;
    const delayMs = 500;

    for (var i = 0; i < symbols.length; i += batchSize) {
      final batch = symbols.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((s) => getClosePrice(s, date).then((v) => MapEntry(s, v))),
      );
      for (final e in batchResults) {
        results[e.key] = e.value;
      }
      if (i + batchSize < symbols.length) {
        await Future.delayed(const Duration(milliseconds: delayMs));
      }
    }
    return results;
  }
}
