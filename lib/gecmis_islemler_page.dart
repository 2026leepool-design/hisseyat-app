import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'logo_service.dart';
import 'stock_logo.dart';
import 'supabase_portfolio_service.dart';
import 'yahoo_finance_service.dart';

class GecmisIslemlerPage extends StatefulWidget {
  const GecmisIslemlerPage({super.key});

  @override
  State<GecmisIslemlerPage> createState() => _GecmisIslemlerPageState();
}

class _GecmisIslemlerPageState extends State<GecmisIslemlerPage> {
  List<TransactionRow> _islemler = [];
  List<PortfolioRow> _portfoy = [];
  Map<String, HisseBilgisi> _guncelFiyatlar = {};
  bool _yukleniyor = true;
  final Set<String> _acikGruplar = {};
  List<Portfolio> _portfoyler = [];
  String? _seciliPortfoyId; // null = "Tümü"
  String? _seciliHisse; // null = "TÜMÜ"
  DateTime _baslangicTarihi = DateTime.now().subtract(const Duration(days: 90));
  DateTime _bitisTarihi = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Yön (landscape) sadece AppShell'de sekme seçildiğinde ayarlanıyor; burada değiştirme
    _yukle();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final portfoyler = await SupabasePortfolioService.portfoyleriYukle();
      final sonuclar = await Future.wait([
        SupabasePortfolioService.islemleriYukle(
          portfolioId: _seciliPortfoyId,
          startDate: _baslangicTarihi,
          endDate: _bitisTarihi,
        ),
        SupabasePortfolioService.portfoyYukle(portfolioId: _seciliPortfoyId),
      ]);

      setState(() {
        _portfoyler = portfoyler;
        _islemler = sonuclar[0] as List<TransactionRow>;
        _portfoy = sonuclar[1] as List<PortfolioRow>;
      });

      final semboller = _islemler.map((e) => e.symbol).toSet().toList();
      final fiyatMap = <String, HisseBilgisi>{};
      for (final symbol in semboller) {
        try {
          final bilgi = await YahooFinanceService.hisseAra(symbol);
          fiyatMap[symbol] = bilgi;
        } catch (_) {}
      }

