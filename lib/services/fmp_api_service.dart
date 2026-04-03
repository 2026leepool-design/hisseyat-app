import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'advanced_metrics_model.dart';

class FmpApiService {
  static Future<AdvancedMetrics?> fetchAdvancedMetrics(String symbol) async {
    final apiKey = dotenv.env['FMP_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[FmpApiService] FMP_API_KEY .env içinde yok veya boş.');
      return null;
    }

    final bistSymbol = _normalizeFmpSymbol(symbol);
    final ratioData = await _fetchFirst(
      'https://financialmodelingprep.com/api/v3/ratios/$bistSymbol?apikey=$apiKey',
    );
    final keyMetricsData = await _fetchFirst(
      'https://financialmodelingprep.com/api/v3/key-metrics/$bistSymbol?apikey=$apiKey',
    );
    if (ratioData == null && keyMetricsData == null) return null;

    final m = <String, dynamic>{...?(keyMetricsData), ...?(ratioData)};
    debugPrint('[FmpApiService] symbol: $bistSymbol, keys: ${m.keys.join(', ')}');
    return AdvancedMetrics(
      fK: _pickNum(m, const [
        'priceEarningsRatio',
        'priceEarningsRatioTTM',
        'peRatio',
        'trailingPE',
      ]),
      pdDd: _pickNum(m, const [
        'priceToBookRatio',
        'priceToBookRatioTTM',
        'pbRatio',
        'priceToBook',
      ]),
      roe: _pickNum(m, const ['returnOnEquity', 'roe', 'roeTTM']),
      temettuVerimi: _pickNum(m, const ['dividendYield', 'dividendYieldTTM']),
      piyasaDegeri: _pickNum(m, const ['marketCap', 'marketCapitalization']),
      beta: _pickNum(m, const ['beta']),
    );
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static double? _pickNum(Map<String, dynamic> map, List<String> keys) {
    final normalized = <String, dynamic>{};
    for (final entry in map.entries) {
      normalized[_normalizeKey(entry.key)] = entry.value;
    }
    for (final key in keys) {
      final n = _num(normalized[_normalizeKey(key)]);
      if (n != null) return n;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchFirst(String url) async {
    final uri = Uri.parse(url);
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    print('API Response Body: ${resp.body}');
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('FMP HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) {
      final err = decoded['Error Message']?.toString();
      if (err != null && err.isNotEmpty) {
        debugPrint('[FmpApiService] API hata mesaji: $err');
        return null;
      }
    }
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map<String, dynamic>) {
      return null;
    }
    return decoded.first as Map<String, dynamic>;
  }

  static String _normalizeFmpSymbol(String symbol) {
    final s = symbol.trim().toUpperCase();
    return s.endsWith('.IS') ? s : '$s.IS';
  }

  static String _normalizeKey(String key) {
    return key
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
