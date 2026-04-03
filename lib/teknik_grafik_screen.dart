import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class TeknikGrafikScreen extends StatefulWidget {
  const TeknikGrafikScreen({
    super.key,
    required this.symbol,
    this.name,
  });

  final String symbol;
  final String? name;

  @override
  State<TeknikGrafikScreen> createState() => _TeknikGrafikScreenState();
}

class _TeknikGrafikScreenState extends State<TeknikGrafikScreen> {
  WebViewController? _controller;
  bool _yukleniyor = true;
  late final bool _isDarkTheme;
  String _interval = 'D';
  String _resolvedSymbol = '';

  static const _bgDark = Color(0xFF131722);
  static const _bgLight = Color(0xFFFFFFFF);

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static const _periods = [
    _Period('15dk', '15'),
    _Period('1sa', '60'),
    _Period('4sa', '240'),
    _Period('1G', 'D'),
    _Period('1H', 'W'),
    _Period('1A', 'M'),
  ];

  // CSS Güncellemesi:
  // 1. Sağ panel boşluğunu kapatmak için .layout__area--right gizlendi.
  // 2. Dialog/Popup/Menu gizlemeleri kaldırıldı (Ayarlar ve Para birimi çalışsın diye).
  // 3. Sadece Header, Footer ve Reklamlar hedeflendi.
  static const _hideUiCss = r'''
    /* --- GİZLENECEKLER --- */
    
    /* Header ve Footer */
    header, footer, .tv-header, .tv-footer,
    [class*="header-"], [class*="footer-"],
    [data-name="header"], [data-name="footer"],
    
    /* Yan Paneller (Watchlist, Haberler vb. - Sağ boşluğun nedeni) */
    .tv-side-panel, .tv-side-toolbar,
    .layout__area--left, .layout__area--right, .layout__area--bottom,
    [class*="sidebar-"], [class*="widgetbar-"],
    
    /* Toolbarlar (Üst ve Alt) */
    .tv-main-panel__toolbar, .tv-floating-toolbar,
    [class*="toolbar-"], [data-name="toolbar"],
    #header-toolbar-intervals, #header-toolbar-properties,
    
    /* Reklam / Banner / Premium Uyarıları */
    .tv-header__banner, .js-banner, [class*="promotion"],
    [class*="trial-"], [class*="go-pro-"],
    button[aria-label="Open in App"],
    [class*="toast-"], /* Sol alt uyarılar */
    
    /* Sağ alt yardım butonu */
    [class*="help-"], [data-name="help-button"]
    { display: none !important; }

    /* --- DÜZENLEMELER --- */

    /* Sayfa yapısını tam ekran yap */
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      overflow: hidden !important;
      background-color: transparent !important;
    }

    /* Grafik alanını TAM ekran yap */
    #tv_chart_container, .chart-container, .layout__area--center, .chart-widget {
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      right: 0 !important;
      bottom: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      z-index: 0 !important; /* Popup'ların altında kalsın */
      margin: 0 !important;
      padding: 0 !important;
    }

    /* Popup, Dialog ve Menülerin (Ayarlar, Para Birimi) görünür olmasını sağla */
    [class*="dialog-"], [class*="popup-"], [class*="menu-"], [class*="overlap-"] {
      display: block !important; 
      z-index: 9999 !important; /* En üstte */
    }

    /* Sol Üst Bilgi Paneli Konumu */
    .chart-widget__top--left, .legend--visible {
      margin-top: 10px !important;
      margin-left: 50px !important;
      transform: scale(0.9);
      transform-origin: top left;
      z-index: 10 !important;
    }
  ''';

