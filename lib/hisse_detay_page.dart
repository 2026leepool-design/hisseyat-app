import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Added
import 'alarm_service.dart';
import 'models/stock_alarm_local.dart';
import 'stock_notes_alarms.dart';
import 'services/alarm_storage_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'stock_detail_screen.dart';
import 'stock_logo.dart';
import 'logo_service.dart';
import 'services/hisse_karti_ozet_service.dart';
import 'supabase_portfolio_service.dart';
import 'yahoo_finance_service.dart';

class HisseDetayPage extends StatefulWidget {
  const HisseDetayPage({
    super.key,
    required this.item,
    this.seciliDoviz = 'TL',
    this.usdKuru = 1.0,
    this.eurKuru = 1.0,
    this.readOnly = false,
    this.portfoyAdi,
    this.isMasked = false,
  });

  final PortfolioRow item;
  final String seciliDoviz;
  final double usdKuru;
  final double eurKuru;
  /// Paylaşılan portföyde true: AL/SAT vb. aksiyonlar gizlenir
  final bool readOnly;
  /// Hissenin ait olduğu portföy adı (liste ve detayda gösterilir)
  final String? portfoyAdi;
  final bool isMasked;

  @override
  State<HisseDetayPage> createState() => _HisseDetayPageState();
}

class _HisseDetayPageState extends State<HisseDetayPage> {
  late PortfolioRow _currentItem;
  HisseBilgisi? _guncelFiyat;
  bool _yukleniyor = true;
  String? _hata;
  List<TransactionRow>? _islemler;
  bool _islemlerYukleniyor = false;
  /// Hisse Geçmişi filtresi: 'all', 'buy', 'sell', 'split', 'dividend'
  String _islemFiltre = 'all';
  bool _fiyatlarMaskeli = false;
  /// ÖZET bölümünde gösterilecek metrik ID listesi (HisseKartiOzetService'den)
  List<String> _ozetMetrikler = List.from(defaultMetrikler);
  /// Özet düzenleme modu
  final bool _ozetDuzenlemeModu = false;
  
  Timer? _timer; // Added

  /// Dünkü kapanış, 52 hafta aralığı vb. için chart meta
  StockChartMeta? _chartMeta;
  /// Son 1 hafta değişimi için grafik serisi
  StockChartWithSeries? _chartWithSeries;
  /// Notlar paneli
  List<StockNote>? _notlar;
  bool _notlarYukleniyor = false;
  bool _notlarAcik = false;
  bool _notuVar = false;
  /// Bu hisse için en az bir aktif alarm var mı (alarm butonu rengi için)
  bool _hasActiveAlarm = false;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _fiyatlarMaskeli = widget.isMasked;
    
    // Önce metrikleri yükle, sonra fiyat ve ek verileri çek
    HisseKartiOzetService.loadMetrikler().then((m) {
      if (mounted) {
        setState(() => _ozetMetrikler = m);
        _fiyatYukle(); // Metrikler yüklendikten sonra ana fiyat yüklemesi
      }
    });

    _islemleriYukle();
    SupabasePortfolioService.notuOlanSemboller().then((s) {
      if (mounted) setState(() => _notuVar = s.contains(_currentItem.symbol));
    });
    AlarmStorageService.getAlarmsForSymbol(_currentItem.symbol).then((list) {
      if (mounted) setState(() => _hasActiveAlarm = list.any((a) => a.isActive));
    });

