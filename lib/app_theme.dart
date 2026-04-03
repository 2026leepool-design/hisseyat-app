import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Precision Editorial — hisse (light) tasarım dili.
/// Kartlarda gölge yok; hafif gölge yalnızca modal / yüzen öğeler için [floatingShadow].
/// Çizgi yerine boşluk; sınır gerekiyorsa [ghostBorderSide].
class AppTheme {
  // —— Precision Editorial (light) ——
  static const Color primaryIndigo = Color(0xFF4555B7);
  static const Color surface = Color(0xFFFBF8FF);
  static const Color surfaceContainerLow = Color(0xFFF3F2FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF2D3147);

  static const double radiusXl = 12;
  static const EdgeInsetsGeometry buttonPaddingHorizontal =
      EdgeInsets.symmetric(horizontal: 20, vertical: 14);

  /// Modal / floating — #2d3147 @ %8
  static List<BoxShadow> get floatingShadow => [
        BoxShadow(
          color: onSurface.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static BorderSide ghostBorderSide(Color base, [double opacity = 0.15]) =>
      BorderSide(color: base.withValues(alpha: opacity));

  // —— Hisse dark (sistem koyu teması, kripto değil) ——
  static const Color bgDark = Color(0xFF12141F);
  static const Color surfaceDark = Color(0xFF1C1F2E);
  static const Color textPrimary = Color(0xFFEEF0F8);
  static const Color textSecondary = Color(0xFFA8ADC4);

  /// İkincil vurgu (buton outline, ikon tonu)
  static const Color secondaryIndigo = Color(0xFF5B6BC7);

  // —— Geriye uyumluluk (eski isimler) ——
  static const Color smokyJade = primaryIndigo;
  static const Color navyBlue = primaryIndigo;
  static const Color slateTeal = secondaryIndigo;
  static const Color darkSlate = onSurface;
  static const Color bgLight = surface;
  static const Color surfaceLight = surfaceContainerLowest;
  static const Color emeraldGreen = Color(0xFF0D9488);
  /// Geriye uyumluluk — pozitif / başarı rengi
  static const Color success = emeraldGreen;
  static const Color mintGreen = Color(0xFF34D399);
  static const Color softRed = Color(0xFFE85D5D);
  static const Color salmonRed = Color(0xFFFDA4AF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color lightPurple = Color(0xFFE9D5FF);
  static const Color offWhite = surface;
  static const Color secondaryAccent = Color(0xFFC4C9F5);

  static Color get cardWhite => surfaceContainerLowest;

  static String currencyDisplay(String? currency) =>
      (currency == null || currency == 'TRY' || currency == 'TL') ? '₺' : currency;

  static Color backgroundGrey(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bgDark : surface;

  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceDark : surfaceContainerLowest;

  /// Kartlar: gölge yok, 12px radius
  static List<BoxShadow> shadow(BuildContext context) => const [];

  static List<BoxShadow> get softShadow => const [];

  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? surfaceDark : surfaceContainerLowest,
      borderRadius: BorderRadius.circular(radiusXl),
    );
  }

  static BoxDecoration get cardDecorationStatic => BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radiusXl),
      );

  /// Özet / banka kartı üst alanı — gradient, radius 12, hafif yüzen gölge
  static BoxDecoration bankCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusXl),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF3A4890), surfaceDark]
            : [primaryIndigo, const Color(0xFF3846A5)],
      ),
      boxShadow: floatingShadow,
    );
  }

  static Color chipGreen(bool karda) => karda ? emeraldGreen : softRed;
  static Color chipBgGreen(bool karda) =>
      karda ? emeraldGreen.withValues(alpha: 0.15) : softRed.withValues(alpha: 0.15);

  static Color _textColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textPrimary : onSurface;

  static Color _textSecondaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textSecondary : onSurface.withValues(alpha: 0.65);

  static double _headlineTracking(double fontSize) => fontSize * -0.02;

  /// Başlıklar — Manrope, hero tracking
  static TextStyle h1(BuildContext context) => GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: _headlineTracking(22),
        color: _textColor(context),
      );

  static TextStyle h2(BuildContext context) => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: _headlineTracking(16),
        color: _textColor(context),
      );

  static TextStyle body(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _textSecondaryColor(context),
      );

  static TextStyle bodySmall(BuildContext context) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: _textSecondaryColor(context),
      );

  static TextStyle price(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textColor(context),
      );

  static TextStyle symbol(BuildContext context) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: _textColor(context),
      );

  /// Material [TextTheme]: Display/Headline → Manrope (-0.02em), diğerleri Inter.
  static TextTheme precisionTypography(Brightness brightness) {
    final Color onTx = brightness == Brightness.light ? onSurface : textPrimary;
    final TextTheme base = ThemeData(useMaterial3: true, brightness: brightness).textTheme.apply(
          bodyColor: onTx,
          displayColor: onTx,
        );
    final TextTheme inter = GoogleFonts.interTextTheme(base);
    double emNeg(double fs) => fs * -0.02;
    TextStyle manrope(double fs, FontWeight w) => GoogleFonts.manrope(
          fontSize: fs,
          fontWeight: w,
          letterSpacing: emNeg(fs),
          height: 1.2,
          color: onTx,
        );
    return inter.copyWith(
      displayLarge: manrope(57, FontWeight.w600),
      displayMedium: manrope(45, FontWeight.w600),
      displaySmall: manrope(36, FontWeight.w600),
      headlineLarge: manrope(32, FontWeight.w600),
      headlineMedium: manrope(28, FontWeight.w600),
      headlineSmall: manrope(24, FontWeight.w600),
    );
  }
}
