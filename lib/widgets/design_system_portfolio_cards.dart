import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../crypto_theme.dart';

/// The Precision Editorial — örnek hisse portföy özeti kartı (light).
/// Test: `Scaffold(body: ListView(children: [PrecisionEditorialPortfolioCard.sample()]))`
class PrecisionEditorialPortfolioCard extends StatelessWidget {
  const PrecisionEditorialPortfolioCard({
    super.key,
    required this.title,
    required this.totalValueLabel,
    required this.totalValue,
    required this.dayChangeLabel,
    required this.dayChangePercent,
    this.positiveDay = true,
  });

  final String title;
  final String totalValueLabel;
  final String totalValue;
  final String dayChangeLabel;
  final String dayChangePercent;
  final bool positiveDay;

  factory PrecisionEditorialPortfolioCard.sample() {
    return const PrecisionEditorialPortfolioCard(
      title: 'Ana Portföy',
      totalValueLabel: 'Toplam değer',
      totalValue: '₺128.450,00',
      dayChangeLabel: 'Bugün',
      dayChangePercent: '+1,24%',
      positiveDay: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = positiveDay ? AppTheme.emeraldGreen : AppTheme.softRed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.h2(context),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalValueLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  totalValue,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                dayChangeLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dayChangePercent,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: changeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryIndigo,
              foregroundColor: Colors.white,
              padding: AppTheme.buttonPaddingHorizontal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
            ),
            child: const Text('Detayları gör'),
          ),
        ],
      ),
    );
  }
}

/// High-Tech Crypto Editorial — örnek kripto portföy kartı (tonal katman, 8px radius).
class CryptoEditorialPortfolioCard extends StatelessWidget {
  const CryptoEditorialPortfolioCard({
    super.key,
    required this.symbolUppercase,
    required this.name,
    required this.valueUsd,
    required this.changePercent,
    this.positive = true,
  });

  final String symbolUppercase;
  final String name;
  final String valueUsd;
  final String changePercent;
  final bool positive;

  factory CryptoEditorialPortfolioCard.sample() {
    return const CryptoEditorialPortfolioCard(
      symbolUppercase: 'BTC',
      name: 'Bitcoin',
      valueUsd: r'$12.840,50',
      changePercent: '+2,15%',
      positive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final changeColor =
        positive ? CryptoTheme.secondaryNeon : CryptoTheme.errorCoral;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CryptoTheme.cardColor(context),
        borderRadius: BorderRadius.circular(CryptoTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: CryptoTheme.cardColorElevated(context),
                  borderRadius: BorderRadius.circular(CryptoTheme.radius),
                ),
                child: Text(
                  symbolUppercase,
                  style: CryptoTheme.labelStyle(context, fontSize: 12)
                      .copyWith(color: CryptoTheme.primaryElectric),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CryptoTheme.surfaceLayer3(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  changePercent.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: changeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: CryptoTheme.bodyInter(context, fontSize: 16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            'PORTFÖY DEĞERİ',
            style: CryptoTheme.labelStyle(context),
          ),
          const SizedBox(height: 6),
          Text(
            valueUsd,
            style: CryptoTheme.bodyInter(context, fontSize: 20, weight: FontWeight.w700)
                .copyWith(color: CryptoTheme.primaryElectric),
          ),
        ],
      ),
    );
  }
}
