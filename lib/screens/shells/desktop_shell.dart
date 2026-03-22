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
    return Row(
      children: [
        _PrimarySidebar(
          currentIndex: index,
          onSelect: onSelect,
          onRecord: onRecord,
        ),
        Expanded(
          child: Column(
            children: [
              _DesktopTopBar(
                title: title,
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
                            final note = await appController.createEmptyNote();
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
      ],
    );
  }
}

class _DesktopTopBar extends StatefulWidget {
  const _DesktopTopBar({
    required this.title,
    required this.showSettings,
    required this.onSettings,
    this.actions,
    this.isSearching = false,
    this.searchQuery = '',
    this.onSearchChanged,
    this.onSearchToggle,
  });

  final String title;
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
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(widget.title, style: theme.textTheme.titleMedium),
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

class _PrimarySidebar extends StatelessWidget {
  const _PrimarySidebar({
    required this.currentIndex,
    required this.onSelect,
    required this.onRecord,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: SvgPicture.asset(
                      Assets.getLogo(context),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Fikr',
                      style: TextStyle(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Obx(() {
                  final recordController = Get.find<RecordController>();
                  final isRecording = recordController.isRecording.value;
                  return FilledButton.icon(
                    onPressed: onRecord,
                    icon: Icon(
                      isRecording
                          ? FeatherIcons.square
                          : FeatherIcons.mic,
                      size: 16,
                    ),
                    label: Text(isRecording ? 'Stop Recording' : 'Record'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isRecording ? Colors.red : null,
                      foregroundColor: isRecording ? Colors.white : null,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              _SidebarItem(
                label: 'Notes',
                icon: FeatherIcons.fileText,
                activeIcon: FeatherIcons.fileText,
                selected: currentIndex == 0,
                onTap: () => onSelect(0),
              ),
              _SidebarItem(
                label: 'Insights',
                icon: FeatherIcons.trendingUp,
                activeIcon: FeatherIcons.trendingUp,
                selected: currentIndex == 1,
                onTap: () => onSelect(1),
              ),
              _SidebarItem(
                label: 'Tasks',
                icon: FeatherIcons.checkSquare,
                activeIcon: FeatherIcons.checkSquare,
                selected: currentIndex == 2,
                onTap: () => onSelect(2),
              ),
              _SidebarItem(
                label: 'Settings',
                icon: FeatherIcons.settings,
                activeIcon: FeatherIcons.settings,
                selected: currentIndex == 3,
                onTap: () => onSelect(3),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        selected: selected,
        leading: Icon(selected ? activeIcon : icon, size: 18),
        title: Text(label, style: theme.textTheme.bodyMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.1),
        selectedColor: colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
