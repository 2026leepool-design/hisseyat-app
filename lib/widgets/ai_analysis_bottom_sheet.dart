import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../crypto_theme.dart';
import '../services/ai_analysis_service.dart';

/// AI analiz bottom sheet: hisse veya kripto. [isCrypto] true ise kripto analizi ve crypto renk paleti kullanılır.
/// [stockContext] verilirse hisse analizinde 52w değişim, F/K, PD/DD, net kar, sektör, 15/52 gün ortalamaları prompt'a eklenir.
void showAIAnalysisBottomSheet(
  BuildContext context, {
  required String symbol,
  required double price,
  required double volume,
  required double changePercent,
  bool isCrypto = false,
  StockAnalysisContext? stockContext,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AIAnalysisSheet(
      symbol: symbol,
      price: price,
      volume: volume,
      changePercent: changePercent,
      isCrypto: isCrypto,
      stockContext: stockContext,
    ),
  );
}

class _AIAnalysisSheet extends StatefulWidget {
  final String symbol;
  final double price;
  final double volume;
  final double changePercent;
  final bool isCrypto;
  final StockAnalysisContext? stockContext;

  const _AIAnalysisSheet({
    required this.symbol,
    required this.price,
    required this.volume,
    required this.changePercent,
    this.isCrypto = false,
    this.stockContext,
  });

  @override
  State<_AIAnalysisSheet> createState() => _AIAnalysisSheetState();
}

class _AIAnalysisSheetState extends State<_AIAnalysisSheet>
    with SingleTickerProviderStateMixin {
  static const _loadingMessages = [
    'Piyasa verileri taranıyor...',
    'Hacim kontrol ediliyor...',
    'Analiz yazılıyor...',
    'Trend değerlendiriliyor...',
    'Risk analizi yapılıyor...',
    'Rapor hazırlanıyor...',
  ];

  String _loadingMessage = _loadingMessages.first;
  Timer? _messageTimer;
  String? _result;
  String? _error;

  Future<String> _runStockAnalysis() async {
    final ctx = await AIAnalysisService.enrichWithChartAverages(
      widget.symbol,
      widget.stockContext,
    );
    return AIAnalysisService.getAnalysis(
      widget.symbol,
      widget.price,
      widget.volume,
      widget.changePercent,
      stockContext: ctx,
    );
  }

  @override
  void initState() {
    super.initState();
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _result == null && _error == null) {
        setState(() {
          _loadingMessage = _loadingMessages[
              Random().nextInt(_loadingMessages.length)];
        });
      }
    });
    final future = widget.isCrypto
        ? AIAnalysisService.getCryptoAnalysis(
            widget.symbol,
            widget.price,
            widget.volume,
            widget.changePercent,
          )
        : _runStockAnalysis();
    future.then((text) {
      _messageTimer?.cancel();
      if (mounted) setState(() => _result = text);
    }).catchError((e, _) {
      _messageTimer?.cancel();
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCrypto = widget.isCrypto;
    final accentColor = isCrypto ? CryptoTheme.cryptoAmber : AppTheme.smokyJade;
    // Hisse: Precision Editorial — light'ta açık zemin; kripto: Etheric Neon.
    final bg = isCrypto
        ? CryptoTheme.backgroundGrey(context)
        : (isDark ? AppTheme.bgDark : AppTheme.surface);
    final textColor = isCrypto
        ? CryptoTheme.textPrimaryFor(context)
        : (isDark ? AppTheme.textPrimary : AppTheme.onSurface);
    final textSecondary = isCrypto
        ? CryptoTheme.textSecondaryFor(context)
        : (isDark ? AppTheme.textSecondary : AppTheme.onSurface.withValues(alpha: 0.65));

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: accentColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  isCrypto ? 'Yapay Zeka Kripto Analizi' : 'Yapay Zeka Hisse Analizi',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: isCrypto ? CryptoTheme.negativeChange : AppTheme.softRed,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _result != null
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        physics: const BouncingScrollPhysics(),
                        child: MarkdownBody(
                          data: _result!,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.inter(
                              fontSize: 15,
                              height: 1.55,
                              color: textColor,
                            ),
                            h1: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                            h2: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                            strong: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                            em: GoogleFonts.inter(
                              fontStyle: FontStyle.italic,
                              color: textSecondary,
                            ),
                            blockquote: GoogleFonts.inter(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                            listIndent: 24,
                          ),
                        ),
                      )
                    : _LoadingView(
                        message: _loadingMessage,
                        accentColor: accentColor,
                        isCrypto: isCrypto,
                      ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatefulWidget {
  final String message;
  final Color? accentColor;
  final bool isCrypto;

  const _LoadingView({
    required this.message,
    this.accentColor,
    this.isCrypto = false,
  });

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppTheme.smokyJade;
    final isCrypto = widget.isCrypto;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isCrypto
        ? CryptoTheme.textPrimaryFor(context)
        : (isDark ? AppTheme.textPrimary : AppTheme.onSurface);
    final textSecondary = isCrypto
        ? CryptoTheme.textSecondaryFor(context)
        : (isDark ? AppTheme.textSecondary : AppTheme.onSurface.withValues(alpha: 0.65));
    final innerCircleBg = isCrypto
        ? CryptoTheme.backgroundGrey(context)
        : (isDark ? AppTheme.bgDark : AppTheme.surface);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * 3.14159,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        accent,
                        accent.withValues(alpha: 0.3),
                        accent.withValues(alpha: 0.5),
                        accent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: innerCircleBg,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.auto_awesome,
                          color: accent,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Yapay Zeka Düşünüyor...',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
