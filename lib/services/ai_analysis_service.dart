import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/gemini_config.dart';
import '../logo_service.dart';
import '../yahoo_finance_service.dart';

/// Gemini API ile hisse analizi. API key: lib/config/gemini_config.dart içindeki [geminiApiKey].
class AIAnalysisService {
  static const _systemInstruction = r'''
Sen 20 yıllık deneyime sahip, Borsa İstanbul uzmanı, sert, gerçekçi ve veriye dayalı konuşan bir borsa analistisin. Analizini **eğlenceli ve şakacı** bir dille yaz; yine de veriye dayalı ve ciddi sonuçlar sun. Şu hisseyi analiz et:

İstenen Çıktı Formatı:

Genel Görünüm: (Hacim ve fiyata bakarak piyasa psikolojisini yorumla).

Teknik Göstergeler: (RSI, MACD gibi değerleri tahmin etmeden, sadece fiyat hareketinin trendi -Boğa/Ayı- üzerine konuş).

Risk Analizi: (Yatırımcıyı bekleyen olası tehlikeler).

Sonuç ve Tavsiye: 400-500 kelimelik bu analizin sonunda kalın harflerle ve net bir şekilde: AL, SAT veya TUT tavsiyesi ver. Sonuna mutlaka YTD - Yatırım Tavsiyesi Değildir uyarısını ekle.
''';

  /// [symbol] BIST sembolü (örn. THYAO veya THYAO.IS), [price] TL, [volume] işlem adedi, [changePercent] günlük % değişim.
  /// [stockContext] verilirse prompt'a 52w değişim, F/K, PD/DD, net kar, sektör, 15/52 gün ortalamaları eklenir.
  /// Hata durumunda exception fırlatır.
  static Future<String> getAnalysis(
    String symbol,
    double price,
    double volume,
    double changePercent, {
    StockAnalysisContext? stockContext,
  }) async {
    if (geminiApiKey.isEmpty) {
      throw Exception(
        'Gemini API anahtarı tanımlı değil. Proje kökündeki .env dosyasına şunu ekleyin: GEMINI_API_KEY=sizin_anahtarınız\n'
        'Anahtar: https://aistudio.google.com/apikey — Uygulamayı yeniden başlatın.',
      );
    }

    final displaySymbol = LogoService.symbolForDisplay(symbol);
    final buf = StringBuffer();
    buf.writeln(
      'Aşağıdaki veriler uygulama tarafından Yahoo Finance ve İş Yatırım verilerine göre hesaplanmıştır. '
      'Günlük değişim yüzdesi önceki kapanışa göredir. Analizinde sadece bu verilere dayan, sayıları olduğu gibi kullan.');
    buf.writeln('');
    buf.writeln('Hisse: $displaySymbol');
    buf.writeln('Anlık Fiyat: ${price.toStringAsFixed(2)} TL');
    buf.writeln('Hacim: ${volume.toStringAsFixed(0)}');
    buf.writeln('Günlük Değişim (önceki kapanışa göre): %${changePercent.toStringAsFixed(2)}');

    if (stockContext != null) {
      if (stockContext.changePercent52W != null) {
        buf.writeln('Son 52 Haftalık Fiyat Değişimi: %${stockContext.changePercent52W!.toStringAsFixed(2)}');
      }
      if (stockContext.fk != null) {
        buf.writeln('F/K (P/E) Değeri: ${stockContext.fk!.toStringAsFixed(2)}');
      }
      if (stockContext.pdDd != null) {
        buf.writeln('PD/DD (P/B) Değeri: ${stockContext.pdDd!.toStringAsFixed(2)}');
      }
      if (stockContext.netKar != null) {
        final n = stockContext.netKar!;
        final netKarStr = n >= 1e9
            ? '${(n / 1e9).toStringAsFixed(2)} milyar TL'
            : n >= 1e6
                ? '${(n / 1e6).toStringAsFixed(2)} milyon TL'
                : '${n.toStringAsFixed(0)} TL';
        buf.writeln('Son Dönem Net Karı: $netKarStr');
      }
      if (stockContext.sector != null && stockContext.sector!.isNotEmpty) {
        buf.writeln('Sektör: ${stockContext.sector}');
        if (stockContext.industry != null && stockContext.industry!.isNotEmpty) {
          buf.writeln('Alt Sektör / Endüstri: ${stockContext.industry}');
        }
        buf.writeln('(Bu hisseyi sektör ortalamaları ve rakipleriyle kıyaslayabilirsin.)');
      }
      if (stockContext.avgClose15 != null) {
        buf.writeln('Son 15 Günlük Kapanış Fiyat Ortalaması: ${stockContext.avgClose15!.toStringAsFixed(2)} TL');
      }
      if (stockContext.avgClose52 != null) {
        buf.writeln('Son 52 Günlük Kapanış Fiyat Ortalaması: ${stockContext.avgClose52!.toStringAsFixed(2)} TL');
      }
      if ((stockContext.avgClose15 != null || stockContext.avgClose52 != null)) {
        buf.writeln('(Bu ortalamalara göre kısa/orta vadeli trend hakkında yorum yap.)');
      }
      buf.writeln('');
    }

    buf.writeln(
      'Yukarıdaki verilere göre analizini yaz. Çıktıda başlıkları **kalın** (Markdown) kullan; '
      'sonuçta AL, SAT veya TUT tavsiyesini kalın yaz ve en sonda "YTD - Yatırım Tavsiyesi Değildir" uyarısını ekle.');
    final userPrompt = buf.toString();

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: geminiApiKey,
      systemInstruction: Content.text(_systemInstruction),
      generationConfig: GenerationConfig(
        maxOutputTokens: 4096,
        temperature: 0.7,
      ),
    );

