import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'advanced_metrics_model.dart';

class CollectApiService {
  static const _endpoint = 'https://api.collectapi.com/economy/hisseSenedi';

  static Future<AdvancedMetrics?> fetchAdvancedMetrics(String symbol) async {
    final apiKey = dotenv.env['COLLECT_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[CollectApiService] COLLECT_API_KEY .env içinde yok veya boş.');
      return null;
    }

    final normalizedSymbol = _normalizeCollectSymbol(symbol);
    final uri = Uri.parse('$_endpoint?symbol=$normalizedSymbol');
    final resp = await http.get(
      uri,
      headers: {
        'content-type': 'application/json',
        'authorization': 'apikey $apiKey',
      },
    ).timeout(const Duration(seconds: 12));
    print('API Response Body: ${resp.body}');

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('CollectAPI HTTP ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    final data = _normalizeData(decoded, normalizedSymbol);
    if (data == null) return null;
    debugPrint('[CollectApiService] symbol: $normalizedSymbol, keys: ${data.keys.join(', ')}');
    final hasAdvancedMetricKey = _pickNum(data, const [
          'fk',
          'f_k',
          'f/k',
          'pe',
          'peRatio',
          'priceEarningsRatio',
          'priceToBookRatio',
          'roe',
          'returnOnEquity',
          'dividendYield',
          'marketCap',
          'beta',
        ]) !=
        null;
    if (!hasAdvancedMetricKey) {
      debugPrint('[CollectApiService] Endpoint finansal oran keyleri donmuyor; metrikler null birakiliyor.');
      return null;
    }
    return AdvancedMetrics(
      fK: _pickNum(data, const [
        'fk',
        'f_k',
        'f/k',
        'pe',
        'peRatio',
        'priceEarningsRatio',
        'priceEarningsRatioTTM',
        'priceEarnings',
      ]),
      pdDd: _pickNum(data, const [
        'pd_dd',
        'pddd',
        'pd/dd',
        'priceToBook',
        'priceToBookRatio',
        'priceToBookRatioTTM',
        'pb',
        'pbRatio',
      ]),
      roe: _pickNum(data, const ['roe', 'returnOnEquity', 'returnOnEquityTTM']),
      temettuVerimi: _pickNum(data, const ['temettuVerimi', 'dividendYield', 'dividendYieldTTM']),
      piyasaDegeri: _pickNum(data, const ['piyasaDegeri', 'marketCap', 'marketCapitalization']),
      beta: _pickNum(data, const ['beta']),
    );
  }

  static Map<String, dynamic>? _normalizeData(dynamic decoded, String normalizedSymbol) {
    if (decoded is Map<String, dynamic>) {
      final result = decoded['result'];
      if (result is Map<String, dynamic>) return result;
      if (result is List && result.isNotEmpty) {
        final mapList = result.whereType<Map<String, dynamic>>().toList();
        if (mapList.isEmpty) return null;
        for (final item in mapList) {
          final code = (item['code'] ?? item['symbol'] ?? '').toString().trim().toUpperCase();
          if (code == normalizedSymbol) return item;
        }
        return mapList.first;
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is List && data.isNotEmpty) {
        final mapList = data.whereType<Map<String, dynamic>>().toList();
        if (mapList.isEmpty) return null;
        for (final item in mapList) {
          final code = (item['code'] ?? item['symbol'] ?? '').toString().trim().toUpperCase();
          if (code == normalizedSymbol) return item;
        }
        return mapList.first;
      }
      return decoded;
    }
    return null;
  }

  static double? _pickNum(Map<String, dynamic> map, List<String> keys) {
    final normalizedMap = <String, dynamic>{};
    for (final entry in map.entries) {
      normalizedMap[_normalizeKey(entry.key)] = entry.value;
    }
    for (final key in keys) {
      final value = normalizedMap[_normalizeKey(key)];
      final n = _parseNum(value);
      if (n != null) return n;
    }
    return null;
  }

  static double? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      var cleaned = value.trim().replaceAll('%', '');
      final hasDot = cleaned.contains('.');
      final hasComma = cleaned.contains(',');
      if (hasDot && hasComma) {
        // 1.234,56 -> 1234.56
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else if (hasComma) {
        // 12,34 -> 12.34
        cleaned = cleaned.replaceAll(',', '.');
      }
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9\.\-]'), '');
      if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;
      return double.tryParse(cleaned);
    }
    return null;
  }

  static String _normalizeCollectSymbol(String symbol) {
    var s = symbol.trim().toUpperCase();
    if (s.endsWith('.IS')) {
      s = s.substring(0, s.length - 3);
    }
    return s;
  }

  static String _normalizeKey(String key) {
    return key
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
