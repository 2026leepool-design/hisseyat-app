import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'app_theme.dart';
import 'splash_page.dart';
import 'alarm_service.dart';
import 'services/price_alarm_background.dart';
import 'services/theme_service.dart';
import 'supabase_config.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Uygulama varsayılan olarak sadece dik (portrait) modda çalışsın
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await ThemeService.instance.init();

  await AlarmService.initialize();
  await AlarmService.requestNotificationPermission();

  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'price-alarm-check',
    'priceAlarmCheck',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  // Assertion hatalarında (örn. satış sonrası _dependents) otomatik geri kapat
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('_dependents.isEmpty')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          navigatorKey.currentState?.maybePop();
        });
      });
    }
    defaultOnError?.call(details);
  };

  // Build hatalarında da otomatik kapat (sadece kritik hatalarda)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final isCriticalError = details.exception is FlutterError &&
        details.exception.toString().contains('_dependents.isEmpty');

    if (isCriticalError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          navigatorKey.currentState?.maybePop();
        });
      });
      return Container(
        color: Colors.red.shade900,
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'İşlem tamamlandı. Kapatılıyor…',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ErrorWidget(details.exception);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppTheme.smokyJade,
        onPrimary: Colors.white,
        secondary: AppTheme.slateTeal,
        surface: AppTheme.surfaceLight,
        onSurface: const Color(0xFF1F2937),
        error: AppTheme.softRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppTheme.bgLight,
      cardTheme: CardThemeData(
        color: AppTheme.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppTheme.smokyJade,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.smokyJade, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppTheme.smokyJade,
        onPrimary: Colors.white,
        secondary: AppTheme.secondaryAccent,
        surface: AppTheme.surfaceDark,
        onSurface: AppTheme.textPrimary,
        error: AppTheme.softRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppTheme.bgDark,
      cardTheme: CardThemeData(
        color: AppTheme.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: Colors.black.withValues(alpha: 0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppTheme.smokyJade,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.smokyJade, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Hisseli Harikalar',
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: mode,
          locale: const Locale('tr', 'TR'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('tr', 'TR'),
            Locale('en', 'US'),
          ],
          home: const SplashPage(),
        );
      },
    );
  }
}
