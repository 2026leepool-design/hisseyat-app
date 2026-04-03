import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Etheric Neon — kripto modu (Material 3 seed paleti: primary violet, emerald, sky blue).
/// Light / dark [Theme.of(context).brightness] ile yüzey ve metinler seçilir.
/// Kart gölgesi yok; tonal katmanlar. Etiketler: uppercase + letterSpacing 0.8. Radius 8px.
class CryptoTheme {
  // —— Seed (her iki modda aynı vurgular) ——
  static const Color seedPrimary = Color(0xFF8B5CF6);
  static const Color seedSecondary = Color(0xFF10B981);
  static const Color seedTertiary = Color(0xFF3B82F6);
  static const Color seedNeutralDark = Color(0xFF0F172A);

  static const Color errorCoral = Color(0xFFEF4444);

  /// Birincil düğme üzerinde metin / ikon
  static const Color onPrimary = Color(0xFFFFFFFF);

  // —— Dark (Etheric Neon — gece) ——
  static const Color _darkScaffold = Color(0xFF0F172A);
  static const Color _darkSurface1 = Color(0xFF1E293B);
  static const Color _darkSurface2 = Color(0xFF334155);
  static const Color _darkSurface3 = Color(0xFF475569);

  // —— Light (Etheric Neon — gündüz) ——
  static const Color _lightScaffold = Color(0xFFF8FAFC);
  static const Color _lightSurface1 = Color(0xFFFFFFFF);
  static const Color _lightSurface2 = Color(0xFFF1F5F9);
  static const Color _lightSurface3 = Color(0xFFE2E8F0);

  static const double radius = 8;
  static const double glassBlurSigma = 20;
  static const double glassBackgroundOpacity = 0.6;

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // —— Semantik renkler ——
  static const Color primaryElectric = seedPrimary;
  static const Color secondaryNeon = seedSecondary;
  static const Color tertiaryBlue = seedTertiary;

  /// Geriye uyumluluk + cam / Slidable
  static const Color surfaceMidnight = _darkScaffold;
  static const Color bgDark = _darkScaffold;
  static const Color surfaceDark = _darkSurface1;
  static const Color cryptoAmber = seedPrimary;
  static const Color cryptoOrange = seedPrimary;
  static const Color accentCyan = seedTertiary;
  static const Color successGreen = seedSecondary;
  static const Color errorRed = errorCoral;
  static const Color priceAccent = seedPrimary;
  static const Color positiveChange = seedSecondary;
  static const Color negativeChange = errorCoral;

  /// Koyu zeminde başlık rengi (sabit); dinamik için [textPrimaryFor].
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textPrimaryDarkBg = textPrimary;
  static const Color textPrimaryLightBg = seedNeutralDark;

  static const Color bgLight = _lightScaffold;
  static const Color surfaceLight = _lightSurface1;

  static Color textPrimaryFor(BuildContext context) =>
      _isDark(context) ? textPrimary : seedNeutralDark;

  static Color textSecondaryFor(BuildContext context) => _isDark(context)
      ? const Color(0xFF94A3B8)
      : const Color(0xFF64748B);

  static Color primaryColor(BuildContext context) => seedPrimary;

  static Color backgroundGrey(BuildContext context) =>
      _isDark(context) ? _darkScaffold : _lightScaffold;

  static Color cardColor(BuildContext context) =>
      _isDark(context) ? _darkSurface1 : _lightSurface1;

  static Color cardColorElevated(BuildContext context) =>
      _isDark(context) ? _darkSurface2 : _lightSurface2;

  static Color surfaceLayer3(BuildContext context) =>
      _isDark(context) ? _darkSurface3 : _lightSurface3;

  /// Input / hayalet çizgi için üst metin rengi
  static Color onSurface(BuildContext context) => textPrimaryFor(context);

  /// Küçük etiketler; metni widget tarafında `.toUpperCase()` verin.
  static TextStyle labelStyle(BuildContext context, {double fontSize = 11}) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: textSecondaryFor(context),
      );

  static TextStyle bodyInter(
    BuildContext context, {
    double fontSize = 14,
    FontWeight? weight,
    Color? color,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: weight ?? FontWeight.w400,
        color: color ?? textPrimaryFor(context),
      );

  static Color glassBarColor(BuildContext context) =>
      backgroundGrey(context).withValues(alpha: glassBackgroundOpacity);

  static ImageFilter get glassBlur =>
      ImageFilter.blur(sigmaX: glassBlurSigma, sigmaY: glassBlurSigma);
}
