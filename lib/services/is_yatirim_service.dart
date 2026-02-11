import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../logo_service.dart';
import '../models/is_yatirim_model.dart';

const _baseUrl = 'https://www.isyatirim.com.tr/tr-tr/analiz/hisse/Sayfalar/sirket-karti.aspx';
const _headers = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'text/html,application/xhtml+xml',
  'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
};

/// İş Yatırım şirket kartından finansal verileri çeker
class IsYatirimService {
  static Future<IsYatirimModel> sirketKartiAl(String symbol) async {
    final base = LogoService.symbolForLogo(symbol).toUpperCase();
    final url = '$_baseUrl?hisse=$base';

    final response = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('İş Yatırım sayfası alınamadı (HTTP ${response.statusCode})');
    }

    return _parseHtml(response.body);
  }

  static IsYatirimModel _parseHtml(String body) {
    final doc = html_parser.parse(body);

    double? sonFiyat;
    double? gunlukDegisimYuzde;
    double? fK;
    double? pdDd;
    double? piyasaDegeri;
    double? netKar;
    double? temettuVerimi;

    // Tüm td/th hücrelerinden label-value çıkar (yan yana veya tablo yapısında)
    final cells = doc.querySelectorAll('td, th');
    for (var i = 0; i < cells.length - 1; i++) {
      final label = _cleanText(cells[i].text).toLowerCase();
      final valueStr = _cleanText(cells[i + 1].text);

      if (_matchesLabel(label, 'son fiyat', 'fiyat') && !label.contains('kazanç') && !label.contains('f/k')) {
        sonFiyat ??= _parsePrice(valueStr);
      } else if (_matchesLabel(label, 'günlük değişim', 'değişim %')) {
        gunlukDegisimYuzde ??= _parseNumber(valueStr.replaceAll('%', ''));
      } else if (_matchesLabel(label, 'f/k', 'fiyat/kazanç')) {
        fK ??= _parseNumber(valueStr);
      } else if (_matchesLabel(label, 'pd/dd', 'piyasa değeri / defter değeri')) {
        pdDd ??= _parseNumber(valueStr);
      } else if (label.contains('piyasa değeri') && !label.contains('defter') && !label.contains('/')) {
        piyasaDegeri ??= _parseBigNumber(valueStr);
      } else if (_matchesLabel(label, 'dönem net kar', 'ana ortaklık payları', 'net kâr')) {
        netKar ??= _parseBigNumber(valueStr);
      } else if (_matchesLabel(label, 'temettü verimi')) {
        temettuVerimi ??= _parseNumber(valueStr.replaceAll('%', ''));
      }
    }

    // Tablo satırları (tr > td) - label ilk hücrede, değer ikincide
    final rows = doc.querySelectorAll('tr');
    for (final row in rows) {
      final tds = row.querySelectorAll('td');
      if (tds.length >= 2) {
        final label = _cleanText(tds[0].text).toLowerCase();
        final valueStr = _cleanText(tds[1].text);

        if (sonFiyat == null && (_matchesLabel(label, 'son fiyat', 'fiyat') && !label.contains('kazanç'))) {
          sonFiyat = _parsePrice(valueStr);
        } else if (gunlukDegisimYuzde == null && _matchesLabel(label, 'günlük değişim')) {
          gunlukDegisimYuzde = _parseNumber(valueStr.replaceAll('%', ''));
        } else if (fK == null && _matchesLabel(label, 'f/k')) {
          fK = _parseNumber(valueStr);
        } else if (pdDd == null && _matchesLabel(label, 'pd/dd')) {
          pdDd = _parseNumber(valueStr);
        } else if (piyasaDegeri == null && label.contains('piyasa değeri') && !label.contains('/')) {
          piyasaDegeri = _parseBigNumber(valueStr);
        } else if (netKar == null && (_matchesLabel(label, 'dönem net kar', 'ana ortaklık payları') || label.contains('dönem net kar/zarar'))) {
          // İlk sayısal sütun (en güncel dönem) - td[1] yerine ilk geçerli sayı
          netKar = _parseBigNumber(valueStr);
          if (netKar == null && tds.length >= 3) {
            netKar = _parseBigNumber(_cleanText(tds[2].text));
          }
        } else if (temettuVerimi == null && _matchesLabel(label, 'temettü verimi')) {
          temettuVerimi = _parseNumber(valueStr.replaceAll('%', ''));
        }
      }
    }

    // Raw HTML regex yedek - F/K, PD/DD, sayılar
    if (fK == null) {
      final fkMatch = RegExp(r'F[/]?K["\s>]*[:\s]*([\d.,]+)', caseSensitive: false).firstMatch(body);
      if (fkMatch != null) fK = _parseNumber(fkMatch.group(1) ?? '');
    }
    if (pdDd == null) {
      final pdMatch = RegExp(r'PD[/]?DD["\s>]*[:\s]*([\d.,]+)', caseSensitive: false).firstMatch(body);
      if (pdMatch != null) pdDd = _parseNumber(pdMatch.group(1) ?? '');
    }

    return IsYatirimModel(
      sonFiyat: sonFiyat,
      gunlukDegisimYuzde: gunlukDegisimYuzde,
      fK: fK,
      pdDd: pdDd,
      piyasaDegeri: piyasaDegeri,
      netKar: netKar,
      temettuVerimi: temettuVerimi,
    );
  }

  static bool _matchesLabel(String label, String a, [String? b, String? c]) {
    if (label.contains(a)) return true;
    if (b != null && label.contains(b)) return true;
    if (c != null && label.contains(c)) return true;
    return false;
  }

  static String _cleanText(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  static double? _parseNumber(String s) {
    if (s.isEmpty) return null;
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  static double? _parsePrice(String s) {
    if (s.isEmpty) return null;
    // 1.234,56 veya 1234.56 formatı
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  /// Bin, milyon, milyar (Türkçe format: 1.234.567.890)
  static double? _parseBigNumber(String s) {
    if (s.isEmpty) return null;
    final cleaned = s.replaceAll(RegExp(r'[^\d,\.\-]'), '').replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
}
