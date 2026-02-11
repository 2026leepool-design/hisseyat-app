import 'package:http/http.dart' as http;
import '../logo_service.dart';

/// Fintables şirket sayfasından logo URL'ini çeker ve önbelleğe alır.
class FintablesLogoService {
  static const _baseUrl = 'https://fintables.com/sirketler';
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml',
  };

  /// Sembol -> logo URL önbelleği (sayfa çekme maliyetini azaltır)
  static final Map<String, String> _urlCache = {};

  /// Varsayılan CDN pattern (sayfa çekilemezse denenir)
  static String _defaultLogoUrl(String baseSymbol) {
    final s = baseSymbol.toLowerCase();
    return 'https://storage.fintables.com/media/uploads/company-logos/${s}_icon.png';
  }

  /// Hisse için logo URL'ini döndürür.
  /// Önce Fintables şirket sayfasından gerçek logo URL'ini çıkarır;
  /// başarısız olursa varsayılan _icon.png pattern'ini kullanır.
  static Future<String> getLogoUrl(String symbol) async {
    final base = LogoService.symbolForLogo(symbol);
    final cacheKey = base.toUpperCase();

    if (_urlCache.containsKey(cacheKey)) {
      return _urlCache[cacheKey]!;
    }

    try {
      final pageUrl = '$_baseUrl/$base';
      final response = await http.get(
        Uri.parse(pageUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final url = _extractLogoUrlFromHtml(response.body, base);
        if (url != null && url.isNotEmpty) {
          _urlCache[cacheKey] = url;
          return url;
        }
      }
    } catch (_) {
      // Sayfa çekilemezse varsayılan URL'e düş
    }

    final fallback = _defaultLogoUrl(base);
    _urlCache[cacheKey] = fallback;
    return fallback;
  }

  /// HTML'den company-logos PNG URL'ini çıkarır.
  /// Hisse kodu ile başlayan (SASA, AKSA vb.) her türlü dosya adını kabul eder:
  /// SASA_icon.png, SASA_7zFPquG.png, aksa_icon.png vb.
  static String? _extractLogoUrlFromHtml(String html, String baseSymbol) {
    final escaped = RegExp.escape(baseSymbol);
    // company-logos/ + HISSE_KODU + (herhangi alfanumerik/altçizgi/nokta/tire) + .png
    final partRe = RegExp(
      'company-logos(?:%2F|/)($escaped[a-zA-Z0-9_.-]*\\.png)',
      caseSensitive: false,
    );
    final partMatch = partRe.firstMatch(html);
    if (partMatch != null) {
      final filename = partMatch.group(1);
      if (filename != null) {
        return 'https://storage.fintables.com/media/uploads/company-logos/$filename';
      }
    }

    // Direkt tam URL (yedek)
    final fullRe = RegExp(
      'https?://storage\\.fintables\\.com/media/uploads/company-logos/$escaped[a-zA-Z0-9_.-]*\\.png',
      caseSensitive: false,
    );
    final fullMatch = fullRe.firstMatch(html);
    if (fullMatch != null) {
      return fullMatch.group(0);
    }

    return null;
  }

  /// Önbelleği temizler (test veya bellek yönetimi için)
  static void clearCache() {
    _urlCache.clear();
  }
}
