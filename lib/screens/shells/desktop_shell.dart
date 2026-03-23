import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/record_controller.dart';
import '../../utils/assets.dart';
import '../note_detail_screen.dart';

class DesktopShell extends StatelessWidget {
  const DesktopShell({
    super.key,
    required this.index,
    required this.title,
    required this.body,
    required this.onSelect,
    required this.onRecord,
    required this.showFilters,
    required this.onToggleFilters,
    required this.onSettings,
    this.insightsActions,
    this.isSearching = false,
    this.searchQuery = '',
    this.onSearchChanged,
    this.onSearchToggle,
  });

  final int index;
  final String title;
  final Widget body;
  final ValueChanged<int> onSelect;
  final VoidCallback onRecord;
  final bool showFilters;
  final VoidCallback onToggleFilters;
  final VoidCallback onSettings;
  final Widget? insightsActions;
  final bool isSearching;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchToggle;

  @override
  Widget build(BuildContext context) {
    bool isScrolled = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Row(
          children: [
            _PrimarySidebar(
              currentIndex: index,
              onSelect: onSelect,
              onRecord: onRecord,
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.vertical) {
                    final shouldShow = notification.metrics.pixels > 10;
                    if (shouldShow != isScrolled) {
                      setState(() => isScrolled = shouldShow);
                    }
                  }
                  return false;
                },
                child: Column(
                  children: [
                    _DesktopTopBar(
                      title: title,
                      isScrolled: isScrolled,
                      showSettings: index != 3,
                      onSettings: onSettings,
                      isSearching: isSearching,
                      searchQuery: searchQuery,
                      onSearchChanged: onSearchChanged,
                      onSearchToggle: onSearchToggle,
                      actions: index == 0
                          ? [
                              IconButton(
                                onPressed: () async {
                                  final appController = Get.find<AppController>();
                                  final note =
                                      await appController.createEmptyNote();
                                  if (context.mounted) {
                                    NoteDetailScreen.show(context, note);
                                  }
                                },
                                icon: const Icon(
                                  FeatherIcons.edit2,
                                  size: 18,
                                ),
                                tooltip: 'New Note',
                              ),
                              Obx(() {
                                final appController = Get.find<AppController>();
                                if (appController.notes.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: onSearchToggle,
                                      icon: Icon(
                                        isSearching
                                            ? FeatherIcons.x
                                            : FeatherIcons.search,
                                        size: 18,
                                      ),
                                      tooltip: isSearching
                                          ? 'Close Search'
                                          : 'Search',
                                    ),
                                    IconButton(
                                      onPressed: onToggleFilters,
                                      icon: Icon(
                                        showFilters
                                            ? FeatherIcons.filter
                                            : FeatherIcons.filter,
                                        size: 18,
                                      ),
                                      tooltip: showFilters
                                          ? 'Hide Filters'
                                          : 'Show Filters',
                                    ),
                                  ],
                                );
                              }),
                            ]
                          : index == 1 && insightsActions != null
                          ? [insightsActions!]
                          : null,
                    ),
                    Expanded(child: body),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DesktopTopBar extends StatefulWidget {
  const _DesktopTopBar({
    required this.title,
    this.isScrolled = false,
    required this.showSettings,
    required this.onSettings,
    this.actions,
    this.isSearching = false,
    this.searchQuery = '',
    this.onSearchChanged,
    this.onSearchToggle,
  });

  final String title;
  final bool isScrolled;
  final bool showSettings;
  final VoidCallback onSettings;
  final List<Widget>? actions;
  final bool isSearching;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchToggle;

  @override
  State<_DesktopTopBar> createState() => _DesktopTopBarState();
}

class _DesktopTopBarState extends State<_DesktopTopBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _DesktopTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Page-specific gradient colours matching the mobile collapsing header
    final gradientColors = switch (widget.title) {
      'Insights' => isDark
          ? const [Color(0xFF34D399), Color(0xFF6EE7B7)]
          : const [Color(0xFF059669), Color(0xFF10B981)],
      'Tasks' => isDark
          ? const [Color(0xFFF97316), Color(0xFFFBBF24)]
          : const [Color(0xFFEA580C), Color(0xFFCA8A04)],
      'Settings' => isDark
          ? const [Color(0xFF818CF8), Color(0xFFC084FC)]
          : const [Color(0xFF4F46E5), Color(0xFF9333EA)],
      _ /* Notes */ => isDark
          ? const [Color(0xFF3CA6A6), Color(0xFF67E8F9), Color(0xFFA78BFA)]
          : const [Color(0xFF0D9488), Color(0xFF2563EB), Color(0xFF7C3AED)],
    };

    final topPadding = MediaQuery.paddingOf(context).top;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 60 + topPadding,
      padding: EdgeInsets.only(
        top: topPadding,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: widget.isScrolled
            ? colorScheme.surface.withValues(alpha: 0.95)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: widget.isScrolled
                ? colorScheme.onSurface.withValues(alpha: 0.07)
                : Colors.transparent,
          ),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          // Logo in header, undecorated
          SvgPicture.asset(
            Assets.getLogo(context),
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const Spacer(),
          if (widget.isSearching)
            _ExpandingSearchField(
              controller: _controller,
              onChanged: widget.onSearchChanged,
              onClose: () {
                _controller.clear();
                widget.onSearchChanged?.call('');
                widget.onSearchToggle?.call();
              },
            ),
          if (widget.actions != null) ...widget.actions!,
        ],
      ),
    );
  }
}

