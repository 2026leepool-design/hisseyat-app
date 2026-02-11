import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/gemini_config.dart';
import '../logo_service.dart';

/// Gemini API ile hisse analizi. API key: lib/config/gemini_config.dart içindeki [geminiApiKey].
class AIAnalysisService {
  static const _systemInstruction = r'''
Sen 20 yıllık deneyime sahip, Borsa İstanbul uzmanı, sert, gerçekçi ve veriye dayalı konuşan bir borsa analistisin. Şu hisseyi analiz et:

İstenen Çıktı Formatı:

Genel Görünüm: (Hacim ve fiyata bakarak piyasa psikolojisini yorumla).

Teknik Göstergeler: (RSI, MACD gibi değerleri tahmin etmeden, sadece fiyat hareketinin trendi -Boğa/Ayı- üzerine konuş).

Risk Analizi: (Yatırımcıyı bekleyen olası tehlikeler).

Sonuç ve Tavsiye: 400-500 kelimelik bu analizin sonunda kalın harflerle ve net bir şekilde: AL, SAT veya TUT tavsiyesi ver. Sonuna mutlaka YTD - Yatırım Tavsiyesi Değildir uyarısını ekle.
''';

  /// [symbol] BIST sembolü (örn. THYAO veya THYAO.IS), [price] TL, [volume] işlem adedi, [changePercent] günlük % değişim.
  /// Hata durumunda exception fırlatır.
  static Future<String> getAnalysis(
    String symbol,
    double price,
    double volume,
    double changePercent,
  ) async {
    if (geminiApiKey.isEmpty) {
      throw Exception(
        'Gemini API anahtarı tanımlı değil. lib/config/gemini_config.dart dosyasına kendi key\'inizi ekleyin.',
      );
    }

    final displaySymbol = LogoService.symbolForDisplay(symbol);
    final userPrompt = '''
Aşağıdaki veriler uygulama tarafından Yahoo Finance anlık verilerine göre hesaplanmıştır. Günlük değişim yüzdesi, önceki kapanış fiyatına göre hesaplanır. Analizinde sadece bu verilere dayan, sayıları olduğu gibi kullan.

Hisse: $displaySymbol
Anlık Fiyat: ${price.toStringAsFixed(2)} TL
Hacim: ${volume.toStringAsFixed(0)}
Günlük Değişim (önceki kapanışa göre): %${changePercent.toStringAsFixed(2)}

Yukarıdaki verilere göre analizini yaz. Çıktıda başlıkları **kalın** (Markdown) kullan; sonuçta AL, SAT veya TUT tavsiyesini kalın yaz ve en sonda "YTD - Yatırım Tavsiyesi Değildir" uyarısını ekle.
''';

    // gemini-1.5-flash v1beta'da bulunamıyor; güncel model kullanılıyor.
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
}
