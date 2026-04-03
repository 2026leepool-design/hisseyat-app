import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_shell.dart';
import 'widgets/app_logo.dart';

const _kRememberMe = 'remember_me';
const _kSavedEmail = 'saved_email';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();

  // Controller'lar
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // Kayıt için
  
  // Anahtarlar
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Durum Değişkenleri
  bool _isLoginTab = true; // true: Giriş, false: Kayıt
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _kvkkAccepted = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    
    // Geçiş animasyonları için
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- YARDIMCI METODLAR ---

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRememberMe) ?? false;

      // Try reading from secure storage first
      String? email = await _storage.read(key: _kSavedEmail);

      // If not found in secure storage, check SharedPreferences (migration)
      if (email == null) {
        email = prefs.getString(_kSavedEmail);
        if (email != null) {
          // Migrate to secure storage
          await _storage.write(key: _kSavedEmail, value: email);
          // Remove from insecure SharedPreferences
          await prefs.remove(_kSavedEmail);
        }
      }

      if (mounted) {
        setState(() {
          _rememberMe = remember;
          if (remember && email != null) _emailController.text = email;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_kRememberMe, true);
      await _storage.write(key: _kSavedEmail, value: _emailController.text.trim());
      // Ensure it's not in SharedPreferences anymore
      await prefs.remove(_kSavedEmail);
    } else {
      await prefs.setBool(_kRememberMe, false);
      await _storage.delete(key: _kSavedEmail);
      await prefs.remove(_kSavedEmail);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    // İngilizce hataları Türkçe'ye çevir
    String displayMsg = message;
    if (message.contains('Invalid login credentials')) {
      displayMsg = 'E-posta veya şifre hatalı.';
    } else if (message.contains('User already registered')) {
      displayMsg = 'Bu e-posta adresi zaten kayıtlı.';
    } else if (message.contains('Password should be at least')) {
      displayMsg = 'Şifre en az 6 karakter olmalıdır.';
    } else if (message.contains('Token has expired')) {
      displayMsg = 'Doğrulama kodunun süresi dolmuş.';
    } else if (message.contains('Error sending recovery email')) {
      displayMsg = 'E-posta gönderilemedi. Lütfen e-posta ayarlarınızı kontrol edin veya daha sonra tekrar deneyin.';
    } else if (message.contains('unexpected_failure')) {
      displayMsg = 'Beklenmedik bir hata oluştu. Lütfen tekrar deneyin.';
    } else if (message.contains('sign_in_failed')) {
      displayMsg = 'Google ile giriş yapılamadı. (SHA-1 ayarı eksik olabilir)';
    } else if (message.contains('network_error')) {
      displayMsg = 'İnternet bağlantınızı kontrol edin.';
    } else if (message.contains('upstream request timeout')) {
      displayMsg = 'Sunucuya ulaşılamadı (Zaman aşımı). Lütfen internetinizi kontrol edin ve tekrar deneyin.';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayMsg),
        backgroundColor: AppTheme.softRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.emeraldGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- AUTH İŞLEMLERİ ---

  Future<void> _signIn() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      await _saveCredentials();
      
      if (mounted) {
        _showSuccess('Giriş Başarılı! Yönlendiriliyorsunuz...');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AppShell()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Beklenmedik bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_registerFormKey.currentState!.validate()) return;
    if (!_kvkkAccepted) {
      _showError('Lütfen Kullanıcı Sözleşmesi ve KVKK metnini onaylayın.');
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    
    try {
      await supabase.auth.signUp(
        email: email,
        password: _passwordController.text.trim(),
        data: {'full_name': _nameController.text.trim()},
      );

      if (mounted) {
        _showSuccess('Kayıt oluşturuldu. Lütfen e-postanızı doğrulayın.');
        // OTP Ekranını Aç
        _showOtpDialog(email);
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Kayıt sırasında hata oluştu.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
      );
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) throw 'Giriş iptal edildi.';

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'Google kimlik bilgileri alınamadı.';
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (mounted) {
        _showSuccess('Google ile giriş başarılı!');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AppShell()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('iptal')) _showError(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Şifre sıfırlama bağlantısı için geçerli bir e-posta girin.');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      _showSuccess('Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.');
    } on AuthException catch (e) {
      print('Auth Hata Kodu: ${e.code}');
      print('Auth Hata Mesajı: ${e.message}');
      _showError(e.message);
    } catch (e) {
      print('Beklenmedik Hata: $e');
      _showError('Hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- OTP DIALOG ---

  void _showOtpDialog(String email) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('E-posta Doğrulama'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$email adresine gönderilen 6 haneli kodu giriniz.',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: '******',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: isVerifying ? null : () async {
                  final token = otpController.text.trim();
                  if (token.length != 6) return;

                  setDialogState(() => isVerifying = true);
                  try {
                    await supabase.auth.verifyOTP(
                      token: token,
                      type: OtpType.signup,
                      email: email,
                    );
                    if (mounted) {
                      Navigator.pop(context); // Dialogu kapat
                      _showSuccess('Doğrulama Başarılı! Giriş yapılıyor...');
                      // Ana sayfaya git
                      Navigator.of(this.context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const AppShell()),
                        (route) => false,
                      );
                    }
                  } on AuthException catch (e) {
                    debugPrint('OTP Hatası: ${e.message}');
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Hata: ${e.message}'), backgroundColor: AppTheme.softRed),
                    );
                  } finally {
                    setDialogState(() => isVerifying = false);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isVerifying 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Doğrula'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // BEYAZ ARKA PLAN (İSTEK ÜZERİNE)
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo - Beyaz zemin için
                // forDarkBackground: false -> Logo renkli veya koyu renkte görünmeli
                const AppLogo(size: 80, forDarkBackground: false),
                const SizedBox(height: 48),

                // Tab Selector
                _buildTabSelector(),
                const SizedBox(height: 32),

                // Animated Form Area
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => 
                    FadeTransition(opacity: animation, child: child),
                  child: _isLoginTab ? _buildLoginForm() : _buildRegisterForm(),
                ),

                const SizedBox(height: 32),
                Text(
                  'veya',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 24),
                
                _buildGoogleButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isLoginTab = true;
                _animationController.reset();
                _animationController.forward();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isLoginTab ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isLoginTab ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Text(
                  'Giriş Yap',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: _isLoginTab ? AppTheme.navyBlue : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isLoginTab = false;
                _animationController.reset();
                _animationController.forward();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isLoginTab ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !_isLoginTab ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Text(
                  'Kayıt Ol',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: !_isLoginTab ? AppTheme.navyBlue : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.black87),
            decoration: _inputDecoration('E-posta', Icons.email_outlined),
            validator: (value) {
              if (value == null || value.isEmpty) return 'E-posta gerekli';
              if (!value.contains('@')) return 'Geçersiz e-posta adresi';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.black87),
            decoration: _inputDecoration('Şifre', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: Colors.grey.shade600),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'Şifre gerekli' : null,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      activeColor: AppTheme.smokyJade,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Beni hatırla', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
                ],
              ),
              TextButton(
                onPressed: _resetPassword,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('Şifremi Unuttum?', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.smokyJade, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(text: 'Giriş Yap', onPressed: _signIn),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('register'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.black87),
            decoration: _inputDecoration('Ad Soyad', Icons.person_outline),
            validator: (value) => (value == null || value.length < 2) ? 'Ad soyad en az 2 karakter olmalı' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.black87),
            decoration: _inputDecoration('E-posta', Icons.email_outlined),
            validator: (value) {
              if (value == null || value.isEmpty) return 'E-posta gerekli';
              if (!value.contains('@')) return 'Geçersiz e-posta';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.black87),
            decoration: _inputDecoration('Şifre', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: Colors.grey.shade600),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) => (value == null || value.length < 6) ? 'Şifre en az 6 karakter olmalı' : null,
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _kvkkAccepted,
            activeColor: AppTheme.smokyJade,
            onChanged: (v) => setState(() => _kvkkAccepted = v ?? false),
            title: RichText(
              text: TextSpan(
                text: 'Kullanıcı Sözleşmesi',
                style: GoogleFonts.inter(color: AppTheme.smokyJade, fontWeight: FontWeight.bold, fontSize: 12),
                children: [
                  TextSpan(text: ' ve ', style: GoogleFonts.inter(color: Colors.grey.shade700, fontWeight: FontWeight.normal)),
                  TextSpan(text: 'KVKK metnini', style: GoogleFonts.inter(color: AppTheme.smokyJade, fontWeight: FontWeight.bold)),
                  TextSpan(text: ' okudum, onaylıyorum.', style: GoogleFonts.inter(color: Colors.grey.shade700, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(text: 'Kayıt Ol', onPressed: _signUp),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({required String text, required VoidCallback onPressed}) {
    return FilledButton(
      onPressed: _isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.smokyJade,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        shadowColor: AppTheme.smokyJade.withOpacity(0.4),
      ),
      child: _isLoading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _googleSignIn,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/48px-Google_%22G%22_logo.svg.png',
            height: 22,
            width: 22,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Text(
            'Google ile devam et',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.onSurface.withValues(alpha: 0.55), fontSize: 14),
      floatingLabelStyle: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: AppTheme.onSurface.withValues(alpha: 0.45), size: 22),
      filled: true,
      fillColor: AppTheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        borderSide: AppTheme.ghostBorderSide(AppTheme.onSurface, 0.15),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        borderSide: AppTheme.ghostBorderSide(AppTheme.primaryIndigo, 0.45),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        borderSide: AppTheme.ghostBorderSide(AppTheme.softRed, 0.4),
      ),
    );
  }
}