    // 3 saniyede bir fiyatı güncelle
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _fiyatYukle(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _notlariYukle() async {
    if (_notlar != null) return;
    setState(() => _notlarYukleniyor = true);
    try {
      final notlar = await SupabasePortfolioService.notlariYukle(_currentItem.symbol);
      if (mounted) {
        setState(() {
          _notlar = notlar;
          _notlarYukleniyor = false;
          _notuVar = notlar.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notlar = [];
          _notlarYukleniyor = false;
        });
      }
    }
  }

  Future<void> _notEkle() async {
    final noteCtrl = TextEditingController();
    String? notMetni;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Not Ekle — ${LogoService.symbolForDisplay(_currentItem.symbol)}'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Not',
            hintText: 'Hisse ile ilgili notunuzu yazın...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Not boş olamaz'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              notMetni = noteCtrl.text.trim();
              Navigator.pop(ctx, true);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    noteCtrl.dispose();
    final metin = notMetni?.trim();
    if (result != true || metin == null || metin.isEmpty) return;
    try {
      await SupabasePortfolioService.notEkle(_currentItem.symbol, metin);
      if (mounted) {
        setState(() => _notlar = null);
        await _notlariYukle();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not eklendi'), backgroundColor: AppTheme.emeraldGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not eklenemedi: ${e.toString().split('\n').first}'), backgroundColor: AppTheme.softRed, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _islemleriYukle() async {
    if (!mounted) return;
    setState(() => _islemlerYukleniyor = true);
    try {
      final islemler = await SupabasePortfolioService.hisseIslemleriYukle(_currentItem.symbol);
      if (mounted) {
        setState(() {
          _islemler = islemler;
          _islemlerYukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _islemler = [];
          _islemlerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _refreshItem() async {
    if (!mounted) return;
    try {
      // PortfolioId'yi koru, eğer varsa
      final portfolioId = _currentItem.portfolioId;
      final liste = await SupabasePortfolioService.portfoyYukle(portfolioId: portfolioId);
      if (!mounted) return;
      
      PortfolioRow? yeni;
      try {
        yeni = liste.firstWhere((e) => e.symbol == _currentItem.symbol);
      } catch (_) {
        // Hisse bulunamazsa mevcut item'i koru
      }
      
      if (yeni != null && mounted) {
        setState(() {
          _currentItem = yeni!;
          _islemler = null;
          _islemleriYukle().catchError((_) {});
        });
        // Fiyat yükleme hatası olsa bile devam et
        if (mounted) {
          try {
            await _fiyatYukle();
          } catch (_) {
            // Sessizce devam et
          }
        }
      } else if (mounted) {
        // Hisse bulunamazsa sayfayı kapatma, sadece fiyatı yenile
        try {
          await _fiyatYukle();
        } catch (_) {
          // Sessizce devam et
        }
      }
    } catch (e) {
      // Hata oluşursa sessizce devam et, sayfayı kapatma
      if (mounted) {
        try {
          await _fiyatYukle();
        } catch (_) {
          // Sessizce devam et
        }
      }
    }
  }

  double _dovizCevir(double tlDegeri) {
    switch (widget.seciliDoviz) {
      case 'USD':
        return tlDegeri / widget.usdKuru;
      case 'EUR':
        return tlDegeri / widget.eurKuru;
      default:
        return tlDegeri;
    }
  }

  String _dovizSembolu() {
    switch (widget.seciliDoviz) {
      case 'USD':
        return 'USD';
      case 'EUR':
        return 'EUR';
      default:
        return '₺';
    }
  }

  String _formatTutar(double v) => NumberFormat('#,##0.##', 'tr_TR').format(v);

  String _formatTutarGoster(double v) => _fiyatlarMaskeli ? '****' : _formatTutar(v);

  String _formatMarketTutarGoster(double v) => _formatTutar(v);

  Future<void> _alarmKurDialog(BuildContext context, PortfolioRow item) async {
    await AlarmService.requestNotificationPermission();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final baslangicFiyat = (_guncelFiyat?.fiyat ?? item.averageCost).toStringAsFixed(2);

    final result = await showDialog<_AlarmKurDialogResult>(
      context: context,
      builder: (ctx) => _AlarmKurDialogContent(
        symbol: item.symbol,
        baslangicFiyat: baslangicFiyat,
      ),
    );

    // Dialog kapandığında alarm durumunu güncelle (buton rengi için)
    if (mounted) {
      AlarmStorageService.getAlarmsForSymbol(item.symbol).then((list) {
        if (mounted) setState(() => _hasActiveAlarm = list.any((a) => a.isActive));
      });
    }

    if (result == null) return;

    final girilenFiyat = result.fiyatStr.trim().replaceAll(',', '.');
    final fiyat = double.tryParse(girilenFiyat);
    if (fiyat == null || fiyat <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Geçerli bir fiyat girin'), behavior: SnackBarBehavior.floating),
        );
      });
      return;
    }
    final symbol = item.symbol.trim().toUpperCase();
    final alarm = StockAlarmLocal(
      id: '${symbol}_${DateTime.now().millisecondsSinceEpoch}',
      symbol: symbol.endsWith('.IS') ? symbol : '$symbol.IS',
      targetPrice: fiyat,
      isAbove: result.isAbove,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await AlarmStorageService.addAlarm(alarm);
    final mesaj = 'Alarm kaydedildi: ${fiyat.toStringAsFixed(2)} TL';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(mesaj),
          backgroundColor: AppTheme.emeraldGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  List<TransactionRow> get _filtrelenmisIslemler {
    if (_islemler == null) return [];
    if (_islemFiltre == 'all') return _islemler!;
    return _islemler!.where((i) => i.transactionType == _islemFiltre).toList();
  }

  bool get _haftaDegisimGerekli =>
      _ozetMetrikler.contains('son_1_hafta_degisim') || _ozetMetrikler.contains('son_1_hafta_degisim_yuzde');

  bool get _chartMetaGerekli =>
      _ozetMetrikler.any((id) => ['dun_kapanis', 'son_1_gun_degisim', 'son_1_gun_degisim_yuzde', '52_hafta_en_yuksek', '52_hafta_en_dusuk', 'gunluk_yuksek', 'gunluk_dusuk'].contains(id));

  Future<void> _fiyatYukle({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _yukleniyor = true;
        _hata = null;
        _chartMeta = null;
        _chartWithSeries = null;
      });
    }
    try {
      final bilgi = await YahooFinanceService.hisseAra(_currentItem.symbol);
      if (!mounted) return;
      setState(() {
        _guncelFiyat = bilgi;
        if (!silent) _yukleniyor = false;
      });

      if (_haftaDegisimGerekli) {
        try {
          final withSeries = await YahooFinanceService.hisseChartWithSeriesAl(_currentItem.symbol);
          if (mounted) setState(() => _chartWithSeries = withSeries);
        } catch (_) {
          // Sessizce devam et
        }
      } else if (_chartMetaGerekli) {
        try {
          final meta = await YahooFinanceService.hisseChartMetaAl(_currentItem.symbol);
          if (mounted) setState(() => _chartMeta = meta);
        } catch (_) {
          // Sessizce devam et
        }
      }
    } on YahooFinanceHata catch (e) {
      if (mounted) {
        setState(() {
          if (!silent) _hata = e.mesaj;
          if (!silent) _yukleniyor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!silent) _hata = 'Fiyat alınamadı.';
          if (!silent) _yukleniyor = false;
        });
      }
    }
  }

  /// Kişiselleştirme sonrası sadece ek verileri (chart meta/series) yükler
  Future<void> _ekVerileriYukle() async {
    if (!mounted) return;
    if (_haftaDegisimGerekli) {
      try {
        final withSeries = await YahooFinanceService.hisseChartWithSeriesAl(_currentItem.symbol);
        if (mounted) setState(() => _chartWithSeries = withSeries);
      } catch (_) {}
    } else if (_chartMetaGerekli) {
      try {
        final meta = await YahooFinanceService.hisseChartMetaAl(_currentItem.symbol);
        if (mounted) setState(() => _chartMeta = meta);
      } catch (_) {}
    } else {
      if (mounted) {
        setState(() {
        _chartMeta = null;
        _chartWithSeries = null;
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem;
    final fiyat = _guncelFiyat?.fiyat;
    final guncelDeger = fiyat != null ? item.totalQuantity * fiyat : null;
    final maliyetDeger = item.toplamDeger;
    final karZarar = guncelDeger != null ? guncelDeger - maliyetDeger : null;
    final karZararYuzde = (karZarar != null && maliyetDeger > 0)
        ? (karZarar / maliyetDeger) * 100
        : null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 56,
            pinned: true,
            floating: false,
            snap: false,
            backgroundColor: AppTheme.navyBlue,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.microtask(() {
                    if (mounted) Navigator.of(context).pop(true);
                  });
                });
              },
            ),
            actions: const [],
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StockLogo(symbol: item.symbol, size: 28),
                const SizedBox(width: 10),
                Text(
                  LogoService.symbolForDisplay(item.symbol),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _hasActiveAlarm ? Icons.notifications_active : Icons.notifications_outlined,
                    size: 22,
                  ),
                  onPressed: () => _alarmKurDialog(context, item),
                  color: _hasActiveAlarm ? Colors.amber : Colors.white,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(36, 36),
                  ),
                  tooltip: _hasActiveAlarm ? 'Alarmlar' : 'Alarm Kur',
                ),
              ],
            ),
            centerTitle: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.navyBlue, AppTheme.darkSlate],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          if (!widget.readOnly && fiyat != null && _hata == null)
            SliverToBoxAdapter(
              child: _buildSabitAltBar(context, item: item, guncelFiyat: fiyat),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.cardDecoration(context),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StockLogo(symbol: item.symbol, size: 56),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: Icon(Icons.edit_note_rounded, size: 22),
                              onPressed: () {
                                setState(() => _notlarAcik = !_notlarAcik);
                                if (_notlarAcik && _notlar == null) _notlariYukle();
                              },
                              color: _notuVar || (_notlar != null && _notlar!.isNotEmpty)
                                  ? const Color(0xFF800020)
                                  : (_notlarAcik ? AppTheme.navyBlue : Colors.grey.shade600),
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(6),
                                minimumSize: const Size(36, 36),
                              ),
                              tooltip: 'Notlar',
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.portfoyAdi != null && widget.portfoyAdi!.isNotEmpty) ...[
                                Text(
                                  widget.portfoyAdi!,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ) ?? TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                              ],
                              Row(
                                children: [
                                  Text(
                                    LogoService.symbolForDisplay(item.symbol),
                                    style: AppTheme.symbol(context),
                                  ),
                                  if (_guncelFiyat?.degisimYuzde != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_guncelFiyat!.degisimYuzde! >= 0 ? '+' : ''}${_guncelFiyat!.degisimYuzde!.toStringAsFixed(2)}%',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _guncelFiyat!.degisimYuzde! >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.name,
                                style: AppTheme.body(context),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.info_outline_rounded, color: AppTheme.darkSlate.withValues(alpha: 0.7), size: 22),
                          tooltip: 'Finansal bilgi',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => StockDetailScreen(symbol: item.symbol, name: item.name),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _notlarAcik
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              Container(
                      decoration: AppTheme.cardDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Notlar',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkSlate,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  color: AppTheme.navyBlue,
                                  onPressed: _notEkle,
                                  tooltip: 'Not Ekle',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: _notlarYukleniyor
                                ? const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navyBlue)),
                                  )
                                : _notlar == null
                                    ? const SizedBox.shrink()
                                    : _notlar!.isEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Text(
                                              'Henüz not yok',
                                              style: AppTheme.bodySmall(context),
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        : ListView.separated(
                                            shrinkWrap: true,
                                            physics: const ClampingScrollPhysics(),
                                            padding: EdgeInsets.zero,
                                            itemCount: _notlar!.length,
                                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                                            itemBuilder: (context, index) {
                                              final not = _notlar![index];
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            not.note,
                                                            style: AppTheme.body(context),
                                                            maxLines: null,
                                                            overflow: TextOverflow.visible,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            DateFormat('dd.MM.yyyy HH:mm').format(not.createdAt),
                                                            style: GoogleFonts.inter(
                                                              fontSize: 11,
                                                              color: Colors.grey.shade600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 18),
                                                      color: AppTheme.softRed,
                                                      onPressed: () async {
                                                        try {
                                                          await SupabasePortfolioService.notSil(not.id);
                                                          if (mounted) {
                                                            setState(() => _notlar = null);
                                                            await _notlariYukle();
                                                          }
                                                        } catch (_) {}
                                                      },
                                                      constraints: const BoxConstraints(),
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                          ),
                        ],
                      ),
                    ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),
                  _yukleniyor
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: CircularProgressIndicator(color: AppTheme.navyBlue),
                          ),
                        )
                      : _hata != null
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.softRed.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AppTheme.softShadow,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: AppTheme.softRed, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _hata!,
                                      style: AppTheme.body(context).copyWith(color: AppTheme.darkSlate),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : (fiyat != null && guncelDeger != null && karZarar != null && karZararYuzde != null)
                              ? _buildBilgiKartlari(
                                  context,
                                  item: item,
                                  guncelFiyat: fiyat,
                                  guncelDeger: guncelDeger,
                                  karZarar: karZarar,
                                  karZararYuzde: karZararYuzde,
                                )
                              : const SizedBox.shrink(), // Fiyat henüz yüklenmediyse boş göster
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSabitAltBar(BuildContext context, {required PortfolioRow item, required double guncelFiyat}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _showAlimDialog(context, item, guncelFiyat),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppTheme.emeraldGreen,
                    foregroundColor: Colors.white,
                    textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('AL'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  onPressed: () => _showSatimDialog(context, item, guncelFiyat),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppTheme.softRed,
                    foregroundColor: Colors.white,
                    textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SAT'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showBolunmeAlimDialog(context, item),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: AppTheme.navyBlue,
                    side: BorderSide(color: AppTheme.navyBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.call_split_rounded, size: 20),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showTemettuDialog(context, item),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: AppTheme.emeraldGreen,
                    side: BorderSide(color: AppTheme.emeraldGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.payments_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, Widget> _buildOzetMap(
    BuildContext context, {
    required PortfolioRow item,
    required double guncelFiyat,
    required double? guncelDeger,
    required double? karZarar,
    required double? karZararYuzde,
  }) {
    final isKar = (karZarar ?? 0) >= 0;
    final sembol = _dovizSembolu();
    final meta = _chartMeta ?? _chartWithSeries?.meta;
    final prevClose = meta?.previousClose;
    final week52High = meta?.week52High;
    final week52Low = meta?.week52Low;
    final dayHigh = meta?.dayHigh;
    final dayLow = meta?.dayLow;
    final buyOrSplit = _islemler
        ?.where((t) => t.transactionType == 'buy' || t.transactionType == 'split')
        .toList() ?? [];
    final portfoyEnYuksek = buyOrSplit.isEmpty ? null : buyOrSplit.map((t) => t.price).reduce((a, b) => a > b ? a : b);
    final portfoyEnDusuk = buyOrSplit.isEmpty ? null : buyOrSplit.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    double? haftaOnceKapanis;
    if (_chartWithSeries != null && _chartWithSeries!.series.length >= 6) {
      haftaOnceKapanis = _chartWithSeries!.series[_chartWithSeries!.series.length - 6].close;
    }
    final son1GunDegisim = prevClose != null ? guncelFiyat - prevClose : null;
    final son1GunYuzde = (prevClose != null && prevClose > 0) ? ((guncelFiyat - prevClose) / prevClose) * 100 : null;
    final son1HaftaDegisim = haftaOnceKapanis != null ? guncelFiyat - haftaOnceKapanis : null;
    final son1HaftaYuzde = (haftaOnceKapanis != null && haftaOnceKapanis > 0)
        ? ((guncelFiyat - haftaOnceKapanis) / haftaOnceKapanis) * 100
        : null;

    final kartlar = <String, Widget>{};
    for (final id in _ozetMetrikler) {
      switch (id) {
        case 'adet':
          kartlar[id] = _OzetKart(
            baslik: 'Adet',
            deger: '${_fiyatlarMaskeli ? '****' : item.totalQuantity.toStringAsFixed(0)} adet',
            ikon: Icons.inventory_2_outlined,
          );
          break;
        case 'guncel_deger':
          kartlar[id] = _OzetKart(
            baslik: 'Güncel değer',
            deger: '${_formatTutarGoster(_dovizCevir(guncelDeger ?? 0))} $sembol',
            ikon: Icons.account_balance_wallet,
            degerStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
          );
          break;
        case 'toplam_maliyet':
          kartlar[id] = _OzetKart(
            baslik: 'Toplam maliyet',
            deger: '${_formatTutarGoster(_dovizCevir(item.toplamDeger))} $sembol',
            ikon: Icons.paid_outlined,
          );
          break;
        case 'hisse_basi_maliyet':
          kartlar[id] = _OzetKart(
            baslik: 'Hisse başı maliyet (ortalama)',
            deger: '${_formatTutarGoster(_dovizCevir(item.averageCost))} $sembol',
            ikon: Icons.trending_up,
          );
          break;
        case 'anlik_fiyat':
          kartlar[id] = _OzetKart(
            baslik: 'Anlık fiyat',
            deger: '${_formatMarketTutarGoster(_dovizCevir(guncelFiyat))} $sembol',
            ikon: Icons.show_chart,
            degerStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.navyBlue),
          );
          break;
        case 'kar_zarar':
          kartlar[id] = Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.chipBgGreen(isKar),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isKar ? Icons.arrow_upward : Icons.arrow_downward, color: AppTheme.chipGreen(isKar), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kar / Zarar (alımdan bu yana)',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.chipGreen(isKar), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${(karZarar ?? 0) >= 0 ? '+' : ''}${_formatTutarGoster(_dovizCevir(karZarar ?? 0))} $sembol',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.chipGreen(isKar)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.chipGreen(isKar).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _fiyatlarMaskeli ? '****%' : '${(karZararYuzde ?? 0) >= 0 ? '+' : ''}${(karZararYuzde ?? 0).toStringAsFixed(2)}%',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.chipGreen(isKar)),
                    ),
                  ),
                ],
              ),
            );
          break;
        case 'dun_kapanis':
          kartlar[id] = _OzetKart(
            baslik: 'Dünkü kapanış',
            deger: prevClose != null ? '${_formatMarketTutarGoster(_dovizCevir(prevClose))} $sembol' : '—',
            ikon: Icons.calendar_today_rounded,
          );
          break;
        case 'son_1_gun_degisim':
          kartlar[id] = _OzetKart(
            baslik: 'Son 1 gün değişim',
            deger: son1GunDegisim != null ? '${son1GunDegisim >= 0 ? '+' : ''}${_formatMarketTutarGoster(_dovizCevir(son1GunDegisim))} $sembol' : '—',
            ikon: Icons.trending_up_rounded,
            degerStyle: son1GunDegisim != null
                ? GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: son1GunDegisim >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed)
                : null,
          );
          break;
        case 'son_1_gun_degisim_yuzde':
          kartlar[id] = _OzetKart(
            baslik: 'Son 1 gün değişim %',
            deger: son1GunYuzde != null ? '${son1GunYuzde >= 0 ? '+' : ''}${son1GunYuzde.toStringAsFixed(2)}%' : '—',
            ikon: Icons.percent_rounded,
            degerStyle: son1GunYuzde != null
                ? GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: son1GunYuzde >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed)
                : null,
          );
          break;
        case 'son_1_hafta_degisim':
          kartlar[id] = _OzetKart(
            baslik: 'Son 1 hafta değişim',
            deger: son1HaftaDegisim != null ? '${son1HaftaDegisim >= 0 ? '+' : ''}${_formatMarketTutarGoster(_dovizCevir(son1HaftaDegisim))} $sembol' : '—',
            ikon: Icons.show_chart_rounded,
            degerStyle: son1HaftaDegisim != null
                ? GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: son1HaftaDegisim >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed)
                : null,
          );
          break;
        case 'son_1_hafta_degisim_yuzde':
          kartlar[id] = _OzetKart(
            baslik: 'Son 1 hafta değişim %',
            deger: son1HaftaYuzde != null ? '${son1HaftaYuzde >= 0 ? '+' : ''}${son1HaftaYuzde.toStringAsFixed(2)}%' : '—',
            ikon: Icons.percent_rounded,
            degerStyle: son1HaftaYuzde != null
                ? GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: son1HaftaYuzde >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed)
                : null,
          );
          break;
        case '52_hafta_en_yuksek':
          kartlar[id] = _OzetKart(
            baslik: '52 hafta en yüksek',
            deger: week52High != null ? '${_formatMarketTutarGoster(_dovizCevir(week52High))} $sembol' : '—',
            ikon: Icons.arrow_upward_rounded,
          );
          break;
        case '52_hafta_en_dusuk':
          kartlar[id] = _OzetKart(
            baslik: '52 hafta en düşük',
            deger: week52Low != null ? '${_formatMarketTutarGoster(_dovizCevir(week52Low))} $sembol' : '—',
            ikon: Icons.arrow_downward_rounded,
          );
          break;
        case 'gunluk_yuksek':
          kartlar[id] = _OzetKart(
            baslik: 'Günlük en yüksek',
            deger: dayHigh != null ? '${_formatMarketTutarGoster(_dovizCevir(dayHigh))} $sembol' : '—',
            ikon: Icons.trending_up_rounded,
          );
          break;
        case 'gunluk_dusuk':
          kartlar[id] = _OzetKart(
            baslik: 'Günlük en düşük',
            deger: dayLow != null ? '${_formatMarketTutarGoster(_dovizCevir(dayLow))} $sembol' : '—',
            ikon: Icons.trending_down_rounded,
          );
          break;
        case 'portfoy_en_yuksek':
          kartlar[id] = _OzetKart(
            baslik: 'Portföydeki en yüksek alış',
            deger: portfoyEnYuksek != null ? '${_formatTutarGoster(_dovizCevir(portfoyEnYuksek))} $sembol' : '—',
            ikon: Icons.arrow_upward_rounded,
          );
          break;
        case 'portfoy_en_dusuk':
          kartlar[id] = _OzetKart(
            baslik: 'Portföydeki en düşük alış',
            deger: portfoyEnDusuk != null ? '${_formatTutarGoster(_dovizCevir(portfoyEnDusuk))} $sembol' : '—',
            ikon: Icons.arrow_downward_rounded,
          );
          break;
        default:
          break;
      }
    }
    return kartlar;
  }

  Future<void> _showOzetKisisellestirmeDialog(BuildContext context) async {
    var secili = List<String>.from(_ozetMetrikler);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              title: const Text('ÖZET kişiselleştirme'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Görmek istediğiniz metrikleri seçin. Seçimler tüm hisse kartlarına uygulanır.',
                      style: AppTheme.bodySmall(context),
                    ),
                    const SizedBox(height: 16),
                    ...tumMetrikler.entries.map((e) {
                      final checked = secili.contains(e.key);
                      return CheckboxListTile(
                        title: Text(e.value, style: const TextStyle(fontSize: 13)),
                        value: checked,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) {
                          if (v == true) {
                            secili = [...secili, e.key];
                          } else {
                            secili = secili.where((id) => id != e.key).toList();
                          }
                          setDlg(() {});
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        secili = List.from(defaultMetrikler);
                        setDlg(() {});
                      },
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Varsayılan değerlere dön'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.darkSlate,
                        side: BorderSide(color: AppTheme.darkSlate.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                FilledButton(
                  onPressed: () async {
                    if (secili.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('En az bir metrik seçin.'), behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    await HisseKartiOzetService.saveMetrikler(secili);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == true && mounted) {
      setState(() => _ozetMetrikler = List.from(secili));
      _ekVerileriYukle();
    }
  }

  Widget _buildBilgiKartlari(
    BuildContext context, {
    required PortfolioRow item,
    required double guncelFiyat,
    required double guncelDeger,
    required double karZarar,
    required double karZararYuzde,
  }) {
    final isKar = karZarar >= 0;
    final sembol = _dovizSembolu();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'ÖZET',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkSlate.withValues(alpha: 0.7),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Kişiselleştir',
                  child: GestureDetector(
                    onTap: () => _showOzetKisisellestirmeDialog(context),
                    child: Icon(
                      Icons.tune_rounded,
                      color: AppTheme.darkSlate.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _fiyatlarMaskeli ? 'Fiyatları göster' : 'Fiyatları gizle',
                  child: GestureDetector(
                    onTap: () => setState(() => _fiyatlarMaskeli = !_fiyatlarMaskeli),
                    child: Icon(
                      _fiyatlarMaskeli ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppTheme.darkSlate.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                return Material(
                  elevation: 8,
                  color: Colors.transparent,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                );
              },
              child: child,
            );
          },
          onReorder: (int oldIndex, int newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = _ozetMetrikler.removeAt(oldIndex);
              _ozetMetrikler.insert(newIndex, item);
            });
            HisseKartiOzetService.saveMetrikler(_ozetMetrikler);
          },
          children: () {
            final ozetMap = _buildOzetMap(
              context,
              item: item,
              guncelFiyat: guncelFiyat ?? 0,
              guncelDeger: guncelDeger ?? 0,
              karZarar: karZarar ?? 0,
              karZararYuzde: karZararYuzde ?? 0,
            );
            return _ozetMetrikler.map((id) {
              return Container(
                key: ValueKey(id),
                margin: const EdgeInsets.only(bottom: 12),
                child: ozetMap[id] ?? const SizedBox.shrink(),
              );
            }).toList();
          }(),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Geçmiş',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkSlate,
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) => setState(() => _islemFiltre = v),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'all', child: Text('Tümü', style: TextStyle(fontSize: 13))),
                const PopupMenuItem(value: 'buy', child: Text('Alım', style: TextStyle(fontSize: 13))),
                const PopupMenuItem(value: 'sell', child: Text('Satım', style: TextStyle(fontSize: 13))),
                const PopupMenuItem(value: 'split', child: Text('Bölünme', style: TextStyle(fontSize: 13))),
                const PopupMenuItem(value: 'dividend', child: Text('Temettü', style: TextStyle(fontSize: 13))),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _islemFiltre == 'all' ? 'Tümü' : _islemFiltre == 'buy' ? 'Alım' : _islemFiltre == 'sell' ? 'Satım' : _islemFiltre == 'split' ? 'Bölünme' : 'Temettü',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.darkSlate.withValues(alpha: 0.8)),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.darkSlate.withValues(alpha: 0.7), size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: AppTheme.softShadow,
          ),
          child: _islemlerYukleniyor
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navyBlue)),
                )
              : _filtrelenmisIslemler.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Henüz işlem yok',
                        style: AppTheme.bodySmall(context),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filtrelenmisIslemler.length,
                      itemBuilder: (context, index) {
                        final islem = _filtrelenmisIslemler[index];
                        final isAlim = islem.transactionType == 'buy';
                        final isBolunme = islem.transactionType == 'split';
                        final isTemettu = islem.transactionType == 'dividend';
                        return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey.shade200, width: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 62,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isTemettu
                                              ? AppTheme.lightPurple
                                              : isBolunme
                                                  ? AppTheme.navyBlue.withValues(alpha: 0.15)
                                                  : isAlim
                                                      ? AppTheme.emeraldGreen.withValues(alpha: 0.15)
                                                      : AppTheme.softRed.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            isTemettu
                                                ? 'TEM'
                                                : isBolunme
                                                    ? 'BÖL'
                                                    : isAlim
                                                        ? 'AL'
                                                        : 'SAT',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isTemettu
                                                  ? AppTheme.purple
                                                  : isBolunme
                                                      ? AppTheme.navyBlue
                                                      : isAlim
                                                          ? AppTheme.emeraldGreen
                                                          : AppTheme.softRed,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat('dd.MM.yyyy').format(islem.createdAt),
                                            style: AppTheme.bodySmall(context),
                                          ),
                                          if (islem.quantity != null)
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                '${_fiyatlarMaskeli ? '****' : islem.quantity!.toStringAsFixed(0)} adet × ${_formatTutarGoster(islem.price)} TL',
                                                style: AppTheme.bodySmall(context).copyWith(fontSize: 11),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          if (isTemettu && islem.quantity == null)
                                            Text(
                                              'Temettü: ${_formatTutarGoster(islem.price)} TL',
                                              style: AppTheme.bodySmall(context).copyWith(fontSize: 11),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      isTemettu
                                          ? '+${_formatTutarGoster(islem.price)} TL'
                                          : isAlim || isBolunme
                                              ? '-${_formatTutarGoster(islem.toplamTutar)} TL'
                                              : '+${_formatTutarGoster(islem.toplamTutar)} TL',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isTemettu
                                            ? AppTheme.purple
                                            : (!isAlim && !isBolunme)
                                                ? AppTheme.emeraldGreen
                                                : AppTheme.darkSlate,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
        ),
      ],
    );
  }

  Future<void> _showAlimDialog(BuildContext context, PortfolioRow item, double anlikFiyat) async {
    double portfoyKomisyon = 0.001;
    if (item.portfolioId != null) {
      final p = await SupabasePortfolioService.portfoyGetir(item.portfolioId!);
      portfoyKomisyon = p?.commissionRate ?? 0.001;
    }
    final result = await showDialog<({int adet, DateTime tarih})>(
      context: context,
      builder: (ctx) => _AlimDiyalogContent(
        item: item,
        anlikFiyat: anlikFiyat,
        portfoyKomisyon: portfoyKomisyon,
      ),
    );
    if (result != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alım kaydedildi: ${result.adet} adet'), backgroundColor: AppTheme.emeraldGreen, behavior: SnackBarBehavior.floating),
        );
        _refreshItem();
        setState(() => _islemler = null);
        _islemleriYukle();
      });
    }
  }

  Future<void> _showSatimDialog(BuildContext context, PortfolioRow item, double anlikFiyat) async {
    double portfoyKomisyon = 0.001;
    if (item.portfolioId != null) {
      final p = await SupabasePortfolioService.portfoyGetir(item.portfolioId!);
      portfoyKomisyon = p?.commissionRate ?? 0.001;
    }
    final adetCtrl = TextEditingController(text: item.totalQuantity.toInt().toString());
    final fiyatCtrl = TextEditingController(text: anlikFiyat.toStringAsFixed(2));
    final komisyonCtrl = TextEditingController(
      text: (portfoyKomisyon * 1000).toStringAsFixed((portfoyKomisyon * 1000).truncateToDouble() == portfoyKomisyon * 1000 ? 0 : 2),
    );
    DateTime seciliTarih = DateTime.now();
    final maxAdet = item.totalQuantity.toInt();
    bool komisyonVarsayilanOlsun = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            final adet = int.tryParse(adetCtrl.text.trim()) ?? 0;
            final fiyat = double.tryParse(fiyatCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
            final toplamGelir = adet * fiyat;
            return AlertDialog(
              title: Text('Satım — ${LogoService.symbolForDisplay(item.symbol)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Eldeki: $maxAdet adet', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: adetCtrl,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Adet (max $maxAdet)',
                            hintText: 'Adet',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: const OutlineInputBorder(),
                            filled: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setDlg(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: fiyatCtrl,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Satış fiyatı (TL)',
                            hintText: '0.00',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: const OutlineInputBorder(),
                            filled: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          onChanged: (_) => setDlg(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showDatePicker(
                              context: ctx,
                              initialDate: seciliTarih,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (t != null) {
                              seciliTarih = t;
                              setDlg(() {});
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade50,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('dd.MM.yyyy').format(seciliTarih), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: komisyonCtrl,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Komisyon (‰)',
                            hintText: '1',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: const OutlineInputBorder(),
                            filled: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}'))],
                          onChanged: (_) => setDlg(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    value: komisyonVarsayilanOlsun,
                    onChanged: (v) {
                      komisyonVarsayilanOlsun = v ?? false;
                      setDlg(() {});
                    },
                    title: const Text('Varsayılan olarak kullan', style: TextStyle(fontSize: 12)),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Toplam gelir:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                        Text('${toplamGelir.toStringAsFixed(2)} TL', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                FilledButton(
                  onPressed: () async {
                    final a = int.tryParse(adetCtrl.text.trim()) ?? 0;
                    final f = double.tryParse(fiyatCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                    if (a < 1) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('En az 1 adet girin'), behavior: SnackBarBehavior.floating));
                      return;
                    }
                    if (a > maxAdet) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Max $maxAdet adet satabilirsiniz'), behavior: SnackBarBehavior.floating));
                      return;
                    }
                    if (f <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Geçerli fiyat girin'), behavior: SnackBarBehavior.floating));
                      return;
                    }
                    final binde = double.tryParse(komisyonCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;
                    final komisyonOrani = (binde / 1000).clamp(0.0, 1.0);
                    try {
                      await SupabasePortfolioService.satimEkle(
                        symbol: item.symbol,
                        name: item.name,
                        quantity: a.toDouble(),
                        price: f,
                        islemTarihi: seciliTarih,
                        portfolioId: item.portfolioId,
                        commissionRate: komisyonOrani,
                      );
                      if (komisyonVarsayilanOlsun && item.portfolioId != null) {
                        await SupabasePortfolioService.portfoyKomisyonOranGuncelle(item.portfolioId!, komisyonOrani);
                      }
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        final tamSatis = (a == maxAdet);
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Satış kaydedildi: $a adet'), backgroundColor: AppTheme.emeraldGreen, behavior: SnackBarBehavior.floating),
                          );
                          if (tamSatis) {
                            // Tüm miktar satıldıysa hisse kartından çık, ana ekrana dön
                            if (context.mounted) Navigator.pop(context);
                            return;
                          }
                          _refreshItem();
                          setState(() => _islemler = null);
                          _islemleriYukle();
                        });
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Hata: ${e.toString().split('\n').first}'), backgroundColor: AppTheme.softRed, behavior: SnackBarBehavior.floating),
                      );
                      }
                    }
                  },
                  child: const Text('Satışı Onayla'),
                ),
              ],
            );
          },
        );
      },
    );
    adetCtrl.dispose();
    fiyatCtrl.dispose();
    komisyonCtrl.dispose();
  }

  Future<void> _showBolunmeAlimDialog(BuildContext context, PortfolioRow item) async {
    final adetCtrl = TextEditingController();
    final toplamMaliyetCtrl = TextEditingController(text: '0');
    DateTime seciliTarih = DateTime.now();

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            final adet = double.tryParse(adetCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
            final toplamMaliyet = double.tryParse(toplamMaliyetCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
            final hisseBasiMaliyet = adet > 0 ? toplamMaliyet / adet : 0.0;
            return AlertDialog(
              title: Text('Bölünme Alımı — ${LogoService.symbolForDisplay(item.symbol)}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: adetCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Eklenen Adet',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      onChanged: (_) => setDlg(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: toplamMaliyetCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Toplam Maliyet (TL)',
                        hintText: 'Toplam harcanan tutar - Bedelsiz ise 0',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      onChanged: (_) => setDlg(() {}),
                    ),
                    if (adet > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Hisse başı maliyet:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${hisseBasiMaliyet.toStringAsFixed(2)} TL',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final t = await showDatePicker(
                          context: ctx,
                          initialDate: seciliTarih,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (t != null) {
                          seciliTarih = t;
                          setDlg(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd.MM.yyyy').format(seciliTarih), style: const TextStyle(fontWeight: FontWeight.w600)),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                FilledButton(
                  onPressed: () async {
                    final a = double.tryParse(adetCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                    final toplam = double.tryParse(toplamMaliyetCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                    if (a <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Geçerli adet girin'), behavior: SnackBarBehavior.floating));
                      return;
                    }
                    if (toplam < 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Toplam maliyet negatif olamaz'), behavior: SnackBarBehavior.floating));
                      return;
                    }
                    final hisseBasi = toplam / a;
                    try {
                      await SupabasePortfolioService.bolunmeEkle(
                        symbol: item.symbol,
                        name: item.name,
                        eklenenAdet: a,
                        maliyet: hisseBasi,
                        islemTarihi: seciliTarih,
                        portfolioId: item.portfolioId,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, a);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Hata: ${e.toString().split('\n').first}'), backgroundColor: AppTheme.softRed, behavior: SnackBarBehavior.floating),
                      );
                      }
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    adetCtrl.dispose();
    toplamMaliyetCtrl.dispose();

    final kaydedilenAdet = result;
    if (kaydedilenAdet != null && kaydedilenAdet > 0 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _islemler = null);
        _refreshItem().catchError((_) {});
        _islemleriYukle().catchError((_) {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bölünme alımı kaydedildi: ${kaydedilenAdet.toStringAsFixed(0)} adet'), backgroundColor: AppTheme.emeraldGreen, behavior: SnackBarBehavior.floating),
        );
      });
    }
  }

  Future<void> _showTemettuDialog(BuildContext context, PortfolioRow item) async {
    final tutarCtrl = TextEditingController();
    DateTime seciliTarih = DateTime.now();

    final kaydedilenTutar = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            final tutar = double.tryParse(tutarCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
            return AlertDialog(
              title: Text('Temettü — ${LogoService.symbolForDisplay(item.symbol)}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: tutarCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Temettü Tutarı (TL)',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      onChanged: (_) => setDlg(() {}),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final t = await showDatePicker(
                          context: ctx,
                          initialDate: seciliTarih,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (t != null) {
                          seciliTarih = t;
                          setDlg(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd.MM.yyyy').format(seciliTarih), style: const TextStyle(fontWeight: FontWeight.w600)),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (tutar > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Temettü tutarı:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Expanded(
                              child: Text(
                                '${tutar.toStringAsFixed(2)} TL',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                FilledButton(
                  onPressed: () async {
                    final t = double.tryParse(tutarCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                    if (t <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Geçerli temettü tutarı girin'), behavior: SnackBarBehavior.floating));
                      return;
                    }
                    try {
                      await SupabasePortfolioService.temettuEkle(
                        symbol: item.symbol,
                        name: item.name,
                        temettuTutari: t,
                        islemTarihi: seciliTarih,
                        portfolioId: item.portfolioId,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, t);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Hata: ${e.toString().split('\n').first}'), backgroundColor: AppTheme.softRed, behavior: SnackBarBehavior.floating),
                      );
                      }
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    tutarCtrl.dispose();

    if (kaydedilenTutar != null && kaydedilenTutar > 0 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _islemler = null);
        _refreshItem().catchError((_) {});
        _islemleriYukle().catchError((_) {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Temettü kaydedildi: ${kaydedilenTutar.toStringAsFixed(2)} TL'), backgroundColor: AppTheme.emeraldGreen, behavior: SnackBarBehavior.floating),
        );
      });
    }
  }
}

class _AlimDiyalogContent extends StatefulWidget {
  final PortfolioRow item;
  final double anlikFiyat;
  final double portfoyKomisyon;

  const _AlimDiyalogContent({
    required this.item,
    required this.anlikFiyat,
    this.portfoyKomisyon = 0.001,
  });

  @override
  State<_AlimDiyalogContent> createState() => _AlimDiyalogContentState();
}

class _AlimDiyalogContentState extends State<_AlimDiyalogContent> {
  final _adetCtrl = TextEditingController(text: '1');
  final _fiyatCtrl = TextEditingController();
  late final TextEditingController _komisyonCtrl;
  DateTime _seciliTarih = DateTime.now();
  bool _komisyonVarsayilanOlsun = false;

  @override
  void initState() {
    super.initState();
    _fiyatCtrl.text = widget.anlikFiyat.toStringAsFixed(2);
    final binde = widget.portfoyKomisyon * 1000;
    _komisyonCtrl = TextEditingController(
      text: binde.toStringAsFixed(binde.truncateToDouble() == binde ? 0 : 2),
    );
  }

  @override
  void dispose() {
    _adetCtrl.dispose();
    _fiyatCtrl.dispose();
    _komisyonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adet = int.tryParse(_adetCtrl.text.trim()) ?? 0;
    final fiyat = double.tryParse(_fiyatCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final toplam = adet * fiyat;
    return StatefulBuilder(
      builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text('Alım — ${LogoService.symbolForDisplay(widget.item.symbol)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _adetCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Adet',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setDlg(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fiyatCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fiyat (TL)',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  onChanged: (_) => setDlg(() {}),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final t = await showDatePicker(
                      context: ctx,
                      initialDate: _seciliTarih,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (t != null) {
                      _seciliTarih = t;
                      setDlg(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd.MM.yyyy').format(_seciliTarih), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _komisyonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Komisyon oranı (binde)',
                    hintText: 'Binde 1 = 0.001',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}'))],
                  onChanged: (_) => setDlg(() {}),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _komisyonVarsayilanOlsun,
                  onChanged: (v) {
                    _komisyonVarsayilanOlsun = v ?? false;
                    setDlg(() {});
                  },
                  title: const Text('Bu portföy için varsayılan olarak kullan', style: TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                const SizedBox(height: 12),
                if (adet > 0 && fiyat > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Toplam:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Expanded(
                          child: Text(
                            '${toplam.toStringAsFixed(2)} TL',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                final a = int.tryParse(_adetCtrl.text.trim()) ?? 0;
                final f = double.tryParse(_fiyatCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                if (a < 1) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az 1 adet girin'), behavior: SnackBarBehavior.floating));
                  return;
                }
                if (f <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli fiyat girin'), behavior: SnackBarBehavior.floating));
                  return;
                }
                final binde = double.tryParse(_komisyonCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;
                final komisyonOrani = (binde / 1000).clamp(0.0, 1.0);
                try {
                  await SupabasePortfolioService.alimEkle(
                    symbol: widget.item.symbol,
                    name: widget.item.name,
                    quantity: a,
                    price: f,
                    islemTarihi: _seciliTarih,
                    portfolioId: widget.item.portfolioId,
                    commissionRate: komisyonOrani,
                  );
                  if (_komisyonVarsayilanOlsun && widget.item.portfolioId != null) {
                    await SupabasePortfolioService.portfoyKomisyonOranGuncelle(widget.item.portfolioId!, komisyonOrani);
                  }
                  if (context.mounted) {
                    Navigator.pop(context, (adet: a, tarih: _seciliTarih));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: ${e.toString().split('\n').first}'), backgroundColor: AppTheme.softRed, behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
              child: const Text('Alımı Onayla'),
            ),
          ],
        );
      },
    );
  }
}

class _OzetKart extends StatelessWidget {
  const _OzetKart({
    required this.baslik,
    required this.deger,
    required this.ikon,
    this.degerStyle,
  });

  final String baslik;
  final String deger;
  final IconData ikon;
  final TextStyle? degerStyle;

  @override
  Widget build(BuildContext context) {
    final style = degerStyle ?? AppTheme.price(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(ikon, color: AppTheme.darkSlate.withValues(alpha: 0.6), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: AppTheme.bodySmall(context),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    deger,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Alarm kur diyaloğunun dönüş değeri (yeni eklenen alarm için)
class _AlarmKurDialogResult {
  final bool isAbove;
  final String fiyatStr;
  _AlarmKurDialogResult({required this.isAbove, required this.fiyatStr});
}

class _AlarmKurDialogContent extends StatefulWidget {
  final String symbol;
  final String baslangicFiyat;

  const _AlarmKurDialogContent({
    required this.symbol,
    required this.baslangicFiyat,
  });

  @override
  State<_AlarmKurDialogContent> createState() => _AlarmKurDialogContentState();
}

class _AlarmKurDialogContentState extends State<_AlarmKurDialogContent> {
  late TextEditingController _controller;
  late bool _isAbove;
  List<StockAlarmLocal> _alarms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.baslangicFiyat);
    _isAbove = true;
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    final list = await AlarmStorageService.getAlarmsForSymbol(widget.symbol);
    if (mounted) {
      setState(() {
      _alarms = list;
      _loading = false;
    });
    }
  }

  Future<void> _toggleAlarm(StockAlarmLocal alarm) async {
    await AlarmStorageService.toggleActive(alarm.id);
    await _loadAlarms();
  }

  Future<void> _editAlarm(BuildContext context, StockAlarmLocal alarm) async {
    final fiyatCtrl = TextEditingController(
      text: NumberFormat('#,##0.##', 'tr_TR').format(alarm.targetPrice),
    );
    var isAbove = alarm.isAbove;

    final updated = await showDialog<StockAlarmLocal>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            title: const Text('Alarmı güncelle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Hedef (Yukarı)'), icon: Icon(Icons.arrow_upward, size: 18)),
                    ButtonSegment(value: false, label: Text('Stop (Aşağı)'), icon: Icon(Icons.arrow_downward, size: 18)),
                  ],
                  selected: {isAbove},
                  onSelectionChanged: (v) => setDlg(() => isAbove = v.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fiyatCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fiyat (TL)',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*'))],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
              FilledButton(
                onPressed: () {
                  final str = fiyatCtrl.text.trim().replaceAll(',', '.');
                  final fiyat = double.tryParse(str);
                  if (fiyat != null && fiyat > 0) {
                    Navigator.pop(ctx, alarm.copyWith(targetPrice: fiyat, isAbove: isAbove));
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          ),
        );
      },
    );
    fiyatCtrl.dispose();
    if (updated != null) {
      await AlarmStorageService.updateAlarm(updated);
      await _loadAlarms();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Alarmlar — ${LogoService.symbolForDisplay(widget.symbol)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              if (_alarms.isNotEmpty) ...[
                Text(
                  'Mevcut alarmlar',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                ..._alarms.map((a) {
                  final tip = a.isAbove ? 'Hedef (Yukarı)' : 'Stop (Aşağı)';
                  final fiyat = NumberFormat('#,##0.##', 'tr_TR').format(a.targetPrice);
                  final textColor = Theme.of(context).colorScheme.onSurface;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        onTap: () => _editAlarm(context, a),
                        title: Text(
                          '$tip — $fiyat TL',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: a.isActive ? textColor : Colors.grey.shade600,
                            decoration: a.isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        trailing: Switch(
                          value: a.isActive,
                          onChanged: (_) => _toggleAlarm(a),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
              Text(
                'Yeni alarm ekle',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Hedef (Yukarı)'), icon: Icon(Icons.arrow_upward, size: 18)),
                  ButtonSegment(value: false, label: Text('Stop (Aşağı)'), icon: Icon(Icons.arrow_downward, size: 18)),
                ],
                selected: {_isAbove},
                onSelectionChanged: (v) => setState(() => _isAbove = v.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Hedef Fiyat (TL)',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              ),
            ],
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(null),
          icon: const Icon(Icons.close),
          tooltip: 'Kapat',
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).pop(_AlarmKurDialogResult(
              isAbove: _isAbove,
              fiyatStr: _controller.text,
            ));
          },
          icon: const Icon(Icons.save),
          tooltip: 'Yeni alarm kaydet',
        ),
      ],
    );
  }
}
