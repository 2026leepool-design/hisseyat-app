import '../supabase_portfolio_service.dart';
import 'historical_price_service.dart';

/// Seçilen tarihteki portföy durumunu hesaplar.
class TimeTunnelService {
  /// Seçilen tarihe kadar (dahil) işlemleri işleyerek o tarihteki hisse adetlerini döndürür.
  /// Sadece adet > 0 olanları döner.
  /// Dönüş tipi: Map<String, double> -> Map<Sembol, ToplamAdet>
  static Future<Map<String, double>> portfoyAdetleriHesapla(DateTime secilenTarih, {String? portfolioId}) async {
    final res = await portfoyAdetleriHesaplaDetayli(secilenTarih, portfolioId: portfolioId);
    return res.map((key, value) => MapEntry(key, value.values.fold(0, (a, b) => a + b)));
  }

  /// Seçilen tarihe kadar olan adetleri portföy bazlı döndürür.
  /// Dönüş tipi: Map<String, Map<String, double>> -> Map<Sembol, Map<PortfoyId, Adet>>
  static Future<Map<String, Map<String, double>>> portfoyAdetleriHesaplaDetayli(DateTime secilenTarih, {String? portfolioId}) async {
    final islemler = await SupabasePortfolioService.islemleriYukle(portfolioId: portfolioId);
    final secilenGun = DateTime(secilenTarih.year, secilenTarih.month, secilenTarih.day);

    final Map<String, Map<String, double>> adetler = {};
    final siraliIslemler = List<TransactionRow>.from(islemler)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final t in siraliIslemler) {
      final tGun = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      if (tGun.isAfter(secilenGun)) continue;

      final sym = t.symbol;
      final pid = t.portfolioId ?? 'ana_portfoy';
      final qty = t.quantity ?? 0;

      if (!adetler.containsKey(sym)) adetler[sym] = {};
      final portfoyAdetleri = adetler[sym]!;

      switch (t.transactionType) {
        case 'buy':
        case 'split':
          portfoyAdetleri[pid] = (portfoyAdetleri[pid] ?? 0) + qty;
          break;
        case 'sell':
          portfoyAdetleri[pid] = (portfoyAdetleri[pid] ?? 0) - qty;
          break;
        case 'dividend':
          break;
        default:
          portfoyAdetleri[pid] = (portfoyAdetleri[pid] ?? 0) + qty;
      }
    }

    // Adeti 0 veya daha az olanları temizle
    final Map<String, Map<String, double>> sonuc = {};
    for (final symEntry in adetler.entries) {
      final temizPortfoyler = Map<String, double>.fromEntries(
        symEntry.value.entries.where((e) => e.value > 0.0001),
      );
      if (temizPortfoyler.isNotEmpty) {
        sonuc[symEntry.key] = temizPortfoyler;
      }
    }

    return sonuc;
  }

  /// Tarihsel fiyatları ve döviz kurlarını batch'ler halinde çeker.
  static Future<TimeTunnelSonuc> hesapla(DateTime secilenTarih, {String? portfolioId}) async {
    final adetler = await portfoyAdetleriHesapla(secilenTarih, portfolioId: portfolioId);
    if (adetler.isEmpty) {
      // Adet yoksa bile piyasa verilerini çekmek isteyebiliriz
      final fxSemboller = ['USDTRY=X', 'EURTRY=X', 'XU100.IS'];
      final fiyatlar = await HistoricalPriceService.getClosePricesBatched(fxSemboller, secilenTarih);
      
      return TimeTunnelSonuc(
        tarih: secilenTarih,
        toplamTry: 0,
        toplamUsd: 0,
        toplamEur: 0,
        usdKuru: fiyatlar['USDTRY=X'] ?? 0.0,
        eurKuru: fiyatlar['EURTRY=X'] ?? 0.0,
        bist100: fiyatlar['XU100.IS'] ?? 0.0,
        pozisyonlar: [],
      );
    }

    final semboller = adetler.keys.toList();
    final fxSemboller = ['USDTRY=X', 'EURTRY=X', 'XU100.IS'];
    final tumSemboller = [...semboller, ...fxSemboller];

    final fiyatlar = await HistoricalPriceService.getClosePricesBatched(tumSemboller, secilenTarih);

    final usdKuru = fiyatlar['USDTRY=X'] ?? 0.0;
    final eurKuru = fiyatlar['EURTRY=X'] ?? 0.0;
    final bist100 = fiyatlar['XU100.IS'] ?? 0.0;

    double toplamTry = 0;
    final pozisyonlar = <TimeTunnelPozisyon>[];

    for (final sym in semboller) {
      final adet = adetler[sym]!;
      final fiyat = fiyatlar[sym];
      final deger = fiyat != null ? adet * fiyat : null;
      if (deger != null) toplamTry += deger;

      pozisyonlar.add(TimeTunnelPozisyon(
        symbol: sym,
        adet: adet,
        tarihselFiyat: fiyat,
        tarihselDeger: deger,
      ));
    }

    pozisyonlar.sort((a, b) => a.symbol.compareTo(b.symbol));

    return TimeTunnelSonuc(
      tarih: secilenTarih,
      toplamTry: toplamTry,
      toplamUsd: usdKuru > 0 ? toplamTry / usdKuru : 0,
      toplamEur: eurKuru > 0 ? toplamTry / eurKuru : 0,
      usdKuru: usdKuru,
      eurKuru: eurKuru,
      bist100: bist100,
      pozisyonlar: pozisyonlar,
    );
  }
}

class TimeTunnelPozisyon {
  final String symbol;
  final double adet;
  final double? tarihselFiyat;
  final double? tarihselDeger;

  TimeTunnelPozisyon({
    required this.symbol,
    required this.adet,
    this.tarihselFiyat,
    this.tarihselDeger,
  });
}

class TimeTunnelSonuc {
  final DateTime tarih;
  final double toplamTry;
  final double toplamUsd;
  final double toplamEur;
  final double usdKuru;
  final double eurKuru;
  final double bist100;
  final List<TimeTunnelPozisyon> pozisyonlar;

  TimeTunnelSonuc({
    required this.tarih,
    required this.toplamTry,
    required this.toplamUsd,
    required this.toplamEur,
    required this.usdKuru,
    required this.eurKuru,
    required this.bist100,
    required this.pozisyonlar,
  });
}
