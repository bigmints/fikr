import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/theme_controller.dart';

class TagChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final bool selected;

  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppPalette.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgAlpha = selected ? (isDark ? 0.18 : 0.12) : (isDark ? 0.12 : 0.08);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: chipColor,
          ),
        ),
      ),
    );
  }
}
