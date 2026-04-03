import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'crypto_theme.dart';
import 'widgets/crypto_glass_app_bar.dart';
import 'supabase_crypto_service.dart';

/// Kripto performans sayfası – portföy özeti
class CryptoPerformansPage extends StatefulWidget {
  const CryptoPerformansPage({super.key});

  @override
  State<CryptoPerformansPage> createState() => _CryptoPerformansPageState();
}

class _CryptoPerformansPageState extends State<CryptoPerformansPage> {
  List<CryptoPortfolioRow> _liste = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final liste = await SupabaseCryptoService.portfoyYukle();
      if (mounted) {
        setState(() {
        _liste = liste;
        _yukleniyor = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toplamMaliyet = _liste.fold(0.0, (s, r) => s + r.toplamDeger);

    return Scaffold(
      backgroundColor: CryptoTheme.backgroundGrey(context),
      appBar: const CryptoGlassAppBar(title: 'Kripto Performans'),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: CryptoTheme.cryptoAmber))
          : RefreshIndicator(
              onRefresh: _yukle,
              color: CryptoTheme.cryptoAmber,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CryptoTheme.cardColorElevated(context),
                        borderRadius: BorderRadius.circular(CryptoTheme.radius),
                      ),
                      child: Column(
                        children: [
                          Text('Toplam Maliyet', style: GoogleFonts.inter(fontSize: 12, color: CryptoTheme.textSecondaryFor(context))),
                          const SizedBox(height: 8),
                          Text(
                            '\$${NumberFormat('#,##0.##').format(toplamMaliyet)}',
                            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: CryptoTheme.priceAccent),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_liste.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.analytics_outlined, size: 64, color: CryptoTheme.textSecondaryFor(context)),
                            const SizedBox(height: 16),
                            Text('Henüz kripto yok', style: GoogleFonts.inter(color: CryptoTheme.textSecondaryFor(context))),
                          ],
                        ),
                      )
                    else
                      Text(
                        '${_liste.length} varlık',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: CryptoTheme.textPrimaryFor(context)),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
