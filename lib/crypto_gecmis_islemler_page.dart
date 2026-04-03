import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'crypto_theme.dart';
import 'widgets/crypto_glass_app_bar.dart';
import 'supabase_crypto_service.dart';
import 'widgets/crypto_logo.dart';

/// Kripto geçmiş işlemler sayfası
class CryptoGecmisIslemlerPage extends StatefulWidget {
  const CryptoGecmisIslemlerPage({super.key});

  @override
  State<CryptoGecmisIslemlerPage> createState() => _CryptoGecmisIslemlerPageState();
}

class _CryptoGecmisIslemlerPageState extends State<CryptoGecmisIslemlerPage> {
  List<CryptoTransactionRow> _islemler = [];
  List<CryptoPortfolio> _portfoyler = [];
  String? _seciliPortfoyId;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final portfoyler = await SupabaseCryptoService.portfoyleriYukle();
      final islemler = await SupabaseCryptoService.islemleriYukle(
        portfolioId: _seciliPortfoyId,
        startDate: DateTime.now().subtract(const Duration(days: 90)),
        endDate: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _portfoyler = portfoyler;
          _islemler = islemler;
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  String _displaySymbol(String sym) =>
      sym.toUpperCase().endsWith('USDT') ? sym.substring(0, sym.length - 4) : sym;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CryptoTheme.backgroundGrey(context),
      appBar: const CryptoGlassAppBar(title: 'Kripto Geçmiş'),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: CryptoTheme.cryptoAmber))
          : RefreshIndicator(
              onRefresh: _yukle,
              color: CryptoTheme.cryptoAmber,
              child: CustomScrollView(
                slivers: [
                  if (_portfoyler.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: DropdownButtonFormField<String>(
                          initialValue: _seciliPortfoyId,
                          decoration: InputDecoration(
                            labelText: 'Portföy',
                            filled: true,
                            fillColor: CryptoTheme.cardColor(context),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          dropdownColor: CryptoTheme.cardColor(context),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tüm portföyler')),
                            ..._portfoyler.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                          ],
                          onChanged: (v) {
                            setState(() => _seciliPortfoyId = v);
                            _yukle();
                          },
                        ),
                      ),
                    ),
                  if (_islemler.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: CryptoTheme.textSecondaryFor(context)),
                          const SizedBox(height: 16),
                          Text('Henüz kripto işlemi yok', style: GoogleFonts.inter(color: CryptoTheme.textSecondaryFor(context))),
                        ],
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final t = _islemler[i];
                          final isAlim = t.type == 'buy';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Card(
                              margin: EdgeInsets.zero,
                              color: CryptoTheme.cardColor(context),
                              child: ListTile(
                                leading: CryptoLogo(symbol: t.symbol, size: 40),
                                title: Text(
                                  '${_displaySymbol(t.symbol)} — ${isAlim ? 'Alım' : 'Satış'}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: CryptoTheme.textPrimaryFor(context)),
                                ),
                                subtitle: Text(
                                  DateFormat('dd.MM.yyyy').format(t.createdAt),
                                  style: TextStyle(fontSize: 12, color: CryptoTheme.textSecondaryFor(context)),
                                ),
                                trailing: Text(
                                  '\$${NumberFormat('#,##0.##').format(t.toplamTutar)}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: isAlim ? CryptoTheme.positiveChange : CryptoTheme.accentCyan,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _islemler.length,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