      setState(() {
        _guncelFiyatlar = fiyatMap;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _yukleniyor = false;
      });
    }
  }

  Future<void> _tarihAraligiSec() async {
    final picked = await showDialog<({DateTime start, DateTime end})>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => _TarihAraligiDialog(
        baslangic: _baslangicTarihi,
        bitis: _bitisTarihi,
        onSecildi: (start, end) => Navigator.pop(ctx, (start: start, end: end)),
        onIptal: () => Navigator.pop(ctx),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _baslangicTarihi = picked.start;
        _bitisTarihi = picked.end;
      });
      _yukle();
    }
  }

  void _filtreMenusuAc() {
    // Geçersiz dropdown değeri (silinen portföy / filtre sonrası kaybolan hisse) sheet build'ini patlatır.
    setState(() {
      if (_seciliPortfoyId != null &&
          !_portfoyler.any((p) => p.id == _seciliPortfoyId)) {
        _seciliPortfoyId = null;
      }
      if (_seciliHisse != null && !_hisseListesi.contains(_seciliHisse)) {
        _seciliHisse = null;
      }
    });

    // Kök navigator + isScrollControlled + şeffaf arka plan bazı cihaz/yatay modda
    // içeriği 0 yükseklikte veya görünmez bırakabiliyor; sheet sekme Navigator'ında açılır.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 12 + MediaQuery.viewPaddingOf(ctx).bottom,
          ),
          child: Material(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(16),
            elevation: 6,
            shadowColor: AppTheme.onSurface.withValues(alpha: 0.12),
            color: sheetTheme.colorScheme.surfaceContainerLowest,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Filtreler', style: AppTheme.h2(ctx)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _seciliPortfoyId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Portföy',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Tümü')),
                          ..._portfoyler.map((p) {
                            // DropdownMenuItem popup sonsuz genişlikte açılır; Expanded kullanmak
                            // "unbounded width" hatasına yol açar. İsim + ipucu düz Text'e dönüştürülür.
                            final hint = (p.isSharedWithMe && p.ownerEmailHint != null)
                                ? ' (@${p.ownerEmailHint})'
                                : (p.isShared ? ' ↑' : '');
                            return DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(
                                '${p.name}$hint',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _seciliPortfoyId = value;
                            _seciliHisse = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _seciliHisse,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Hisse',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('TÜMÜ')),
                          ..._hisseListesi.map((s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(LogoService.symbolForDisplay(s),
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (value) => setState(() => _seciliHisse = value),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _tarihAraligiSec();
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          '${DateFormat('dd.MM.yyyy', 'tr_TR').format(_baslangicTarihi)} - ${DateFormat('dd.MM.yyyy', 'tr_TR').format(_bitisTarihi)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _yukle();
                        },
                        child: const Text('Uygula'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _portfoydeVar(String symbol) {
    return _portfoy.any((p) => p.symbol == symbol);
  }

  PortfolioRow? _portfoyBul(String symbol) {
    try {
      return _portfoy.firstWhere((p) => p.symbol == symbol);
    } catch (_) {
      return null;
    }
  }

  double? _karZararHesapla(TransactionRow islem) {
    if (islem.transactionType == 'buy' || islem.transactionType == 'split') {
      final portfoy = _portfoyBul(islem.symbol);
      if (portfoy == null) return null;
      final guncelFiyat = _guncelFiyatlar[islem.symbol]?.fiyat;
      if (guncelFiyat == null) return null;
      final guncelDeger = portfoy.totalQuantity * guncelFiyat;
      final maliyetDeger = portfoy.totalQuantity * portfoy.averageCost;
      return guncelDeger - maliyetDeger;
    } else if (islem.transactionType == 'dividend') {
      return islem.price; // Temettü direkt gelir
    } else {
      // Satış: transaction'da kayıtlı satış karı varsa onu kullan
      if (islem.satisKari != null) return islem.satisKari;
      final alimFiyati = _ortalamaAlimFiyati(islem.symbol, islem.createdAt);
      if (alimFiyati == null) return null;
      return (islem.price - alimFiyati) * (islem.quantity ?? 0);
    }
  }

  double? _karZararYuzdeHesapla(TransactionRow islem) {
    if (islem.transactionType == 'buy' || islem.transactionType == 'split') {
      final portfoy = _portfoyBul(islem.symbol);
      if (portfoy == null) return null;
      final guncelFiyat = _guncelFiyatlar[islem.symbol]?.fiyat;
      if (guncelFiyat == null) return null;
      final maliyetDeger = portfoy.totalQuantity * portfoy.averageCost;
      if (maliyetDeger == 0) return null;
      final karZarar = (portfoy.totalQuantity * guncelFiyat) - maliyetDeger;
      return (karZarar / maliyetDeger) * 100;
    } else if (islem.transactionType == 'dividend') {
      return null; // Temettü için yüzde hesaplanmaz
    } else {
      // Satış: transaction'da kayıtlı hisse başı kar % varsa onu kullan
      if (islem.satisKarYuzde != null) return islem.satisKarYuzde;
      final alimFiyati = _ortalamaAlimFiyati(islem.symbol, islem.createdAt);
      if (alimFiyati == null || alimFiyati == 0) return null;
      return ((islem.price - alimFiyati) / alimFiyati) * 100;
    }
  }

  double? _ortalamaAlimFiyati(String symbol, DateTime satisTarihi) {
    final alimlar = _islemler
        .where((t) =>
            t.symbol == symbol &&
            t.type == 'buy' &&
            t.createdAt.isBefore(satisTarihi))
        .toList();
    if (alimlar.isEmpty) return null;

    double toplamAdet = 0;
    double toplamDeger = 0;
    for (final alim in alimlar) {
      if (alim.quantity != null) {
        toplamAdet += alim.quantity!;
        toplamDeger += alim.quantity! * alim.price;
      }
    }
    return toplamAdet > 0 ? toplamDeger / toplamAdet : null;
  }

  void _detayGoster(TransactionRow islem) {
    final portfoydeVar = _portfoydeVar(islem.symbol);
    final karZarar = _karZararHesapla(islem);
    final karZararYuzde = _karZararYuzdeHesapla(islem);
    final guncelFiyat = _guncelFiyatlar[islem.symbol]?.fiyat;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: islem.transactionType == 'dividend'
                    ? AppTheme.lightPurple
                    : islem.transactionType == 'split'
                        ? AppTheme.navyBlue.withValues(alpha: 0.15)
                        : islem.transactionType == 'buy'
                            ? AppTheme.chipBgGreen(true)
                            : AppTheme.chipBgGreen(false),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                islem.transactionType == 'dividend'
                    ? 'TEMETTÜ'
                    : islem.transactionType == 'split'
                        ? 'BÖLÜNME'
                        : islem.transactionType == 'buy'
                            ? 'ALIM'
                            : 'SATIŞ',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: islem.transactionType == 'dividend'
                      ? AppTheme.purple
                      : islem.transactionType == 'split'
                          ? AppTheme.navyBlue
                          : islem.transactionType == 'buy'
                              ? AppTheme.emeraldGreen
                              : AppTheme.softRed,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LogoService.symbolForDisplay(islem.symbol),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (portfoydeVar)
              Icon(
                Icons.check_circle,
                size: 20,
                color: AppTheme.navyBlue,
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetaySatir('Tarih', DateFormat('dd.MM.yyyy').format(islem.createdAt)),
              if (islem.quantity != null) ...[
                const SizedBox(height: 12),
                _DetaySatir('Adet', islem.quantity!.toStringAsFixed(0)),
              ],
              const SizedBox(height: 12),
              _DetaySatir(
                islem.transactionType == 'dividend' ? 'Temettü Tutarı' : 'Fiyat',
                '${_formatTutar(islem.price)} TL',
              ),
              const SizedBox(height: 12),
              _DetaySatir(
                islem.transactionType == 'dividend' ? 'Gelir' : 'Toplam',
                '${_formatTutar(islem.toplamTutar)} TL',
              ),
              if (guncelFiyat != null && portfoydeVar && (islem.transactionType == 'buy' || islem.transactionType == 'split')) ...[
                const SizedBox(height: 16),
                _DetaySatir('Güncel Fiyat', '${_formatTutar(guncelFiyat)} TL'),
              ],
              if (karZarar != null && karZararYuzde != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.chipBgGreen(karZarar >= 0),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            karZarar >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: AppTheme.chipGreen(karZarar >= 0),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            islem.transactionType == 'sell' && islem.satisKari != null
                                ? 'Satış karı (ort. maliyet üzerinden):'
                                : portfoydeVar
                                    ? 'Güncel kar/zarar:'
                                    : 'İşlem kar/zararı:',
                            style: AppTheme.body(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkSlate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${karZarar >= 0 ? '+' : ''}${_formatTutar(karZarar)} TL',
                        style: AppTheme.price(context).copyWith(
                          fontSize: 18,
                          color: AppTheme.chipGreen(karZarar >= 0),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${karZararYuzde >= 0 ? '+' : ''}${karZararYuzde.toStringAsFixed(2)}%${islem.transactionType == 'sell' && islem.satisKarYuzde != null ? ' (hisse başı)' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.chipGreen(karZarar >= 0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  String _formatTutar(double v) => NumberFormat('#,##0.##', 'tr_TR').format(v);

  /// Hisse sembolüne göre gruplanmış, tarih sıralı işlemler
  Map<String, List<TransactionRow>> get _gruplanmisIslemler {
    final gruplar = <String, List<TransactionRow>>{};
    for (final t in _islemler) {
      gruplar.putIfAbsent(t.symbol, () => []).add(t);
    }
    for (final list in gruplar.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return gruplar;
  }

  /// Hisse listesi: seçili portföydeki veya tüm işlemlerdeki hisseler, alfabetik sıralı
  List<String> get _hisseListesi {
    final symbols = _islemler.map((e) => e.symbol).toSet().toList();
    symbols.sort((a, b) => LogoService.symbolForDisplay(a).toLowerCase().compareTo(LogoService.symbolForDisplay(b).toLowerCase()));
    return symbols;
  }

  /// Grup anahtarları: _seciliHisse varsa sadece o, yoksa tüm gruplar (önce elde olanlar, sonra satılmışlar)
  List<String> get _gruplanmisIslemlerKeys {
    var keys = _gruplanmisIslemler.keys.toList();
    if (_seciliHisse != null) {
      keys = keys.where((k) => k == _seciliHisse).toList();
    }
    keys.sort((a, b) {
      final ozetA = _grupOzeti(a);
      final ozetB = _grupOzeti(b);
      final eldeA = ozetA.eldekiAdet > 0;
      final eldeB = ozetB.eldekiAdet > 0;
      if (eldeA != eldeB) return eldeA ? -1 : 1; // Elde olanlar önce
      return a.compareTo(b);
    });
    return keys;
  }

  /// Grup özeti: toplam alım bedeli, toplam satış bedeli, eldeki adet, güncel bedel
  ({double toplamAlimBedeli, double toplamSatisBedeli, double eldekiAdet, double? guncelBedel})
      _grupOzeti(String symbol) {
    final list = _gruplanmisIslemler[symbol] ?? [];
    double toplamAlim = 0, toplamSatis = 0;
    for (final t in list) {
      final tutar = t.toplamTutar;
      if (t.transactionType == 'buy' || t.transactionType == 'split') {
        toplamAlim += tutar;
      } else if (t.transactionType == 'sell') {
        toplamSatis += tutar;
      } else if (t.transactionType == 'dividend') {
        toplamSatis += tutar; // Temettü gelir olarak sayılır
      }
    }
    final portfoy = _portfoyBul(symbol);
    final eldekiAdet = portfoy?.totalQuantity ?? 0;
    final guncelFiyat = _guncelFiyatlar[symbol]?.fiyat;
    final guncelBedel = guncelFiyat != null ? eldekiAdet * guncelFiyat : null;
    return (
      toplamAlimBedeli: toplamAlim,
      toplamSatisBedeli: toplamSatis,
      eldekiAdet: eldekiAdet,
      guncelBedel: guncelBedel,
    );
  }

  /// Grup için kar/zarar tutarı ve yüzdesi. Tamamen satılmışsa satış-giriş; elde varsa güncel-maliyet.
  ({double? tutar, double? yuzde}) _grupKarZarar(String symbol) {
    final ozet = _grupOzeti(symbol);
    final portfoy = _portfoyBul(symbol);

    if (ozet.eldekiAdet > 0 && portfoy != null) {
      final maliyet = portfoy.totalQuantity * portfoy.averageCost;
      final guncelDeger = ozet.guncelBedel;
      if (guncelDeger == null || maliyet <= 0) return (tutar: null, yuzde: null);
      final tutar = guncelDeger - maliyet;
      final yuzde = (tutar / maliyet) * 100;
      return (tutar: tutar, yuzde: yuzde);
    }
    // Tamamen satılmış
    if (ozet.toplamAlimBedeli <= 0) return (tutar: null, yuzde: null);
    final tutar = ozet.toplamSatisBedeli - ozet.toplamAlimBedeli;
    final yuzde = (tutar / ozet.toplamAlimBedeli) * 100;
    return (tutar: tutar, yuzde: yuzde);
  }

  List<Portfolio> _sembolPaylasimPortfoyleri(String symbol, List<TransactionRow> list) {
    if (_seciliPortfoyId != null) return const [];
    final seen = <String>{};
    final result = <Portfolio>[];
    for (final t in list) {
      final pid = t.portfolioId;
      if (pid == null || seen.contains(pid)) continue;
      seen.add(pid);
      final p = _portfoyler.where((x) => x.id == pid).firstOrNull;
      if (p != null && p.isShared) result.add(p);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Geçmiş İşlemler',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.darkSlate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _tarihAraligiSec,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            child: Text(
                              '${DateFormat('dd.MM.yy', 'tr_TR').format(_baslangicTarihi)} - ${DateFormat('dd.MM.yy', 'tr_TR').format(_bitisTarihi)}',
                              style: AppTheme.bodySmall(context).copyWith(color: AppTheme.navyBlue),
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _filtreMenusuAc,
                    icon: Icon(Icons.tune_rounded, color: AppTheme.navyBlue),
                    tooltip: 'Filtreler (portföy, hisse, tarih)',
                  ),
                ],
              ),
            ),
            Expanded(
            child: _yukleniyor
                ? Center(child: CircularProgressIndicator(color: AppTheme.navyBlue))
                : _islemler.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz işlem yapılmamış',
                        style: AppTheme.body(context),
                      ),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: _yukle,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _gruplanmisIslemlerKeys.length,
                    itemBuilder: (context, groupIndex) {
                      final symbol = _gruplanmisIslemlerKeys[groupIndex];
                      final transactions = _gruplanmisIslemler[symbol]!;
                      final portfoy = _portfoyBul(symbol);
                      final ozet = _grupOzeti(symbol);

                      final acik = _acikGruplar.contains(symbol);
                      final paylasimPortfoyleri = _sembolPaylasimPortfoyleri(symbol, transactions);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Grup satırı: logo, hisse adı, toplam bilgileri, + / - butonu
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    if (acik) {
                                      _acikGruplar.remove(symbol);
                                    } else {
                                      _acikGruplar.add(symbol);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      StockLogo(symbol: symbol, size: 30),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              LogoService.symbolForDisplay(symbol),
                                              style: AppTheme.symbol(context).copyWith(fontSize: 14),
                                            ),
                                            if (_seciliPortfoyId != null && portfoy != null)
                                              Text(
                                                portfoy.name,
                                                style: AppTheme.bodySmall(context).copyWith(fontSize: 10),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            if (_seciliPortfoyId == null && paylasimPortfoyleri.isNotEmpty)
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 2,
                                                children: paylasimPortfoyleri.map((p) {
                                                  final hint = p.ownerEmailHint != null ? '(@${p.ownerEmailHint})' : '';
                                                  return Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.people_outline, size: 11, color: Colors.grey[600]),
                                                      const SizedBox(width: 2),
                                                      Text(hint, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Builder(
                                          builder: (context) {
                                            final kz = _grupKarZarar(symbol);
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: _GecmisOzetHucre(
                                                        label: 'Alım',
                                                        value: _formatTutar(ozet.toplamAlimBedeli),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: _GecmisOzetHucre(
                                                        label: 'Eldeki',
                                                        value: ozet.eldekiAdet.toStringAsFixed(0),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: _GecmisOzetHucre(
                                                        label: 'Satım',
                                                        value: _formatTutar(ozet.toplamSatisBedeli),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: kz.tutar != null
                                                          ? _GecmisOzetHucre(
                                                              label: 'K/Z',
                                                              value:
                                                                  '${kz.tutar! >= 0 ? '+' : ''}${_formatTutar(kz.tutar!)}  ${kz.yuzde! >= 0 ? '+' : ''}${kz.yuzde!.toStringAsFixed(1)}%',
                                                              karda: kz.tutar! >= 0,
                                                              bold: ozet.eldekiAdet == 0,
                                                            )
                                                          : const _GecmisOzetHucre(label: 'K/Z', value: '—'),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            if (acik) {
                                              _acikGruplar.remove(symbol);
                                            } else {
                                              _acikGruplar.add(symbol);
                                            }
                                          });
                                        },
                                        icon: Icon(acik ? Icons.remove_circle_outline : Icons.add_circle_outline),
                                        color: AppTheme.navyBlue,
                                        style: IconButton.styleFrom(padding: const EdgeInsets.all(2), minimumSize: const Size(28, 28)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (acik) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                color: AppTheme.backgroundGrey(context),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text('Tarih', style: AppTheme.bodySmall(context).copyWith(fontWeight: FontWeight.w600, fontSize: 10))),
                                    Expanded(flex: 1, child: Center(child: Text('Tip', style: AppTheme.bodySmall(context).copyWith(fontWeight: FontWeight.w600, fontSize: 10)))),
                                    Expanded(flex: 1, child: Text('Adet', style: AppTheme.bodySmall(context).copyWith(fontWeight: FontWeight.w600, fontSize: 10), textAlign: TextAlign.end)),
                                    Expanded(flex: 2, child: Text('Fiyat', style: AppTheme.bodySmall(context).copyWith(fontWeight: FontWeight.w600, fontSize: 10), textAlign: TextAlign.end)),
                                    Expanded(flex: 2, child: Text('Toplam', style: AppTheme.bodySmall(context).copyWith(fontWeight: FontWeight.w600, fontSize: 10), textAlign: TextAlign.end)),
                                  ],
                                ),
                              ),
                              ...transactions.map((islem) {
                                final karZarar = _karZararHesapla(islem);
                                return InkWell(
                                  onTap: () => _detayGoster(islem),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            DateFormat('dd.MM.yyyy').format(islem.createdAt),
                                            style: AppTheme.bodySmall(context).copyWith(fontSize: 11),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: islem.transactionType == 'dividend'
                                                    ? AppTheme.lightPurple
                                                    : islem.transactionType == 'split'
                                                        ? AppTheme.navyBlue.withValues(alpha: 0.15)
                                                        : islem.transactionType == 'buy'
                                                            ? AppTheme.chipBgGreen(true)
                                                            : AppTheme.chipBgGreen(false),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                islem.transactionType == 'dividend'
                                                    ? 'TEM'
                                                    : islem.transactionType == 'split'
                                                        ? 'BÖL'
                                                        : islem.transactionType == 'buy'
                                                            ? 'AL'
                                                            : 'SAT',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: islem.transactionType == 'dividend'
                                                      ? AppTheme.purple
                                                      : islem.transactionType == 'split'
                                                          ? AppTheme.navyBlue
                                                          : islem.transactionType == 'buy'
                                                              ? AppTheme.emeraldGreen
                                                              : AppTheme.softRed,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            islem.quantity != null ? islem.quantity!.toStringAsFixed(0) : '—',
                                            style: AppTheme.bodySmall(context).copyWith(fontSize: 11),
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            _formatTutar(islem.price),
                                            style: AppTheme.bodySmall(context).copyWith(fontSize: 11),
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            _formatTutar(islem.toplamTutar),
                                            style: AppTheme.bodySmall(context).copyWith(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: karZarar != null && karZarar >= 0 ? AppTheme.emeraldGreen : karZarar != null ? AppTheme.softRed : AppTheme.darkSlate,
                                            ),
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
          ),
            ],
          ),
        ),
    );
  }
}

/// Kart üstünde etiket + değer bitişik; sütunlar arasında [SizedBox] ile boşluk üst widget’ta verilir.
class _GecmisOzetHucre extends StatelessWidget {
  final String label;
  final String value;
  final bool? karda;
  final bool bold;

  const _GecmisOzetHucre({
    required this.label,
    required this.value,
    this.karda,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: karda != null ? AppTheme.chipGreen(karda!) : AppTheme.darkSlate,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$label:', style: AppTheme.bodySmall(context).copyWith(fontSize: 11)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: valueStyle,
            textAlign: TextAlign.start,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _DetaySatir extends StatelessWidget {
  final String label;
  final String value;

  const _DetaySatir(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TarihAraligiDialog extends StatefulWidget {
  final DateTime baslangic;
  final DateTime bitis;
  final void Function(DateTime start, DateTime end) onSecildi;
  final VoidCallback onIptal;

  const _TarihAraligiDialog({
    required this.baslangic,
    required this.bitis,
    required this.onSecildi,
    required this.onIptal,
  });

  @override
  State<_TarihAraligiDialog> createState() => _TarihAraligiDialogState();
}

class _TarihAraligiDialogState extends State<_TarihAraligiDialog> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.baslangic;
    _end = widget.bitis;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AlertDialog(
      title: const Text('Tarih Aralığı Seç'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('Son 3 ay'),
              onTap: () => widget.onSecildi(now.subtract(const Duration(days: 90)), now),
            ),
            ListTile(
              title: const Text('Son 6 ay'),
              onTap: () => widget.onSecildi(now.subtract(const Duration(days: 180)), now),
            ),
            ListTile(
              title: const Text('Son 1 yıl'),
              onTap: () => widget.onSecildi(now.subtract(const Duration(days: 365)), now),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today, size: 20),
              title: Text('Başlangıç: ${DateFormat('dd.MM.yyyy', 'tr_TR').format(_start)}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _start,
                  firstDate: DateTime(2000),
                  lastDate: _end,
                );
                if (d != null && mounted) setState(() => _start = d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, size: 20),
              title: Text('Bitiş: ${DateFormat('dd.MM.yyyy', 'tr_TR').format(_end)}'),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _end,
                  firstDate: _start,
                  lastDate: now,
                );
                if (d != null && mounted) setState(() => _end = d);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onIptal, child: const Text('İptal')),
        FilledButton(
          onPressed: () => widget.onSecildi(_start, _end),
          child: const Text('Uygula'),
        ),
      ],
    );
  }
}
