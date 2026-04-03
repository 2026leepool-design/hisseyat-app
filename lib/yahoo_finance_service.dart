import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'data/bist_hisseleri.dart';

/// Yahoo Finance'tan hisse bilgisi (anlık fiyat ve tam ad) çeker.
class YahooFinanceService {
  static const _baseUrl = 'https://query1.finance.yahoo.com/v8/finance/chart';
  static const _searchUrl = 'https://query1.finance.yahoo.com/v1/finance/search';
  static const _quoteSummaryUrl = 'https://query1.finance.yahoo.com/v10/finance/quoteSummary';

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36',
  };

  /// Sembole .IS ekler (Türk hisseleri için). Zaten .IS ile bitiyorsa eklemez.
  static String _sembolIsEkle(String raw) {
    if (raw.endsWith('.IS')) return raw;
    return '$raw.IS';
  }

  /// Hisse sembolüne göre anlık fiyat ve tam adı getirir.
  /// Başarılı: [HisseBilgisi] döner.
  /// Hata: [YahooFinanceHata] fırlatır.
  static Future<HisseBilgisi> hisseAra(String sembol) async {
    final raw = sembol.trim().toUpperCase();
    if (raw.isEmpty) {
      throw YahooFinanceHata('Lütfen bir hisse sembolü girin.');
    }
    final symbol = _sembolIsEkle(raw);

    final url = Uri.parse(
      '$_baseUrl/$symbol?interval=1d&range=5d&includePrePost=false',
    );

    final response = await http.get(url, headers: _headers).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw YahooFinanceHata(
        'İstek zaman aşımına uğradı. İnternet bağlantınızı kontrol edin.',
      ),
    );

    if (response.statusCode != 200) {
      debugPrint('[Yahoo hisseAra] HTTP ${response.statusCode} URL: $url');
      throw YahooFinanceHata(
        'Hisse bulunamadı veya sunucu hatası. (HTTP ${response.statusCode})',
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final chart = json['chart'] as Map<String, dynamic>?;

      if (chart != null && chart['error'] != null) {
        final err = chart['error'] as Map<String, dynamic>?;
        final desc = err?['description'] as String? ?? 'Hisse bulunamadı.';
        throw YahooFinanceHata(desc);
      }

      final resultList = chart?['result'] as List<dynamic>?;

      if (resultList == null || resultList.isEmpty) {
        throw YahooFinanceHata('Hisse bulunamadı: $symbol');
      }

      final result = resultList.first as Map<String, dynamic>;
      final meta = result['meta'] as Map<String, dynamic>?;

      if (meta == null) {
        throw YahooFinanceHata('Hisse verisi alınamadı.');
      }

      // Anlık fiyat: regularMarketPrice veya previousClose
      double? fiyat = (meta['regularMarketPrice'] as num?)?.toDouble();
      fiyat ??= (meta['previousClose'] as num?)?.toDouble();
      if (fiyat == null) {
        // indicators.quote[0].close son elemanını kullan
        final indicators = result['indicators'] as Map<String, dynamic>?;
        final quoteList = indicators?['quote'] as List<dynamic>?;
        if (quoteList != null && quoteList.isNotEmpty) {
          final quote = quoteList.first as Map<String, dynamic>;
          final closeList = quote['close'] as List<dynamic>?;
          if (closeList != null && closeList.isNotEmpty) {
            final lastClose = closeList.last;
            if (lastClose != null) {
              fiyat = (lastClose as num).toDouble();
            }
          }
        }
      }
      if (fiyat == null || fiyat <= 0) {
        throw YahooFinanceHata('Fiyat bilgisi alınamadı.');
      }

      // Tam ad: longName, shortName veya symbol
      final tamAd = meta['longName'] as String? ??
          meta['shortName'] as String? ??
          meta['symbol'] as String? ??
          symbol;

      double? previousClose = _oncekiKapanisSeriden(result) ??
          (meta['chartPreviousClose'] as num?)?.toDouble() ??
          (meta['previousClose'] as num?)?.toDouble();

      double? degisimYuzde;
      if (previousClose != null && previousClose > 0) {
        degisimYuzde = ((fiyat - previousClose) / previousClose) * 100;
      }

      return HisseBilgisi(
        sembol: meta['symbol'] as String? ?? symbol,
        tamAd: tamAd,
        fiyat: fiyat,
        paraBirimi: meta['currency'] as String? ?? 'USD',
        degisimYuzde: degisimYuzde,
      );
    } on YahooFinanceHata {
      rethrow;
    } catch (e) {
      if (e is FormatException || e is TypeError) {
        throw YahooFinanceHata('Hisse bulunamadı veya veri formatı hatalı.');
      }
      throw YahooFinanceHata(
        'Beklenmeyen hata: ${e.toString().split('\n').first}',
      );
    }
  }

  /// Hisse adı veya sembolüne göre arama yapar (autocomplete için).
  /// Hem hisse kodu (CONSE, CANTE) hem şirket adı (Consus Enerji, Can Termik) ile arar.
  /// Önce yerel BIST listesinden, sonra Yahoo API'den arar.
  static Future<List<HisseAramaSonucu>> hisseAraListele(String sorgu) async {
    final q = sorgu.trim();
    if (q.isEmpty) return [];

    final sonuclar = <HisseAramaSonucu>[];
    final varOlanSemboller = <String>{};
    final symbolUpper = q.toUpperCase().replaceAll(' ', '');

    // 1. Yerel BIST Listesinden Arama (Öncelikli)
    // Kod ile başlayanlar
    bistHisseleri.forEach((kod, ad) {
      if (kod.startsWith(symbolUpper)) {
        if (!varOlanSemboller.contains(kod)) {
          varOlanSemboller.add(kod);
          sonuclar.add(HisseAramaSonucu(
            sembol: '$kod.IS',
            kisaAd: kod,
            uzunAd: ad,
            borsa: 'IST',
            tip: 'EQUITY',
          ));
        }
      }
    });

    // İsim içinde geçenler (3 harften uzunsa)
    if (q.length >= 3) {
      final qUpperTr = symbolUpper.replaceAll('i', 'İ').replaceAll('ı', 'I');
      bistHisseleri.forEach((kod, ad) {
        if (varOlanSemboller.contains(kod)) return;
        final adUpper = ad.toUpperCase().replaceAll('i', 'İ').replaceAll('ı', 'I');
        
        // Basit içerir kontrolü (hem İngilizce hem Türkçe karakterler için)
        if (adUpper.contains(symbolUpper) || adUpper.contains(qUpperTr)) {
          varOlanSemboller.add(kod);
          sonuclar.add(HisseAramaSonucu(
            sembol: '$kod.IS',
            kisaAd: kod,
            uzunAd: ad,
            borsa: 'IST',
            tip: 'EQUITY',
          ));
        }
      });
    }

    // Sorgu hisse kodu gibi görünüyorsa (2–5 harf): doğrudan sembol ile dene (yerel listede yoksa)
    if (symbolUpper.length >= 2 &&
        symbolUpper.length <= 5 &&
        RegExp(r'^[A-Z]+$').hasMatch(symbolUpper) &&
        !varOlanSemboller.contains(symbolUpper)) {
      final sym = '$symbolUpper.IS';
      try {
        // API çağrısı yapmadan önce yerel listede yoksa dene
        // Ancak bu API çağrısı yavaşlatabilir, sadece arama API'si yeterli olabilir.
        // Yine de garanti olsun diye bırakıyoruz.
        final meta = await chartMetaAlSymbol(sym);
        if (meta != null) {
          sonuclar.add(HisseAramaSonucu(
            sembol: meta.symbol,
            kisaAd: meta.longName,
            uzunAd: meta.longName,
            borsa: '',
            tip: 'EQUITY',
          ));
          varOlanSemboller.add(symbolUpper);
        }
      } catch (_) {}
    }

    final url = Uri.parse(_searchUrl).replace(
      queryParameters: {'q': q, 'quotesCount': '10', 'newsCount': '0'},
    );

    try {
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 5), // Timeout süresini kısalttım (8 -> 5)
        onTimeout: () => throw YahooFinanceHata('Arama zaman aşımına uğradı.'),
      );

      if (response.statusCode != 200) return sonuclar;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final quotes = json['quotes'] as List<dynamic>?;
      if (quotes == null || quotes.isEmpty) return sonuclar;

      for (final quote in quotes) {
        final m = quote as Map<String, dynamic>;
        final symbol = m['symbol'] as String? ?? '';
        final shortname = m['shortname'] as String? ?? '';
        final longname = m['longname'] as String? ?? shortname;
        final exchange = m['exchange'] as String? ?? '';
        final quoteType = m['quoteType'] as String? ?? '';
        
        if (symbol.isEmpty) continue;
        
        // Sadece .IS olanları alıyoruz (BIST)
        if (!symbol.toUpperCase().endsWith('.IS')) continue;

        // Sembolün kökünü al (THYAO.IS -> THYAO)
        final rootSymbol = symbol.toUpperCase().replaceAll('.IS', '');
        
        if (varOlanSemboller.contains(rootSymbol)) continue;
        
        varOlanSemboller.add(rootSymbol);
        sonuclar.add(HisseAramaSonucu(
          sembol: symbol,
          kisaAd: shortname,
          uzunAd: longname,
          borsa: exchange,
          tip: quoteType,
        ));
      }
      return sonuclar;
    } catch (_) {
      return sonuclar;
    }
  }

  /// Döviz kuru bilgisini getirir (TRY bazlı).
  /// Örnek: USDTRY=X, EURTRY=X
  static Future<double> dovizKuruAl(String sembol) async {
    final symbol = sembol.trim().toUpperCase();
    if (!symbol.endsWith('TRY=X') && !symbol.endsWith('TRY')) {
      // Eğer sadece USD veya EUR gelirse, TRY=X ekle
      final baseSymbol = symbol.replaceAll('TRY', '').replaceAll('=', '');
      final fullSymbol = '${baseSymbol}TRY=X';
      return dovizKuruAl(fullSymbol);
    }

    final url = Uri.parse(
      '$_baseUrl/$symbol?interval=1d&range=1d&includePrePost=false',
    );

    try {
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw YahooFinanceHata('Döviz kuru alınamadı.'),
      );

      if (response.statusCode != 200) {
        debugPrint('[Yahoo dovizKuruAl] HTTP ${response.statusCode} URL: $url');
        throw YahooFinanceHata('Döviz kuru alınamadı. (HTTP ${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final chart = json['chart'] as Map<String, dynamic>?;

      if (chart != null && chart['error'] != null) {
        throw YahooFinanceHata('Döviz kuru bulunamadı.');
      }

      final resultList = chart?['result'] as List<dynamic>?;
      if (resultList == null || resultList.isEmpty) {
        throw YahooFinanceHata('Döviz kuru bulunamadı.');
      }

      final result = resultList.first as Map<String, dynamic>;
      final meta = result['meta'] as Map<String, dynamic>?;

      if (meta == null) {
        throw YahooFinanceHata('Döviz kuru verisi alınamadı.');
      }

      double? kur = (meta['regularMarketPrice'] as num?)?.toDouble();
      kur ??= (meta['previousClose'] as num?)?.toDouble();
      
      if (kur == null || kur <= 0) {
        throw YahooFinanceHata('Geçerli döviz kuru alınamadı.');
      }

      return kur;
    } catch (e) {
      if (e is YahooFinanceHata) rethrow;
      throw YahooFinanceHata('Döviz kuru alınırken hata oluştu.');
    }
  }

  /// Grafik serisinde bir önceki mumun kapanışını döndürür (BIST için meta.chartPreviousClose sıklıkla yanlış).
  /// Günlük grafikte son iki geçerli kapanıştan ikincisi = önceki işlem günü kapanışı.
  static double? _oncekiKapanisSeriden(Map<String, dynamic> result) {
    final quoteList = result['indicators']?['quote'] as List<dynamic>?;
    if (quoteList == null || quoteList.isEmpty) return null;
    final quote = quoteList.first as Map<String, dynamic>;
    final closeList = quote['close'] as List<dynamic>?;
    if (closeList == null || closeList.isEmpty) return null;
    double? parseClose(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    int lastIdx = closeList.length - 1;
    while (lastIdx >= 0 && parseClose(closeList[lastIdx]) == null) {
      lastIdx--;
    }
    if (lastIdx < 1) return null;
    int prevIdx = lastIdx - 1;
    while (prevIdx >= 0 && parseClose(closeList[prevIdx]) == null) {
      prevIdx--;
    }
    if (prevIdx < 0) return null;
    return parseClose(closeList[prevIdx]);
  }

  /// v8/finance/chart API'sinden hisse detay verisi çeker. Tek kaynak - quote kullanılmaz.
  /// chart.result[0].meta üzerinden: fiyat, önceki kapanış, günlük/52 hafta aralığı.
  /// marketCap ve trailingPE chart'ta yoksa null döner (UI'da '-' gösterilir).
  static Future<StockChartMeta?> hisseChartMetaAl(String sembol) async {
    final raw = sembol.trim().toUpperCase();
    if (raw.isEmpty) return null;
    final symbol = _sembolIsEkle(raw);

    final url = Uri.parse(
      '$_baseUrl/$symbol?interval=1d&range=1y&includePrePost=false',
    );

    try {
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw YahooFinanceHata('İstek zaman aşımına uğradı.'),
      );

      if (response.statusCode != 200) {
        throw YahooFinanceHata('Hisse verisi alınamadı. (HTTP ${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final chart = json['chart'] as Map<String, dynamic>?;
      if (chart != null && chart['error'] != null) {
        final err = chart['error'] as Map<String, dynamic>?;
        final desc = err?['description'] as String? ?? 'Hisse bulunamadı.';
        throw YahooFinanceHata(desc);
      }

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
      if (price == null || price <= 0) return null;

      final previousClose = _oncekiKapanisSeriden(result) ?? parseNum(meta['chartPreviousClose']) ?? parseNum(meta['previousClose']);
      double? dayHigh = parseNum(meta['regularMarketDayHigh']);
      double? dayLow = parseNum(meta['regularMarketDayLow']);
      double? week52High = parseNum(meta['fiftyTwoWeekHigh']);
      double? week52Low = parseNum(meta['fiftyTwoWeekLow']);

      final indicators = result['indicators'] as Map<String, dynamic>?;
      final quoteList = indicators?['quote'] as List<dynamic>?;
      final quote = (quoteList != null && quoteList.isNotEmpty) ? quoteList.first as Map<String, dynamic> : null;

      if (dayHigh == null || dayLow == null) {
        if (quote != null) {
          final highList = quote['high'] as List<dynamic>?;
          final lowList = quote['low'] as List<dynamic>?;
          final validHighs = highList?.whereType<num>().toList() ?? [];
          final validLows = lowList?.whereType<num>().toList() ?? [];
          if (dayHigh == null && validHighs.isNotEmpty) dayHigh = validHighs.last.toDouble();
          if (dayLow == null && validLows.isNotEmpty) dayLow = validLows.last.toDouble();
        }
      }

      // 52 hafta verisi meta'da yoksa seriden hesapla
      if (week52High == null || week52Low == null) {
        if (quote != null) {
          final closeList = quote['close'] as List<dynamic>?;
          final validCloses = closeList?.whereType<num>().map((e) => e.toDouble()).toList() ?? [];
          if (validCloses.isNotEmpty) {
            if (week52High == null) week52High = validCloses.reduce((a, b) => a > b ? a : b);
            if (week52Low == null) week52Low = validCloses.reduce((a, b) => a < b ? a : b);
          }
        }
      }

      final longName = meta['longName'] as String? ?? meta['shortName'] as String? ?? symbol;
      double? regularMarketVolume = parseNum(meta['regularMarketVolume']);
      if (regularMarketVolume == null && quote != null) {
        final volumeList = quote['volume'] as List<dynamic>?;
        if (volumeList != null && volumeList.isNotEmpty) {
          final lastVol = volumeList.last;
          if (lastVol != null) regularMarketVolume = (lastVol as num).toDouble();
        }
      }
      final currency = meta['currency'] as String? ?? 'TRY';

      return StockChartMeta(
        symbol: meta['symbol'] as String? ?? symbol,
        longName: longName,
        price: price,
        previousClose: previousClose,
        dayHigh: dayHigh,
        dayLow: dayLow,
        week52High: week52High,
        week52Low: week52Low,
        regularMarketVolume: regularMarketVolume,
        currency: currency,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sembolü olduğu gibi kullanarak chart meta döner (endeks, döviz, emtia için).
  /// Örn: XU100.IS, USDTRY=X, GC=F
  static Future<StockChartMeta?> chartMetaAlSymbol(String symbol) async {
    final sym = symbol.trim();
    if (sym.isEmpty) return null;

    final url = Uri.parse(
      '$_baseUrl/$sym?interval=1d&range=1d&includePrePost=false',
    );

    try {
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw YahooFinanceHata('İstek zaman aşımına uğradı.'),
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
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
      if (price == null || price <= 0) return null;

      final previousClose = parseNum(meta['chartPreviousClose']) ?? parseNum(meta['previousClose']);
      final longName = meta['longName'] as String? ?? meta['shortName'] as String? ?? sym;
      final regularMarketVolume = parseNum(meta['regularMarketVolume']);
      final currency = meta['currency'] as String? ?? 'TRY';

      return StockChartMeta(
        symbol: meta['symbol'] as String? ?? sym,
        longName: longName,
        price: price,
        previousClose: previousClose,
        dayHigh: parseNum(meta['regularMarketDayHigh']),
        dayLow: parseNum(meta['regularMarketDayLow']),
        week52High: parseNum(meta['fiftyTwoWeekHigh']),
        week52Low: parseNum(meta['fiftyTwoWeekLow']),
        regularMarketVolume: regularMarketVolume,
        currency: currency,
      );
    } catch (_) {
      return null;
    }
  }

  /// Hisse meta + günlük grafik serisi (tek API çağrısı).
  static Future<StockChartWithSeries?> hisseChartWithSeriesAl(String sembol) async {
    final raw = sembol.trim().toUpperCase();
    if (raw.isEmpty) return null;
    final symbol = _sembolIsEkle(raw);

    final url = Uri.parse(
      '$_baseUrl/$symbol?interval=1d&range=1y&includePrePost=false',
    );

    try {
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw YahooFinanceHata('İstek zaman aşımına uğradı.'),
      );

      if (response.statusCode != 200) {
        throw YahooFinanceHata('Hisse verisi alınamadı. (HTTP ${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final chart = json['chart'] as Map<String, dynamic>?;
      if (chart != null && chart['error'] != null) {
        final err = chart['error'] as Map<String, dynamic>?;
        final desc = err?['description'] as String? ?? 'Hisse bulunamadı.';
        throw YahooFinanceHata(desc);
      }

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
      if (price == null || price <= 0) return null;

      final previousClose = _oncekiKapanisSeriden(result) ?? parseNum(meta['chartPreviousClose']) ?? parseNum(meta['previousClose']);
      double? dayHigh = parseNum(meta['regularMarketDayHigh']);
      double? dayLow = parseNum(meta['regularMarketDayLow']);
      double? week52High = parseNum(meta['fiftyTwoWeekHigh']);
      double? week52Low = parseNum(meta['fiftyTwoWeekLow']);

      final indicators = result['indicators'] as Map<String, dynamic>?;
      final quoteList = indicators?['quote'] as List<dynamic>?;
      final quote = (quoteList != null && quoteList.isNotEmpty) ? quoteList.first as Map<String, dynamic> : null;

      if (dayHigh == null || dayLow == null) {
        if (quote != null) {
          final highList = quote['high'] as List<dynamic>?;
          final lowList = quote['low'] as List<dynamic>?;
          final validHighs = highList?.whereType<num>().toList() ?? [];
          final validLows = lowList?.whereType<num>().toList() ?? [];
          if (dayHigh == null && validHighs.isNotEmpty) dayHigh = validHighs.last.toDouble();
          if (dayLow == null && validLows.isNotEmpty) dayLow = validLows.last.toDouble();
        }
      }

      // 52 hafta verisi meta'da yoksa seriden hesapla
      if (week52High == null || week52Low == null) {
        if (quote != null) {
          final closeList = quote['close'] as List<dynamic>?;
          final validCloses = closeList?.whereType<num>().map((e) => e.toDouble()).toList() ?? [];
          if (validCloses.isNotEmpty) {
            if (week52High == null) week52High = validCloses.reduce((a, b) => a > b ? a : b);
            if (week52Low == null) week52Low = validCloses.reduce((a, b) => a < b ? a : b);
          }
        }
      }

      final longName = meta['longName'] as String? ?? meta['shortName'] as String? ?? symbol;
      double? regularMarketVolume = parseNum(meta['regularMarketVolume']);
      if (regularMarketVolume == null && quote != null) {
        final volumeList = quote['volume'] as List<dynamic>?;
        if (volumeList != null && volumeList.isNotEmpty) {
          final lastVol = volumeList.last;
          if (lastVol != null) regularMarketVolume = (lastVol as num).toDouble();
        }
      }
      final currency = meta['currency'] as String? ?? 'TRY';

      final stockMeta = StockChartMeta(
        symbol: meta['symbol'] as String? ?? symbol,
        longName: longName,
        price: price,
        previousClose: previousClose,
        dayHigh: dayHigh,
        dayLow: dayLow,
        week52High: week52High,
        week52Low: week52Low,
        regularMarketVolume: regularMarketVolume,
        currency: currency,
      );

      // Grafik serisi: timestamp + close
      final timestampList = result['timestamp'] as List<dynamic>?;
      final closeList = quote?['close'] as List<dynamic>?;

      final series = <StockChartPoint>[];
      if (timestampList != null && closeList != null) {
        final len = timestampList.length < closeList.length ? timestampList.length : closeList.length;
        for (var i = 0; i < len; i++) {
          final ts = timestampList[i];
          final close = closeList[i];
          if (ts != null && close != null) {
            final t = ts is num ? ts.toInt() : int.tryParse(ts.toString());
            final c = parseNum(close);
            if (t != null && c != null && c > 0) {
              series.add(StockChartPoint(timestamp: t, close: c));
            }
          }
        }
      }

      return StockChartWithSeries(meta: stockMeta, series: series);
    } catch (e) {
      rethrow;
    }
  }

  /// Grafik için OHLC verisi çeker. interval: 1h, 1d vb. range: 5d, 1mo, 6mo, 1y, 5y
  static Future<List<ChartOHLCPoint>?> hisseChartOHLCAl(
    String sembol, {
    String interval = '1d',
    String range = '1y',
  }) async {
    final raw = sembol.trim().toUpperCase();
    if (raw.isEmpty) return null;
    final symbol = _sembolIsEkle(raw);

    final url = Uri.parse(
      '$_baseUrl/$symbol?interval=$interval&range=$range&includePrePost=false',
    );

    try {
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw YahooFinanceHata('İstek zaman aşımına uğradı.'),
      );
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final chart = json['chart'] as Map<String, dynamic>?;
      if (chart != null && chart['error'] != null) return null;

      final resultList = chart?['result'] as List<dynamic>?;
      if (resultList == null || resultList.isEmpty) return null;

      final result = resultList.first as Map<String, dynamic>;
      final timestampList = result['timestamp'] as List<dynamic>?;
      final indicators = result['indicators'] as Map<String, dynamic>?;
      final quoteList = indicators?['quote'] as List<dynamic>?;
      final quote = quoteList != null && quoteList.isNotEmpty ? quoteList.first as Map<String, dynamic> : null;

      final openList = quote?['open'] as List<dynamic>?;
      final highList = quote?['high'] as List<dynamic>?;
      final lowList = quote?['low'] as List<dynamic>?;
      final closeList = quote?['close'] as List<dynamic>?;

      if (timestampList == null || closeList == null) return null;

      double? parseNum(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      final points = <ChartOHLCPoint>[];
      for (var i = 0; i < timestampList.length; i++) {
        final ts = timestampList[i];
        final t = ts is num ? ts.toInt() : int.tryParse(ts.toString());
        if (t == null) continue;
        final c = parseNum(closeList[i >= closeList.length ? closeList.length - 1 : i]);
        if (c == null || c <= 0) continue;
        final o = parseNum(openList != null && i < openList.length ? openList[i] : null) ?? c;
        final h = parseNum(highList != null && i < highList.length ? highList[i] : null) ?? c;
        final l = parseNum(lowList != null && i < lowList.length ? lowList[i] : null) ?? c;
        points.add(ChartOHLCPoint(timestamp: t, open: o, high: h, low: l, close: c));
      }
      return points.isEmpty ? null : points;
    } catch (_) {
      return null;
    }
  }

  /// quoteSummary summaryDetail'dan sadece önceki kapanışı döndürür.
  /// Chart meta'daki previousClose BIST için bazen yanlış olabiliyor; bu değer daha güvenilir olabilir.
  static Future<double?> oncekiKapanisQuoteSummary(String sembol) async {
    final raw = sembol.trim().toUpperCase();
    if (raw.isEmpty) return null;
    final symbol = _sembolIsEkle(raw);
    try {
      final url = Uri.parse('$_quoteSummaryUrl/$symbol?modules=summaryDetail');
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw YahooFinanceHata('İstek zaman aşımına uğradı.'),
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final resultList = (json['quoteSummary'] as Map<String, dynamic>?)?['result'] as List<dynamic>?;
      if (resultList == null || resultList.isEmpty) return null;
      final result = resultList.first as Map<String, dynamic>;
      final summary = result['summaryDetail'] as Map<String, dynamic>?;
      if (summary == null) return null;
      final v = summary['previousClose'];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    } catch (_) {
      return null;
    }
  }

  /// Hisse için detaylı finansal bilgiler (Company Overview, Sector, Beta, EPS vb.)
  /// Endpoint: quoteSummary?modules=assetProfile,summaryDetail,defaultKeyStatistics,financialData
  /// Sembol .IS ile kullanılır (örn: SNICA.IS).
  static Future<HisseDetayliBilgi?> hisseDetayliBilgiAl(String sembol, {StockChartMeta? chartMeta}) async {
    final raw = sembol.trim().toUpperCase();
    if (raw.isEmpty) return null;
    final symbol = _sembolIsEkle(raw);

    try {
      final url = Uri.parse('$_quoteSummaryUrl/$symbol?modules=assetProfile,summaryDetail,defaultKeyStatistics,financialData');
      final response = await http.get(url, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw YahooFinanceHata('İstek zaman aşımına uğradı.'),
      );

      if (response.statusCode != 200) {
        return _hisseDetayliBilgiFallback(symbol, chartMeta);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final quoteSummary = json['quoteSummary'] as Map<String, dynamic>?;
      dynamic resultList = quoteSummary?['result'];
      if (resultList == null || (resultList is List && resultList.isEmpty)) {
        return _hisseDetayliBilgiFallback(symbol, chartMeta);
      }

      final result = (resultList as List).first as Map<String, dynamic>;
      final summary = result['summaryDetail'] as Map<String, dynamic>?;
      final keyStats = result['defaultKeyStatistics'] as Map<String, dynamic>?;
      final financialData = result['financialData'] as Map<String, dynamic>?;
      final assetProfile = result['assetProfile'] as Map<String, dynamic>?;

      if (summary == null) return _hisseDetayliBilgiFallback(symbol, chartMeta);

      double? parseNum(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        if (v is Map && v['raw'] != null) return (v['raw'] as num).toDouble();
        return double.tryParse(v.toString());
      }

      String? parseStr(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      /// Yahoo .fmt formatlı string (veya raw'dan string)
      String? parseFmt(dynamic v) {
        if (v == null) return null;
        if (v is Map && v['fmt'] != null) return (v['fmt'] as String).trim();
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      final hisseBilgi = await hisseAra(symbol);

      // Temel istatistikler (raw + fmt)
      final avgVolume30Day = keyStats != null ? parseNum(keyStats['averageVolume10days']) ?? parseNum(keyStats['averageVolume']) : null;
      final dividendYieldRaw = summary['dividendYield'] != null ? parseNum(summary['dividendYield']) : null;
      final dividendYield = dividendYieldRaw;
      final trailingEps = keyStats != null ? parseNum(keyStats['trailingEps']) : null;
      final netIncome = financialData != null ? parseNum(financialData['netIncomeToCommon']) : null;
      final totalRevenue = financialData != null ? parseNum(financialData['totalRevenue']) : null;
      final sharesOutstanding = keyStats != null ? parseNum(keyStats['sharesOutstanding']) : null;
      final beta = keyStats != null ? parseNum(keyStats['beta']) : null;
      final betaFromSummary = summary['beta'] != null ? parseNum(summary['beta']) : null;
      final betaRes = beta ?? betaFromSummary;

      // Formatlı stringler (UI'da .fmt veya '-')
      final betaFmt = parseFmt(keyStats?['beta']) ?? parseFmt(summary['beta']) ?? (betaRes != null ? betaRes.toString() : null);
      final piyasaDegeriFmt = parseFmt(summary['marketCap']);
      final fKFmt = parseFmt(summary['trailingPE']);
      final epsFmt = parseFmt(keyStats?['trailingEps']);
      final temettuVerimiFmt = parseFmt(summary['dividendYield']);

      // Genişletilmiş alanlar (financialData varsa)
      final enterpriseValue = keyStats != null ? parseNum(keyStats['enterpriseValue']) : null;
      final priceToBook = keyStats != null ? parseNum(keyStats['priceToBook']) : null;
      final priceToSales = summary['priceToSalesTrailing12Months'] != null ? parseNum(summary['priceToSalesTrailing12Months']) : null;
      final payoutRatio = summary['payoutRatio'] != null ? parseNum(summary['payoutRatio']) : null;
      final totalDebt = financialData != null ? parseNum(financialData['totalDebt']) : null;
      final totalCash = financialData != null ? parseNum(financialData['totalCash']) : null;
      final freeCashflow = financialData != null ? parseNum(financialData['freeCashflow']) : null;
      final profitMargins = financialData != null ? parseNum(financialData['profitMargins']) : null;
      final grossMargins = financialData != null ? parseNum(financialData['grossMargins']) : null;
      final returnOnAssets = financialData != null ? parseNum(financialData['returnOnAssets']) : null;
      final returnOnEquity = financialData != null ? parseNum(financialData['returnOnEquity']) : null;
      final debtToEquity = financialData != null ? parseNum(financialData['debtToEquity']) : null;
      final currentRatio = financialData != null ? parseNum(financialData['currentRatio']) : null;
      final targetMeanPrice = financialData != null ? parseNum(financialData['targetMeanPrice']) : null;
      final ortalama50Gun = summary['fiftyDayAverage'] != null ? parseNum(summary['fiftyDayAverage']) : null;
      final ortalama200Gun = summary['twoHundredDayAverage'] != null ? parseNum(summary['twoHundredDayAverage']) : null;
      final pegRatio = keyStats != null ? parseNum(keyStats['pegRatio']) : null;
      final sector = assetProfile != null ? parseStr(assetProfile['sector']) : null;
      final industry = assetProfile != null ? parseStr(assetProfile['industry']) : null;
      final website = assetProfile != null ? parseStr(assetProfile['website']) : null;
      final fullTimeEmployees = assetProfile != null ? parseNum(assetProfile['fullTimeEmployees']) : null;
      final longBusinessSummary = assetProfile != null ? parseStr(assetProfile['longBusinessSummary']) : null;
      final floatShares = keyStats != null ? parseNum(keyStats['floatShares']) : null;
      double? floatRate;
      if (floatShares != null && sharesOutstanding != null && sharesOutstanding! > 0) {
        floatRate = (floatShares / sharesOutstanding!) * 100;
      }
      String? ceo;
      if (assetProfile != null) {
        final officers = assetProfile['companyOfficers'] as List<dynamic>?;
        if (officers != null && officers.isNotEmpty) {
          final first = officers.first as Map<String, dynamic>?;
          ceo = first != null ? parseStr(first['name']) : null;
        }
      }
      final city = assetProfile != null ? parseStr(assetProfile['city']) : null;
      final state = assetProfile != null ? parseStr(assetProfile['state']) : null;
      final country = assetProfile != null ? parseStr(assetProfile['country']) : null;
      final headquarters = [city, state, country].whereType<String>().join(', ');

      return HisseDetayliBilgi(
        sembol: symbol,
        tamAd: hisseBilgi.tamAd,
        sonFiyat: hisseBilgi.fiyat,
        paraBirimi: hisseBilgi.paraBirimi,
        oncekiKapanis: parseNum(summary['previousClose']),
        gunAcilis: parseNum(summary['open']),
        gunEnYuksek: parseNum(summary['dayHigh']),
        gunEnDusuk: parseNum(summary['dayLow']),
        hafta52EnYuksek: parseNum(summary['fiftyTwoWeekHigh']),
        hafta52EnDusuk: parseNum(summary['fiftyTwoWeekLow']),
        piyasaDegeri: parseNum(summary['marketCap']),
        fK: parseNum(summary['trailingPE']),
        ileriFK: parseNum(summary['forwardPE']),
        hacim: parseNum(summary['volume']),
        ortalamaHacim30Gun: avgVolume30Day,
        temettuVerimi: dividendYield != null ? dividendYield * 100 : null,
        basitHBK: trailingEps,
        netKazanc: netIncome,
        gelir: totalRevenue,
        halkaAcikHisseler: sharesOutstanding,
        beta: betaRes,
        betaFmt: betaFmt,
        piyasaDegeriFmt: piyasaDegeriFmt,
        fKFmt: fKFmt,
        epsFmt: epsFmt,
        temettuVerimiFmt: temettuVerimiFmt,
        enterpriseValue: enterpriseValue,
        priceToBook: priceToBook,
        priceToSales: priceToSales,
        payoutRatio: payoutRatio,
        totalDebt: totalDebt,
        totalCash: totalCash,
        freeCashflow: freeCashflow,
        profitMargins: profitMargins,
        grossMargins: grossMargins,
        returnOnAssets: returnOnAssets,
        returnOnEquity: returnOnEquity,
        debtToEquity: debtToEquity,
        currentRatio: currentRatio,
        targetMeanPrice: targetMeanPrice,
        ortalama50Gun: ortalama50Gun,
        ortalama200Gun: ortalama200Gun,
        pegRatio: pegRatio,
        sector: sector,
        industry: industry,
        website: website,
        longBusinessSummary: longBusinessSummary,
        floatShares: floatShares,
        floatRate: floatRate,
        fullTimeEmployees: fullTimeEmployees,
        ceo: ceo,
        headquarters: headquarters.isEmpty ? null : headquarters,
        ipoTarihi: null,
        exDividendDate: null,
        sonrakiKazancTarihi: null,
        iceridekilerYuzde: null,
        kurumlarYuzde: null,
      );
    } catch (e) {
      return _hisseDetayliBilgiFallback(symbol, chartMeta);
    }
  }

  /// quoteSummary başarısız veya BIST için null döndüğünde chart meta + hisseAra ile minimal bilgi oluşturur
  static Future<HisseDetayliBilgi?> _hisseDetayliBilgiFallback(String symbol, StockChartMeta? chartMeta) async {
    if (chartMeta == null) return null;
    try {
      final hisseBilgi = await hisseAra(symbol);
      return HisseDetayliBilgi(
        sembol: symbol,
        tamAd: hisseBilgi.tamAd,
        sonFiyat: hisseBilgi.fiyat,
        paraBirimi: hisseBilgi.paraBirimi,
        oncekiKapanis: chartMeta.previousClose,
        gunAcilis: null,
        gunEnYuksek: chartMeta.dayHigh,
        gunEnDusuk: chartMeta.dayLow,
        hafta52EnYuksek: chartMeta.week52High,
        hafta52EnDusuk: chartMeta.week52Low,
        piyasaDegeri: null,
        fK: null,
        ileriFK: null,
        hacim: chartMeta.regularMarketVolume,
        ortalamaHacim30Gun: null,
        temettuVerimi: null,
        basitHBK: null,
        netKazanc: null,
        gelir: null,
        halkaAcikHisseler: null,
        beta: null,
      );
    } catch (_) {
      // hisseAra da başarısızsa chart meta ile en azından fiyat bilgisi oluştur
      return HisseDetayliBilgi(
        sembol: symbol,
        tamAd: chartMeta.longName,
        sonFiyat: chartMeta.price,
        paraBirimi: chartMeta.currency,
        oncekiKapanis: chartMeta.previousClose,
        gunAcilis: null,
        gunEnYuksek: chartMeta.dayHigh,
        gunEnDusuk: chartMeta.dayLow,
        hafta52EnYuksek: chartMeta.week52High,
        hafta52EnDusuk: chartMeta.week52Low,
        piyasaDegeri: null,
        fK: null,
        ileriFK: null,
        hacim: chartMeta.regularMarketVolume,
        ortalamaHacim30Gun: null,
        temettuVerimi: null,
        basitHBK: null,
        netKazanc: null,
        gelir: null,
        halkaAcikHisseler: null,
        beta: null,
      );
    }
  }
}

class HisseAramaSonucu {
  final String sembol;
  final String kisaAd;
  final String uzunAd;
  final String borsa;
  final String tip;

  HisseAramaSonucu({
    required this.sembol,
    required this.kisaAd,
    required this.uzunAd,
    required this.borsa,
    required this.tip,
  });

  String get goruntulenecekAd =>
      uzunAd.isNotEmpty ? uzunAd : (kisaAd.isNotEmpty ? kisaAd : sembol);
}

class HisseBilgisi {
  final String sembol;
  final String tamAd;
  final double fiyat;
  final String paraBirimi;
  final double? degisimYuzde;

  HisseBilgisi({
    required this.sembol,
    required this.tamAd,
    required this.fiyat,
    required this.paraBirimi,
    this.degisimYuzde,
  });
}

/// Detaylı finansal bilgiler (quoteSummary'den) - Temel istatistikler ve genişletilmiş alanlar
class HisseDetayliBilgi {
  final String sembol;
  final String tamAd;
  final double sonFiyat;
  final String paraBirimi;
  final double? oncekiKapanis;
  final double? gunAcilis;
  final double? gunEnYuksek;
  final double? gunEnDusuk;
  final double? hafta52EnYuksek;
  final double? hafta52EnDusuk;
  final double? piyasaDegeri;
  final double? fK;
  final double? ileriFK;
  final double? hacim;
  
  // Temel istatistikler
  final double? ortalamaHacim30Gun; // Average Volume (30D)
  final double? temettuVerimi; // Dividend Yield
  final double? basitHBK; // Trailing EPS (TTM)
  final double? netKazanc; // Net Income (Current Year)
  final double? gelir; // Total Revenue (FY)
  final double? halkaAcikHisseler; // Shares Outstanding
  final double? beta; // Beta (1Y)
  final String? betaFmt;
  final String? piyasaDegeriFmt;
  final String? fKFmt;
  final String? epsFmt;
  final String? temettuVerimiFmt;

  // Genişletilmiş alanlar (assetProfile, summaryDetail, defaultKeyStatistics, financialData)
  final double? enterpriseValue;
  final double? priceToBook;
  final double? priceToSales;
  final double? payoutRatio;
  final double? totalDebt;
  final double? totalCash;
  final double? freeCashflow;
  final double? profitMargins;
  final double? grossMargins;
  final double? returnOnAssets;
  final double? returnOnEquity;
  final double? debtToEquity;
  final double? currentRatio;   // Cari oran (likidite)
  final double? targetMeanPrice; // Analist hedef fiyatı
  final double? ortalama50Gun;   // 50 günlük hareketli ortalama
  final double? ortalama200Gun;  // 200 günlük hareketli ortalama
  final double? pegRatio;        // PEG oranı (büyüme değerleme)
  final String? sector;
  final String? industry;
  final String? website;
  final String? longBusinessSummary; // Şirket açıklaması (ne iş yapar)
  final double? floatShares;
  final double? floatRate; // Fiili dolaşım oranı (%)
  final double? fullTimeEmployees;
  final String? ceo;
  final String? headquarters; // Adres: city, country
  final DateTime? ipoTarihi;
  final DateTime? exDividendDate;
  final DateTime? sonrakiKazancTarihi;
  final double? iceridekilerYuzde;
  final double? kurumlarYuzde;

  HisseDetayliBilgi({
    required this.sembol,
    required this.tamAd,
    required this.sonFiyat,
    required this.paraBirimi,
    this.oncekiKapanis,
    this.gunAcilis,
    this.gunEnYuksek,
    this.gunEnDusuk,
    this.hafta52EnYuksek,
    this.hafta52EnDusuk,
    this.piyasaDegeri,
    this.fK,
    this.ileriFK,
    this.hacim,
    this.ortalamaHacim30Gun,
    this.temettuVerimi,
    this.basitHBK,
    this.netKazanc,
    this.gelir,
    this.halkaAcikHisseler,
    this.beta,
    this.betaFmt,
    this.piyasaDegeriFmt,
    this.fKFmt,
    this.epsFmt,
    this.temettuVerimiFmt,
    this.enterpriseValue,
    this.priceToBook,
    this.priceToSales,
    this.payoutRatio,
    this.totalDebt,
    this.totalCash,
    this.freeCashflow,
    this.profitMargins,
    this.grossMargins,
    this.returnOnAssets,
    this.returnOnEquity,
    this.debtToEquity,
    this.currentRatio,
    this.targetMeanPrice,
    this.ortalama50Gun,
    this.ortalama200Gun,
    this.pegRatio,
    this.sector,
    this.industry,
    this.website,
    this.longBusinessSummary,
    this.floatShares,
    this.floatRate,
    this.fullTimeEmployees,
    this.ceo,
    this.headquarters,
    this.ipoTarihi,
    this.exDividendDate,
    this.sonrakiKazancTarihi,
    this.iceridekilerYuzde,
    this.kurumlarYuzde,
  });
}

/// v8/finance/chart API meta objesinden türetilen model
/// marketCap ve trailingPE chart'ta gelmez, UI'da '-' gösterilir
class StockChartMeta {
  final String symbol;
  final String longName;
  final double price;
  final double? previousClose;
  final double? dayLow;
  final double? dayHigh;
  final double? week52Low;
  final double? week52High;
  final double? regularMarketVolume;
  final String currency;

  StockChartMeta({
    required this.symbol,
    required this.longName,
    required this.price,
    this.previousClose,
    this.dayLow,
    this.dayHigh,
    this.week52Low,
    this.week52High,
    this.regularMarketVolume,
    this.currency = 'TRY',
  });
}

/// Grafik noktası: timestamp (Unix saniye) + kapanış fiyatı
class StockChartPoint {
  final int timestamp;
  final double close;
  StockChartPoint({required this.timestamp, required this.close});
}

/// Meta + günlük grafik serisi (tek API çağrısı)
class StockChartWithSeries {
  final StockChartMeta meta;
  final List<StockChartPoint> series;
  StockChartWithSeries({required this.meta, required this.series});
}

/// OHLC grafik noktası (tooltip için açılış, yüksek, düşük, kapanış)
class ChartOHLCPoint {
  final int timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  ChartOHLCPoint({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
  double get changePercent => open > 0 ? ((close - open) / open) * 100 : 0;
}

class YahooFinanceHata implements Exception {
  final String mesaj;
  YahooFinanceHata(this.mesaj);

  @override
  String toString() => mesaj;
}
