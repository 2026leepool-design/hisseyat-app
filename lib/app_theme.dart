import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Charcoal & Smoky Jade – 2026 sessiz lüks paleti
/// Varlık yönetimi / yatırım / özel bankacılık uygulamaları için
class AppTheme {
  // === YENİ PALET (Charcoal & Smoky Jade) ===
  /// Arka plan (koyu) – dark mode
  static const Color bgDark = Color(0xFF111827);
  /// Yüzey – dark mode kartlar
  static const Color surfaceDark = Color(0xFF1F2937);
  /// Birincil accent – smoky jade
  static const Color smokyJade = Color(0xFF356B6B);
  /// Alternatif birincil – slate teal
  static const Color slateTeal = Color(0xFF3A6D7E);
  /// İkincil accent – hafif mavi-mor geçiş
  static const Color secondaryAccent = Color(0xFFA3BFFA);
  /// Başarı / Pozitif
  static const Color success = Color(0xFF059669);
  /// Metin primer – dark mode
  static const Color textPrimary = Color(0xFFF3F4F6);
  /// Metin secondary – dark mode
  static const Color textSecondary = Color(0xFF9CA3AF);
  /// Light arka plan
  static const Color bgLight = Color(0xFFFAFAFA);
  /// Light yüzey / kart
  static const Color surfaceLight = Colors.white;

  // === GERİYE UYUMLULUK (eski isimler → yeni palet) ===
  static const Color navyBlue = smokyJade;
  static const Color darkSlate = slateTeal;
  static const Color emeraldGreen = success;
  static const Color mintGreen = Color(0xFF34D399);
  static const Color softRed = Color(0xFFF87171);
  static const Color salmonRed = Color(0xFFFDA4AF);
  static const Color purple = Color(0xFF9333EA);
  static const Color lightPurple = Color(0xFFE9D5FF);
  static const Color offWhite = bgLight;
  static Color get cardWhite => surfaceLight;

  /// Türk lirası için ₺, diğer para birimleri için kodu döndürür (ekranda gösterim).
  static String currencyDisplay(String? currency) =>
      (currency == null || currency == 'TRY' || currency == 'TL') ? '₺' : currency;

  static Color backgroundGrey(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bgDark : Colors.grey.shade50;

  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceDark : surfaceLight;

  // Yumuşak gölge (Apple/iOS tarzı)
  static List<BoxShadow> shadow(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05,
          ),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static BoxDecoration cardDecoration(BuildContext context) => BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadow(context),
      );

  static BoxDecoration cardDecorationStatic = BoxDecoration(
    color: surfaceLight,
    borderRadius: BorderRadius.circular(16),
    boxShadow: softShadow,
  );

  // Bank kartı / header gradient
  static BoxDecoration bankCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [smokyJade, surfaceDark]
            : [smokyJade, slateTeal],
        stops: const [0.0, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: smokyJade.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // Kar/zarar chip renkleri
  static Color chipGreen(bool karda) => karda ? success : softRed;
  static Color chipBgGreen(bool karda) =>
      karda ? success.withValues(alpha: 0.15) : softRed.withValues(alpha: 0.15);

  // Tipografi – tema uyumlu renkler
  static Color _textColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textPrimary : const Color(0xFF1F2937);
  static Color _textSecondaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textSecondary : Colors.grey.shade700;

  /// Ana başlıklar (örn. Varlıklarım) – 22pt bold
  static TextStyle h1(BuildContext context) => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: _textColor(context),
      );
  /// Alt başlıklar, bölüm başlıkları – 16pt semi-bold
  static TextStyle h2(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textColor(context),
      );
  /// Gövde metni – 14pt
  static TextStyle body(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _textSecondaryColor(context),
      );
  /// İkincil metin, açıklamalar – 12pt
  static TextStyle bodySmall(BuildContext context) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: _textSecondaryColor(context),
      );
  /// Fiyat, tutar – 16pt semi-bold
  static TextStyle price(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textColor(context),
      );
  /// Hisse sembolü – 17pt bold
  static TextStyle symbol(BuildContext context) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: _textColor(context),
      );
}
