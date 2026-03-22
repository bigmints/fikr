import 'package:flutter/material.dart';
import '../../controllers/theme_controller.dart';
import '../../utils/app_spacing.dart';

/// Airbnb-style collapsing header that pins to the top.
/// Large gradient title collapses to a compact bar on scroll.
class CollapsingSliverHeader extends SliverPersistentHeaderDelegate {
  CollapsingSliverHeader({
    required this.title,
    required this.topPadding,
    required this.isDark,
    this.actions = const [],
    this.subtitle,
    this.gradientColors,
    this.transparentBackground = false,
  });

  final String title;
  final double topPadding;
  final bool isDark;
  final List<Widget> actions;
  final String? subtitle;
  final List<Color>? gradientColors;
  final bool transparentBackground;

  static const double _expandedBody = 100;
  static const double _collapsedBody = 52;

  @override
  double get maxExtent => topPadding + _expandedBody;

  @override
  double get minExtent => topPadding + _collapsedBody;

  @override
  bool shouldRebuild(covariant CollapsingSliverHeader old) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);

    final titleSize = _lerp(32, 18, t);
    final bgOpacity = t;
    final subtitleOpacity = (1.0 - t * 2.5).clamp(0.0, 1.0);
    final bottomBorderOpacity = (t * 1.5).clamp(0.0, 1.0);

    final colors =
        gradientColors ??
        (isDark
            ? const [Color(0xFF3CA6A6), Color(0xFF67E8F9), Color(0xFFA78BFA)]
            : const [Color(0xFF0D9488), Color(0xFF2563EB), Color(0xFF7C3AED)]);

    final bgColor = isDark ? AppPalette.surfaceDark : Colors.white;
    final borderColor = isDark
        ? AppPalette.outlineDark
        : AppPalette.outlineLight;

    return Container(
      decoration: BoxDecoration(
        color: transparentBackground
            ? bgColor.withValues(alpha: bgOpacity * 0.7)
            : bgColor.withValues(alpha: bgOpacity),
        border: Border(
          bottom: BorderSide(
            color: transparentBackground
                ? borderColor.withValues(alpha: bottomBorderOpacity * 0.3)
                : borderColor.withValues(alpha: bottomBorderOpacity),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.xs,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            if (subtitle != null && subtitleOpacity > 0)
              Opacity(
                opacity: subtitleOpacity,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.xxs,
                    AppSpacing.pageHorizontal,
                    0,
                  ),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppPalette.textBodyDark
                          : AppPalette.textBodyLight,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Simple icon button for use in header actions row.
class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppPalette.textBodyDark : AppPalette.textBodyLight;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon, size: 18, color: color),
      ),
    );
  }
}
