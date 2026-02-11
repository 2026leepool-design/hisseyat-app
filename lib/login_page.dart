import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_shell.dart';
import 'widgets/app_logo.dart';

const _kRememberMe = 'remember_me';
const _kSavedEmail = 'saved_email';
const _kSavedPassword = 'saved_password';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRememberMe) ?? false;
      final email = prefs.getString(_kSavedEmail);
      final password = prefs.getString(_kSavedPassword);
      if (mounted) {
        setState(() {
          _rememberMe = remember;
          if (email != null) _emailController.text = email;
          if (remember && password != null) _passwordController.text = password;
        });
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_kRememberMe, true);
      await prefs.setString(_kSavedEmail, _emailController.text.trim());
      await prefs.setString(_kSavedPassword, _passwordController.text);
    } else {
      await prefs.setBool(_kRememberMe, false);
      await prefs.remove(_kSavedEmail);
      await prefs.remove(_kSavedPassword);
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _saveCredentials();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Giriş Başarılı! Yönlendiriliyorsunuz...'),
            backgroundColor: AppTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AppShell()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.message}'), backgroundColor: AppTheme.softRed, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Beklenmedik bir hata oluştu'), backgroundColor: AppTheme.softRed, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kayıt Başarılı! Giriş yapabilirsiniz.'),
            backgroundColor: AppTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt Hatası: ${e.message}'), backgroundColor: AppTheme.softRed, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Finansal arka plan: gradient + grafik hissi
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.navyBlue,
                  AppTheme.darkSlate,
                  AppTheme.darkSlate.withValues(alpha: 0.9),
                  AppTheme.emeraldGreen.withValues(alpha: 0.2),
                ],
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),
          CustomPaint(
            painter: _FinanceGridPainter(),
            size: Size.infinite,
          ),
          // Hafif bulanıklık üzerinde form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLogo(size: 56, forDarkBackground: true),
                        const SizedBox(height: 16),
                        Text(
                          'Giriş / Kayıt',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                          ),
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                fillColor: WidgetStateProperty.resolveWith((_) => Colors.transparent),
                                checkColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _rememberMe = !_rememberMe),
                              child: Text(
                                'Beni hatırla',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        if (_isLoading)
                          const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: Colors.white70)))
                        else
                          Column(
                            children: [
                              FilledButton(
                                onPressed: _signIn,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.emeraldGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                child: const Text('Giriş Yap'),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _signUp,
                                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                                child: const Text('Kayıt Ol'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grafik/ızgara hissi veren hafif çizgiler
class _FinanceGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    // Birkaç "grafik çizgisi" eğrisi
    final curvePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.5, size.width * 0.5, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.75, size.width, size.height * 0.4);
    canvas.drawPath(path, curvePaint);
    final path2 = Path();
    path2.moveTo(0, size.height * 0.85);
    path2.quadraticBezierTo(size.width * 0.4, size.height * 0.6, size.width * 0.8, size.height * 0.9);
    path2.lineTo(size.width, size.height * 0.75);
    canvas.drawPath(path2, curvePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
