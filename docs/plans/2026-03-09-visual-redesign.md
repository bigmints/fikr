# Visual Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign Fikr's visual language to be editorial and premium — Plus Jakarta Sans + Inter fonts, shadow-based cards, refined color palette, new home layout, redesigned insights screen, and a dedicated Tasks tab.

**Architecture:** Surgical file-by-file changes working bottom-up: design tokens first (typography, palette, theme), then shared widgets, then screens. No architectural changes — same GetX controllers, same routing. Tasks tab added to existing 3-tab shell.

**Tech Stack:** Flutter, Dart, GetX, google_fonts package (already installed — `plusJakartaSans` and `inter` are available in the package)

---

## Task 1: Replace AppTypography — Plus Jakarta Sans + Inter

**Files:**
- Modify: `lib/utils/app_typography.dart`

**Step 1: Replace the entire file content**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Plus Jakarta Sans — headings, titles, labels, buttons
  static TextStyle _heading(double size, {FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.plusJakartaSans(
        fontWeight: weight,
        fontSize: size,
        letterSpacing: size >= 22 ? -0.03 * size : (size >= 16 ? -0.01 * size : 0),
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

  // Body
  static TextStyle get bodyLarge  => _body(16);
  static TextStyle get bodyMedium => _body(14);
  static TextStyle get bodySmall  => _body(13);

  // Label
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
```

**Step 2: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```
Expected: No errors.

**Step 3: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/utils/app_typography.dart && git commit -m "design: replace Archivo+Lato with Plus Jakarta Sans+Inter"
```

---

## Task 2: Update AppPalette and ThemeData in ThemeController

**Files:**
- Modify: `lib/controllers/theme_controller.dart`

**Step 1: Replace AppPalette with expanded token set**

Replace the `AppPalette` class at the top of the file with:

```dart
class AppPalette {
  // Brand
  static const Color primary      = Color(0xFF3CA6A6);
  static const Color primaryLight = Color(0x143CA6A6); // 8% opacity
  static const Color taskAccent   = Color(0xFFF97316); // orange for tasks
  static const Color taskLight    = Color(0x14F97316); // 8% opacity orange
  static const Color danger       = Color(0xFFEF4444);
  static const Color secondary    = Color(0xFF9E3DFF);

  // Light
  static const Color backgroundLight              = Color(0xFFFAFAFA);
  static const Color surfaceLight                 = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight            = Color(0xFFF4F5F7);
  static const Color onSurfaceLight               = Color(0xFF111318);
  static const Color surfaceContainerHighestLight = Color(0xFFF4F5F7);
  static const Color outlineLight                 = Color(0xFFEAECF0);
  static const Color shadowLight                  = Color(0x0F000000);
  static const Color textBodyLight                = Color(0xFF6B7280);
  static const Color textLabelLight               = Color(0xFF9CA3AF);
  static const Color inputFillLight               = Color(0xFFF4F5F7);

  // Dark
  static const Color backgroundDark              = Color(0xFF0F0F0F);
  static const Color surfaceDark                 = Color(0xFF1A1A1A);
  static const Color surfaceMutedDark            = Color(0xFF252525);
  static const Color onSurfaceDark               = Color(0xFFF1F1F1);
  static const Color surfaceContainerHighestDark = Color(0xFF2A2A2A);
  static const Color outlineDark                 = Color(0xFF2E2E2E);
  static const Color shadowDark                  = Color(0x40000000);
  static const Color textBodyDark                = Color(0xFF8B8B8B);
  static const Color textLabelDark               = Color(0xFF5A5A5A);
  static const Color buttonBackgroundDark        = Color(0xFF1E293B);
  static const Color buttonBorderDark            = Color(0xFF3A3A3A);
}
```

**Step 2: Replace lightTheme**

Replace the entire `static ThemeData get lightTheme` getter with:

```dart
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
    // Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.onSurfaceLight,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
      ),
    ),
    // Chips — pill shape, teal accent on selected
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
    // App bar
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
    // Cards — shadow-based, no border
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: AppPalette.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    // Navigation bar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppPalette.surfaceLight,
      indicatorColor: AppPalette.primaryLight,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppPalette.primary, size: 22);
        }
        return IconThemeData(color: AppPalette.textLabelLight, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelSmall.copyWith(
            color: AppPalette.primary,
            fontWeight: FontWeight.w600,
          );
        }
        return AppTypography.labelSmall.copyWith(color: AppPalette.textLabelLight);
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppTypography.bodyMedium.copyWith(color: AppPalette.textLabelLight),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.primary;
          return AppPalette.textBodyLight;
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.primary;
          return AppPalette.textBodyLight;
        }),
      ),
    ),
  );
}
```

**Step 3: Replace darkTheme**

Replace the entire `static ThemeData get darkTheme` getter with:

```dart
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppPalette.surfaceMutedDark,
      selectedColor: AppPalette.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelStyle: AppTypography.labelMedium.copyWith(color: AppPalette.textBodyDark),
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
      titleTextStyle: AppTypography.titleMedium.copyWith(color: AppPalette.onSurfaceDark),
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
        return IconThemeData(color: AppPalette.textLabelDark, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelSmall.copyWith(
            color: AppPalette.primary,
            fontWeight: FontWeight.w600,
          );
        }
        return AppTypography.labelSmall.copyWith(color: AppPalette.textLabelDark);
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppTypography.bodyMedium.copyWith(color: AppPalette.textLabelDark),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.primary;
          return AppPalette.textBodyDark;
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.primary;
          return AppPalette.textBodyDark;
        }),
      ),
    ),
  );
}
```

**Step 4: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```

