import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'crypto_theme.dart';
import 'widgets/crypto_glass_app_bar.dart';
import 'models/crypto_coin.dart';
import 'widgets/ai_analysis_bottom_sheet.dart';

/// Kripto para detay ekranı – fiyat, değişim, hacim
class CryptoDetailScreen extends StatelessWidget {
  const CryptoDetailScreen({
    super.key,
    required this.coin,
  });

  final CryptoCoin coin;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##', 'tr_TR');
    return Scaffold(
      backgroundColor: CryptoTheme.backgroundGrey(context),
      appBar: CryptoGlassAppBar(
        titleWidget: Text(
          '${coin.displaySymbol} / USDT',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: CryptoTheme.textPrimaryFor(context),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Yapay Zeka Analizi',
            onPressed: () => showAIAnalysisBottomSheet(
              context,
              symbol: coin.symbol,
              price: coin.price,
              volume: coin.volume,
              changePercent: coin.changePercent,
              isCrypto: true,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CryptoTheme.cardColorElevated(context),
                  borderRadius: BorderRadius.circular(CryptoTheme.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Güncel Fiyat',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CryptoTheme.textSecondaryFor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${fmt.format(coin.price)}',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: CryptoTheme.priceAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (coin.changePercent >= 0
                                    ? CryptoTheme.positiveChange
                                    : CryptoTheme.negativeChange)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${coin.changePercent >= 0 ? '+' : ''}${coin.changePercent.toStringAsFixed(2)}%',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: coin.changePercent >= 0
                                  ? CryptoTheme.positiveChange
                                  : CryptoTheme.negativeChange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _InfoRow(
                label: '24s Hacim',
                value: fmt.format(coin.volume),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: CryptoTheme.textSecondaryFor(context),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: CryptoTheme.textPrimaryFor(context),
          ),
        ),
      ],
    );
  }
}