  @override
  void initState() {
    super.initState();
    _isDarkTheme =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initializeChart();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── Sembol ───────────────────────────────────────────────────────────────

  static String _bare(String symbol) {
    var s = symbol.trim().toUpperCase();
    if (s.startsWith('BIST:')) s = s.substring(5);
    if (s.endsWith('.IS')) s = s.substring(0, s.length - 3);
    s = s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return s.isEmpty ? 'XU100' : s;
  }

  Future<void> _initializeChart() async {
    final bare = _bare(widget.symbol);
    String? found = await _searchBistSymbol(bare, exact: bare);
    
    if (found == null && widget.name != null) {
      final firstToken = widget.name!.trim().split(RegExp(r'\s+')).first;
      found = await _searchBistSymbol(firstToken);
    }

    setState(() {
      _resolvedSymbol = found ?? 'BIST:$bare';
    });

    _loadWebView();
  }

  Future<String?> _searchBistSymbol(String query, {String? exact}) async {
    if (query.isEmpty) return null;
    try {
      final uri = Uri.https(
        'symbol-search.tradingview.com',
        '/symbol_search/',
        {'text': query, 'exchange': 'BIST', 'lang': 'tr', 'domain': 'production'},
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final list = jsonDecode(resp.body);
      if (list is! List) return null;

      String? firstMatch;
      final exactUpper = exact?.toUpperCase();

      for (final item in list) {
        final exch = (item['exchange'] ?? '').toString().toUpperCase();
        if (exch != 'BIST') continue;
        final full = (item['full_name'] ?? '').toString().toUpperCase();
        final sym = (item['symbol'] ?? '').toString().toUpperCase();
        if (exactUpper != null && sym == exactUpper) return full;
        firstMatch ??= full;
      }
      return firstMatch;
    } catch (_) {
      return null;
    }
  }

  // ── WebView ───────────────────────────────────────────────────────────────

  void _loadWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_isDarkTheme ? _bgDark : _bgLight)
      ..setUserAgent(_userAgent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          await _injectCss();
          Future.delayed(const Duration(milliseconds: 1500), _injectCss);
          if (mounted) setState(() => _yukleniyor = false);
        },
      ));

    final uri = _buildUrl(_resolvedSymbol, _interval);
    controller.loadRequest(uri, headers: {'Accept-Language': 'tr-TR'});

    if (mounted) setState(() => _controller = controller);
  }

  Uri _buildUrl(String symbol, String interval) {
    return Uri.https('www.tradingview.com', '/chart/', {
      'symbol': symbol,
      'interval': interval,
      'theme': _isDarkTheme ? 'dark' : 'light',
      'timezone': 'Europe/Istanbul',
      'hide_side_toolbar': '1',
    });
  }

  Future<void> _injectCss() async {
    if (_controller == null) return;
    const js = "var style = document.createElement('style');"
        "style.innerHTML = `$_hideUiCss`;"
        "document.head.appendChild(style);";
    try {
      await _controller!.runJavaScript(js);
    } catch (_) {}
  }

  void _changeInterval(String interval) {
    if (_interval == interval || _controller == null) return;
    setState(() {
      _interval = interval;
      _yukleniyor = true;
    });
    final uri = _buildUrl(_resolvedSymbol, interval);
    _controller!.loadRequest(uri);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg = _isDarkTheme ? _bgDark : _bgLight;
    final fg = _isDarkTheme ? Colors.white : Colors.black87;
    final barBg = (_isDarkTheme ? const Color(0xFF1E222D) : Colors.grey.shade100)
        .withValues(alpha: 0.9);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: _controller == null
                ? const SizedBox.shrink()
                : WebViewWidget(controller: _controller!),
          ),

          if (_yukleniyor)
            Positioned.fill(
              child: Container(
                color: bg,
                child: Center(
                  child: CircularProgressIndicator(color: fg),
                ),
              ),
            ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                color: barBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, size: 18, color: fg),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _periods.map((p) {
                        final isSelected = _interval == p.val;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => _changeInterval(p.val),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (_isDarkTheme
                                          ? Colors.white24
                                          : Colors.black12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  p.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? fg
                                        : fg.withValues(alpha: 0.6),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Period {
  final String label;
  final String val;
  const _Period(this.label, this.val);
}