**Step 5: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/controllers/theme_controller.dart && git commit -m "design: new AppPalette tokens + shadow cards + teal nav + pill chips"
```

---

## Task 3: Redesign TagChip widget

**Files:**
- Modify: `lib/widgets/tag_chip.dart`

**Step 1: Read the current file**

Read `lib/widgets/tag_chip.dart` to understand its props (likely takes `label`, `color`, `onTap`).

**Step 2: Replace with editorial pill chip**

The new tag chip should be: teal pill background at 8% opacity, teal text, tight uppercase label. Replace the widget's build method:

```dart
import 'package:flutter/material.dart';
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
    final bgOpacity = isDark ? 0.12 : 0.08;
    final textOpacity = isDark ? 0.9 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? chipColor.withValues(alpha: isDark ? 0.2 : 0.12)
              : chipColor.withValues(alpha: bgOpacity),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: chipColor.withValues(alpha: textOpacity),
          ),
        ),
      ),
    );
  }
}
```

**Step 3: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```

**Step 4: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/widgets/tag_chip.dart && git commit -m "design: editorial pill TagChip with teal tint"
```

---

## Task 4: Redesign NoteCard widget

**Files:**
- Modify: `lib/screens/home/widgets/note_card.dart`

**Step 1: Read the current file completely**

Read `lib/screens/home/widgets/note_card.dart`.

**Step 2: Replace the card's decoration and layout**

The note card needs:
- White background with shadow (no border)
- 16px radius
- Title: Plus Jakarta Sans 15px semibold, near-black
- Snippet: Inter 13px, muted, 2-line max
- Bottom row: bucket chip left, timestamp right

Find the Card widget or Container that forms the card shell. Replace its decoration/shape with:

```dart
// Card container — shadow-based, no border
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).cardTheme.color,
    borderRadius: BorderRadius.circular(16),
    boxShadow: Theme.of(context).brightness == Brightness.light
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
  ),
  child: /* existing card content */,
)
```

Update the title TextStyle to:
```dart
style: AppTypography.titleSmall.copyWith(
  color: Theme.of(context).colorScheme.onSurface,
  height: 1.3,
)
```

Update the snippet TextStyle to:
```dart
style: AppTypography.bodySmall.copyWith(
  color: AppPalette.textBodyLight, // use textBodyDark in dark mode
  height: 1.5,
)
```

Update the timestamp TextStyle to:
```dart
style: AppTypography.labelSmall.copyWith(
  color: Theme.of(context).brightness == Brightness.light
      ? AppPalette.textLabelLight
      : AppPalette.textLabelDark,
)
```

**Step 3: Update card padding to 16px (from 24px if set)**

The card padding should be `EdgeInsets.all(16)` — not 24px which is too much for a list card.

**Step 4: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```