class _ExpandingSearchField extends StatelessWidget {
  const _ExpandingSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: 280,
      height: 40,
      margin: const EdgeInsets.only(right: 8),
      child: TextField(
        controller: controller,
        autofocus: true,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search notes...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onClose,
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Docked FAB-style Rail ─────────────────────────────────

class _PrimarySidebar extends StatelessWidget {
  const _PrimarySidebar({
    required this.currentIndex,
    required this.onSelect,
    required this.onRecord,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onRecord;

  static const _items = [
    (icon: FeatherIcons.fileText,    label: 'Notes',    index: 0),
    (icon: FeatherIcons.trendingUp,  label: 'Insights', index: 1),
    (icon: FeatherIcons.checkSquare, label: 'Tasks',    index: 2),
    (icon: FeatherIcons.settings,    label: 'Settings', index: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Top items (Notes, Insights)
    final topItems = _items.sublist(0, 2);
    // Bottom items (Tasks, Settings)
    final bottomItems = _items.sublist(2);

    return SizedBox(
      width: 80,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Top nav items ──
              _DockedCard(
                isDark: isDark,
                colorScheme: colorScheme,
                child: Column(
                  children: [
                    for (final item in topItems)
                      _RailItem(
                        icon: item.icon,
                        label: item.label,
                        selected: currentIndex == item.index,
                        onTap: () => onSelect(item.index),
                        colorScheme: colorScheme,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── FAB (Record) ──
              Obx(() {
                final rc = Get.find<RecordController>();
                final isRecording = rc.isRecording.value;
                return GestureDetector(
                  onTap: onRecord,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isRecording
                          ? const Color(0xFFEF4444)
                          : colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isRecording
                                  ? const Color(0xFFEF4444)
                                  : colorScheme.primary)
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isRecording ? FeatherIcons.square : FeatherIcons.mic,
                      color: Colors.white,
                      size: isRecording ? 20 : 24,
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),

              // ── Bottom nav items ──
              _DockedCard(
                isDark: isDark,
                colorScheme: colorScheme,
                child: Column(
                  children: [
                    for (final item in bottomItems)
                      _RailItem(
                        icon: item.icon,
                        label: item.label,
                        selected: currentIndex == item.index,
                        onTap: () => onSelect(item.index),
                        colorScheme: colorScheme,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted-glass card container for docked rail sections.
class _DockedCard extends StatelessWidget {
  const _DockedCard({
    required this.isDark,
    required this.colorScheme,
    required this.child,
  });

  final bool isDark;
  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.85)
            : colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Single icon+label item for the docked FAB rail.
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.45);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
