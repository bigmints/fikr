import 'package:flutter/material.dart';

const kDesktopBreakpoint = 920.0;
const kTabletBreakpoint = 640.0;

/// Max width for main content columns on tablet/desktop (notes, tasks, etc.)
const kContentMaxWidth = 720.0;

/// Max width for settings-style single-column content
const kSettingsMaxWidth = 580.0;

// Desktop: >= 920
bool isDesktopWidth(BuildContext context) {
  return MediaQuery.of(context).size.width >= kDesktopBreakpoint;
}

bool isDesktopConstraints(BoxConstraints constraints) {
  return constraints.maxWidth >= kDesktopBreakpoint;
}

// Tablet: >= 640 && < 920
bool isTabletWidth(BuildContext context) {
  return MediaQuery.of(context).size.width >= kTabletBreakpoint &&
      MediaQuery.of(context).size.width < kDesktopBreakpoint;
}

bool isTabletConstraints(BoxConstraints constraints) {
  return constraints.maxWidth >= kTabletBreakpoint &&
      constraints.maxWidth < kDesktopBreakpoint;
}

// Mobile: < 640
bool isMobileWidth(BuildContext context) {
  return MediaQuery.of(context).size.width < kTabletBreakpoint;
}

bool isMobileConstraints(BoxConstraints constraints) {
  return constraints.maxWidth < kTabletBreakpoint;
}

extension LayoutExtensions on BuildContext {
  bool get isDesktop => isDesktopWidth(this);
  bool get isTablet => isTabletWidth(this);
  bool get isMobile => isMobileWidth(this);
}

extension ConstraintExtensions on BoxConstraints {
  bool get isDesktop => isDesktopConstraints(this);
  bool get isTablet => isTabletConstraints(this);
  bool get isMobile => isMobileConstraints(this);
}

/// Centers [child] horizontally and constrains it to [maxWidth].
/// On narrow screens the constraint has no effect.
///
/// Use this to prevent content from stretching edge-to-edge on iPad/desktop.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