**Step 5: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/screens/home/widgets/note_card.dart && git commit -m "design: shadow-based NoteCard with editorial typography"
```

---

## Task 5: Redesign Home Screen — remove hero banner, new header

**Files:**
- Modify: `lib/screens/home/mobile_home.dart`

**Step 1: Read the entire file**

Read `lib/screens/home/mobile_home.dart`.

**Step 2: Remove the _HeroBanner widget entirely**

Delete the `_HeroBanner` class (the 280px dark gradient widget). Also remove any call to it in the build tree.

**Step 3: Replace with a new sticky header**

In the main `build` method, replace the hero banner section with this header widget at the top of the scroll view:

```dart
// App header — wordmark + record FAB hint
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(
      children: [
        Text(
          'Fikr',
          style: AppTypography.headlineMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        // Profile icon / avatar area (keep existing if present, else omit)
      ],
    ),
  ),
),
// Search bar
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: _SearchBar(), // keep existing search widget but restyle
  ),
),
// Bucket filter chips
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
    child: _BucketFilterChips(), // keep existing chips but update padding
  ),
),
```

**Step 4: Update the search bar styling**

Find the search bar widget/container in the file. Ensure it uses:
```dart
decoration: BoxDecoration(
  color: Theme.of(context).brightness == Brightness.light
      ? AppPalette.surfaceMutedLight
      : AppPalette.surfaceMutedDark,
  borderRadius: BorderRadius.circular(12),
),
```
No border, no shadow — just a soft fill.

**Step 5: Update note list padding**

Notes list padding should be `EdgeInsets.symmetric(horizontal: 20)` with `SliverPadding`.

**Step 6: Update the bucket filter chips horizontal scroll padding**

Left padding: `20px`. Gap between chips: `8px`.

**Step 7: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```

**Step 8: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/screens/home/mobile_home.dart && git commit -m "design: remove hero banner, new editorial home header"
```

---

## Task 6: Add Tasks tab to navigation

**Files:**
- Modify: `lib/screens/home_shell.dart`
- Modify: `lib/screens/shells/mobile_shell.dart`

**Step 1: Read both files fully**

Read `lib/screens/home_shell.dart` and `lib/screens/shells/mobile_shell.dart`.

**Step 2: Add Tasks screen to home_shell.dart**

In `home_shell.dart`, find where `_screens` list is defined. Add `TasksScreen()` at index 2 (between Insights and Settings):

```dart
_screens = [
  const NewHomeScreen(),    // 0
  const InsightsScreen(),   // 1
  const TasksScreen(),      // 2  ← ADD THIS
  const SettingsScreen(),   // 3  (was 2)
];
```

Make sure `TasksScreen` is imported:
```dart
import 'screens/tasks/tasks_screen.dart';
```

Update any index-based logic (e.g., `if (index == 2)` for settings) to account for the new index.

**Step 3: Update mobile_shell.dart NavigationBar**

Find the `NavigationBar` destinations list. Add a Tasks destination at index 2:

```dart
NavigationBar(
  selectedIndex: controller.currentIndex.value,
  onDestinationSelected: (index) => controller.currentIndex.value = index,
  destinations: const [
    NavigationDestination(
      icon: Icon(FontAwesomeIcons.noteSticky),
      selectedIcon: Icon(FontAwesomeIcons.solidNoteSticky),
      label: 'Notes',
    ),
    NavigationDestination(
      icon: Icon(FontAwesomeIcons.chartLine),
      selectedIcon: Icon(FontAwesomeIcons.arrowTrendUp),
      label: 'Insights',
    ),
    NavigationDestination(
      icon: Icon(FontAwesomeIcons.listCheck),
      selectedIcon: Icon(FontAwesomeIcons.listCheck),
      label: 'Tasks',
    ),
    NavigationDestination(
      icon: Icon(FontAwesomeIcons.gear),
      selectedIcon: Icon(FontAwesomeIcons.gear),
      label: 'Settings',
    ),
  ],
)
```

**Step 4: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```

