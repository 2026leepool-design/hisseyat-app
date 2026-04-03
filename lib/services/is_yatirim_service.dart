import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import '../logo_service.dart';
import '../models/is_yatirim_model.dart';
import '../util/company_about_text.dart';

const _baseUrl = 'https://www.isyatirim.com.tr/tr-tr/analiz/hisse/Sayfalar/sirket-karti.aspx';
const _headers = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'text/html,application/xhtml+xml',
  'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
};

/// İş Yatırım şirket kartından finansal verileri çeker
class IsYatirimService {
  static String _decodeResponseBody(http.Response response) {
    final ct = response.headers['content-type']?.toLowerCase() ?? '';
    final bytes = response.bodyBytes;
    if (ct.contains('iso-8859') ||
        ct.contains('windows-1254') ||
        ct.contains('charset=windows-1254')) {
      return latin1.decode(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// İş Yatırım şirket kartından şirket profili (künye + faaliyet alanı) çeker.
  /// Sembol URL'de .IS olmadan kullanılır (THYAO.IS -> THYAO).
  /// Yanıt çoğunlukla UTF-8; charset latin ise latin1 kullanılır.
  static Future<IsYatirimCompanyProfile?> fetchCompanyProfile(String symbol) async {
    try {
      final base = LogoService.symbolForLogo(symbol).toUpperCase();
      if (base.isEmpty) return null;
      final url = '$_baseUrl?hisse=$base';

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;
      final body = _decodeResponseBody(response);
      return _parseCompanyProfileHtml(body);
    } catch (_) {
      return null;
    }
  }

  static IsYatirimCompanyProfile? _parseCompanyProfileHtml(String body) {
    final doc = html_parser.parse(body);
    doc.querySelectorAll('script, style, noscript').forEach((e) => e.remove());

    String? sirketUnvani;
    String? kurulusTarihi;
    String? genelMudur;
    String? sektor;
    String? webSitesi;
    String? halkaArzTarihi;
    String? odenmisSermaye;
    String? fiiliDolasimOraniStr;
    double? fiiliDolasimOraniYuzde;
    String? sirketHakkinda;

    String trimLabel(String s) => _cleanText(s);

    void setFromLabel(String label, String value) {
      final v = _cleanText(value);
      final l = trimLabel(label);
      if (v.isEmpty) return;
      if (_labelContains(l, 'Genel Müdür')) genelMudur ??= v;
      else if (_labelContains(l, 'Kuruluş Tarihi')) kurulusTarihi ??= v;
      else if (_labelContains(l, 'Faaliyet Alanı') || _labelContains(l, 'Sektör')) sektor ??= v;
      else if (_labelContains(l, 'Web Adresi')) webSitesi ??= v;
      else if (_labelContains(l, 'Halka Arz Tarihi')) halkaArzTarihi ??= v;
      else if (_labelContains(l, 'Ödenmiş Sermaye')) odenmisSermaye ??= v;
      else if (_labelContains(l, 'Fiili Dolaşım Oranı')) {
        fiiliDolasimOraniStr ??= v;
        final numStr = v.replaceAll('%', '').replaceAll(',', '.').trim();
        fiiliDolasimOraniYuzde ??= double.tryParse(numStr);
      }
    }

    // Tablolarda: <th> veya <td> başlık, hemen sonraki <td> değer
    final tables = doc.querySelectorAll('table');
    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td, th');
        if (cells.length >= 2) {
          final label = trimLabel(cells[0].text);
          final value = trimLabel(cells[1].text);
          setFromLabel(label, value);
        }
      }
    }

    // Tüm td/th sıralı: label sonra değer
    final cells = doc.querySelectorAll('td, th');
    for (var i = 0; i < cells.length - 1; i++) {
      setFromLabel(_cleanText(cells[i].text), _cleanText(cells[i + 1].text));
    }

    if (sirketUnvani == null) {
      final title = doc.querySelector('title');
      if (title != null) {
        final t = _cleanText(title.text);
        if (t.isNotEmpty && !t.toLowerCase().startsWith('error')) sirketUnvani = t;
      }
    }
    if (sirketUnvani == null) {
      final h1 = doc.querySelector('h1');
      if (h1 != null) {
        final t = _cleanText(h1.text);
        if (t.isNotEmpty) sirketUnvani = t;
      }
    }

    sirketHakkinda = _extractSirketHakkinda(doc);

    return IsYatirimCompanyProfile(
      sirketUnvani: sirketUnvani,
      kurulusTarihi: kurulusTarihi,
      genelMudur: genelMudur,
      sektor: sektor,
      webSitesi: webSitesi,
      halkaArzTarihi: halkaArzTarihi,
      odenmisSermaye: odenmisSermaye,
      fiiliDolasimOrani: fiiliDolasimOraniStr,
      fiiliDolasimOraniYuzde: fiiliDolasimOraniYuzde,
      sirketHakkinda: sirketHakkinda,
    );
  }

  static bool _labelContains(String label, String needle) {
    return label.toLowerCase().contains(needle.toLowerCase());
  }

  static Future<IsYatirimModel> sirketKartiAl(String symbol) async {
    final base = LogoService.symbolForLogo(symbol).toUpperCase();
    final url = '$_baseUrl?hisse=$base';

    final response = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('İş Yatırım sayfası alınamadı (HTTP ${response.statusCode})');
    }

    final body = _decodeResponseBody(response);
    return _parseHtml(body);
  }

  /// Script/menü dışı, anlamlı faaliyet paragrafı.
  static String? _extractSirketHakkinda(Document doc) {
    const selectors = [
      'main p',
      'article p',
      '[role="main"] p',
      '.ms-richtextfield p',
      '.ms-rtestate-field p',
      '#DeltaPlaceHolderMain p',
      '.ms-rte-wpcontainer p',
    ];
    for (final sel in selectors) {
      for (final p in doc.querySelectorAll(sel)) {
        final text = _cleanText(p.text);
        if (text.length < 80) continue;
        if (CompanyAboutText.isGarbage(text)) continue;
        return text;
      }
    }
    for (final p in doc.querySelectorAll('p')) {
      final text = _cleanText(p.text);
      if (text.length < 120) continue;
      if (CompanyAboutText.isGarbage(text)) continue;
      return text;
    }
    return null;
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
    final l = label.toLowerCase();
    if (l.contains(a.toLowerCase())) return true;
    if (b != null && l.contains(b.toLowerCase())) return true;
    if (c != null && l.contains(c.toLowerCase())) return true;
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
