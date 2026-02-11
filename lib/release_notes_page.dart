import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_shell.dart';
import 'login_page.dart';

const _keyDontShowReleaseNotes = 'release_notes_dont_show_v4_1';

Future<bool> shouldShowReleaseNotes() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_keyDontShowReleaseNotes) ?? false);
}

Future<void> setDontShowReleaseNotes(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_keyDontShowReleaseNotes, value);
}

class ReleaseNotesPage extends StatefulWidget {
  const ReleaseNotesPage({super.key});

  @override
  State<ReleaseNotesPage> createState() => _ReleaseNotesPageState();
}

class _ReleaseNotesPageState extends State<ReleaseNotesPage> {
  bool _dontShowAgain = false;

  void _devam() async {
    if (_dontShowAgain) {
      await setDontShowReleaseNotes(true);
    }
    if (!mounted) return;
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => isLoggedIn ? const AppShell() : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Yenilikler',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'v4.1 — Son güncellemede neler değişti?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection('Ekran Düzeni & Taşma Düzeltmeleri', [
                        '• Performans sayfasında tarih aralığı alanları taşma düzeltildi',
                        '• Alt navigasyon (Ana Sayfa, Geçmiş, Zaman Tüneli, Performans, Portföyler) dar ekranda taşmıyor',
                        '• Uygulama açılışı her zaman dikey (portrait); sadece Geçmiş İşlemler ekranı yatay (landscape)',
                      ]),
                      _buildSection('Portföy Bilgisi', [
                        '• Hisse kartlarında hangi portföye ait olduğu, hisse kodunun hemen üstünde küçük fontla gösteriliyor',
                        '• Hisse detay sayfasında da aynı portföy adı bilgisi eklendi',
                      ]),
                      _buildSection('Fiyat Grafiği (Hisse Bilgi Ekranı)', [
                        '• Grafik üstte, finansal özet altta; sayfa aşağı kaydırılınca grafik de birlikte kayıyor',
                        '• Tooltip: Tarih (yyyy-MM-dd), Açılış, Kapanış, Düşük, Yüksek, Değişim % formatında gösteriliyor',
                      ]),
                      _buildSection('Alarmlar', [
                        '• Alarm kurma sırasında oluşan hata giderildi',
                        '• Alarm kurarken bildirim izni isteniyor; gerekli yetkiler uygulama açılışında ve alarm kurulurken talep ediliyor',
                        '• Uygulama kapalıyken bile 15 dakikada bir fiyat kontrolü yapılıyor; tetiklenen alarmlar bildirimle gösteriliyor',
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _dontShowAgain,
                onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
                title: Text(
                  'Bir daha gösterme',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkSlate),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.navyBlue,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _devam,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Devam',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.darkSlate,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
