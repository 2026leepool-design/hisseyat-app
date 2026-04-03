import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'logo_service.dart';
import 'models/is_yatirim_model.dart';
import 'teknik_grafik_screen.dart';
import 'services/favori_hisse_service.dart';
import 'supabase_portfolio_service.dart';
import 'services/finansal_ozet_metrik_service.dart';
import 'services/is_yatirim_service.dart';
import 'services/advanced_metrics_model.dart';
import 'services/advanced_metrics_service.dart';
import 'stock_logo.dart';
import 'services/ai_analysis_service.dart';
import 'util/company_about_text.dart';
import 'widgets/ai_analysis_bottom_sheet.dart';
import 'yahoo_finance_service.dart';

/// Hisse detay sayfası (StockDetailScreen) - v8/finance/chart ile tek kaynak
class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({
    super.key,
    required this.symbol,
    this.name,
  });

  final String symbol;
  final String? name;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  StockChartMeta? _meta;
  double? _previousCloseOverride;
  IsYatirimModel? _isYatirimData;
  AdvancedMetrics _advancedMetrics = const AdvancedMetrics.empty();
  HisseDetayliBilgi? _detayliBilgi;
  IsYatirimCompanyProfile? _isYatirimProfil;
  bool _yukleniyor = true;
  bool _isYatirimYukleniyor = true;
  bool _advancedMetrikYukleniyor = true;
  String? _hata;
  List<String> _ozetMetrikler = List.from(defaultFinansalOzetMetrikler);
  bool _ozetDuzenlemeModu = false;
  bool _isFavori = false;
  Timer? _yenilemeTimer;
  List<TransactionRow> _islemler = [];

  @override
  void initState() {
    super.initState();
    SupabasePortfolioService.hisseIslemleriYukle(widget.symbol).then((list) {
      if (mounted) setState(() => _islemler = list);
    }).catchError((_) {});
    FinansalOzetMetrikService.loadMetrikler().then((m) {
      if (mounted) setState(() => _ozetMetrikler = m);
    });
    FavoriHisseService.isFavori(widget.symbol).then((v) {
      if (mounted) setState(() => _isFavori = v);
    });
    _yukle();
    _yenilemeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _meta != null) _sessizYenile();
    });
  }

  @override
  void dispose() {
    _yenilemeTimer?.cancel();
    super.dispose();
  }

  /// 3 sn yenileme için; yükleniyor göstermeden sadece veriyi günceller.
  Future<void> _sessizYenile() async {
    try {
      final meta = await YahooFinanceService.hisseChartMetaAl(widget.symbol);
      if (mounted) {
        setState(() {
          _meta = meta;
          if (_meta == null) _hata = 'Hisse verisi alınamadı.';
        });
      }
      YahooFinanceService.oncekiKapanisQuoteSummary(widget.symbol).then((v) {
        if (!mounted || v == null) return;
        final meta = _meta;
        if (meta != null && meta.dayLow != null && meta.dayHigh != null) {
          final low = meta.dayLow!;
          final high = meta.dayHigh!;
          if (v < low * 0.85 || v > high * 1.15) return;
        }
        setState(() => _previousCloseOverride = v);
      }).catchError((_) {});
      if (mounted) {
        IsYatirimService.sirketKartiAl(widget.symbol).then((data) {
          if (mounted) setState(() => _isYatirimData = data);
        }).catchError((_) {});
      }
    } catch (_) {}
  }

  Future<void> _toggleFavori() async {
    await FavoriHisseService.toggleFavori(widget.symbol);
    if (mounted) {
      setState(() => _isFavori = !_isFavori);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavori ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _isYatirimYukleniyor = true;
      _advancedMetrikYukleniyor = true;
      _hata = null;
    });
    try {
      final meta = await YahooFinanceService.hisseChartMetaAl(widget.symbol);
      if (mounted) {
        setState(() {
          _meta = meta;
          _yukleniyor = false;
          if (_meta == null) _hata = 'Hisse verisi alınamadı.';
        });
      }
      YahooFinanceService.oncekiKapanisQuoteSummary(widget.symbol).then((v) {
        if (!mounted || v == null) return;
        final meta = _meta;
        if (meta != null && meta.dayLow != null && meta.dayHigh != null) {
          final low = meta.dayLow!;
          final high = meta.dayHigh!;
          if (v < low * 0.85 || v > high * 1.15) return;
        }
        setState(() => _previousCloseOverride = v);
      }).catchError((_) {});

      // Finansal özet için İş Yatırım verilerini al (paralel / sonra)
      if (mounted) {
        IsYatirimService.sirketKartiAl(widget.symbol).then((data) {
          if (mounted) {
            setState(() {
              _isYatirimData = data;
              _isYatirimYukleniyor = false;
            });
          }
        }).catchError((_) {
          if (mounted) {
            setState(() {
              _isYatirimData = null;
              _isYatirimYukleniyor = false;
            });
          }
        });
      }
      // Derin finansal metrikler için fallback mimarisi (CollectAPI -> FMP)
      if (mounted) {
        AdvancedMetricsService.fetchAdvancedMetrics(widget.symbol).then((m) {
          if (mounted) {
            setState(() {
              _advancedMetrics = m;
              _advancedMetrikYukleniyor = false;
            });
          }
        }).catchError((_) {
          if (mounted) {
            setState(() {
              _advancedMetrics = const AdvancedMetrics.empty();
              _advancedMetrikYukleniyor = false;
            });
          }
        });
      }
      // Profil: Yahoo + İş Yatırım paralel; boş alanlar İş Yatırım ile doldurulur
      if (mounted) {
        final meta = _meta;
        YahooFinanceService.hisseDetayliBilgiAl(widget.symbol, chartMeta: meta).then((bilgi) {
          if (mounted) setState(() => _detayliBilgi = bilgi);
        }).catchError((_) {});
        IsYatirimService.fetchCompanyProfile(widget.symbol).then((p) {
          if (mounted) setState(() => _isYatirimProfil = p);
        }).catchError((_) {
          if (mounted) setState(() => _isYatirimProfil = null);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _isYatirimYukleniyor = false;
          _advancedMetrikYukleniyor = false;
          _hata = 'Veri alınamadı: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  String _formatSayi(double? v) {
    if (v == null) return '—';
    return NumberFormat('#,##0.##', 'tr_TR').format(v);
  }

  /// Hacim için kısaltılmış format (898K, 1.2M vb.)
  String _formatHacim(double? v) {
    if (v == null) return '—';
    if (v >= 1e12) return '${(v / 1e12).toStringAsFixed(2)}T';
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  List<_OzetKartVeri> _buildOzetKartVerileri() {
    final meta = _meta;
    final data = _isYatirimData;
    final detayli = _detayliBilgi; // Yahoo quoteSummary – İş Yatırım yoksa yedek
    final cur = AppTheme.currencyDisplay(meta?.currency);
    var effectivePrev = _previousCloseOverride ?? meta?.previousClose;
    final dL = meta?.dayLow;
    final dH = meta?.dayHigh;
    if (effectivePrev != null && dL != null && dH != null && (effectivePrev < dL * 0.9 || effectivePrev > dH * 1.1)) {
      effectivePrev = null;
    }
    final sonuc = <_OzetKartVeri>[];

    for (final id in _ozetMetrikler) {
      final baslik = tumFinansalOzetMetrikler[id];
      String? deger;

      switch (id) {
        case 'onceki_kapanis':
          deger = effectivePrev != null ? '${_formatSayi(effectivePrev)} $cur' : '—';
          break;
        case 'hacim':
          final vol = meta?.regularMarketVolume;
          deger = vol != null ? _formatHacim(vol) : '—';
          break;
        case 'gunluk_yuksek_dusuk':
          final dH = meta?.dayHigh;
          final dL = meta?.dayLow;
          deger = (dH != null && dL != null) ? '${_formatSayi(dL)} - ${_formatSayi(dH)} $cur' : '—';
          break;
        case '52_haftalik_aralik':
          final wL = meta?.week52Low;
          final wH = meta?.week52High;
          deger = (wL != null && wH != null) ? '${_formatSayi(wL)} - ${_formatSayi(wH)} $cur' : '—';
          break;
        case 'son_fiyat':
          // Hisse kodundaki anlık fiyatla aynı kaynak (Yahoo); İş Yatırım sadece yedek
          final price = meta?.price ?? data?.sonFiyat;
          deger = price != null ? '${_formatSayi(price)} $cur' : '—';
          break;
        case 'gunluk_degisim':
          if (effectivePrev != null && effectivePrev > 0 && meta?.price != null) {
            final change = ((meta!.price - effectivePrev) / effectivePrev) * 100;
            deger = '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%';
          } else if (data?.gunlukDegisimYuzde != null) {
            final v = data!.gunlukDegisimYuzde!;
            deger = '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
          } else {
            deger = '—';
          }
          break;
        case 'f_k': {
          var v = data?.fK ?? detayli?.fK ?? _advancedMetrics.fK;
          if (v == null && meta?.price != null && meta!.price > 0 && detayli?.basitHBK != null && detayli!.basitHBK! != 0) {
            v = meta.price / detayli.basitHBK!;
          }
          deger = v != null ? _formatSayi(v) : '—';
          break;
        }
        case 'pd_dd': {
          final v = data?.pdDd ?? detayli?.priceToBook ?? _advancedMetrics.pdDd;
          deger = v != null ? _formatSayi(v) : '—';
          break;
        }
        case 'piyasa_degeri': {
          var v = data?.piyasaDegeri ?? detayli?.piyasaDegeri ?? _advancedMetrics.piyasaDegeri;
          if (v == null && meta?.price != null && detayli?.halkaAcikHisseler != null && detayli!.halkaAcikHisseler! > 0) {
            v = meta!.price * detayli.halkaAcikHisseler!;
          }
          deger = v != null ? '${_formatHacim(v)} $cur' : '—';
          break;
        }
        case 'net_kar': {
          final v = data?.netKar ?? detayli?.netKazanc;
          deger = v != null ? '${_formatHacim(v)} $cur' : '—';
          break;
        }
        case 'temettu_verimi': {
          final v = data?.temettuVerimi ?? detayli?.temettuVerimi ?? _advancedMetrics.temettuVerimi;
          deger = v != null ? '${_formatSayi(v)}%' : '—';
          break;
        }
        case 'beta': {
          final v = detayli?.beta ?? _advancedMetrics.beta;
          deger = v != null ? _formatSayi(v) : '—';
          break;
        }
        case 'roe': {
          final yahooRoe = detayli?.returnOnEquity;
          final fallbackRoe = _advancedMetrics.roe;
          final v = yahooRoe != null
              ? yahooRoe * 100
              : (fallbackRoe != null && fallbackRoe.abs() <= 1 ? fallbackRoe * 100 : fallbackRoe);
          deger = v != null ? '${_formatSayi(v)}%' : '—';
          break;
        }
        case 'cari_oran': {
          final v = detayli?.currentRatio;
          deger = v != null ? _formatSayi(v) : '—';
          break;
        }
        case 'borc_ozkaynak': {
          final v = detayli?.debtToEquity;
          deger = v != null ? _formatSayi(v) : '—';
          break;
        }
        case 'analist_hedef_fiyat': {
          final v = detayli?.targetMeanPrice;
          deger = v != null ? '${_formatSayi(v)} $cur' : '—';
          break;
        }
        case 'ortalama_50_gun': {
          final v = detayli?.ortalama50Gun;
          deger = v != null ? '${_formatSayi(v)} $cur' : '—';
          break;
        }
        case 'ortalama_200_gun': {
          final v = detayli?.ortalama200Gun;
          deger = v != null ? '${_formatSayi(v)} $cur' : '—';
          break;
        }
        case 'peg_oran': {
          final v = detayli?.pegRatio;
          deger = v != null ? _formatSayi(v) : '—';
          break;
        }
        default:
          continue;
      }
      if (baslik != null) {
        sonuc.add(_OzetKartVeri(id: id, baslik: baslik, deger: deger));
      }
    }
    return sonuc;
  }

  void _ozetKartSil(String id) {
    if (_ozetMetrikler.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir metrik kalmalı.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() {
      _ozetMetrikler = _ozetMetrikler.where((e) => e != id).toList();
    });
  }

  void _ozetKartYerDegistir(int eskiIndex, int yeniIndex) {
    if (eskiIndex < 0 || eskiIndex >= _ozetMetrikler.length) return;
    if (yeniIndex < 0 || yeniIndex >= _ozetMetrikler.length) return;
    if (eskiIndex == yeniIndex) return;
    setState(() {
      final item = _ozetMetrikler.removeAt(eskiIndex);
      var insertIndex = yeniIndex;
      if (eskiIndex < yeniIndex) insertIndex--;
      _ozetMetrikler.insert(insertIndex, item);
    });
  }

  Future<void> _ozetDuzenlemeModuKapat() async {
    if (_ozetMetrikler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir metrik kalmalı.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await FinansalOzetMetrikService.saveMetrikler(_ozetMetrikler);
    if (mounted) setState(() => _ozetDuzenlemeModu = false);
  }

  Future<void> _showFinansalOzetKisisellestirmeDialog(BuildContext context) async {
    var secili = List<String>.from(_ozetMetrikler);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              title: const Text('Finansal Özet kişiselleştirme'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Görmek istediğiniz metrikleri seçin. Seçimler tüm hisselerde geçerli olur.',
                      style: AppTheme.bodySmall(context),
                    ),
                    const SizedBox(height: 16),
                    ...tumFinansalOzetMetrikler.entries.map((e) {
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
                        secili = List.from(defaultFinansalOzetMetrikler);
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
                    await FinansalOzetMetrikService.saveMetrikler(secili);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey(context),
      appBar: AppBar(
        title: Text(
          LogoService.symbolForDisplay(widget.symbol),
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFavori ? Icons.star_rounded : Icons.star_border_rounded),
            onPressed: _toggleFavori,
            tooltip: _isFavori ? 'Favorilerden çıkar' : 'Favorilere ekle',
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: AppTheme.navyBlue))
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
              : _meta == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StockLogo(symbol: widget.symbol, size: 56),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      _meta!.longName,
                                      style: AppTheme.h1(context).copyWith(fontSize: 20),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isFavori ? Icons.star_rounded : Icons.star_border_rounded,
                                      color: _isFavori ? Colors.amber : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      size: 28,
                                    ),
                                    onPressed: _toggleFavori,
                                    tooltip: _isFavori ? 'Favorilerden çıkar' : 'Favorilere ekle',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _formatSayi(_meta!.price),
                                    style: GoogleFonts.inter(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.darkSlate,
                                    ),
                                  ),
                                  if (_meta!.previousClose != null && _meta!.previousClose! > 0) ...[
                                    const SizedBox(width: 12),
                                    Builder(
                                      builder: (context) {
                                        final prev = _meta!.previousClose!;
                                        final change = ((_meta!.price - prev) / prev) * 100;
                                        final karda = change >= 0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.chipBgGreen(karda),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.chipGreen(karda),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildOzetTabContent(context),
                                const SizedBox(height: 32),
                                _SirketProfilTab(
                                  isYatirimProfil: _isYatirimProfil,
                                  detayli: _detayliBilgi,
                                  advancedMetrics: _advancedMetrics,
                                  advancedMetricsLoading: _advancedMetrikYukleniyor,
                                  currency: AppTheme.currencyDisplay(_meta?.currency),
                                  formatSayi: _formatSayi,
                                  formatHacim: _formatHacim,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildOzetTabContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AIAnalizButton(
          meta: _meta!,
          effectivePreviousClose: () {
            var p = _previousCloseOverride ?? _meta?.previousClose;
            final dL = _meta?.dayLow;
            final dH = _meta?.dayHigh;
            if (p != null && dL != null && dH != null && (p < dL * 0.9 || p > dH * 1.1)) p = null;
            return p;
          }(),
          isYatirimData: _isYatirimData,
          advancedMetrics: _advancedMetrics,
          detayliBilgi: _detayliBilgi,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Fiyat Grafiği', style: AppTheme.h2(context)),
            Material(
              color: AppTheme.navyBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (context) => TeknikGrafikScreen(
                        symbol: widget.symbol,
                        name: widget.name ?? _meta?.longName,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.candlestick_chart, size: 18, color: AppTheme.navyBlue),
                      const SizedBox(width: 6),
                      Text('Teknik', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.navyBlue)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 320,
          child: _FiyatGrafikWidget(
            symbol: widget.symbol,
            name: widget.name ?? _meta?.longName,
            transactions: _islemler,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Finansal Özet', style: AppTheme.h2(context)),
            Tooltip(
              message: 'Kişiselleştir',
              child: IconButton(
                icon: Icon(Icons.tune_rounded, color: AppTheme.darkSlate.withValues(alpha: 0.7), size: 22),
                onPressed: () => _showFinansalOzetKisisellestirmeDialog(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        (_isYatirimYukleniyor || _advancedMetrikYukleniyor)
            ? Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navyBlue)),
                    const SizedBox(width: 12),
                    Text('Veriler yükleniyor...', style: AppTheme.body(context).copyWith(color: Colors.grey.shade600)),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final veriler = _buildOzetKartVerileri();
                  if (veriler.isEmpty) return const SizedBox.shrink();
                  if (_ozetDuzenlemeModu) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _ozetDuzenlemeModuKapat,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Kapat'),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.navyBlue),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.7,
                          children: List.generate(veriler.length, (index) {
                            final v = veriler[index];
                            return _DuzenlenebilirVeriKutusu(
                              key: ValueKey(v.id),
                              veri: v,
                              index: index,
                              onSil: () => _ozetKartSil(v.id),
                              onYerDegistir: _ozetKartYerDegistir,
                            );
                          }),
                        ),
                      ],
                    );
                  }
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.7,
                    children: veriler.map((v) {
                      return GestureDetector(
                        onLongPress: () => setState(() => _ozetDuzenlemeModu = true),
                        child: _VeriKutusu(baslik: v.baslik, deger: v.deger),
                      );
                    }).toList(),
                  );
                },
              ),
      ],
    );
  }

}

/// Şirket Profili & Detaylar – İş Yatırım (BIST) + Yahoo birleşik; boş alanlar "Bilinmiyor"
class _SirketProfilTab extends StatefulWidget {
  final IsYatirimCompanyProfile? isYatirimProfil;
  final HisseDetayliBilgi? detayli;
  final AdvancedMetrics advancedMetrics;
  final bool advancedMetricsLoading;
  final String currency;
  final String Function(double?) formatSayi;
  final String Function(double?) formatHacim;

  const _SirketProfilTab({
    this.isYatirimProfil,
    this.detayli,
    required this.advancedMetrics,
    required this.advancedMetricsLoading,
    required this.currency,
    required this.formatSayi,
    required this.formatHacim,
  });

  @override
  State<_SirketProfilTab> createState() => _SirketProfilTabState();
}

class _SirketProfilTabState extends State<_SirketProfilTab> {
  bool _aciklamaGenisletildi = false;
  static const int _aciklamaMaxSatir = 5;
  static const String _bilinmiyor = 'Bilinmiyor';

  static const String _tire = '-';

  @override
  Widget build(BuildContext context) {
    final p = widget.isYatirimProfil;
    final d = widget.detayli;
    final adv = widget.advancedMetrics;
    final aciklamaMetni = CompanyAboutText.pick(d?.longBusinessSummary, p?.sirketHakkinda);

    String ceo() => p?.genelMudur ?? d?.ceo ?? _bilinmiyor;
    String kurulus() {
      if (p?.kurulusTarihi != null && p!.kurulusTarihi!.trim().isNotEmpty) return p.kurulusTarihi!;
      if (d?.ipoTarihi != null) return DateFormat('yyyy', 'tr_TR').format(d!.ipoTarihi!);
      return _bilinmiyor;
    }
    String sektor() => p?.sektor ?? d?.sector ?? _tire;
    String industry() => d?.industry ?? _tire;
    String webSitesi() => p?.webSitesi ?? d?.website ?? _tire;
    String calisanSayisi() {
      if (d?.fullTimeEmployees != null) return widget.formatSayi(d!.fullTimeEmployees!);
      return _tire;
    }
    String halkaArz() => p?.halkaArzTarihi ?? _bilinmiyor;
    String odenmisSermaye() => p?.odenmisSermaye ?? (d?.halkaAcikHisseler != null ? widget.formatHacim(d!.halkaAcikHisseler!) : _bilinmiyor);
    String fiiliDolasim() {
      if (p?.fiiliDolasimOrani != null && p!.fiiliDolasimOrani!.trim().isNotEmpty) return p.fiiliDolasimOrani!;
      if (p?.fiiliDolasimOraniYuzde != null) return '${widget.formatSayi(p?.fiiliDolasimOraniYuzde)}%';
      if (d?.floatRate != null) return '${widget.formatSayi(d!.floatRate)}%';
      return _bilinmiyor;
    }
    String betaStr() => d?.betaFmt ?? (d?.beta != null ? widget.formatSayi(d!.beta) : (adv.beta != null ? widget.formatSayi(adv.beta) : null)) ?? _tire;
    String fkStr() => d?.fKFmt ?? (d?.fK != null ? widget.formatSayi(d!.fK) : (adv.fK != null ? widget.formatSayi(adv.fK) : null)) ?? _tire;
    String epsStr() => d?.epsFmt ?? (d?.basitHBK != null ? widget.formatSayi(d!.basitHBK) : null) ?? _tire;
    String temettuStr() => d?.temettuVerimiFmt ?? (d?.temettuVerimi != null ? '${widget.formatSayi(d!.temettuVerimi)}%' : (adv.temettuVerimi != null ? '${widget.formatSayi(adv.temettuVerimi)}%' : null)) ?? _tire;
    String piyasaDegeriStr() => d?.piyasaDegeriFmt ?? (d?.piyasaDegeri != null ? widget.formatHacim(d!.piyasaDegeri!) : (adv.piyasaDegeri != null ? widget.formatHacim(adv.piyasaDegeri) : null)) ?? _tire;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hakkında', style: AppTheme.h2(context)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                aciklamaMetni.isEmpty
                    ? 'Bu şirket için otomatik metin üretilemedi (kaynak sayfasında anlamlı özet bulunamadı). '
                        'Aşağıdaki sektör, web sitesi ve finansal özet bilgilerine bakabilirsiniz.'
                    : aciklamaMetni,
                style: AppTheme.body(context),
                maxLines: _aciklamaGenisletildi ? null : _aciklamaMaxSatir,
                overflow: _aciklamaGenisletildi ? null : TextOverflow.ellipsis,
              ),
              if (aciklamaMetni.isNotEmpty && aciklamaMetni.length > 280) ...[
                if (!_aciklamaGenisletildi)
                  TextButton(
                    onPressed: () => setState(() => _aciklamaGenisletildi = true),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.navyBlue),
                    child: const Text('Devamını Oku'),
                  )
                else
                  TextButton(
                    onPressed: () => setState(() => _aciklamaGenisletildi = false),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.navyBlue),
                    child: const Text('Daha az göster'),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Bilgiler', style: AppTheme.h2(context)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Table(
            columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
            children: [
              _profilSatir(context, 'Sektör', sektor()),
              _profilSatir(context, 'Endüstri', industry()),
              _profilSatir(context, 'Çalışan Sayısı', calisanSayisi()),
              _profilSatir(context, 'Web Sitesi', webSitesi(), isLink: webSitesi() != _tire && webSitesi().trim().isNotEmpty),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Finansal Özet', style: AppTheme.h2(context)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.advancedMetricsLoading) ...[
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navyBlue),
                    ),
                    const SizedBox(width: 8),
                    Text('Derin finansal veriler yükleniyor...', style: AppTheme.bodySmall(context)),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Table(
                columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                children: [
                  _profilSatir(context, 'Beta', betaStr()),
                  _profilSatir(context, 'F/K (P/E)', fkStr()),
                  _profilSatir(context, 'EPS (Hisse Başı Kâr)', epsStr()),
                  _profilSatir(context, 'Temettü Verimi', temettuStr()),
                  _profilSatir(context, 'Piyasa Değeri', piyasaDegeriStr()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Künye', style: AppTheme.h2(context)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Table(
            columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
            children: [
              _profilSatir(context, 'Genel Müdür / CEO', ceo()),
              _profilSatir(context, 'Kuruluş Tarihi', kurulus()),
              _profilSatir(context, 'Halka Arz Tarihi', halkaArz()),
              _profilSatir(context, 'Ödenmiş Sermaye', odenmisSermaye()),
              _profilSatir(context, 'Fiili Dolaşım Oranı', fiiliDolasim()),
            ],
          ),
        ),
      ],
    );
  }

  TableRow _profilSatir(BuildContext context, String label, String value, {bool isLink = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(label, style: AppTheme.bodySmall(context).copyWith(color: Colors.grey.shade700)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 16),
          child: isLink
              ? InkWell(
                  onTap: () {
                    final url = value.trim();
                    if (url.isEmpty || url == '—' || url == _bilinmiyor || url == _tire) return;
                    Uri? uri = Uri.tryParse(url);
                    if (uri != null && !uri.hasScheme) uri = Uri.parse('https://$url');
                    if (uri != null) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    value,
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.navyBlue, decoration: TextDecoration.underline),
                  ),
                )
              : Text(value, style: AppTheme.body(context)),
        ),
      ],
    );
  }
}