    final response = await model.generateContent([Content.text(userPrompt)]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini yanıt üretemedi.');
    }
    return text;
  }

  /// Hisse analizi için ek bağlam (isteğe bağlı). 15/52 gün ortalamaları yoksa servis chart verisinden hesaplar.
  static Future<StockAnalysisContext?> enrichWithChartAverages(
    String symbol,
    StockAnalysisContext? existing,
  ) async {
    if (existing?.avgClose15 != null && existing?.avgClose52 != null) return existing;
    final points = await YahooFinanceService.hisseChartOHLCAl(
      symbol,
      interval: '1d',
      range: '1y',
    );
    if (points == null || points.length < 15) return existing;
    double sum15 = 0, sum52 = 0;
    final n15 = points.length >= 15 ? 15 : points.length;
    final n52 = points.length >= 52 ? 52 : points.length;
    for (var i = points.length - n15; i < points.length; i++) {
      sum15 += points[i].close;
    }
    for (var i = points.length - n52; i < points.length; i++) {
      sum52 += points[i].close;
    }
    final avg15 = n15 > 0 ? sum15 / n15 : null;
    final avg52 = n52 > 0 ? sum52 / n52 : null;
    return StockAnalysisContext(
      changePercent52W: existing?.changePercent52W,
      fk: existing?.fk,
      pdDd: existing?.pdDd,
      netKar: existing?.netKar,
      sector: existing?.sector,
      industry: existing?.industry,
      avgClose15: avg15 ?? existing?.avgClose15,
      avgClose52: avg52 ?? existing?.avgClose52,
    );
  }

  static const _cryptoSystemInstruction = r'''
Sen kripto para piyasası uzmanı, veriye dayalı ve gerçekçi konuşan bir analistsin. Verilen kripto varlığı (USDT çifti) analiz et.

İstenen Çıktı Formatı:

Genel Görünüm: (Hacim ve fiyata bakarak piyasa psikolojisini yorumla).

Trend: (Fiyat hareketinin yönü - Boğa/Ayı - üzerine kısa değerlendirme).

Risk Analizi: (Volatilite, likidite ve yatırımcıyı bekleyen olası riskler).

Sonuç ve Tavsiye: 400-500 kelime içinde analizi özetle; sonunda kalın harflerle net şekilde AL, SAT veya TUT tavsiyesi ver. Sonuna "YTD - Yatırım Tavsiyesi Değildir" uyarısını ekle.
''';

  /// Kripto analizi: [symbol] örn. BTCUSDT veya BTC, [price] USD, [volume] 24s hacim, [changePercent] 24s % değişim.
  static Future<String> getCryptoAnalysis(
    String symbol,
    double price,
    double volume,
    double changePercent,
  ) async {
    if (geminiApiKey.isEmpty) {
      throw Exception(
        'Gemini API anahtarı tanımlı değil. Proje kökündeki .env dosyasına şunu ekleyin: GEMINI_API_KEY=sizin_anahtarınız\n'
        'Anahtar: https://aistudio.google.com/apikey — Uygulamayı yeniden başlatın.',
      );
    }

    final displaySymbol = symbol.toUpperCase().replaceAll('USDT', '').trim();
    if (displaySymbol.isEmpty) throw Exception('Geçersiz sembol.');

    final userPrompt = '''
Aşağıdaki veriler uygulama tarafından Binance 24 saatlik verilerine göre alınmıştır. Analizinde sadece bu verilere dayan, sayıları olduğu gibi kullan.

Kripto: $displaySymbol / USDT
Anlık Fiyat: \$${price.toStringAsFixed(2)}
24s Hacim (USDT): ${volume.toStringAsFixed(0)}
24s Değişim (%): %${changePercent.toStringAsFixed(2)}

Yukarıdaki verilere göre analizini yaz. Çıktıda başlıkları **kalın** (Markdown) kullan; sonuçta AL, SAT veya TUT tavsiyesini kalın yaz ve en sonda "YTD - Yatırım Tavsiyesi Değildir" uyarısını ekle.
''';

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: geminiApiKey,
      systemInstruction: Content.text(_cryptoSystemInstruction),
      generationConfig: GenerationConfig(
        maxOutputTokens: 4096,
        temperature: 0.7,
      ),
    );

    final response = await model.generateContent([Content.text(userPrompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini yanıt üretemedi.');
    }
    return text;
  }
}

/// Hisse analizi prompt'una eklenecek ek veriler.
class StockAnalysisContext {
  final double? changePercent52W;
  final double? fk;
  final double? pdDd;
  final double? netKar;
  final String? sector;
  final String? industry;
  final double? avgClose15;
  final double? avgClose52;

  const StockAnalysisContext({
    this.changePercent52W,
    this.fk,
    this.pdDd,
    this.netKar,
    this.sector,
    this.industry,
    this.avgClose15,
    this.avgClose52,
  });
}
