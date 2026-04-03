import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_theme.dart';
import 'splash_page.dart';
import 'alarm_service.dart';
import 'services/price_alarm_background.dart';
import 'services/theme_service.dart';
import 'supabase_config.dart';
import 'update_password_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase'i başlatıyoruz
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[main] .env yüklenemedi: $e');
    debugPrint('[main] env.example ile devam ediliyor.');
    await dotenv.load(fileName: "env.example");
  }

  // Hassas veriler .env dosyasından yüklenir.

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
      'SUPABASE_URL ve SUPABASE_ANON_KEY tanımlı olmalı. '
      'env.example dosyasına Supabase Dashboard > Settings > API değerlerini girin.',
    );
  }

  // Uygulama varsayılan olarak sadece dik (portrait) modda çalışsın
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Şifre sıfırlama deep linkini dinle
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final AuthChangeEvent event = data.event;
    if (event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const UpdatePasswordScreen()),
      );
    }
  });

  // Manuel Deep Link Dinleyici
  final appLinks = AppLinks();
  
  // 1. Soğuk Açılış (Cold Start)
  try {
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      debugPrint('Initial Deep Link: $initialUri');
    }
  } catch (e) {
    debugPrint('Initial Link Hatası: $e');
  }

  // 2. Arka Plandan Açılış (Stream)
  appLinks.uriLinkStream.listen((uri) {
    debugPrint('Stream Deep Link: $uri');
  });

  await ThemeService.instance.init();
  
  if (!kIsWeb) {
    await AlarmService.initialize();
    await AlarmService.requestNotificationPermission();

    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'price-alarm-check',
      'priceAlarmCheck',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

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
    final cs = ColorScheme.light(
      primary: AppTheme.primaryIndigo,
      onPrimary: Colors.white,
      secondary: AppTheme.secondaryIndigo,
      onSecondary: Colors.white,
      surface: AppTheme.surface,
      onSurface: AppTheme.onSurface,
      surfaceContainerLow: AppTheme.surfaceContainerLow,
      surfaceContainerLowest: AppTheme.surfaceContainerLowest,
      error: AppTheme.softRed,
      onError: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: AppTheme.surface,
      textTheme: AppTheme.precisionTypography(Brightness.light),
      cardTheme: CardThemeData(
        color: AppTheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        shadowColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: AppTheme.buttonPaddingHorizontal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: AppTheme.buttonPaddingHorizontal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppTheme.buttonPaddingHorizontal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        backgroundColor: AppTheme.surfaceContainerLowest,
        shadowColor: AppTheme.onSurface.withValues(alpha: 0.08),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppTheme.surfaceContainerLowest,
        elevation: 2,
        shadowColor: AppTheme.onSurface.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          borderSide: AppTheme.ghostBorderSide(AppTheme.onSurface, 0.15),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          borderSide: AppTheme.ghostBorderSide(AppTheme.primaryIndigo, 0.45),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(color: AppTheme.onSurface.withValues(alpha: 0.65), fontSize: 14),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final cs = ColorScheme.dark(
      primary: AppTheme.primaryIndigo,
      onPrimary: Colors.white,
      secondary: AppTheme.secondaryIndigo,
      onSecondary: Colors.white,
      surface: AppTheme.surfaceDark,
      onSurface: AppTheme.textPrimary,
      error: AppTheme.softRed,
      onError: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: AppTheme.bgDark,
      textTheme: AppTheme.precisionTypography(Brightness.dark),
      cardTheme: CardThemeData(
        color: AppTheme.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        shadowColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: AppTheme.buttonPaddingHorizontal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: AppTheme.buttonPaddingHorizontal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppTheme.buttonPaddingHorizontal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        backgroundColor: AppTheme.surfaceDark,
        shadowColor: AppTheme.textPrimary.withValues(alpha: 0.12),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 2,
        shadowColor: AppTheme.textPrimary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          borderSide: AppTheme.ghostBorderSide(AppTheme.textPrimary, 0.15),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          borderSide: AppTheme.ghostBorderSide(AppTheme.primaryIndigo, 0.45),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 14),
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
          title: 'Hisseyat',
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
