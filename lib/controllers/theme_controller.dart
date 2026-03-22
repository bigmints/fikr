import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/app_typography.dart';

class AppPalette {
  // Brand
  static const Color primary = Color(0xFF3CA6A6);
  static const Color primaryLight = Color(0x143CA6A6); // ~8% opacity
  static const Color taskAccent = Color(0xFFF97316); // orange for tasks
  static const Color danger = Color(0xFFEF4444);
  static const Color secondary = Color(0xFF9E3DFF);

  // Light theme
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFF4F5F7);
  static const Color onSurfaceLight = Color(0xFF111318);
  static const Color surfaceContainerHighestLight = Color(0xFFF4F5F7);
  static const Color outlineLight = Color(0xFFEAECF0);
  static const Color shadowLight = Color(0x0F000000);
  static const Color textBodyLight = Color(0xFF6B7280);
  static const Color textLabelLight = Color(0xFF9CA3AF);
  static const Color inputFillLight = Color(0xFFF4F5F7);

  // Dark theme
  static const Color backgroundDark = Color(0xFF0F0F0F);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceMutedDark = Color(0xFF252525);
  static const Color onSurfaceDark = Color(0xFFF1F1F1);
  static const Color surfaceContainerHighestDark = Color(0xFF2A2A2A);
  static const Color outlineDark = Color(0xFF2E2E2E);
  static const Color shadowDark = Color(0x40000000);
  static const Color textBodyDark = Color(0xFF8B8B8B);
  static const Color textLabelDark = Color(0xFF5A5A5A);
  static const Color buttonBackgroundDark = Color(0xFF1E293B);
  static const Color buttonBorderDark = Color(0xFF3A3A3A);

  /// Consistent card decoration for all card-like containers.
  /// Use this instead of inline BoxDecoration with ad-hoc shadows.
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? outlineDark : outlineLight, width: 1),
    );
  }
}

class ThemeController extends GetxController {
  late final Rx<ThemeMode> themeMode;

  @override
  void onInit() {
    super.onInit();
    themeMode = ThemeMode.system.obs;
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: AppPalette.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppPalette.primary,
        onPrimary: Colors.white,
        secondary: AppPalette.secondary,
        onSecondary: Colors.black,
        surface: AppPalette.surfaceLight,
        onSurface: AppPalette.onSurfaceLight,
        surfaceContainerHighest: AppPalette.surfaceContainerHighestLight,
        outline: AppPalette.outlineLight,
        shadow: AppPalette.shadowLight,
        error: AppPalette.danger,
      ),
      textTheme: AppTypography.textTheme.apply(
        bodyColor: AppPalette.onSurfaceLight,
        displayColor: AppPalette.onSurfaceLight,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.onSurfaceLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.surfaceLight,
          foregroundColor: AppPalette.onSurfaceLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppPalette.outlineLight),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.onSurfaceLight,
          side: const BorderSide(color: AppPalette.outlineLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.surfaceMutedLight,
        disabledColor: AppPalette.surfaceMutedLight,
        selectedColor: AppPalette.primaryLight,
        secondarySelectedColor: AppPalette.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppPalette.textBodyLight,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: AppPalette.primary,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        showCheckmark: false,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.backgroundLight,
        foregroundColor: AppPalette.onSurfaceLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.titleMedium.copyWith(
          color: AppPalette.onSurfaceLight,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppPalette.backgroundLight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        color: AppPalette.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surfaceLight,
        indicatorColor: AppPalette.primaryLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppPalette.primary, size: 22);
          }
          return const IconThemeData(
            color: AppPalette.textLabelLight,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              color: AppPalette.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelSmall.copyWith(
            color: AppPalette.textLabelLight,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF374151),
        textColor: AppPalette.onSurfaceLight,
        tileColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.outlineLight,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.inputFillLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppPalette.textLabelLight,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.primary;
            }
            return AppPalette.textBodyLight;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.primary;
            }
            return AppPalette.textBodyLight;
          }),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppPalette.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppPalette.primary,
        onPrimary: Colors.black,
        secondary: AppPalette.secondary,
        onSecondary: Colors.white,
        surface: AppPalette.surfaceDark,
        onSurface: AppPalette.onSurfaceDark,
        surfaceContainerHighest: AppPalette.surfaceContainerHighestDark,
        outline: AppPalette.outlineDark,
        shadow: AppPalette.shadowDark,
        error: AppPalette.danger,
      ),
      textTheme: AppTypography.textTheme.apply(
        bodyColor: AppPalette.onSurfaceDark,
        displayColor: AppPalette.onSurfaceDark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.onSurfaceDark,
          foregroundColor: AppPalette.backgroundDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.surfaceDark,
          foregroundColor: AppPalette.onSurfaceDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppPalette.outlineDark),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.onSurfaceDark,
          side: const BorderSide(color: AppPalette.outlineDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.surfaceMutedDark,
        selectedColor: AppPalette.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppPalette.textBodyDark,
        ),
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: AppPalette.primary,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        showCheckmark: false,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.backgroundDark,
        foregroundColor: AppPalette.onSurfaceDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.titleMedium.copyWith(
          color: AppPalette.onSurfaceDark,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppPalette.backgroundDark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        color: AppPalette.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surfaceDark,
        indicatorColor: AppPalette.primaryLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppPalette.primary, size: 22);
          }
          return const IconThemeData(color: AppPalette.textLabelDark, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              color: AppPalette.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelSmall.copyWith(
            color: AppPalette.textLabelDark,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFE5E7EB),
        textColor: Color(0xFFE5E7EB),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.outlineDark,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surfaceMutedDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppPalette.textLabelDark,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.primary;
            }
            return AppPalette.textBodyDark;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.primary;
            }
            return AppPalette.textBodyDark;
          }),
        ),
      ),
    );
  }
}
