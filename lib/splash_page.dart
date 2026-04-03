import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_shell.dart';
import 'login_page.dart';
import 'release_notes_page.dart';

// Animasyon için canlı renk paleti
const List<Color> _ballColors = [
  Color(0xFF356B6B), // Jade
  Color(0xFFFFD700), // Gold
  Color(0xFFE57373), // Red
  Color(0xFF4CAF50), // Green
  Color(0xFF64B5F6), // Blue
  Color(0xFFBA68C8), // Purple
  Color(0xFFFFB74D), // Orange
];

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  
  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  late List<AnimationController> _ballControllers;
  static const _ballCount = 7; // Top sayısı

  @override
  void initState() {
    super.initState();

    // Logo Animasyonları
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    // Metin Animasyonları
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutQuart),
    );

    // Top Animasyonları
    _ballControllers = List.generate(
      _ballCount,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (i * 100)), // Her top farklı hızda
      ),
    );
    _startBallBouncing();

    // Sıralı Başlatma
    _logoController.forward().then((_) {
      _textController.forward();
    });

    // Yönlendirme
    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;
      
      // İlk açılış kontrolü veya login durumu
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      final showNotes = await shouldShowReleaseNotes();
      
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
            showNotes 
              ? const ReleaseNotesPage() 
              : (isLoggedIn ? const AppShell() : const LoginPage()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  void _startBallBouncing() {
    for (var i = 0; i < _ballCount; i++) {
      // Rastgele gecikmelerle başlat
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (!mounted) return;
        _ballControllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    for (final c in _ballControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // BEYAZ ARKA PLAN
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              
              // --- LOGO ---
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 160,
                        height: 160,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.smokyJade.withOpacity(0.15),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(
                            color: AppTheme.smokyJade.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Image.asset(
                          'assets/icon/app_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.candlestick_chart_rounded,
                              size: 80,
                              color: AppTheme.smokyJade,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // --- APP NAME & SLOGAN ---
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      Text(
                        'Hisseyat',
                        style: GoogleFonts.outfit(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.smokyJade, // KOYU RENK
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.smokyJade.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Manage your Stock&Crypto with Hisseyat',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.smokyJade.withOpacity(0.8), // KOYU RENK
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
              
              // --- FUN BOUNCING BALLS ANIMATION ---
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_ballCount, (index) {
                    return _BouncingBall(
                      controller: _ballControllers[index],
                      color: _ballColors[index % _ballColors.length],
                      delay: index,
                    );
                  }),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Loading Text
              Text(
                'Yükleniyor...',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.smokyJade.withOpacity(0.6), // KOYU RENK
                  letterSpacing: 2,
                ),
              ),
              
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _BouncingBall extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final int delay;

  const _BouncingBall({
    required this.controller,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Sinüs dalgası hareketi + Sıçrama efekti
        final t = controller.value;
        final bounceHeight = 30.0 + (delay % 2 * 15.0); // Farklı yükseklikler
        final val = math.sin(t * math.pi); // 0 -> 1 -> 0
        final translateY = -val * bounceHeight;
        
        // Zıplarken hafifçe ezilme efekti (scale)
        final scaleX = 1.0 + (val < 0.1 ? 0.2 : 0.0); // Yere değdiğinde genişle
        final scaleY = 1.0 - (val < 0.1 ? 0.2 : 0.0); // Yere değdiğinde basıklaş

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          transform: Matrix4.translationValues(0, translateY, 0),
          child: Transform.scale(
            scaleX: scaleX,
            scaleY: scaleY,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10 + (val * 5),
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
