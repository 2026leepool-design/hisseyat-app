import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../crypto_theme.dart';

/// Kripto para logosu.
/// 1) Atomiclabs CDN, 2) CoinIcons API, 3) Renkli daire + harf fallback.
class CryptoLogo extends StatefulWidget {
  final String symbol; // BTCUSDT veya BTC
  final double size;

  const CryptoLogo({
    super.key,
    required this.symbol,
    this.size = 44,
  });

  @override
  State<CryptoLogo> createState() => _CryptoLogoState();
}

class _CryptoLogoState extends State<CryptoLogo> {
  static const _atomicLabsBase =
      'https://cdn.jsdelivr.net/gh/atomiclabs/cryptocurrency-icons@bea1a9722a8c63169dcc06e86182bf2c55a76bbc/128/color';
  static const _coinIconsBase = 'https://cryptoicons.org/api/icon';

  int _urlIndex = 0;

  String get _normalizedSymbol {
    final s = widget.symbol.toUpperCase().replaceAll('USDT', '').trim();
    return s.isEmpty ? widget.symbol : s;
  }

  String get _lowerSymbol => _normalizedSymbol.toLowerCase();

  String? get _currentUrl {
    switch (_urlIndex) {
      case 0:
        return '$_atomicLabsBase/$_lowerSymbol.png';
      case 1:
        return '$_coinIconsBase/$_lowerSymbol/200';
      default:
        return null;
    }
  }

  static Color _colorForSymbol(String sym) {
    const colors = [
      CryptoTheme.cryptoAmber,
      CryptoTheme.cryptoOrange,
      CryptoTheme.accentCyan,
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
    ];
    final base = sym.toUpperCase().replaceAll('USDT', '');
    final hash = base.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildFallback() {
    final display = _normalizedSymbol;
    final text = display.length >= 3 ? display.substring(0, 3) : display;
    final color = _colorForSymbol(display);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: widget.size * 0.32,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  void _onImageError() {
    if (_urlIndex < 1 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _urlIndex++);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _currentUrl;

    if (url == null) {
      return _buildFallback();
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          httpHeaders: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
          },
          placeholder: (context, url) => _buildFallback(),
          errorWidget: (context, url, error) {
            _onImageError();
            return _buildFallback();
          },
        ),
      ),
    );
  }
}