/// AI Analiz Et butonu – parlayan glow, bottom sheet açar
class _AIAnalizButton extends StatelessWidget {
  final StockChartMeta meta;
  final double? effectivePreviousClose;
  final IsYatirimModel? isYatirimData;
  final AdvancedMetrics advancedMetrics;
  final HisseDetayliBilgi? detayliBilgi;

  const _AIAnalizButton({
    required this.meta,
    this.effectivePreviousClose,
    this.isYatirimData,
    required this.advancedMetrics,
    this.detayliBilgi,
  });

  @override
  Widget build(BuildContext context) {
    final prev = effectivePreviousClose ?? meta.previousClose ?? 0.0;
    final changePercent = prev > 0
        ? ((meta.price - prev) / prev) * 100
        : 0.0;
    final volume = meta.regularMarketVolume ?? 0.0;

    double? changePercent52W;
    if (meta.week52Low != null && meta.week52Low! > 0) {
      changePercent52W = ((meta.price - meta.week52Low!) / meta.week52Low!) * 100;
    }

    final stockContext = StockAnalysisContext(
      changePercent52W: changePercent52W,
      fk: isYatirimData?.fK ?? detayliBilgi?.fK ?? advancedMetrics.fK,
      pdDd: isYatirimData?.pdDd ?? detayliBilgi?.priceToBook ?? advancedMetrics.pdDd,
      netKar: isYatirimData?.netKar,
      sector: detayliBilgi?.sector,
      industry: detayliBilgi?.industry,
    );

    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showAIAnalysisBottomSheet(
            context,
            symbol: meta.symbol,
            price: meta.price,
            volume: volume,
            changePercent: changePercent,
            stockContext: stockContext,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                AppTheme.smokyJade.withValues(alpha: 0.25),
                AppTheme.slateTeal.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppTheme.smokyJade.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.smokyJade.withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppTheme.smokyJade,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'AI Analiz Et',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zaman aralığı: etiket, interval, range
const _zamanAraliklari = [
  ('G', '1d', '5d'),
  ('H', '1h', '5d'),
  ('1A', '1d', '1mo'),
  ('6A', '1d', '6mo'),
  ('1Y', '1d', '1y'),
  ('5Y', '1wk', '5y'),
];

/// Çizgisel fiyat grafiği – dokunma ile tooltip, zaman aralığı seçici, alım/satım okları, MA15/MA50
class _FiyatGrafikWidget extends StatefulWidget {
  final String symbol;
  final String? name;
  final List<TransactionRow> transactions;

  const _FiyatGrafikWidget({
    required this.symbol,
    this.name,
    this.transactions = const [],
  });

  @override
  State<_FiyatGrafikWidget> createState() => _FiyatGrafikWidgetState();
}

class _FiyatGrafikWidgetState extends State<_FiyatGrafikWidget> {
  List<ChartOHLCPoint>? _points;
  List<ChartOHLCPoint>? _bist100Points;
  bool _yukleniyor = true;
  String? _hata;
  int _seciliAralik = 4; // varsayılan 1Y

  static const _bist100Symbol = 'XU100.IS';

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
    final aralik = _zamanAraliklari[_seciliAralik];
    final sonuclar = await Future.wait([
      YahooFinanceService.hisseChartOHLCAl(
        widget.symbol,
        interval: aralik.$2,
        range: aralik.$3,
      ),
      YahooFinanceService.hisseChartOHLCAl(
        _bist100Symbol,
        interval: aralik.$2,
        range: aralik.$3,
      ),
    ]);
    if (mounted) {
      setState(() {
        _points = sonuclar[0];
        _bist100Points = sonuclar[1];
        _yukleniyor = false;
        if (_points == null || _points!.isEmpty) _hata = 'Veri alınamadı';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zaman aralığı seçici (Teknik butonu başlık yanına taşındı)
          Row(
            children: [
              ...List.generate(
                _zamanAraliklari.length,
                (i) {
                  final secili = _seciliAralik == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: secili
                          ? AppTheme.navyBlue.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _seciliAralik = i;
                            _yukle();
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            _zamanAraliklari[i].$1,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: secili ? FontWeight.w600 : FontWeight.w500,
                              color: secili ? AppTheme.navyBlue : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator(color: AppTheme.navyBlue))
                : _hata != null || _points == null || _points!.isEmpty
                    ? Center(
                        child: Text(
                          _hata ?? 'Veri yok',
                          style: AppTheme.body(context),
                        ),
                      )
                    : _GrafikIcerik(
                        points: _points!,
                        bistPoints: _bist100Points,
                        transactions: widget.transactions,
                      ),
          ),
        ],
      ),
    );
  }
}

class _GrafikIcerik extends StatefulWidget {
  final List<ChartOHLCPoint> points;
  final List<ChartOHLCPoint>? bistPoints;
  final List<TransactionRow> transactions;

  const _GrafikIcerik({
    required this.points,
    this.bistPoints,
    this.transactions = const [],
  });

  @override
  State<_GrafikIcerik> createState() => _GrafikIcerikState();
}

class _GrafikIcerikState extends State<_GrafikIcerik> {
  TransactionRow? _selectedTransaction;

  /// BIST verisini hisse tarihlerine hizalayıp normalize (100 bazlı) değerler üretir.
  /// Her hisse indeksi için bir spot döner (eksik günlerde bir önceki değer kullanılır).
  List<FlSpot>? _bistSpotsNormalized() {
    if (widget.bistPoints == null || widget.bistPoints!.isEmpty) return null;
    final bistByDay = <int, double>{};
    for (final p in widget.bistPoints!) {
      bistByDay[p.timestamp ~/ 86400] = p.close;
    }
    final bistFirst = widget.bistPoints!.first.close;
    if (bistFirst <= 0) return null;
    final spots = <FlSpot>[];
    var lastBist = bistFirst;
    for (var i = 0; i < widget.points.length; i++) {
      final day = widget.points[i].timestamp ~/ 86400;
      var bistClose = bistByDay[day];
      if (bistClose == null || bistClose <= 0) {
        final nearest = bistByDay.keys.where((d) => (d - day).abs() <= 7).toList();
        nearest.sort((a, b) => (a - day).abs().compareTo((b - day).abs()));
        bistClose = nearest.isNotEmpty ? bistByDay[nearest.first]! : lastBist;
      }
      if (bistClose > 0) lastBist = bistClose;
      spots.add(FlSpot(i.toDouble(), 100 * lastBist / bistFirst));
    }
    return spots;
  }

  int _closestPointIndex(DateTime txDate) {
    final txDay = txDate.millisecondsSinceEpoch ~/ 86400000;
    var best = 0;
    var bestDiff = 999999;
    for (var i = 0; i < widget.points.length; i++) {
      final d = (widget.points[i].timestamp ~/ 86400 - txDay).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final ilk = points.first.close;
    final son = points.last.close;
    final karda = son >= ilk;
    final lineColor = karda ? AppTheme.success : AppTheme.softRed;
    final gradientColors = [
      lineColor.withValues(alpha: 0.4),
      lineColor.withValues(alpha: 0.05),
    ];

    final ref = points.first.close;
    final spots = points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), 100 * e.value.close / ref)).toList();
    final bistSpots = _bistSpotsNormalized();

    // MA15 ve MA50 (100 bazlı)
    final ma15 = <FlSpot>[];
    final ma50 = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      if (i >= 14) {
        double sum = 0;
        for (var j = i - 14; j <= i; j++) sum += points[j].close;
        ma15.add(FlSpot(i.toDouble(), 100 * (sum / 15) / ref));
      }
      if (i >= 49) {
        double sum = 0;
        for (var j = i - 49; j <= i; j++) sum += points[j].close;
        ma50.add(FlSpot(i.toDouble(), 100 * (sum / 50) / ref));
      }
    }

    // İşlem noktaları (alım: yeşil aşağı ok, satım: kırmızı yukarı ok)
    final buySpots = <FlSpot>[];
    final sellSpots = <FlSpot>[];
    final transByIndex = <int, TransactionRow>{};
    for (final tx in widget.transactions) {
      if (tx.transactionType != 'buy' && tx.transactionType != 'sell') continue;
      final idx = _closestPointIndex(tx.createdAt);
      if (idx < 0 || idx >= points.length) continue;
      final y = 100 * points[idx].close / ref;
      transByIndex[idx] = tx;
      if (tx.transactionType == 'buy') {
        buySpots.add(FlSpot(idx.toDouble(), y));
      } else {
        sellSpots.add(FlSpot(idx.toDouble(), y));
      }
    }

    final allY = <double>[...spots.map((s) => s.y)];
    if (bistSpots != null) allY.addAll(bistSpots.map((s) => s.y));
    if (ma15.isNotEmpty) allY.addAll(ma15.map((s) => s.y));
    if (ma50.isNotEmpty) allY.addAll(ma50.map((s) => s.y));
    final minY = (allY.reduce((a, b) => a < b ? a : b) * 0.995);
    final maxY = (allY.reduce((a, b) => a > b ? a : b) * 1.005);

    final titlesData = FlTitlesData(
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, meta) => Text('${NumberFormat('#,##0', 'tr_TR').format(v)}%', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade600)))),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 0)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 20,
          interval: (points.length / 4).ceilToDouble(),
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= points.length) return const SizedBox();
            final dt = DateTime.fromMillisecondsSinceEpoch(points[i].timestamp * 1000);
            return Text(DateFormat('d MMM', 'tr_TR').format(dt), style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade600));
          },
        ),
      ),
    );

    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: lineColor,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: gradientColors)),
      ),
    ];
    const bistColor = Colors.orange;
    if (bistSpots != null && bistSpots.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: bistSpots,
        isCurved: true,
        color: bistColor,
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    if (ma15.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: ma15,
        isCurved: true,
        color: Colors.blue,
        barWidth: 1.2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    if (ma50.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: ma50,
        isCurved: true,
        color: Colors.purple,
        barWidth: 1.2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }
    if (buySpots.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: buySpots,
        isCurved: false,
        color: Colors.transparent,
        barWidth: 0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => _ArrowDotPainter(isBuy: true),
        ),
        belowBarData: BarAreaData(show: false),
      ));
    }
    if (sellSpots.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: sellSpots,
        isCurved: false,
        color: Colors.transparent,
        barWidth: 0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => _ArrowDotPainter(isBuy: false),
        ),
        belowBarData: BarAreaData(show: false),
      ));
    }

    final chartData = LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 0.5)),
      titlesData: titlesData,
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (points.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      lineBarsData: lineBars,
      lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchSpotThreshold: 24,
          touchCallback: (event, response) {
            if (response?.lineBarSpots == null || response!.lineBarSpots!.isEmpty) {
              setState(() => _selectedTransaction = null);
              return;
            }
            final touched = response.lineBarSpots!.first;
            final idx = touched.x.toInt();
            final tx = transByIndex[idx];
            setState(() => _selectedTransaction = tx);
          },
          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
            final isHisseBar = barData.color == lineColor;
            final noLine = FlLine(color: Colors.transparent, strokeWidth: 0);
            return spotIndexes.map((index) {
              if (isHisseBar) {
                return TouchedSpotIndicatorData(
                  noLine,
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bd, i) => _TouchPulseDotPainter(
                      color: lineColor,
                      strokeColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                );
              }
              return TouchedSpotIndicatorData(noLine, const FlDotData(show: false));
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return [];
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final tooltipStyle = TextStyle(
                fontSize: 11,
                color: isDark ? Colors.black87 : Colors.black87,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              );
              return touchedSpots.map((spot) {
                // fl_chart touchedSpots ve tooltipItems listelerinin boyutunu birebir ister.
                final i = spot.x.toInt();
                final isMainPriceLine = spot.barIndex == 0;
                if (!isMainPriceLine || i < 0 || i >= points.length) {
                  return null;
                }
                final p = points[i];
                final dt = DateTime.fromMillisecondsSinceEpoch(p.timestamp * 1000);
                final fmt = NumberFormat('#,##0.##', 'tr_TR');
                final text = 'Tarih: ${DateFormat('yyyy-MM-dd', 'tr_TR').format(dt)}\n'
                    'Açılış: ${fmt.format(p.open)}\n'
                    'Kapanış: ${fmt.format(p.close)}\n'
                    'Düşük: ${fmt.format(p.low)}\n'
                    'Yüksek: ${fmt.format(p.high)}\n'
                    'Değişim: %${p.changePercent.toStringAsFixed(2)}';
                return LineTooltipItem(text, tooltipStyle, textAlign: TextAlign.left);
              }).toList();
            },
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            tooltipMargin: 10,
            maxContentWidth: 150,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            showOnTopOfTheChartBoxArea: true,
            tooltipBorder: BorderSide(color: Colors.grey.shade400, width: 1),
            getTooltipColor: (spot) => Colors.white,
          ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final chartH = bistSpots != null ? constraints.maxHeight - 28 : constraints.maxHeight;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bistSpots != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _LegendDot(color: lineColor, label: 'Hisse'),
                    const SizedBox(width: 16),
                    _LegendDot(color: Colors.orange, label: 'BIST100'),
                    if (ma15.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      _LegendDot(color: Colors.blue, label: 'MA15'),
                    ],
                    if (ma50.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      _LegendDot(color: Colors.purple, label: 'MA50'),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: SizedBox(
                width: w,
                height: chartH,
                child: LineChart(chartData, duration: const Duration(milliseconds: 200)),
              ),
            ),
            if (_selectedTransaction != null) _buildTransactionTooltip(_selectedTransaction!),
          ],
        );
      },
    );
  }

  Widget _buildTransactionTooltip(TransactionRow tx) {
    final fmt = NumberFormat('#,##0.##', 'tr_TR');
    final isSell = tx.transactionType == 'sell';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isSell ? 'Satış' : 'Alım',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isSell ? AppTheme.softRed : AppTheme.success,
            ),
          ),
          const SizedBox(height: 4),
          Text('Adet: ${fmt.format(tx.quantity ?? 0)}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
          Text('Fiyat: ${fmt.format(tx.price)} ₺', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
          Text('Tarih: ${DateFormat('dd.MM.yyyy', 'tr_TR').format(tx.createdAt)}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
          if (isSell && tx.satisKarYuzde != null)
            Text(
              'Kar %: ${tx.satisKarYuzde! >= 0 ? '+' : ''}${fmt.format(tx.satisKarYuzde)}%',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: tx.satisKarYuzde! >= 0 ? AppTheme.success : AppTheme.softRed),
            ),
        ],
      ),
    );
  }
}

