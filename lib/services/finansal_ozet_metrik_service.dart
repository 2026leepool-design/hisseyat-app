import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _keyFinansalOzetMetrikleri = 'finansal_ozet_metrikleri';

/// Finansal Özet ekranında varsayılan gösterilecek metrikler
/// Yahoo meta: fiyat/hacim | İş Yatırım: oranlar ve bilanço
const defaultFinansalOzetMetrikler = [
  'onceki_kapanis',
  'hacim',
  'gunluk_yuksek_dusuk',
  '52_haftalik_aralik',
  'son_fiyat',
  'gunluk_degisim',
  'f_k',
  'pd_dd',
  'piyasa_degeri',
  'net_kar',
  'temettu_verimi',
];

/// Tüm seçilebilir metrikler: id -> görünen ad
/// Yahoo meta: onceki_kapanis, hacim, gunluk_yuksek_dusuk, 52_haftalik_aralik
/// İş Yatırım: son_fiyat, gunluk_degisim, f_k, pd_dd, piyasa_degeri, net_kar, temettu_verimi
const tumFinansalOzetMetrikler = {
  'onceki_kapanis': 'Önceki Kapanış',
  'hacim': 'Hacim',
  'gunluk_yuksek_dusuk': 'Günlük Yüksek/Düşük',
  '52_haftalik_aralik': '52 Haftalık Aralık',
  'son_fiyat': 'Son Fiyat',
  'gunluk_degisim': 'Günlük Değişim %',
  'f_k': 'F/K (Fiyat/Kazanç)',
  'pd_dd': 'PD/DD (Piyasa/Defter Değeri)',
  'piyasa_degeri': 'Piyasa Değeri',
  'net_kar': 'Net Kâr (Son Dönem)',
  'temettu_verimi': 'Temettü Verimi',
};

/// Finansal Özet metrik tercihlerini SharedPreferences'ta saklar
class FinansalOzetMetrikService {
  static Future<List<String>> loadMetrikler() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyFinansalOzetMetrikleri);
    if (jsonStr == null || jsonStr.isEmpty) return List.from(defaultFinansalOzetMetrikler);
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final ids = list.map((e) => e.toString()).toList();
      return ids.where((id) => tumFinansalOzetMetrikler.containsKey(id)).toList();
    } catch (_) {
      return List.from(defaultFinansalOzetMetrikler);
    }
  }

  static Future<void> saveMetrikler(List<String> metrikler) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFinansalOzetMetrikleri, jsonEncode(metrikler));
  }

  static Future<void> resetToDefault() async {
    await saveMetrikler(List.from(defaultFinansalOzetMetrikler));
  }
}
