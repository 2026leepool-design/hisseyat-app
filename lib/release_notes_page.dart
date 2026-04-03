import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_shell.dart';
import 'login_page.dart';

const _keyDontShowReleaseNotes = 'release_notes_dont_show_v5_2';

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
                'v5.2 — Son güncellemede neler değişti?',
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
                      _buildSection('Şirket profili (hisse detay)', [
                        '• Hisse detay sayfasında "Şirket Profili" bölümü yenilendi: Hakkında, Bilgiler, Finansal Özet ve Künye',
                        '• Yahoo Finance: Company Overview (longBusinessSummary), Sektör, Beta, F/K, EPS, Temettü Verimi, Piyasa Değeri artık doğru endpoint (quoteSummary) ile çekiliyor',
                        '• BIST hisseleri için İş Yatırım web sitesinden şirket kartı verileri (Genel Müdür, Kuruluş Tarihi, Web Sitesi, Ödenmiş Sermaye, Fiili Dolaşım vb.) taranıyor',
                        '• Veri yoksa "-" veya "Bilinmiyor" gösteriliyor; uygulama çökmeden devam ediyor',
                      ]),
                      _buildSection('Yahoo Finance servisi', [
                        '• quoteSummary adresi güncellendi: assetProfile, summaryDetail, defaultKeyStatistics, financialData modülleri kullanılıyor',
                        '• Sembol .IS ile gönderiliyor (örn. SNICA.IS); Beta, Piyasa Değeri, F/K, EPS, Temettü için formatlı (.fmt) değerler destekleniyor',
                      ]),
                      _buildSection('Profil arayüzü', [
                        '• En üstte "Hakkında" ile şirket açıklaması; uzunsa "Devamını Oku" ile genişletilebiliyor',
                        '• Bilgiler tablosu: Sektör, Endüstri, Çalışan Sayısı, Web Sitesi (tıklanınca açılıyor)',
                        '• Finansal Özet: Beta, F/K, EPS, Temettü Verimi, Piyasa Değeri',
                        '• Künye: CEO, Kuruluş, Halka Arz Tarihi, Ödenmiş Sermaye, Fiili Dolaşım (İş Yatırım + Yahoo birleşik)',
                      ]),
                      _buildSection('Hata düzeltmeleri', [
                        '• Profil sekmesinde nullable alan erişim hatası giderildi (fiiliDolasimOraniYuzde)',
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