/// Alım (aşağı yeşil ok) / Satım (yukarı kırmızı ok) noktası çizer.
class _ArrowDotPainter extends FlDotPainter {
  final bool isBuy;

  _ArrowDotPainter({required this.isBuy});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final color = isBuy ? AppTheme.success : AppTheme.softRed;
    final path = Path();
    const w = 8.0;
    const h = 10.0;
    if (isBuy) {
      path.moveTo(offsetInCanvas.dx, offsetInCanvas.dy - h / 2);
      path.lineTo(offsetInCanvas.dx - w / 2, offsetInCanvas.dy + h / 2);
      path.lineTo(offsetInCanvas.dx, offsetInCanvas.dy + h / 2 - 2);
      path.lineTo(offsetInCanvas.dx + w / 2, offsetInCanvas.dy + h / 2);
      path.close();
    } else {
      path.moveTo(offsetInCanvas.dx, offsetInCanvas.dy + h / 2);
      path.lineTo(offsetInCanvas.dx - w / 2, offsetInCanvas.dy - h / 2);
      path.lineTo(offsetInCanvas.dx, offsetInCanvas.dy - h / 2 + 2);
      path.lineTo(offsetInCanvas.dx + w / 2, offsetInCanvas.dy - h / 2);
      path.close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  Size getSize(FlSpot spot) => const Size(16, 20);

  @override
  List<Object?> get props => [isBuy];

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  bool hitTest(FlSpot spot, Offset touched, Offset center, double extraThreshold) {
    return (touched - center).distance <= 20;
  }

  @override
  Color get mainColor => isBuy ? AppTheme.success : AppTheme.softRed;
}

/// Dokunulan noktada pulse/halka etkili tek nokta çizer (grafikte ekstra çizgi yok).
class _TouchPulseDotPainter extends FlDotPainter {
  final Color color;
  final Color strokeColor;

