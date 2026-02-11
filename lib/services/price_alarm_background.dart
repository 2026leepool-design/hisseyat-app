import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/stock_alarm_local.dart';

const _keyAlarms = 'stock_price_alarms';
const _baseUrl = 'https://query1.finance.yahoo.com/v8/finance/chart';
const _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36';

/// WorkManager için top-level callback - mutlaka sınıf dışında olmalı
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    await _runPriceAlarmCheck();
    return true;
  });
}

Future<void> _runPriceAlarmCheck() async {
  try {
    final alarms = await _loadAlarms();
    if (alarms.isEmpty) return;

    final notifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    const androidChannel = AndroidNotificationChannel(
      'stock_alarms',
      'Hisse Alarmları',
      description: 'Hisse fiyat alarmları için bildirimler',
      importance: Importance.high,
    );
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    for (final alarm in alarms) {
      if (!alarm.isActive) continue;
      try {
        final price = await _fetchPrice(alarm.symbol);
        if (price == null || price <= 0) continue;

        final tetiklendi = alarm.isAbove
            ? price >= alarm.targetPrice
            : price <= alarm.targetPrice;

        if (tetiklendi) {
          await _showNotification(notifications, alarm, price);
          await _deactivateAlarm(alarm);
        }
      } catch (_) {
        continue;
      }
    }
  } catch (_) {}
}

Future<List<StockAlarmLocal>> _loadAlarms() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = prefs.getString(_keyAlarms);
  if (jsonStr == null || jsonStr.isEmpty) return [];
  try {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => StockAlarmLocal.fromJson(e as Map<String, dynamic>))
        .where((a) => a.isActive)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<double?> _fetchPrice(String symbol) async {
  final raw = symbol.trim().toUpperCase();
  if (raw.isEmpty) return null;
  final sym = raw.endsWith('.IS') ? raw : '$raw.IS';
  final url = Uri.parse(
    '$_baseUrl/$sym?interval=1d&range=5d&includePrePost=false',
  );

  final response = await _httpGet(url);
  if (response == null) return null;

  final json = jsonDecode(response) as Map<String, dynamic>;
  final chart = json['chart'] as Map<String, dynamic>?;
  if (chart != null && chart['error'] != null) return null;

  final resultList = chart?['result'] as List<dynamic>?;
  if (resultList == null || resultList.isEmpty) return null;

  final result = resultList.first as Map<String, dynamic>;
  final meta = result['meta'] as Map<String, dynamic>?;
  if (meta == null) return null;

  double? parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  double? price = parseNum(meta['regularMarketPrice']) ?? parseNum(meta['previousClose']);
  if (price == null || price <= 0) {
    final indicators = result['indicators'] as Map<String, dynamic>?;
    final quoteList = indicators?['quote'] as List<dynamic>?;
    if (quoteList != null && quoteList.isNotEmpty) {
      final quote = quoteList.first as Map<String, dynamic>;
      final closeList = quote['close'] as List<dynamic>?;
      if (closeList != null && closeList.isNotEmpty) {
        final last = closeList.last;
        if (last != null) price = (last as num).toDouble();
      }
    }
  }
  return price;
}

Future<String?> _httpGet(Uri url) async {
  try {
    final response = await http
        .get(url, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) return response.body;
  } catch (_) {}
  return null;
}

Future<void> _showNotification(
  FlutterLocalNotificationsPlugin plugin,
  StockAlarmLocal alarm,
  double guncelFiyat,
) async {
  final sembol = _symbolForDisplay(alarm.symbol);
  final tip = alarm.isAbove ? 'Hedef Fiyat' : 'Stop Fiyat';
  final baslik = '🔔 $sembol $tip Alarmı!';
  final mesaj = 'Güncel Fiyat: ${guncelFiyat.toStringAsFixed(2)} TL';

  const androidDetails = AndroidNotificationDetails(
    'stock_alarms',
    'Hisse Alarmları',
    channelDescription: 'Hisse fiyat alarmları için bildirimler',
    importance: Importance.high,
    priority: Priority.high,
  );
  const details = NotificationDetails(android: androidDetails);
  await plugin.show(alarm.id.hashCode.abs(), baslik, mesaj, details);
}

String _symbolForDisplay(String symbol) {
  if (symbol.toUpperCase().endsWith('.IS')) {
    return symbol.substring(0, symbol.length - 3);
  }
  return symbol;
}

Future<void> _deactivateAlarm(StockAlarmLocal alarm) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = prefs.getString(_keyAlarms);
  if (jsonStr == null || jsonStr.isEmpty) return;
  try {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    final alarms = list
        .map((e) => StockAlarmLocal.fromJson(e as Map<String, dynamic>))
        .toList();
    final idx = alarms.indexWhere((a) => a.id == alarm.id);
    if (idx >= 0) {
      alarms[idx] = alarm.copyWith(isActive: false);
      await prefs.setString(_keyAlarms, jsonEncode(alarms.map((a) => a.toJson()).toList()));
    }
  } catch (_) {}
}
