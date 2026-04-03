import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'crypto_detail_screen.dart';
import 'crypto_theme.dart';
import 'logo_service.dart';
import 'services/app_mode_service.dart';
import 'services/theme_service.dart';
import 'models/crypto_coin.dart';
import 'services/crypto_service.dart';
import 'services/favori_hisse_service.dart';
import 'stock_detail_screen.dart';
import 'stock_logo.dart';
import 'widgets/ai_analysis_bottom_sheet.dart';
import 'widgets/crypto_logo.dart';
import 'login_page.dart';
import 'yahoo_finance_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ana sayfa: Hisse | Crypto toggle, Bugün, BIST/crypto piyasası, hisse/kripto ara.
class AnaSayfaPage extends StatefulWidget {
  const AnaSayfaPage({super.key});

  @override
  State<AnaSayfaPage> createState() => _AnaSayfaPageState();
}

class _AnaSayfaPageState extends State<AnaSayfaPage> {

  static const _piyasaSembolleri = [
    ('BIST100', 'XU100.IS'),
    ('BIST30', 'XU030.IS'),
    ('USD/TRY', 'USDTRY=X'),
    ('EUR/TRY', 'EURTRY=X'),
    ('Altın', 'GC=F'),
    ('Gümüş', 'SI=F'),
  ];

  /// BIST 30 endeks hisse sembolleri
  static const _bist30Sembolleri = [
    'AKBNK', 'AEFES', 'ARCLK', 'ASELS', 'BIMAS', 'DOAS', 'EKGYO', 'EREGL',
    'ENKAI', 'FROTO', 'GARAN', 'GUBRF', 'HALKS', 'ISCTR', 'KCHOL', 'KONTR',
    'KOZAA', 'KOZAL', 'PETKM', 'SASA', 'SAHOL', 'SISE', 'SNGKM', 'TCELL',
    'THYAO', 'TKFEN', 'TOASO', 'TSKB', 'TUPRS', 'YKBNK',
  ];

  List<StockChartMeta?> _piyasaMetas = List.filled(6, null);
  bool _piyasaYukleniyor = true;
  List<StockChartMeta> _bist30Liste = [];
  bool _bist30Yukleniyor = true;
  Set<String> _favoriSet = {};
  Timer? _yenilemeTimer;

  // Kripto modu
  List<CryptoCoin> _cryptoListe = [];
  bool _cryptoYukleniyor = true;
  Timer? _cryptoTimer;

