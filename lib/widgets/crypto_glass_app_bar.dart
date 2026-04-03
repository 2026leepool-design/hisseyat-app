import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../crypto_theme.dart';

/// Kripto modu: %60 opaklık + blur 20 — AppBar arka planı.
class CryptoGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CryptoGlassAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
  }) : assert(title != null || titleWidget != null, 'title veya titleWidget verilmeli');

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final Widget titleW = titleWidget ??
        Text(
          title!,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: CryptoTheme.textPrimaryFor(context),
          ),
        );
    return ClipRect(
      child: BackdropFilter(
        filter: CryptoTheme.glassBlur,
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: CryptoTheme.glassBarColor(context),
          foregroundColor: CryptoTheme.textPrimaryFor(context),
          leading: leading,
          title: titleW,
          actions: actions,
        ),
      ),
    );
  }
}
