import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _keyFavoriHisseSembolleri = 'favori_hisse_sembolleri';

/// Favori hisse sembollerini (BIST kodu, örn. THYAO) SharedPreferences'ta saklar.
class FavoriHisseService {
  static Future<List<String>> getFavoriler() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyFavoriHisseSembolleri);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e.toString().toUpperCase()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setFavoriler(List<String> semboller) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = semboller.map((s) => s.toUpperCase()).toSet().toList();
    await prefs.setString(_keyFavoriHisseSembolleri, jsonEncode(normalized));
  }

  /// Sembolü normalize eder (THYAO.IS -> THYAO).
  static String _norm(String symbol) {
    final s = symbol.toUpperCase();
    return s.endsWith('.IS') ? s.substring(0, s.length - 3) : s;
  }

  static Future<bool> isFavori(String symbol) async {
    final list = await getFavoriler();
    return list.contains(_norm(symbol));
  }

  static Future<void> toggleFavori(String symbol) async {
    final list = await getFavoriler();
    final n = _norm(symbol);
    if (list.contains(n)) {
      await setFavoriler(list.where((s) => s != n).toList());
    } else {
      await setFavoriler([...list, n]);
    }
  }

  static Future<void> favoriEkle(String symbol) async {
    final list = await getFavoriler();
    final n = _norm(symbol);
    if (list.contains(n)) return;
    await setFavoriler([...list, n]);
  }

  static Future<void> favoriCikar(String symbol) async {
    final list = await getFavoriler();
    await setFavoriler(list.where((s) => s != _norm(symbol)).toList());
  }
}
