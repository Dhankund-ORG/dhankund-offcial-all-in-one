import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double padding;
  final Color? color;
  final bool isGold;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = 16.0,
    this.color,
    this.isGold = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: isGold
          ? AppTheme.goldGlassDecoration(borderRadius: borderRadius)
          : AppTheme.glassDecoration(
              color: color ?? const Color(0x0CFFFFFF),
              borderRadius: borderRadius,
            ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: child,
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: card,
        ),
      );
    }

    return card;
  }
}