**Step 5: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/screens/home_shell.dart lib/screens/shells/mobile_shell.dart && git commit -m "feat: add Tasks as 3rd tab in bottom navigation"
```

---

## Task 7: Redesign Tasks Screen

**Files:**
- Modify: `lib/screens/tasks/tasks_screen.dart`
- Modify: `lib/widgets/task_tile.dart`

**Step 1: Read both files fully**

**Step 2: Rewrite task_tile.dart**

Replace with a clean, orange-accented tile:

```dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../controllers/theme_controller.dart';
import '../models/insights_models.dart';
import '../utils/app_typography.dart';

class TaskTile extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final bool showSource;
  final bool compact;

  const TaskTile({
    super.key,
    required this.todo,
    required this.onToggle,
    this.showSource = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = todo.isCompleted;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDone
        ? (isDark ? AppPalette.textLabelDark : AppPalette.textLabelLight)
        : Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: compact ? 6 : 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? AppPalette.taskAccent : Colors.transparent,
                border: isDone
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppPalette.textLabelDark
                            : AppPalette.outlineLight,
                        width: 1.5,
                      ),
              ),
              child: isDone
                  ? const Icon(
                      FontAwesomeIcons.check,
                      size: 10,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: textColor,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: textColor,
                    height: 1.4,
                  ),
                ),
                if (showSource && todo.source.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.solidNoteSticky,
                        size: 9,
                        color: isDark
                            ? AppPalette.textLabelDark
                            : AppPalette.textLabelLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        todo.source,
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? AppPalette.textLabelDark
                              : AppPalette.textLabelLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 3: Rewrite tasks_screen.dart**

Replace the screen with an editorial layout using sections:

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../utils/app_typography.dart';
import '../../widgets/task_tile.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _showCompleted = false;
  final AppController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          final active = controller.todoItems
              .where((t) => !t.isCompleted)
              .toList();
          final done = controller.todoItems
              .where((t) => t.isCompleted)
              .toList();

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tasks',
                        style: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (active.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${active.length} pending',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark
                                  ? AppPalette.textLabelDark
                                  : AppPalette.textLabelLight,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Active tasks
              if (active.isEmpty && done.isEmpty)
                SliverFillRemaining(
                  child: _EmptyTasksState(),
                )
              else ...[
                if (active.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Active',
                      count: active.length,
                      color: AppPalette.taskAccent,
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => TaskTile(
                        todo: active[i],
                        onToggle: () =>
                            controller.toggleTaskComplete(active[i].id),
                      ),
                      childCount: active.length,
                    ),
                  ),
                ],

                // Completed section
                if (done.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: GestureDetector(
                      onTap: () => setState(
                          () => _showCompleted = !_showCompleted),
                      child: _SectionHeader(
                        title: 'Completed',
                        count: done.length,
                        trailing: Icon(
                          _showCompleted
                              ? FontAwesomeIcons.chevronUp
                              : FontAwesomeIcons.chevronDown,
                          size: 12,
                          color: isDark
                              ? AppPalette.textLabelDark
                              : AppPalette.textLabelLight,
                        ),
                      ),
                    ),
                  ),
                  if (_showCompleted)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => TaskTile(
                          todo: done[i],
                          onToggle: () =>
                              controller.toggleTaskComplete(done[i].id),
                        ),
                        childCount: done.length,
                      ),
                    ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color? color;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: AppTypography.labelLarge.copyWith(
              color: isDark
                  ? AppPalette.textBodyDark
                  : AppPalette.textBodyLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppTypography.labelLarge.copyWith(
              color: isDark
                  ? AppPalette.textLabelDark
                  : AppPalette.textLabelLight,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppPalette.taskAccent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FontAwesomeIcons.listCheck,
                size: 28,
                color: AppPalette.taskAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No tasks yet',
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Record a voice note and Fikr will extract action items automatically.',
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppPalette.textBodyDark
                    : AppPalette.textBodyLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 4: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```

**Step 5: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/screens/tasks/tasks_screen.dart lib/widgets/task_tile.dart && git commit -m "design: editorial Tasks screen with orange accents and section headers"
```

---

## Task 8: Redesign Insights Screen

**Files:**
- Modify: `lib/screens/insights/mobile_insights.dart`
- Modify: `lib/screens/insights/widgets/insight_components.dart`

**Step 1: Read both files fully**

**Step 2: Remove tasks preview from mobile_insights.dart**

Find the task preview section (the one that shows up to 5 tasks and a "View All" link). Delete it entirely — tasks now have their own tab.

**Step 3: Redesign the Insights header**

At the top of the screen, add:
```dart
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (lastGeneratedDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Updated ${_formatDate(lastGeneratedDate)}',
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppPalette.textLabelDark : AppPalette.textLabelLight,
              ),
            ),
          ),
      ],
    ),
  ),
),
```

**Step 4: Redesign the reminders section**

In `insight_components.dart`, find the reminders banner widget. Replace its gradient background with a clean card:

```dart
Container(
  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppPalette.primary.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: AppPalette.primary.withValues(alpha: 0.15),
      width: 1,
    ),
  ),
  child: /* existing reminder list content */,
)
```

**Step 5: Redesign highlights cards (full-width stacked)**

In `insight_components.dart`, find the highlights/ideas cards widget. Replace horizontal scroll cards with stacked full-width cards:

Each highlight card:
```dart
Container(
  margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Theme.of(context).cardTheme.color,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? [] : [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
    border: isDark
        ? Border.all(color: AppPalette.outlineDark, width: 1)
        : null,
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Left accent bar — bucket color
      Container(
        width: 3,
        height: 44,
        decoration: BoxDecoration(
          color: bucketColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 14),
      // Icon + content
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              highlight.title,
              style: AppTypography.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              highlight.detail,
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppPalette.textBodyDark : AppPalette.textBodyLight,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  ),
)
```

**Step 6: Add a "Generate Insights" button when insights are stale**

At the bottom of the insights screen, add a teal filled button if insights haven't been generated recently:
```dart
FilledButton.icon(
  onPressed: () => controller.captureInsightsEdition(),
  icon: const Icon(FontAwesomeIcons.wandMagicSparkles, size: 14),
  label: const Text('Generate Insights'),
  style: FilledButton.styleFrom(
    backgroundColor: AppPalette.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
)
```

**Step 7: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```

**Step 8: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/screens/insights/ && git commit -m "design: editorial Insights screen with stacked highlight cards"
```

---

## Task 9: Update EmptyState widget

**Files:**
- Modify: `lib/widgets/empty_state.dart`

**Step 1: Read the file**

**Step 2: Update to match new design language**

The empty state icon container should use teal tint (not a colored circle). Update:
- Icon container background: `AppPalette.primary.withValues(alpha: 0.08)`
- Icon container border: `AppPalette.primary.withValues(alpha: 0.15)`
- Title: `AppTypography.titleMedium`
- Subtitle: `AppTypography.bodySmall` with muted color
- Container size: 72x72 (not 80x80)

**Step 3: Run flutter analyze + commit**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub && git add lib/widgets/empty_state.dart && git commit -m "design: update EmptyState to match editorial design language"
```

---

## Task 10: Typography cleanup — Detail screen and Settings

**Files:**
- Modify: `lib/screens/details/mobile_note_detail.dart`
- Modify: `lib/screens/details/widgets/detail_content.dart`
- Modify: `lib/screens/settings/mobile_settings.dart`

**Step 1: Read all three files**

**Step 2: Detail screen — update text styles**

In `detail_content.dart`:
- Note title: `AppTypography.titleLarge` (was likely `titleMedium` or `headlineSmall`)
- Note body/transcript: `AppTypography.bodyMedium.copyWith(height: 1.6)`
- Section labels: `AppTypography.labelMedium.copyWith(letterSpacing: 0.3)`

In `mobile_note_detail.dart`:
- AppBar title: `AppTypography.titleSmall`
- Ensure bottom padding of 100px for FAB clearance

**Step 3: Settings screen — update text styles and section headers**

In `mobile_settings.dart`, section headers should use:
```dart
Text(
  'SECTION TITLE',
  style: AppTypography.labelSmall.copyWith(
    color: isDark ? AppPalette.textLabelDark : AppPalette.textLabelLight,
    letterSpacing: 0.8,
    fontWeight: FontWeight.w600,
  ),
)
```

**Step 4: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```

**Step 5: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/screens/details/ lib/screens/settings/mobile_settings.dart && git commit -m "design: typography cleanup on detail and settings screens"
```

---

## Task 11: Final polish — FAB and recording indicator

**Files:**
- Modify: `lib/screens/shells/mobile_shell.dart`

**Step 1: Read the FAB section in mobile_shell.dart**

**Step 2: Update FAB styling**

The FAB (record button) should be:
```dart
FloatingActionButton(
  onPressed: _handleRecord,
  backgroundColor: isRecording ? AppPalette.danger : AppPalette.primary,
  foregroundColor: Colors.white,
  elevation: 4,
  shape: const CircleBorder(),
  child: Icon(
    isRecording ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
    size: 20,
  ),
)
```

- Teal background when idle (not black)
- Red only when actively recording
- Clean circle shape with elevation 4

**Step 3: Update recording indicator pill**

The recording indicator at the bottom should use the new typography:
```dart
// Recording indicator container
Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  decoration: BoxDecoration(
    color: AppPalette.onSurfaceLight, // near-black
    borderRadius: BorderRadius.circular(100),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Red dot
      Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppPalette.danger,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        elapsedTime,
        style: AppTypography.labelMedium.copyWith(
          color: Colors.white,
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
      ),
    ],
  ),
)
```

**Step 4: Run flutter analyze**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```

