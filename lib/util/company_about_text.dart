/// Hisse "Hakkında" metni: Yahoo özeti ile İş Yatırım scrape sonucunu birleştirir,
/// script/menü çöplüğünü ve bariz bozuk metni ekrana çıkarmaz.
class CompanyAboutText {
  CompanyAboutText._();

  /// Script, menü listesi veya bariz mojibake içeren metinler.
  static bool isGarbage(String text) {
    final t = text.trim();
    if (t.length < 40) return false;
    final lower = t.toLowerCase();
    if (lower.contains('document.documentelement') ||
        lower.contains('window.onload') ||
        lower.contains('getelementbyid') ||
        lower.contains('addeventlistener')) {
      return true;
    }
    if (lower.contains('function(') && lower.contains('{')) return true;
    if (RegExp(r'\bvar\s+[a-zA-Z_$][\w$]*\s*=\s*function').hasMatch(t)) return true;
    // Menü: çok sayıda kısa büyük harf kod (A1CAP, THYAO …)
    final tickerLike = RegExp(r'(?<![A-Z])[A-Z]{2,6}(?:\.[A-Z]{1,4})?(?![A-Z])');
    if (tickerLike.allMatches(t).length >= 25) return true;
    // UTF-8 yanlış latin1 okunmuş tipik kalıntılar
    if (t.contains('Ã¼') || t.contains('Ä±') || t.contains('Å') || t.contains('Ã§')) {
      return true;
    }
    return false;
  }

  /// Önce Yahoo [longBusinessSummary], temizse onu; değilse İş Yatırım metni; ikisi de çöpse boş.
  static String pick(String? yahooLongSummary, String? isYatirimHakkinda) {
    final y = yahooLongSummary?.trim() ?? '';
    final iy = isYatirimHakkinda?.trim() ?? '';
    if (y.isNotEmpty && !isGarbage(y)) return y;
    if (iy.isNotEmpty && !isGarbage(iy)) return iy;
    return '';
  }
}
