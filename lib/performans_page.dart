import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'logo_service.dart';
import 'services/historical_price_service.dart';
import 'services/time_tunnel_service.dart';
import 'stock_logo.dart';
import 'supabase_portfolio_service.dart';

/// Performans sayfası: Portföy performansı veya Satış performansı
class PerformansPage extends StatefulWidget {
  const PerformansPage({super.key});

  @override
  State<PerformansPage> createState() => _PerformansPageState();
}

class _PerformansPageState extends State<PerformansPage> {
  int _seciliMod = 0; // 0: Portföy, 1: Satış
  List<Portfolio> _portfoyler = [];
  String? _seciliPortfoyId;
  DateTime _baslangicTarihi = DateTime.now().subtract(const Duration(days: 90));
  DateTime _bitisTarihi = DateTime.now();
  bool _yukleniyor = false;
  String? _hata;

  // Portföy performansı sonuçları
  double? _baslangicDeger;
  double? _bitisDeger;
  List<_HissePerformansi> _hissePerformanslari = [];

  // Satış performansı sonuçları
  List<TransactionRow> _satisIslemleri = [];

  @override
  void initState() {
    super.initState();
    _portfoyleriYukle();
  }

  Future<void> _portfoyleriYukle() async {
    try {
      final list = await SupabasePortfolioService.portfoyleriYukle();
      if (mounted) setState(() => _portfoyler = list);
    } catch (_) {}
  }

