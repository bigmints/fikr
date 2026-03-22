import 'package:flutter/material.dart';

/// Design tokens for consistent spacing across the app.
///
/// Usage:
///   padding: EdgeInsets.all(AppSpacing.md)
///   SizedBox(height: AppSpacing.sm)
///   padding: AppSpacing.pagePadding
class AppSpacing {
  AppSpacing._();

  // ── Raw values ──
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  // ── Semantic tokens ──

  /// Standard horizontal padding for page-level content
  static const double pageHorizontal = md; // 16

  /// Standard vertical gap between sections
  static const double sectionGap = xl; // 24

  /// Inner card padding
  static const double cardInner = lg; // 20

  /// Gap between stacked cards
  static const double cardGap = sm; // 12

  /// Convenience insets for page-level content
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
  );

  /// Symmetric page padding with vertical
  static const EdgeInsets pagePaddingAll = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
    vertical: md,
  );

  /// Section padding (used for section headers, content blocks)
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
    vertical: xs,
  );
}
