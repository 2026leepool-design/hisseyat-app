import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'logo_service.dart';
import 'services/fintables_logo_service.dart';

/// Hisse logosu widget'ı.
/// Fintables şirket sayfasından logo URL'ini çeker, CachedNetworkImage ile önbelleğe alır.
/// Yüklenemezse deterministik pastel avatar gösterir.
class StockLogo extends StatelessWidget {
  /// Hisse sembolü (örn: THYAO veya THYAO.IS)
  final String symbol;
  /// Logo boyutu (px)
  final double size;

  const StockLogo({
    super.key,
    required this.symbol,
    this.size = 48,
  });

  /// Sembole göre deterministik pastel renk (Gmail/Contacts tarzı)
  static Color _pastelColorForSymbol(String symbol) {
    const pastels = [
      Color(0xFFB39DDB),
      Color(0xFF81C784),
      Color(0xFF64B5F6),
      Color(0xFFFFB74D),
      Color(0xFFE57373),
      Color(0xFF4DB6AC),
      Color(0xFFBA68C8),
      Color(0xFF7986CB),
      Color(0xFF4DD0E1),
      Color(0xFFA1887F),
    ];
    final hash = symbol.toUpperCase().hashCode.abs();
    return pastels[hash % pastels.length];
  }

  static Widget _buildFallback(String symbol, double size) {
    final base = LogoService.symbolForLogo(symbol);
    final text = base.length >= 2 ? base.substring(0, 2).toUpperCase() : base.toUpperCase();
    final color = _pastelColorForSymbol(base);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<String>(
        future: FintablesLogoService.getLogoUrl(symbol),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildFallback(symbol, size);
          }

          final url = snapshot.data!;
          return ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              httpHeaders: const {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
              },
              placeholder: (context, url) => _buildFallback(symbol, size),
              errorWidget: (context, url, error) => _buildFallback(symbol, size),
            ),
          );
        },
      ),
    );
  }
}
