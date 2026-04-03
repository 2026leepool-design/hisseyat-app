import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../crypto_theme.dart';

/// Sabit alt navigasyon çubuğu – Ana Sayfa, Geçmiş, Zaman Tüneli, Performans, Portföyler
class AppBottomNavBar extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<int>? onTap;
  final bool cryptoMode;

  const AppBottomNavBar({
    super.key,
    required this.currentRoute,
    this.onTap,
    this.cryptoMode = false,
  });

  int get _currentIndex {
    switch (currentRoute) {
      case 'AnaSayfa':
      case 'MyHomePage':
        return 0;
      case 'GecmisIslemlerPage':
        return 1;
      case 'TimeTunnelScreen':
        return 2;
      case 'PerformansPage':
        return 3;
      case 'Portfoyler':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cryptoMode) {
      return ClipRect(
        child: BackdropFilter(
          filter: CryptoTheme.glassBlur,
          child: Container(
            decoration: BoxDecoration(
              color: CryptoTheme.glassBarColor(context),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                        child: _NavItem(
                      icon: Icons.home_rounded,
                      label: 'Ana Sayfa',
                      isActive: _currentIndex == 0,
                      activeColor: CryptoTheme.primaryElectric,
                      inactiveColor: CryptoTheme.textSecondaryFor(context),
                      radius: CryptoTheme.radius,
                      onTap: () => onTap?.call(0),
                    )),
                    Expanded(
                        child: _NavItem(
                      icon: Icons.history_rounded,
                      label: 'Geçmiş',
                      isActive: _currentIndex == 1,
                      activeColor: CryptoTheme.primaryElectric,
                      inactiveColor: CryptoTheme.textSecondaryFor(context),
                      radius: CryptoTheme.radius,
                      onTap: () => onTap?.call(1),
                    )),
                    Expanded(
                        child: _NavItem(
                      icon: Icons.timeline_rounded,
                      label: 'Zaman Tüneli',
                      isActive: _currentIndex == 2,
                      activeColor: CryptoTheme.primaryElectric,
                      inactiveColor: CryptoTheme.textSecondaryFor(context),
                      radius: CryptoTheme.radius,
                      onTap: () => onTap?.call(2),
                    )),
                    Expanded(
                        child: _NavItem(
                      icon: Icons.analytics_rounded,
                      label: 'Performans',
                      isActive: _currentIndex == 3,
                      activeColor: CryptoTheme.primaryElectric,
                      inactiveColor: CryptoTheme.textSecondaryFor(context),
                      radius: CryptoTheme.radius,
                      onTap: () => onTap?.call(3),
                    )),
                    Expanded(
                        child: _NavItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Portföyler',
                      isActive: _currentIndex == 4,
                      activeColor: CryptoTheme.primaryElectric,
                      inactiveColor: CryptoTheme.textSecondaryFor(context),
                      radius: CryptoTheme.radius,
                      onTap: () => onTap?.call(4),
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final bgColor = isDark ? AppTheme.bgDark : AppTheme.surface;
    final activeColor = AppTheme.primaryIndigo;
    final inactiveColor =
        isDark ? AppTheme.textSecondary : AppTheme.onSurface.withValues(alpha: 0.55);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: AppTheme.floatingShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                  child: _NavItem(
                icon: Icons.home_rounded,
                label: 'Ana Sayfa',
                isActive: _currentIndex == 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                radius: AppTheme.radiusXl,
                onTap: () => onTap?.call(0),
              )),
              Expanded(
                  child: _NavItem(
                icon: Icons.history_rounded,
                label: 'Geçmiş',
                isActive: _currentIndex == 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                radius: AppTheme.radiusXl,
                onTap: () => onTap?.call(1),
              )),
              Expanded(
                  child: _NavItem(
                icon: Icons.timeline_rounded,
                label: 'Zaman Tüneli',
                isActive: _currentIndex == 2,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                radius: AppTheme.radiusXl,
                onTap: () => onTap?.call(2),
              )),
              Expanded(
                  child: _NavItem(
                icon: Icons.analytics_rounded,
                label: 'Performans',
                isActive: _currentIndex == 3,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                radius: AppTheme.radiusXl,
                onTap: () => onTap?.call(3),
              )),
              Expanded(
                  child: _NavItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Portföyler',
                isActive: _currentIndex == 4,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                radius: AppTheme.radiusXl,
                onTap: () => onTap?.call(4),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final double radius;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.radius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isActive)
              Container(
                width: 24,
                height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
