/// Sembol formatlama servisi.
class LogoService {
  /// Sembolden .IS (veya benzeri) sonekini kaldırır.
  /// Örn: THYAO.IS -> THYAO. Hem logo hem ekranda gösterim için kullanılır.
  static String symbolForLogo(String symbol) {
    final upper = symbol.toUpperCase().trim();
    if (upper.endsWith('.IS')) {
      return upper.replaceAll('.IS', '');
    }
    return upper;
  }

  /// Ekranda göstermek için sembol (.IS kaldırılmış).
  static String symbolForDisplay(String symbol) => symbolForLogo(symbol);
}
