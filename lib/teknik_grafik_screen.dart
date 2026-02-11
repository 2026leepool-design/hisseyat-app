import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Teknik analiz ekranı – TradingView grafiği, yatay (landscape) modda
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
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  /// Yahoo sembolünü TradingView formatına çevirir (örn. SASA.IS -> BIST:SASA)
  static String _tradingViewSymbol(String symbol) {
    final upper = symbol.toUpperCase().trim();
    if (upper.endsWith('.IS')) {
      return 'BIST:${upper.replaceAll('.IS', '')}';
    }
    return upper;
  }

  @override
  Widget build(BuildContext context) {
    final tvSymbol = _tradingViewSymbol(widget.symbol);
    final chartUrl = Uri.parse(
      'https://www.tradingview.com/chart/?symbol=${Uri.encodeComponent(tvSymbol)}',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      body: Stack(
        children: [
          // WebView tam ekran – altta kalan alanı maksimum kullanır
          Positioned.fill(
            child: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(chartUrl)
                ..setNavigationDelegate(
                  NavigationDelegate(onPageFinished: (_) {}),
                ),
            ),
          ),
          // Sol üstte küçük geri butonu (overlay)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