  Future<void> _hesapla() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
      _baslangicDeger = null;
      _bitisDeger = null;
      _hissePerformanslari = [];
      _satisIslemleri = [];
    });

    try {
      if (_seciliMod == 0) {
        await _portfoyPerformansiHesapla();
      } else {
        await _satisPerformansiHesapla();
      }
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString().split('\n').first);
    }

    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _portfoyPerformansiHesapla() async {
    // Başlangıç tarihindeki portföy adetleri
    final baslangicAdetler = await TimeTunnelService.portfoyAdetleriHesapla(
      _baslangicTarihi,
      portfolioId: _seciliPortfoyId,
    );
    // Bitiş tarihindeki portföy adetleri
    final bitisAdetler = await TimeTunnelService.portfoyAdetleriHesapla(
      _bitisTarihi,
      portfolioId: _seciliPortfoyId,
    );

    final semboller = {...baslangicAdetler.keys, ...bitisAdetler.keys}.toList();
    if (semboller.isEmpty) {
      if (mounted) {
        setState(() {
          _baslangicDeger = 0;
          _bitisDeger = 0;
        });
      }
      return;
    }

    final baslangicFiyatlar = await HistoricalPriceService.getClosePricesBatched(semboller, _baslangicTarihi);
    final bitisFiyatlar = await HistoricalPriceService.getClosePricesBatched(semboller, _bitisTarihi);

    double baslangicToplam = 0;
    double bitisToplam = 0;
    final liste = <_HissePerformansi>[];

    for (final sym in semboller) {
      final basAdet = baslangicAdetler[sym] ?? 0;
      final bitAdet = bitisAdetler[sym] ?? 0;
      final basFiyat = baslangicFiyatlar[sym];
      final bitFiyat = bitisFiyatlar[sym];

      final basDeger = (basAdet > 0 && basFiyat != null ? basAdet * basFiyat : 0).toDouble();
      final bitDeger = (bitAdet > 0 && bitFiyat != null ? bitAdet * bitFiyat : 0).toDouble();

      baslangicToplam += basDeger;
      bitisToplam += bitDeger;

      if (basAdet > 0 || bitAdet > 0) {
        double? degisimYuzde;
        if (basDeger > 0 && bitDeger > 0) {
          degisimYuzde = ((bitDeger - basDeger) / basDeger) * 100;
        } else if (bitDeger > 0) {
          degisimYuzde = 100;
        } else if (basDeger > 0) {
          degisimYuzde = -100;
        }

        liste.add(_HissePerformansi(
          symbol: sym,
          baslangicDeger: basDeger,
          bitisDeger: bitDeger,
          degisimYuzde: degisimYuzde,
        ));
      }
    }

    liste.sort((a, b) => (b.bitisDeger + b.baslangicDeger).compareTo(a.bitisDeger + a.baslangicDeger));

    if (mounted) {
      setState(() {
        _baslangicDeger = baslangicToplam;
        _bitisDeger = bitisToplam;
        _hissePerformanslari = liste;
      });
    }
  }

  Future<void> _satisPerformansiHesapla() async {
    final islemler = await SupabasePortfolioService.islemleriYukle(
      portfolioId: _seciliPortfoyId,
      startDate: _baslangicTarihi,
      endDate: _bitisTarihi,
    );
    final satislar = islemler.where((t) => t.transactionType == 'sell').toList();
    satislar.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
      setState(() => _satisIslemleri = satislar);
    }
  }

  String _formatTutar(double v) => NumberFormat('#,##0.##', 'tr_TR').format(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey(context),
      appBar: AppBar(
        title: Text('Performans', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mod seçimi
                  _buildModSecimi(),
                  const SizedBox(height: 20),
                  // Portföy seçimi
                  _buildPortfoySecimi(),
                  const SizedBox(height: 20),
                  // Tarih aralığı
                  _buildTarihAraligi(),
                  const SizedBox(height: 20),
                  // Hesapla butonu
                  FilledButton.icon(
                    onPressed: _yukleniyor ? null : _hesapla,
                    icon: _yukleniyor
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.analytics_rounded, size: 20),
                    label: Text(_yukleniyor ? 'Hesaplanıyor...' : 'Hesapla'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_hata != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.cardDecoration(context),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppTheme.softRed, size: 28),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_hata!, style: AppTheme.body(context))),
                        ],
                      ),
                    )
                  else if (_seciliMod == 0 && _baslangicDeger != null) ...[
                    _buildPortfoyOzet(),
                    if (_hissePerformanslari.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Hisse Bazlı Değişim', style: AppTheme.h2(context)),
                      const SizedBox(height: 12),
                      ..._hissePerformanslari.map(_buildHissePerformansKarti),
                    ],
                  ] else if (_seciliMod == 1 && _satisIslemleri.isNotEmpty) ...[
                    Text('Satış İşlemleri (${_satisIslemleri.length})', style: AppTheme.h2(context)),
                    const SizedBox(height: 12),
                    ..._satisIslemleri.map(_buildSatisKarti),
                  ] else if (_seciliMod == 1 && !_yukleniyor && _satisIslemleri.isEmpty && _baslangicDeger == null) ...[
                    if (_portfoyler.isNotEmpty && _seciliPortfoyId != null) ...[
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: AppTheme.cardDecoration(context),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.sell_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'Seçilen aralıkta satış işlemi yok',
                                style: AppTheme.body(context),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildModSecimi() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Performans Tipi', style: AppTheme.h2(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModChip(
                  label: 'Portföy Performansı',
                  secili: _seciliMod == 0,
                  onTap: () => setState(() => _seciliMod = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModChip(
                  label: 'Satış Performansı',
                  secili: _seciliMod == 1,
                  onTap: () => setState(() => _seciliMod = 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortfoySecimi() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Portföy', style: AppTheme.h2(context)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _seciliPortfoyId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text('Tümü'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tümü')),
              ..._portfoyler.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() => _seciliPortfoyId = v),
          ),
        ],
      ),
    );
  }

  Widget _buildTarihAraligi() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tarih Aralığı', style: AppTheme.h2(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _baslangicTarihi,
                      firstDate: DateTime(2000),
                      lastDate: _bitisTarihi,
                    );
                    if (d != null) setState(() => _baslangicTarihi = d);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20, color: AppTheme.navyBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            DateFormat('dd.MM.yyyy', 'tr_TR').format(_baslangicTarihi),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: 18),
              ),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _bitisTarihi,
                      firstDate: _baslangicTarihi,
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _bitisTarihi = d);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20, color: AppTheme.navyBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            DateFormat('dd.MM.yyyy', 'tr_TR').format(_bitisTarihi),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortfoyOzet() {
    final degisim = _bitisDeger! - _baslangicDeger!;
    final degisimYuzde = _baslangicDeger! > 0 ? (degisim / _baslangicDeger!) * 100 : 0.0;
    final karda = degisim >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.bankCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Başlangıç (${DateFormat('dd.MM.yyyy', 'tr_TR').format(_baslangicTarihi)})',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
          ),
          Text(
            '${_formatTutar(_baslangicDeger!)} ₺',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Bitiş (${DateFormat('dd.MM.yyyy', 'tr_TR').format(_bitisTarihi)})',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
          ),
          Text(
            '${_formatTutar(_bitisDeger!)} ₺',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const Divider(height: 24, color: Colors.white24),
          Text(
            '${degisim >= 0 ? '+' : ''}${_formatTutar(degisim)} ₺  (${degisim >= 0 ? '+' : ''}${degisimYuzde.toStringAsFixed(2)}%)',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: karda ? AppTheme.emeraldGreen : AppTheme.softRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHissePerformansKarti(_HissePerformansi h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          StockLogo(symbol: h.symbol, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LogoService.symbolForDisplay(h.symbol), style: AppTheme.symbol(context)),
                Text(
                  '${_formatTutar(h.baslangicDeger)} ₺ → ${_formatTutar(h.bitisDeger)} ₺',
                  style: AppTheme.bodySmall(context),
                ),
              ],
            ),
          ),
          if (h.degisimYuzde != null)
            Text(
              '${h.degisimYuzde! >= 0 ? '+' : ''}${h.degisimYuzde!.toStringAsFixed(2)}%',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: h.degisimYuzde! >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSatisKarti(TransactionRow t) {
    final kar = t.satisKari ?? 0;
    final yuzde = t.satisKarYuzde;
    final karda = kar >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          StockLogo(symbol: t.symbol, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LogoService.symbolForDisplay(t.symbol), style: AppTheme.symbol(context)),
                Text(
                  DateFormat('dd.MM.yyyy', 'tr_TR').format(t.createdAt),
                  style: AppTheme.bodySmall(context),
                ),
                if (t.quantity != null)
                  Text(
                    '${t.quantity!.toStringAsFixed(0)} adet × ${_formatTutar(t.price)} ₺',
                    style: AppTheme.bodySmall(context),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${kar >= 0 ? '+' : ''}${_formatTutar(kar)} ₺',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: karda ? AppTheme.emeraldGreen : AppTheme.softRed,
                ),
              ),
              if (yuzde != null)
                Text(
                  '${yuzde >= 0 ? '+' : ''}${yuzde.toStringAsFixed(2)}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: karda ? AppTheme.emeraldGreen : AppTheme.softRed,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HissePerformansi {
  final String symbol;
  final double baslangicDeger;
  final double bitisDeger;
  final double? degisimYuzde;

  _HissePerformansi({
    required this.symbol,
    required this.baslangicDeger,
    required this.bitisDeger,
    this.degisimYuzde,
  });
}

class _ModChip extends StatelessWidget {
  final String label;
  final bool secili;
  final VoidCallback onTap;

  const _ModChip({required this.label, required this.secili, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: secili ? AppTheme.navyBlue : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: secili ? Colors.white : AppTheme.darkSlate,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