**Step 5: Commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add lib/screens/shells/mobile_shell.dart && git commit -m "design: teal FAB, refined recording indicator"
```

---

## Task 12: Final verification

**Step 1: Run full analysis**
```bash
cd /Users/pretheesh/Projects/fikr && flutter analyze --no-pub
```
Expected: No issues.

**Step 2: Run on device**
```bash
cd /Users/pretheesh/Projects/fikr && flutter run -d macos
```
Or target iOS simulator if available.

**Step 3: Visual checklist**
- [ ] Home screen shows wordmark header, no dark banner
- [ ] Note cards have shadow, no border, 16px radius
- [ ] Typography is Plus Jakarta Sans (headings) + Inter (body) — visible difference from before
- [ ] Bottom nav has 4 tabs: Notes, Insights, Tasks, Settings
- [ ] Tasks tab shows active/completed sections with orange checkboxes
- [ ] Insights screen has stacked highlight cards with left color bar
- [ ] FAB is teal (not black), turns red when recording
- [ ] Tags are pill-shaped with teal tint
- [ ] Dark mode still looks correct

**Step 4: Fix any visual issues found during review**

**Step 5: Final commit**
```bash
cd /Users/pretheesh/Projects/fikr && git add -A && git commit -m "design: complete visual redesign — editorial light theme, new nav, tasks tab"
```
