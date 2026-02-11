import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'logo_service.dart';
import 'models/is_yatirim_model.dart';
import 'teknik_grafik_screen.dart';
import 'services/favori_hisse_service.dart';
import 'services/finansal_ozet_metrik_service.dart';
import 'services/is_yatirim_service.dart';
import 'stock_logo.dart';
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
  bool _yukleniyor = true;
  bool _isYatirimYukleniyor = true;
  String? _hata;
  List<String> _ozetMetrikler = List.from(defaultFinansalOzetMetrikler);
  bool _ozetDuzenlemeModu = false;
  bool _isFavori = false;
  Timer? _yenilemeTimer;

  @override
  void initState() {
    super.initState();
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
        if (mounted) setState(() => _previousCloseOverride = v);
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
        if (mounted) setState(() => _previousCloseOverride = v);
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _isYatirimYukleniyor = false;
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
    final cur = AppTheme.currencyDisplay(meta?.currency);
    final effectivePrev = _previousCloseOverride ?? meta?.previousClose;
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
          final price = data?.sonFiyat ?? meta?.price;
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
        case 'f_k':
          deger = data?.fK != null ? _formatSayi(data!.fK) : '—';
          break;
        case 'pd_dd':
          deger = data?.pdDd != null ? _formatSayi(data!.pdDd) : '—';
          break;
        case 'piyasa_degeri':
          deger = data?.piyasaDegeri != null ? '${_formatHacim(data!.piyasaDegeri)} $cur' : '—';
          break;
        case 'net_kar':
          deger = data?.netKar != null ? _formatHacim(data!.netKar) : '—';
          break;
        case 'temettu_verimi':
          deger = data?.temettuVerimi != null ? '${_formatSayi(data!.temettuVerimi)}%' : '—';
          break;
        default:
          continue;
      }
      if (baslik != null && deger != null) {
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
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
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
                          const SizedBox(height: 20),
                          _AIAnalizButton(meta: _meta!),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Fiyat Grafiği',
                                style: AppTheme.h2(context),
                              ),
                              Material(
                                color: AppTheme.navyBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
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
                                        Text(
                                          'Teknik',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.navyBlue,
                                          ),
                                        ),
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
                            child: _FiyatGrafikWidget(symbol: widget.symbol, name: widget.name ?? _meta?.longName),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Finansal Özet',
                                style: AppTheme.h2(context),
                              ),
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
                          _isYatirimYukleniyor
                              ? Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: AppTheme.cardDecoration(context),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.navyBlue,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Veriler yükleniyor...',
                                        style: AppTheme.body(context).copyWith(color: Colors.grey.shade600),
                                      ),
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
                                              style: TextButton.styleFrom(
                                                foregroundColor: AppTheme.navyBlue,
                                              ),
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
                                          onLongPress: () {
                                            setState(() => _ozetDuzenlemeModu = true);
                                          },
                                          child: _VeriKutusu(baslik: v.baslik, deger: v.deger),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
    );
  }
}

/// AI Analiz Et butonu – parlayan glow, bottom sheet açar
class _AIAnalizButton extends StatelessWidget {
  final StockChartMeta meta;

  const _AIAnalizButton({required this.meta});

  @override
  Widget build(BuildContext context) {
    final prev = meta.previousClose ?? 0;
    final changePercent = prev > 0
        ? ((meta.price - prev) / prev) * 100
        : 0.0;
    final volume = meta.regularMarketVolume ?? 0.0;

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

/// Çizgisel fiyat grafiği – dokunma ile tooltip, zaman aralığı seçici
class _FiyatGrafikWidget extends StatefulWidget {
  final String symbol;
  final String? name;

  const _FiyatGrafikWidget({required this.symbol, this.name});

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
                    : _GrafikIcerik(points: _points!, bistPoints: _bist100Points),
          ),
        ],
      ),
    );
  }
}

class _GrafikIcerik extends StatelessWidget {
  final List<ChartOHLCPoint> points;
  final List<ChartOHLCPoint>? bistPoints;

  const _GrafikIcerik({required this.points, this.bistPoints});

  /// BIST verisini hisse tarihlerine hizalayıp normalize (100 bazlı) değerler üretir.
  /// Her hisse indeksi için bir spot döner (eksik günlerde bir önceki değer kullanılır).
  List<FlSpot>? _bistSpotsNormalized() {
    if (bistPoints == null || bistPoints!.isEmpty) return null;
    final bistByDay = <int, double>{};
    for (final p in bistPoints!) {
      bistByDay[p.timestamp ~/ 86400] = p.close;
    }
    final bistFirst = bistPoints!.first.close;
    if (bistFirst <= 0) return null;
    final spots = <FlSpot>[];
    var lastBist = bistFirst;
    for (var i = 0; i < points.length; i++) {
      final day = points[i].timestamp ~/ 86400;
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

  @override
  Widget build(BuildContext context) {
    final ilk = points.first.close;
    final son = points.last.close;
    final karda = son >= ilk;
    final lineColor = karda ? AppTheme.success : AppTheme.softRed;
    final gradientColors = [
      lineColor.withValues(alpha: 0.4),
      lineColor.withValues(alpha: 0.05),
    ];

    // Hisse: normalize 100 bazlı (karşılaştırma için)
    final ref = points.first.close;
    final spots = points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), 100 * e.value.close / ref)).toList();
    final bistSpots = _bistSpotsNormalized();

    final allY = <double>[...spots.map((s) => s.y)];
    if (bistSpots != null) allY.addAll(bistSpots.map((s) => s.y));
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
              final lineBarSpot = touchedSpots.first;
              final i = lineBarSpot.x.toInt();
              if (i < 0 || i >= points.length) return [];
              final p = points[i];
              final dt = DateTime.fromMillisecondsSinceEpoch(p.timestamp * 1000);
              final fmt = NumberFormat('#,##0.##', 'tr_TR');
              final text = 'Tarih: ${DateFormat('yyyy-MM-dd', 'tr_TR').format(dt)}\n'
                  'Açılış: ${fmt.format(p.open)}\n'
                  'Kapanış: ${fmt.format(p.close)}\n'
                  'Düşük: ${fmt.format(p.low)}\n'
                  'Yüksek: ${fmt.format(p.high)}\n'
                  'Değişim: %${p.changePercent.toStringAsFixed(2)}';
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return [
                LineTooltipItem(
                  text,
                  TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.black87 : Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                  textAlign: TextAlign.left,
                ),
              ];
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
          ],
        );
      },
    );
  }
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
