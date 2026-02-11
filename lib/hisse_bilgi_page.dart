import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'logo_service.dart';
import 'yahoo_finance_service.dart';

/// Hisse ile ilgili güncel finansal verileri gösteren sayfa.
class HisseBilgiPage extends StatefulWidget {
  const HisseBilgiPage({super.key, required this.symbol, required this.name});

  final String symbol;
  final String name;

  @override
  State<HisseBilgiPage> createState() => _HisseBilgiPageState();
}

class _HisseBilgiPageState extends State<HisseBilgiPage> {
  HisseDetayliBilgi? _bilgi;
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      var bilgi = await YahooFinanceService.hisseDetayliBilgiAl(widget.symbol);
      if (bilgi == null) {
        final temel = await YahooFinanceService.hisseAra(widget.symbol);
        bilgi = HisseDetayliBilgi(
          sembol: temel.sembol,
          tamAd: temel.tamAd,
          sonFiyat: temel.fiyat,
          paraBirimi: temel.paraBirimi,
        );
      }
      if (mounted) {
        setState(() {
          _bilgi = bilgi;
          _yukleniyor = false;
        });
      }
    } on YahooFinanceHata catch (e) {
      if (mounted) {
        setState(() {
          _hata = e.mesaj;
          _yukleniyor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = 'Veri alınamadı.';
          _yukleniyor = false;
        });
      }
    }
  }

  String _formatSayi(double? v, {int ondalik = 2}) {
    if (v == null) return '—';
    return NumberFormat('#,##0.##', 'tr_TR').format(v);
  }

  String _formatBuyukSayi(double? v) {
    if (v == null) return '—';
    if (v >= 1e12) return '${(v / 1e12).toStringAsFixed(2)} T';
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)} B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)} M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(2)} K';
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey(context),
      appBar: AppBar(
        title: Text(
          '${LogoService.symbolForDisplay(widget.symbol)} — Finansal Bilgi',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: const [],
      ),
      body: _yukleniyor
          ? Center(child: CircularProgressIndicator(color: AppTheme.navyBlue))
          : _hata != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 48, color: AppTheme.softRed),
                        const SizedBox(height: 16),
                        Text(
                          _hata!,
                          textAlign: TextAlign.center,
                          style: AppTheme.body(context),
                        ),
                      ],
                    ),
                  ),
                )
              : _bilgi == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _BilgiKart(
                              baslik: _bilgi!.tamAd,
                              altBaslik: 'Sembol: ${LogoService.symbolForDisplay(_bilgi!.sembol)}',
                            ),
                            const SizedBox(height: 12),
                            _BilgiKart(
                              baslik: 'Son Fiyat',
                              deger: '${_formatSayi(_bilgi!.sonFiyat)} ${AppTheme.currencyDisplay(_bilgi!.paraBirimi)}',
                              buyukDeger: true,
                            ),
                            const SizedBox(height: 12),
                            _BilgiKart(
                              baslik: 'Önceki Kapanış',
                              deger: '${_formatSayi(_bilgi!.oncekiKapanis)} ${AppTheme.currencyDisplay(_bilgi!.paraBirimi)}',
                            ),
                            const SizedBox(height: 12),
                            _BilgiKart(
                              baslik: 'Günlük En Yüksek / En Düşük',
                              deger: '${_formatSayi(_bilgi!.gunEnYuksek)} / ${_formatSayi(_bilgi!.gunEnDusuk)} ${AppTheme.currencyDisplay(_bilgi!.paraBirimi)}',
                            ),
                            const SizedBox(height: 12),
                            _BilgiKart(
                              baslik: '52 Hafta En Yüksek / En Düşük',
                              deger: '${_formatSayi(_bilgi!.hafta52EnYuksek)} / ${_formatSayi(_bilgi!.hafta52EnDusuk)} ${AppTheme.currencyDisplay(_bilgi!.paraBirimi)}',
                            ),
                            const SizedBox(height: 12),
                            _BilgiKart(
                              baslik: 'Piyasa Değeri (Pazar Cap)',
                              deger: '${_formatBuyukSayi(_bilgi!.piyasaDegeri)} ${AppTheme.currencyDisplay(_bilgi!.paraBirimi)}',
                            ),
                            const SizedBox(height: 12),
                            _BilgiKart(
                              baslik: 'F/K (P/E) Oranı',
                              deger: _formatSayi(_bilgi!.fK, ondalik: 2),
                            ),
                            const SizedBox(height: 12),
                            _BilgiKart(
                              baslik: 'İleri F/K (Forward P/E)',
                              deger: _formatSayi(_bilgi!.ileriFK, ondalik: 2),
                            ),
                            const SizedBox(height: 12),
                            _BilgiKart(
                              baslik: 'İşlem Hacmi',
                              deger: _formatBuyukSayi(_bilgi!.hacim),
                            ),
                          ],
                        ),
                      ),
    );
  }
}

class _BilgiKart extends StatelessWidget {
  final String baslik;
  final String? altBaslik;
  final String? deger;
  final bool buyukDeger;

  const _BilgiKart({
    required this.baslik,
    this.altBaslik,
    this.deger,
    this.buyukDeger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: AppTheme.bodySmall(context),
          ),
          if (altBaslik != null) ...[
            const SizedBox(height: 4),
            Text(
              altBaslik!,
              style: AppTheme.body(context),
            ),
          ],
          if (deger != null) ...[
            const SizedBox(height: 8),
            Text(
              deger!,
              style: (buyukDeger ? AppTheme.h1(context) : AppTheme.price(context)).copyWith(
                fontSize: buyukDeger ? 22 : 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
