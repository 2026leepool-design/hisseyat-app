import 'package:flutter/material.dart';

/// StockTrack Pro uygulama logosu – assets/icon/app_logo.png
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 48,
    this.forDarkBackground = true,
  });

  final double size;
  final bool forDarkBackground;

  static const String _assetPath = 'assets/icon/app_logo.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        _assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.show_chart, 
          size: size * 0.7, 
          color: forDarkBackground ? Colors.white70 : const Color(0xFF356B6B), // Smoky Jade
        ),
      ),
    );
  }
}