  @override
  void initState() {
    super.initState();
    _piyasaYukle();
    _bist30Yukle();
    _cryptoYukle();
    _yenilemeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !AppModeService.isCrypto) {
        _piyasaYukle(sessiz: true);
        _bist30Yukle(sessiz: true);
      }
    });
    _cryptoTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && AppModeService.isCrypto) _cryptoYukle(sessiz: true);
    });
  }

  @override
  void dispose() {
    _yenilemeTimer?.cancel();
    _cryptoTimer?.cancel();
    super.dispose();
  }

  Future<void> _cryptoYukle({bool sessiz = false}) async {
    if (!sessiz) setState(() => _cryptoYukleniyor = true);
    final liste = await CryptoService.getCryptoMarket();
    if (mounted) {
      setState(() {
        _cryptoListe = liste;
        _cryptoYukleniyor = false;
      });
    }
  }

  Future<void> _piyasaYukle({bool sessiz = false}) async {
    if (!sessiz) setState(() => _piyasaYukleniyor = true);
    final sonuclar = await Future.wait(
      _piyasaSembolleri.map((e) => YahooFinanceService.chartMetaAlSymbol(e.$2)),
    );
    if (mounted) {
      setState(() {
        _piyasaMetas = sonuclar;
        _piyasaYukleniyor = false;
      });
    }
  }

  Future<void> _bist30Yukle({bool sessiz = false}) async {
    if (!mounted) return;
    if (!sessiz) setState(() => _bist30Yukleniyor = true);
    final metas = <StockChartMeta>[];
    Set<String> favoriSet = {};
    try {
      final favoriler = await FavoriHisseService.getFavoriler();
      favoriSet = favoriler.map((s) => s.toUpperCase()).toSet();
      final bist30Set = _bist30Sembolleri.map((s) => s.toUpperCase()).toSet();
      for (var i = 0; i < _bist30Sembolleri.length; i += 8) {
        if (!mounted) return;
        final batch = _bist30Sembolleri.skip(i).take(8).toList();
        final batchSonuc = await Future.wait(
          batch.map((s) => YahooFinanceService.hisseChartMetaAl(s).catchError((_) => null)),
        );
        for (final m in batchSonuc) {
          if (m != null) metas.add(m);
        }
      }
      // BIST30 dışı favorileri yükle (en üstte göstermek için)
      final favoriDisinda = favoriler.where((s) => !bist30Set.contains(s.toUpperCase())).toList();
      final disariMetas = <StockChartMeta>[];
      for (final s in favoriDisinda) {
        if (!mounted) return;
        try {
          final m = await YahooFinanceService.hisseChartMetaAl(s);
          if (m != null) disariMetas.add(m);
        } catch (_) {}
      }
      metas.insertAll(0, disariMetas);
      // Sıra: 1) Favoriler (önce BIST30 dışı favoriler, sonra BIST30 favorileri index sırasına göre), 2) Diğer BIST30
      final symbolToIndex = {for (var i = 0; i < _bist30Sembolleri.length; i++) _bist30Sembolleri[i]: i};
      metas.sort((a, b) {
        final aSym = a.symbol.toUpperCase().replaceAll('.IS', '');
        final bSym = b.symbol.toUpperCase().replaceAll('.IS', '');
        final aFav = favoriSet.contains(aSym) ? 0 : 1;
        final bFav = favoriSet.contains(bSym) ? 0 : 1;
        if (aFav != bFav) return aFav.compareTo(bFav);
        final aBist = bist30Set.contains(aSym) ? 1 : 0;
        final bBist = bist30Set.contains(bSym) ? 1 : 0;
        if (aBist != bBist) return aBist.compareTo(bBist);
        return (symbolToIndex[aSym] ?? 999).compareTo(symbolToIndex[bSym] ?? 999);
      });
    } catch (_) {
      // Hata olsa da yükleme ekranı kapansın
    }
    if (mounted) {
      setState(() {
        _bist30Liste = metas;
        _favoriSet = favoriSet;
        _bist30Yukleniyor = false;
      });
    }
  }

  void _hisseDetayaGit(String symbol, String? name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StockDetailScreen(
          symbol: symbol,
          name: name,
        ),
      ),
    ).then((_) {
      if (mounted) _bist30Yukle(sessiz: true);
    });
  }

  void _cryptoDetayaGit(CryptoCoin coin) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CryptoDetailScreen(coin: coin),
      ),
    ).then((_) {
      if (mounted) _cryptoYukle(sessiz: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppModeService.instance.cryptoMode,
      builder: (context, cryptoMode, _) {
        final bgColor = cryptoMode
            ? CryptoTheme.backgroundGrey(context)
            : AppTheme.backgroundGrey(context);

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Hisse'), icon: Icon(Icons.bar_chart_rounded, size: 18)),
                            ButtonSegment(value: true, label: Text('Crypto'), icon: Icon(Icons.currency_bitcoin_rounded, size: 18)),
                          ],
                          selected: {cryptoMode},
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return cryptoMode ? CryptoTheme.cryptoAmber : AppTheme.smokyJade;
                              }
                              return null;
                            }),
                          ),
                          onSelectionChanged: (Set<bool> v) {
                            AppModeService.instance.setCryptoMode(v.first);
                            setState(() {});
                          },
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return IconButton(
                            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 24),
                            tooltip: isDark ? 'Açık tema' : 'Koyu tema',
                            onPressed: () => ThemeService.instance.toggleDarkLight(context),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 24),
                        tooltip: 'Oturumu Kapat',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Oturumu Kapat'),
                              content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(backgroundColor: AppTheme.softRed),
                                  child: const Text('Çıkış Yap'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          await Supabase.instance.client.auth.signOut();
                          if (!context.mounted) return;
                          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: cryptoMode ? _buildCryptoContent(context) : _buildHisseContent(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHisseContent(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth > 0 ? (screenWidth - 40 - 20) / 3 : 100.0;
    final cardHeight = cardWidth / 1.5;
    final gridHeight = 2 * cardHeight + 10;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bugün',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  Supabase.instance.client.auth.currentUser?.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _piyasaYukleniyor
                    ? SizedBox(
                        height: gridHeight.clamp(120.0, 200.0),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navyBlue),
                        ),
                      )
                    : SizedBox(
                        height: gridHeight,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(6, (i) {
                            final label = _piyasaSembolleri[i].$1;
                            final meta = _piyasaMetas[i];
                            return SizedBox(
                              width: cardWidth,
                              height: cardHeight,
                              child: _PiyasaKarti(
                                label: label,
                                meta: meta,
                              ),
                            );
                          }),
                        ),
                      ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'BIST 30 Hisseleri',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Autocomplete<HisseAramaSonucu>(
                optionsBuilder: (editingValue) {
                  final metin = editingValue.text.trim();
                  if (metin.length < 2) return Future.value([]);
                  return YahooFinanceService.hisseAraListele(metin);
                },
                displayStringForOption: (o) => '${LogoService.symbolForDisplay(o.sembol)} — ${o.goruntulenecekAd}',
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      TextInputFormatter.withFunction((old, replace) => TextEditingValue(
                        text: replace.text.toUpperCase(),
                        selection: replace.selection,
                      )),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Hisse ara',
                      hintText: 'THYAO, GARAN...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          if (value.text.isEmpty) return const SizedBox.shrink();
                          return IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => controller.clear(),
                            tooltip: 'Temizle',
                          );
                        },
                      ),
                    ),
                    onSubmitted: (_) => onFieldSubmitted(),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final opt = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                onSelected(opt);
                                _hisseDetayaGit(opt.sembol, opt.goruntulenecekAd);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    StockLogo(symbol: opt.sembol, size: 36),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            LogoService.symbolForDisplay(opt.sembol),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            opt.goruntulenecekAd,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                onSelected: (opt) {
                  _hisseDetayaGit(opt.sembol, opt.goruntulenecekAd);
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_bist30Yukleniyor)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navyBlue)),
              ),
            )
          else if (_bist30Liste.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'BIST 30 hisseleri yüklenemedi.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _bist30Yukle,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Yeniden dene'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.navyBlue),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final meta = _bist30Liste[index];
                  final fmt = NumberFormat('#,##0.##', 'tr_TR');
                  final curSym = AppTheme.currencyDisplay(meta.currency);
                  final fiyatStr = '${fmt.format(meta.price)} $curSym';
                  final prev = meta.previousClose ?? 0.0;
                  final changePercent = prev > 0
                      ? ((meta.price - prev) / prev) * 100
                      : 0.0;
                  final volume = meta.regularMarketVolume ?? 0.0;
                  final symKey = meta.symbol.toUpperCase().replaceAll('.IS', '');
                  final isFavori = _favoriSet.contains(symKey);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _hisseDetayaGit(meta.symbol, meta.longName),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  StockLogo(symbol: meta.symbol, size: 44),
                                  if (isFavori)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Icon(Icons.star_rounded, color: Colors.amber[700], size: 20),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      LogoService.symbolForDisplay(meta.symbol),
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      meta.longName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    fiyatStr,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppTheme.navyBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: changePercent >= 0 ? AppTheme.success : AppTheme.softRed,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.auto_awesome,
                                  size: 20,
                                  color: AppTheme.smokyJade,
                                ),
                                onPressed: () {
                                  showAIAnalysisBottomSheet(
                                    context,
                                    symbol: meta.symbol,
                                    price: meta.price,
                                    volume: volume,
                                    changePercent: changePercent,
                                  );
                                },
                                tooltip: 'AI Analiz',
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _bist30Liste.length,
              ),
            ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildCryptoContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kripto Piyasası',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: CryptoTheme.textPrimaryFor(context),
                  ),
                ),
                Text(
                  Supabase.instance.client.auth.currentUser?.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: CryptoTheme.textSecondaryFor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Autocomplete<CryptoCoin>(
              optionsBuilder: (editingValue) {
                final metin = editingValue.text.trim();
                if (metin.length < 2) return Future.value([]);
                return CryptoService.cryptoAra(metin);
              },
              displayStringForOption: (c) => '${c.displaySymbol} — \$${NumberFormat('#,##0.##', 'tr_TR').format(c.price)}',
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    TextInputFormatter.withFunction((old, replace) => TextEditingValue(
                      text: replace.text.toUpperCase(),
                      selection: replace.selection,
                    )),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Kripto ara',
                    hintText: 'BTC, ETH, SOL...',
                    filled: true,
                    fillColor: CryptoTheme.cardColor(context),
                    prefixIcon: Icon(Icons.search, color: CryptoTheme.cryptoAmber),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => controller.clear(),
                          tooltip: 'Temizle',
                        );
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(CryptoTheme.radius)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(CryptoTheme.radius),
                      borderSide: BorderSide(
                        color: CryptoTheme.textPrimaryFor(context).withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(CryptoTheme.radius),
                      borderSide: BorderSide(color: CryptoTheme.primaryElectric.withValues(alpha: 0.45)),
                    ),
                  ),
                  style: TextStyle(color: CryptoTheme.textPrimaryFor(context), fontWeight: FontWeight.w600),
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    color: CryptoTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(CryptoTheme.radius),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final coin = options.elementAt(index);
                          return InkWell(
                            onTap: () {
                              onSelected(coin);
                              _cryptoDetayaGit(coin);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  CryptoLogo(symbol: coin.symbol, size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          coin.displaySymbol,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: CryptoTheme.textPrimaryFor(context),
                                          ),
                                        ),
                                        Text(
                                          '\$${NumberFormat('#,##0.##', 'tr_TR').format(coin.price)}',
                                            style: TextStyle(
                                            fontSize: 12,
                                            color: CryptoTheme.textSecondaryFor(context),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${coin.changePercent >= 0 ? '+' : ''}${coin.changePercent.toStringAsFixed(2)}%',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: coin.changePercent >= 0
                                          ? CryptoTheme.positiveChange
                                          : CryptoTheme.negativeChange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              onSelected: (coin) => _cryptoDetayaGit(coin),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (_cryptoYukleniyor)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CryptoTheme.cryptoAmber,
                ),
              ),
            ),
          )
        else if (_cryptoListe.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 48, color: CryptoTheme.textSecondaryFor(context)),
                  const SizedBox(height: 16),
                  Text(
                    'Kripto verileri yüklenemedi.\nİnternet bağlantınızı kontrol edin.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CryptoTheme.textSecondaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _cryptoYukle,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Yeniden dene'),
                    style: TextButton.styleFrom(foregroundColor: CryptoTheme.cryptoAmber),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final coin = _cryptoListe[index];
                final fmt = NumberFormat('#,##0.##', 'tr_TR');
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Material(
                    color: CryptoTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _cryptoDetayaGit(coin),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            CryptoLogo(symbol: coin.symbol, size: 44),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Text(
                                coin.displaySymbol,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: CryptoTheme.textPrimaryFor(context),
                                ),
                              ),
                            ),
                            Text(
                              '\$${fmt.format(coin.price)}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: CryptoTheme.priceAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${coin.changePercent >= 0 ? '+' : ''}${coin.changePercent.toStringAsFixed(2)}%',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: coin.changePercent >= 0
                                    ? CryptoTheme.positiveChange
                                    : CryptoTheme.negativeChange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: _cryptoListe.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _PiyasaKarti extends StatelessWidget {
  final String label;
  final StockChartMeta? meta;

  const _PiyasaKarti({required this.label, required this.meta});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##', 'tr_TR');
    String? fiyatStr;
    double? degisimYuzde;
    if (meta != null) {
      fiyatStr = '${fmt.format(meta!.price)} ${AppTheme.currencyDisplay(meta!.currency)}';
      if (meta!.previousClose != null && meta!.previousClose! > 0) {
        degisimYuzde = ((meta!.price - meta!.previousClose!) / meta!.previousClose!) * 100;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                fiyatStr ?? '—',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (degisimYuzde != null) ...[
            const SizedBox(height: 2),
            Text(
              '${degisimYuzde >= 0 ? '+' : ''}${degisimYuzde.toStringAsFixed(2)}%',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: degisimYuzde >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