  _TouchPulseDotPainter({required this.color, required this.strokeColor});

  static const double _innerRadius = 5;
  static const double _strokeWidth = 2.5;
  static const double _outerRingRadius = 11;
  static const double _outerRingStroke = 2;

  @override
  List<Object?> get props => [color, strokeColor];

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final center = offsetInCanvas;
    // Dış halka (pulse)
    final outerPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _outerRingStroke;
    canvas.drawCircle(center, _outerRingRadius, outerPaint);
    // İç nokta: stroke + dolgu
    final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(center, _innerRadius, fillPaint);
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawCircle(center, _innerRadius, strokePaint);
  }

  @override
  Size getSize(FlSpot spot) {
    final r = _outerRingRadius + _outerRingStroke;
    return Size(r * 2, r * 2);
  }

  @override
  bool hitTest(FlSpot spot, Offset touched, Offset center, double extraThreshold) {
    final threshold = _outerRingRadius + extraThreshold;
    return (touched - center).distance <= threshold;
  }

  @override
  Color get mainColor => color;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _OzetKartVeri {
  final String id;
  final String baslik;
  final String deger;
  _OzetKartVeri({required this.id, required this.baslik, required this.deger});
}

class _VeriKutusu extends StatelessWidget {
  final String baslik;
  final String deger;

