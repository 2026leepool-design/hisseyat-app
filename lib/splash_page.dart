import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_shell.dart';
import 'login_page.dart';
import 'release_notes_page.dart';
import 'widgets/app_logo.dart';

// Uygulama ile uyumlu Charcoal & Smoky Jade paleti
const _splashBgDark = Color(0xFF111827);
const _splashSurface = Color(0xFF1F2937);
const _splashJade = Color(0xFF356B6B);
const _splashTeal = Color(0xFF3A6D7E);
const _splashAccent = Color(0xFFA3BFFA);

/// Uygulama açılış sayfası: retro logo, komplike yükleniyor animasyonu, ~5 sn sonra login/home
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late AnimationController _progressController;
  late List<AnimationController> _dotControllers;
  static const _dotCount = 5;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    _dotControllers = List.generate(
      _dotCount,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      ),
    );
    _startDotWave();

    _logoController.forward();

    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      final showNotes = await shouldShowReleaseNotes();
      if (!mounted) return;
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => showNotes
              ? const ReleaseNotesPage()
              : (isLoggedIn ? const AppShell() : const LoginPage()),
        ),
      );
    });
  }

  void _startDotWave() {
    for (var i = 0; i < _dotCount; i++) {
      Future.delayed(Duration(milliseconds: 150 * i), () {
        if (!mounted) return;
        _dotControllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    for (final c in _dotControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _splashBgDark,
              _splashSurface,
              _splashJade,
              _splashTeal,
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: _splashJade.withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: AppLogo(size: 120, forDarkBackground: true),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Text(
                      'StockTrack Pro',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: _splashJade.withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Text(
                      'Portföyünüz şaha kalkıyor! 📈',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(flex: 2),
              Column(
                children: [
                  _LoadingAnimation(
                    progressController: _progressController,
                    dotControllers: _dotControllers,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Uygulama yükleniyor...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dalga halinde zıplayan noktalar + 5 sn dolan ilerleme çubuğu
class _LoadingAnimation extends StatelessWidget {
  final AnimationController progressController;
  final List<AnimationController> dotControllers;

  const _LoadingAnimation({
    required this.progressController,
    required this.dotControllers,
  });

  static const _dotColors = [
    _splashJade,
    _splashTeal,
    _splashAccent,
    AppTheme.success,
    _splashJade,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _SplashPageState._dotCount,
            (i) => AnimatedBuilder(
              animation: dotControllers[i],
              builder: (context, child) {
                final t = dotControllers[i].value;
                final bounce = 8 * math.sin(t * math.pi);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  transform: Matrix4.translationValues(0, -bounce, 0),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _dotColors[i],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _dotColors[i].withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          height: 6,
          child: AnimatedBuilder(
            animation: progressController,
            builder: (context, child) {
              return CustomPaint(
                painter: _LoadingBarPainter(progressController.value),
                size: const Size(200, 6),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LoadingBarPainter extends CustomPainter {
  final double progress;

  _LoadingBarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );
    final fillWidth = size.width * progress.clamp(0.0, 1.0);
    if (fillWidth > 0) {
      final fillRrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, fillWidth, size.height),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        fillRrect,
        Paint()
          ..shader = const LinearGradient(
            colors: [_splashJade, _splashTeal],
            stops: [0.0, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoadingBarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
