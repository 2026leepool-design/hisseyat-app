import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // 1. Kullanıcıdan bildirim izni iste (iOS ve Android 13+ için zorunlu)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Kullanıcı bildirim izni verdi.');

      // 2. Bu cihaza ait benzersiz FCM Token'ı al
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('FCM Token alındı: $token');
        await saveTokenToSupabase(token);
      }

      // 3. Token yenilenirse (uygulama silinip yüklenirse vb.) tekrar kaydet
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        saveTokenToSupabase(newToken);
      });
    } else {
      debugPrint('Kullanıcı bildirim iznini reddetti.');
    }
  }

  /// Token'ı Supabase'deki profiles tablosuna kaydeder
  static Future<void> saveTokenToSupabase(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'fcm_token': token, // Bu sütunu veritabanına ekleyeceğiz
        });
        debugPrint('FCM Token Supabase\'e kaydedildi.');
      } catch (e) {
        debugPrint('Token kaydedilirken hata oluştu: $e');
      }
    }
  }
}