  const _VeriKutusu({required this.baslik, required this.deger});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            baslik,
            style: AppTheme.bodySmall(context).copyWith(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            deger,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkSlate,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DuzenlenebilirVeriKutusu extends StatelessWidget {
  final _OzetKartVeri veri;
  final int index;
  final VoidCallback onSil;
  final void Function(int eskiIndex, int yeniIndex) onYerDegistir;

  const _DuzenlenebilirVeriKutusu({
    super.key,
    required this.veri,
    required this.index,
    required this.onSil,
    required this.onYerDegistir,
  });

  Widget _kutuIcerik(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _VeriKutusu(baslik: veri.baslik, deger: veri.deger),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: AppTheme.softRed,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onSil,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.remove, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.of(context).size.width - 40 - 12) / 2;
    return LongPressDraggable<int>(
      data: index,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: cardWidth,
          child: Opacity(opacity: 0.9, child: _kutuIcerik(context)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: _kutuIcerik(context)),
      child: DragTarget<int>(
        onAcceptWithDetails: (d) {
          if (d.data != index) onYerDegistir(d.data, index);
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: candidateData.isNotEmpty ? Border.all(color: AppTheme.navyBlue, width: 2) : null,
            ),
            child: _kutuIcerik(context),
          );
        },
      ),
    );
  }
}
