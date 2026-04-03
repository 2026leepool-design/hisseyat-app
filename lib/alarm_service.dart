import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/stock_alarm_local.dart';
import 'services/alarm_storage_service.dart';
import 'yahoo_finance_service.dart';
import 'logo_service.dart';

/// Fiyat alarmı kontrolü ve bildirim servisi (WorkManager + lokal alarmlar)
class AlarmService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Bildirim servisini başlatır
  static Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    const androidChannel = AndroidNotificationChannel(
      'stock_alarms',
      'Hisse Alarmları',
      description: 'Hisse fiyat alarmları için bildirimler',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  /// Android 13+ için bildirim izni ister
  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    if (!_initialized) await initialize();

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Uygulama açıkken alarm kontrolü (foreground)
  static Future<void> kontrolEtVeBildir() async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();

    try {
      final alarmlar = await AlarmStorageService.loadActiveAlarms();
      if (alarmlar.isEmpty) return;

      for (final alarm in alarmlar) {
        try {
          final meta = await YahooFinanceService.hisseChartMetaAl(alarm.symbol);
          final guncelFiyat = meta?.price;
          if (guncelFiyat == null || guncelFiyat <= 0) continue;

          final tetiklendi = alarm.isAbove
              ? guncelFiyat >= alarm.targetPrice
              : guncelFiyat <= alarm.targetPrice;

          if (tetiklendi) {
            await _bildirimGoster(alarm, guncelFiyat);
            await AlarmStorageService.updateAlarm(
                alarm.copyWith(isActive: false));
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
  }

  static Future<void> _bildirimGoster(
      StockAlarmLocal alarm, double guncelFiyat) async {
    final sembol = LogoService.symbolForDisplay(alarm.symbol);
    final tip = alarm.isAbove ? 'Hedef Fiyat' : 'Stop Fiyat';
    final baslik = '🔔 $sembol $tip Alarmı!';
    final mesaj = 'Güncel Fiyat: ${guncelFiyat.toStringAsFixed(2)} TL';

    const androidDetails = AndroidNotificationDetails(
      'stock_alarms',
      'Hisse Alarmları',
      channelDescription: 'Hisse fiyat alarmları için bildirimler',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      alarm.id.hashCode.abs(),
      baslik,
      mesaj,
      details,
    );
  }

}
