import '../supabase_portfolio_service.dart';
import 'historical_price_service.dart';

/// Seçilen tarihteki portföy durumunu hesaplar.
class TimeTunnelService {
  /// Seçilen tarihe kadar (dahil) işlemleri işleyerek o tarihteki hisse adetlerini döndürür.
  /// Sadece adet > 0 olanları döner.
  static Future<Map<String, double>> portfoyAdetleriHesapla(DateTime secilenTarih, {String? portfolioId}) async {
    final islemler = await SupabasePortfolioService.islemleriYukle(portfolioId: portfolioId);
    final secilenGun = DateTime(secilenTarih.year, secilenTarih.month, secilenTarih.day);

    final adetler = <String, double>{};
    final siraliIslemler = List<TransactionRow>.from(islemler)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final t in siraliIslemler) {
      final tGun = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      if (tGun.isAfter(secilenGun)) continue;

      final sym = t.symbol;
      final qty = t.quantity ?? 0;

      switch (t.transactionType) {
        case 'buy':
        case 'split':
          adetler[sym] = (adetler[sym] ?? 0) + qty;
          break;
        case 'sell':
          adetler[sym] = (adetler[sym] ?? 0) - qty;
          break;
        case 'dividend':
          break;
        default:
          adetler[sym] = (adetler[sym] ?? 0) + qty;
      }
    }

    return Map.fromEntries(
      adetler.entries.where((e) => e.value > 0),
    );
  }

  /// Tarihsel fiyatları ve döviz kurlarını batch'ler halinde çeker.
  static Future<TimeTunnelSonuc> hesapla(DateTime secilenTarih) async {
    final adetler = await portfoyAdetleriHesapla(secilenTarih);
    if (adetler.isEmpty) {
      return TimeTunnelSonuc(
        tarih: secilenTarih,
        toplamTry: 0,
        toplamUsd: 0,
        toplamEur: 0,
        usdKuru: 0,
        eurKuru: 0,
        pozisyonlar: [],
      );
    }

    final semboller = adetler.keys.toList();
    final fxSemboller = ['USDTRY=X', 'EURTRY=X'];
    final tumSemboller = [...semboller, ...fxSemboller];

    final fiyatlar = await HistoricalPriceService.getClosePricesBatched(tumSemboller, secilenTarih);

    final usdKuru = fiyatlar['USDTRY=X'] ?? 0.0;
    final eurKuru = fiyatlar['EURTRY=X'] ?? 0.0;

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
  final List<TimeTunnelPozisyon> pozisyonlar;

  TimeTunnelSonuc({
    required this.tarih,
    required this.toplamTry,
    required this.toplamUsd,
    required this.toplamEur,
    required this.usdKuru,
    required this.eurKuru,
    required this.pozisyonlar,
  });
}
