import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'crypto_theme.dart';
import 'widgets/crypto_glass_app_bar.dart';
import 'services/crypto_service.dart';
import 'supabase_crypto_service.dart';
import 'widgets/crypto_logo.dart';

/// Kripto zaman tüneli – geçmiş tarihteki portföy değeri (Binance klines ile)
class CryptoTimeTunnelScreen extends StatefulWidget {
  const CryptoTimeTunnelScreen({super.key});

  @override
  State<CryptoTimeTunnelScreen> createState() => _CryptoTimeTunnelScreenState();
}

class _CryptoTimeTunnelScreenState extends State<CryptoTimeTunnelScreen> {
  DateTime _seciliTarih = DateTime.now().subtract(const Duration(days: 30));
  Map<String, double> _adetler = {};
  double _toplamUsd = 0;
  bool _yukleniyor = false;
  String? _hata;

  Future<void> _hesapla() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final adetler = await SupabaseCryptoService.portfoyAdetleriHesapla(_seciliTarih);
      final pozitif = <String, double>{};
      for (final e in adetler.entries) {
        final sym = e.key.toUpperCase().endsWith('USDT') ? e.key : '${e.key}USDT';
        pozitif[sym] = e.value;
      }
      double toplam = 0;
      for (final e in pozitif.entries) {
        final fiyat = await CryptoService.getHistoricalPrice(e.key, _seciliTarih);
        if (fiyat != null) toplam += e.value * fiyat;
      }
      if (mounted) {
        setState(() {
          _adetler = pozitif;
          _toplamUsd = toplam;
          _yukleniyor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _hata = e.toString().split('\n').first;
        _yukleniyor = false;
      });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _hesapla();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CryptoTheme.backgroundGrey(context),
      appBar: const CryptoGlassAppBar(title: 'Kripto Zaman Tüneli'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _seciliTarih,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() => _seciliTarih = picked);
                  _hesapla();
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat('dd.MM.yyyy').format(_seciliTarih)),
              style: OutlinedButton.styleFrom(foregroundColor: CryptoTheme.cryptoAmber),
            ),
            const SizedBox(height: 24),
            if (_yukleniyor)
              const Center(child: CircularProgressIndicator(color: CryptoTheme.cryptoAmber))
            else if (_hata != null)
              Text(_hata!, style: TextStyle(color: CryptoTheme.negativeChange))
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CryptoTheme.cardColorElevated(context),
                  borderRadius: BorderRadius.circular(CryptoTheme.radius),
                ),
                child: Column(
                  children: [
                    Text('Portföy Değeri', style: GoogleFonts.inter(fontSize: 12, color: CryptoTheme.textSecondaryFor(context))),
                    const SizedBox(height: 8),
                    Text(
                      '\$${NumberFormat('#,##0.##').format(_toplamUsd)}',
                      style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: CryptoTheme.priceAccent),
                    ),
                    if (_adetler.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ..._adetler.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                CryptoLogo(symbol: e.key, size: 32),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    e.key.replaceAll('USDT', ''),
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: CryptoTheme.textPrimaryFor(context)),
                                  ),
                                ),
                                Text('${e.value.toStringAsFixed(2)} adet', style: TextStyle(color: CryptoTheme.textSecondaryFor(context))),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
