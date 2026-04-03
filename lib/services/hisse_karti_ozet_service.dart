import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _keyOzetMetrikleri = 'hisse_karti_ozet_metrikleri';

/// Hisse kartı ÖZET bölümünde gösterilecek metriklerin ID'leri
const defaultMetrikler = [
  'kar_zarar',
  'adet',
  'guncel_deger',
  'toplam_maliyet',
  'hisse_basi_maliyet',
  'anlik_fiyat',
  'dun_kapanis',
  'gunluk_yuksek',
  'gunluk_dusuk',
];

/// Tüm seçilebilir metrikler: id -> görünen ad
const tumMetrikler = {
  'adet': 'Adet',
  'guncel_deger': 'Güncel değer',
  'toplam_maliyet': 'Toplam maliyet',
  'hisse_basi_maliyet': 'Hisse başı maliyet (ortalama)',
  'anlik_fiyat': 'Anlık fiyat',
  'kar_zarar': 'Kar / Zarar (alımdan bu yana)',
  'dun_kapanis': 'Dünkü kapanış',
  'son_1_gun_degisim': 'Son 1 gün değişim',
  'son_1_gun_degisim_yuzde': 'Son 1 gün değişim %',
  'son_1_hafta_degisim': 'Son 1 hafta değişim',
  'son_1_hafta_degisim_yuzde': 'Son 1 hafta değişim %',
  '52_hafta_en_yuksek': '52 hafta en yüksek',
  '52_hafta_en_dusuk': '52 hafta en düşük',
  'gunluk_yuksek': 'Günlük en yüksek',
  'gunluk_dusuk': 'Günlük en düşük',
  'portfoy_en_yuksek': 'Portföydeki en yüksek alış',
  'portfoy_en_dusuk': 'Portföydeki en düşük alış',
};

/// Hisse kartı ÖZET metrik tercihlerini SharedPreferences'ta saklar
class HisseKartiOzetService {
  static Future<List<String>> loadMetrikler() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyOzetMetrikleri);
    if (jsonStr == null || jsonStr.isEmpty) return List.from(defaultMetrikler);
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final ids = list.map((e) => e.toString()).toList();
      return ids.where((id) => tumMetrikler.containsKey(id)).toList();
    } catch (_) {
      return List.from(defaultMetrikler);
    }
  }

  static Future<void> saveMetrikler(List<String> metrikler) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOzetMetrikleri, jsonEncode(metrikler));
  }

  static Future<void> resetToDefault() async {
    await saveMetrikler(List.from(defaultMetrikler));
  }
}
