import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Plus Jakarta Sans — headings, titles, labels, buttons
  static TextStyle _heading(double size, {FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.plusJakartaSans(
        fontWeight: weight,
        fontSize: size,
        letterSpacing: size >= 22
            ? -0.03 * size
            : (size >= 16 ? -0.02 * size : 0),
      );

  // Inter — body, snippets, metadata, inputs
  static TextStyle _body(double size, {FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontWeight: weight,
        fontSize: size,
        letterSpacing: 0,
      );

  // Display
  static TextStyle get displayLarge  => _heading(48, weight: FontWeight.w800);
  static TextStyle get displayMedium => _heading(40, weight: FontWeight.w800);
  static TextStyle get displaySmall  => _heading(32, weight: FontWeight.w700);

  // Headline
  static TextStyle get headlineLarge  => _heading(28, weight: FontWeight.w700);
  static TextStyle get headlineMedium => _heading(24, weight: FontWeight.w700);
  static TextStyle get headlineSmall  => _heading(20, weight: FontWeight.w600);

  // Title
  static TextStyle get titleLarge  => _heading(18, weight: FontWeight.w600);
  static TextStyle get titleMedium => _heading(16, weight: FontWeight.w600);
  static TextStyle get titleSmall  => _heading(14, weight: FontWeight.w600);

  // Body — Inter
  static TextStyle get bodyLarge  => _body(16);
  static TextStyle get bodyMedium => _body(14);
  static TextStyle get bodySmall  => _body(13);

  // Label — Inter medium weight
  static TextStyle get labelLarge  => _body(13, weight: FontWeight.w500);
  static TextStyle get labelMedium => _body(12, weight: FontWeight.w500);
  static TextStyle get labelSmall  => _body(11, weight: FontWeight.w500);

  static TextTheme get textTheme => TextTheme(
    displayLarge:   displayLarge,
    displayMedium:  displayMedium,
    displaySmall:   displaySmall,
    headlineLarge:  headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall:  headlineSmall,
    titleLarge:     titleLarge,
    titleMedium:    titleMedium,
    titleSmall:     titleSmall,
    bodyLarge:      bodyLarge,
    bodyMedium:     bodyMedium,
    bodySmall:      bodySmall,
    labelLarge:     labelLarge,
    labelMedium:    labelMedium,
    labelSmall:     labelSmall,
  );
}
