import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock_alarm_local.dart';

const _keyAlarms = 'stock_price_alarms';

/// Alarmları SharedPreferences'ta saklar
class AlarmStorageService {
  static Future<List<StockAlarmLocal>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyAlarms);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => StockAlarmLocal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<StockAlarmLocal>> loadActiveAlarms() async {
    final all = await loadAlarms();
    return all.where((a) => a.isActive).toList();
  }

  static Future<void> saveAlarms(List<StockAlarmLocal> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final list = alarms.map((a) => a.toJson()).toList();
    await prefs.setString(_keyAlarms, jsonEncode(list));
  }

  static Future<void> addAlarm(StockAlarmLocal alarm) async {
    final alarms = await loadAlarms();
    alarms.add(alarm);
    await saveAlarms(alarms);
  }

  static Future<void> removeAlarm(String id) async {
    final alarms = await loadAlarms();
    alarms.removeWhere((a) => a.id == id);
    await saveAlarms(alarms);
  }

  static Future<void> updateAlarm(StockAlarmLocal alarm) async {
    final alarms = await loadAlarms();
    final idx = alarms.indexWhere((a) => a.id == alarm.id);
    if (idx >= 0) {
      alarms[idx] = alarm;
      await saveAlarms(alarms);
    }
  }

  static Future<void> toggleActive(String id) async {
    final alarms = await loadAlarms();
    final idx = alarms.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      alarms[idx] = alarms[idx].copyWith(isActive: !alarms[idx].isActive);
      await saveAlarms(alarms);
    }
  }

  static Future<List<StockAlarmLocal>> getAlarmsForSymbol(String symbol) async {
    final alarms = await loadAlarms();
    final s = symbol.trim().toUpperCase();
    return alarms.where((a) => a.symbol.toUpperCase() == s).toList();
  }
}
