import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'logo_service.dart';
import 'performans_hesaplama_info_page.dart';
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
      if (mounted) {
        setState(() {
          _portfoyler = list;
          // Eğer seçili portföy yoksa veya listede değilse (ve liste boş değilse) ilkini seç
          if (_seciliPortfoyId == null || !list.any((p) => p.id == _seciliPortfoyId)) {
            if (list.isNotEmpty) {
              _seciliPortfoyId = list.first.id;
              _hesapla(); // İlk portföy seçilince tekrar hesapla
            }
          }
        });
      }
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
    if (_seciliPortfoyId == null) {
      if (mounted) {
        setState(() {
          _baslangicDeger = 0;
          _bitisDeger = 0;
        });
      }
      return;
    }

    final baslangicAdetlerDetayli = await TimeTunnelService.portfoyAdetleriHesaplaDetayli(
      _baslangicTarihi,
      portfolioId: _seciliPortfoyId,
    );
    final bitisAdetlerDetayli = await TimeTunnelService.portfoyAdetleriHesaplaDetayli(
      _bitisTarihi,
      portfolioId: _seciliPortfoyId,
    );
    final islemler = await SupabasePortfolioService.islemleriYukle(
      portfolioId: _seciliPortfoyId,
      startDate: _baslangicTarihi,
      endDate: _bitisTarihi,
    );

    final baslangicGun = DateTime(_baslangicTarihi.year, _baslangicTarihi.month, _baslangicTarihi.day);
    final bitisGun = DateTime(_bitisTarihi.year, _bitisTarihi.month, _bitisTarihi.day);
    final aralikIslemleri = islemler.where((t) {
      final tGun = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      return tGun.isAfter(baslangicGun) && !tGun.isAfter(bitisGun);
    }).toList();

    final islemSembolleri = aralikIslemleri.map((e) => e.symbol).toSet();
    final semboller = {...baslangicAdetlerDetayli.keys, ...bitisAdetlerDetayli.keys, ...islemSembolleri}.toList();

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
    final islemlerBySymbol = <String, List<TransactionRow>>{};
    for (final t in aralikIslemleri) {
      (islemlerBySymbol[t.symbol] ??= []).add(t);
    }

    double baslangicToplam = 0;
    double cepToplam = 0;
    final liste = <_HissePerformansi>[];

    for (final sym in semboller) {
      final basAdet = baslangicAdetlerDetayli[sym]?[_seciliPortfoyId] ?? 0;
      final bitAdet = bitisAdetlerDetayli[sym]?[_seciliPortfoyId] ?? 0;
      final basFiyat = baslangicFiyatlar[sym];
      final bitFiyat = bitisFiyatlar[sym];
      final basDeger = (basAdet > 0 && basFiyat != null ? basAdet * basFiyat : 0).toDouble();
      final bitDeger = (bitAdet > 0 && bitFiyat != null ? bitAdet * bitFiyat : 0).toDouble();
      final symIslemler = (islemlerBySymbol[sym] ?? [])..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      baslangicToplam += basDeger;
      double splitEklenenAdet = 0;
      for (final t in symIslemler) {
        if (t.transactionType == 'split') splitEklenenAdet += (t.quantity ?? 0);
      }
      final splitOrani = basAdet > 0 ? ((basAdet + splitEklenenAdet) / basAdet) : null;
      final baslangicReelFiyat = (splitOrani != null && splitOrani > 0 && basFiyat != null) ? basFiyat * splitOrani : basFiyat;

      double cepEtki = -basDeger + bitDeger;
      final detaylar = <_HareketDetayi>[];
      for (final t in symIslemler) {
        final komisyon = t.commission ?? 0;
        final qty = t.quantity ?? 0;
        final brut = qty * t.price;
        if (t.transactionType == 'sell') {
          final net = brut - komisyon;
          cepEtki += net;
          detaylar.add(_HareketDetayi(
            tip: 'Satış',
            aciklama: '${qty.toStringAsFixed(0)} adet × ${_formatTutar(t.price)} ₺',
            etki: net,
            tarih: t.createdAt,
          ));
        } else if (t.transactionType == 'buy') {
          final net = brut + komisyon;
          cepEtki -= net;
          detaylar.add(_HareketDetayi(
            tip: 'Alım',
            aciklama: '${qty.toStringAsFixed(0)} adet × ${_formatTutar(t.price)} ₺',
            etki: -net,
            tarih: t.createdAt,
          ));
        } else if (t.transactionType == 'split') {
          final net = brut + komisyon;
          cepEtki -= net;
          detaylar.add(_HareketDetayi(
            tip: 'Bölünme',
            aciklama: '${qty.toStringAsFixed(0)} adet × ${_formatTutar(t.price)} ₺',
            etki: -net,
            tarih: t.createdAt,
          ));
        } else if (t.transactionType == 'dividend') {
          cepEtki += t.price;
          detaylar.add(_HareketDetayi(
            tip: 'Temettü',
            aciklama: 'Nakit temettü',
            etki: t.price,
            tarih: t.createdAt,
          ));
        }
      }

      final sadeceIslemVar = basAdet <= 0 && bitAdet <= 0 && symIslemler.isNotEmpty;
      if (basAdet > 0 || bitAdet > 0 || symIslemler.isNotEmpty) {
        final baz = basDeger > 0 ? basDeger : null;
        final degisimYuzde = baz != null && baz > 0 ? (cepEtki / baz) * 100 : null;
        cepToplam += cepEtki;

        liste.add(_HissePerformansi(
          symbol: sym,
          portfolioId: _seciliPortfoyId!,
          baslangicDeger: basDeger,
          bitisDeger: bitDeger,
          baslangicAdet: basAdet,
          bitisAdet: bitAdet,
          baslangicFiyat: baslangicReelFiyat,
          bitisFiyat: bitFiyat,
          cepEtki: cepEtki,
          degisimYuzde: degisimYuzde,
          detaylar: detaylar,
          sadeceIslemVar: sadeceIslemVar,
        ));
      }
    }

    final normalizeBitisDegeri = baslangicToplam + cepToplam;
    liste.sort((a, b) {
      if (a.sadeceIslemVar != b.sadeceIslemVar) return a.sadeceIslemVar ? 1 : -1;
      return b.cepEtki.abs().compareTo(a.cepEtki.abs());
    });

    if (mounted) {
      setState(() {
        _baslangicDeger = baslangicToplam;
        _bitisDeger = normalizeBitisDegeri;
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PerformansHesaplamaInfoPage()),
                      );
                    },
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('Hesaplama yöntemi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navyBlue,
                      side: AppTheme.ghostBorderSide(AppTheme.primaryIndigo, 0.15),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
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
            items: _portfoyler.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                        if (p.isShared) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                          if (p.isSharedWithMe && p.ownerEmailHint != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(@${p.ownerEmailHint})',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ],
                      ],
                    ),
                  )).toList(),
            onChanged: (v) {
              setState(() => _seciliPortfoyId = v);
              _hesapla();
            },
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
          const SizedBox(height: 24),
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
    final p = _portfoyler.where((x) => x.id == h.portfolioId).firstOrNull;
    final portfoyAdi = p?.name ?? (h.portfolioId == 'ana_portfoy' ? 'Ana Portföy' : 'Bilinmeyen');
    final isShared = p?.isShared ?? false;
    final ownerHint = p?.ownerEmailHint;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: (h.sadeceIslemVar
              ? AppTheme.cardDecoration(context).copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2630)
                      : const Color(0xFFFFF6E6),
                )
              : AppTheme.cardDecoration(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StockLogo(symbol: h.symbol, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(LogoService.symbolForDisplay(h.symbol), style: AppTheme.symbol(context)),
                    Text(
                      'Adet: ${h.baslangicAdet.toStringAsFixed(2)} → ${h.bitisAdet.toStringAsFixed(2)}',
                      style: AppTheme.bodySmall(context),
                    ),
                    Text(
                      'Fiyat: ${h.baslangicFiyat != null ? "${_formatTutar(h.baslangicFiyat!)} ₺" : "-"} → ${h.bitisFiyat != null ? "${_formatTutar(h.bitisFiyat!)} ₺" : "-"}',
                      style: AppTheme.bodySmall(context),
                    ),
                    Text(
                      'Cep etkisi: ${h.cepEtki >= 0 ? '+' : ''}${_formatTutar(h.cepEtki)} ₺',
                      style: AppTheme.bodySmall(context),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${h.cepEtki >= 0 ? '+' : ''}${_formatTutar(h.cepEtki)} ₺',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: h.cepEtki >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed,
                    ),
                  ),
                  if (h.degisimYuzde != null)
                    Text(
                      '${h.degisimYuzde! >= 0 ? '+' : ''}${h.degisimYuzde!.toStringAsFixed(2)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: h.degisimYuzde! >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (h.detaylar.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...h.detaylar.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${d.tip}: ${d.aciklama} (${DateFormat('dd.MM.yyyy', 'tr_TR').format(d.tarih)})',
                          style: AppTheme.bodySmall(context),
                        ),
                      ),
                      Text(
                        '${d.etki >= 0 ? '+' : ''}${_formatTutar(d.etki)} ₺',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: d.etki >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (_seciliPortfoyId == null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 52), // Logo + spacing
                if (isShared) ...[
                  Icon(Icons.people_outline, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                ],
                Text(
                  portfoyAdi,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                if (isShared && ownerHint != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(@$ownerHint)',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSatisKarti(TransactionRow t) {
    final kar = t.satisKari ?? 0;
    final yuzde = t.satisKarYuzde;
    final karda = kar >= 0;

    final p = _portfoyler.where((x) => x.id == t.portfolioId).firstOrNull;
    final portfoyAdi = p?.name ?? (t.portfolioId == null ? 'Ana Portföy' : 'Bilinmeyen');
    final isShared = p?.isShared ?? false;
    final ownerHint = p?.ownerEmailHint;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          if (_seciliPortfoyId == null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 48), // Logo + spacing
                if (isShared) ...[
                  Icon(Icons.people_outline, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                ],
                Text(
                  portfoyAdi,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                if (isShared && ownerHint != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(@$ownerHint)',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HissePerformansi {
  final String symbol;
  final String portfolioId;
  final double baslangicDeger;
  final double bitisDeger;
  final double baslangicAdet;
  final double bitisAdet;
  final double? baslangicFiyat;
  final double? bitisFiyat;
  final double cepEtki;
  final double? degisimYuzde;
  final List<_HareketDetayi> detaylar;
  final bool sadeceIslemVar;

  _HissePerformansi({
    required this.symbol,
    required this.portfolioId,
    required this.baslangicDeger,
    required this.bitisDeger,
    required this.baslangicAdet,
    required this.bitisAdet,
    required this.baslangicFiyat,
    required this.bitisFiyat,
    required this.cepEtki,
    this.degisimYuzde,
    this.detaylar = const [],
    this.sadeceIslemVar = false,
  });
}

class _HareketDetayi {
  final String tip;
  final String aciklama;
  final double etki;
  final DateTime tarih;

  _HareketDetayi({
    required this.tip,
    required this.aciklama,
    required this.etki,
    required this.tarih,
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
