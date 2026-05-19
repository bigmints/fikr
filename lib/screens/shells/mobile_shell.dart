import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/record_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/vision_controller.dart';
import '../../widgets/expandable_fab.dart';

class MobileShell extends StatelessWidget {
  const MobileShell({
    super.key,
    required this.index,
    required this.title,
    required this.body,
    required this.onSelect,
    required this.onRecord,
    this.actions,
    this.hideAppBar = false,
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
  final List<Widget>? actions;
  final bool hideAppBar;
  final bool isSearching;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recordController = Get.find<RecordController>();

    return Scaffold(
      appBar: hideAppBar
          ? null
          : AppBar(
              title: Text(title, style: theme.textTheme.titleMedium),
              centerTitle: false,
              backgroundColor: colorScheme.surface,
              scrolledUnderElevation: 0,
              elevation: 0,
              actions: actions,
            ),
      body: Column(
        children: [
          if (isSearching && !hideAppBar)
            _MobileSearchBar(
              query: searchQuery,
              onChanged: onSearchChanged,
              onClose: onSearchToggle,
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 65,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: FeatherIcons.fileText,
                label: 'Notes',
                isSelected: index == 0,
                onTap: () => onSelect(0),
                colorScheme: colorScheme,
              ),
              _NavItem(
                icon: FeatherIcons.trendingUp,
                label: 'Insights',
                isSelected: index == 1,
                onTap: () => onSelect(1),
                colorScheme: colorScheme,
              ),

              _NavItem(
                icon: FeatherIcons.checkSquare,
                label: 'Tasks',
                isSelected: index == 2,
                onTap: () => onSelect(2),
                colorScheme: colorScheme,
              ),
              _NavItem(
                icon: FeatherIcons.settings,
                label: 'Settings',
                isSelected: index == 3,
                onTap: () => onSelect(3),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Obx(() {
        final isRecording = recordController.isRecording.value;
        if (isRecording) {
          return SizedBox(
            height: 64,
            width: 64,
            child: FloatingActionButton(
              onPressed: onRecord,
              elevation: 4,
              backgroundColor: AppPalette.danger,
              shape: const CircleBorder(),
              child: const Icon(
                FeatherIcons.square,
                color: Colors.white,
                size: 24,
              ),
            ),
          );
        }

        return ExpandableFab(
          distance: 72,
          mainIcon: const Icon(
            FeatherIcons.plus,
            color: Colors.white,
            size: 28,
          ),
          backgroundColor: AppPalette.primary,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: FloatingActionButton(
                heroTag: 'fab_mic',
                onPressed: onRecord,
                backgroundColor: AppPalette.primary,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(
                  FeatherIcons.mic,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            SizedBox(
              width: 52,
              height: 52,
              child: FloatingActionButton(
                heroTag: 'fab_camera',
                onPressed: () {
                  final visionCtrl = Get.isRegistered<VisionController>()
                      ? Get.find<VisionController>()
                      : Get.put(VisionController());
                  _showVisionPickerOptions(context, visionCtrl);
                },
                backgroundColor: colorScheme.secondary,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(
                  FeatherIcons.camera,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showVisionPickerOptions(
    BuildContext context,
    VisionController controller,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(FeatherIcons.camera),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  controller.pickAndAnalyse(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.image),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  controller.pickAndAnalyse(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileSearchBar extends StatefulWidget {
  const _MobileSearchBar({
    required this.query,
    required this.onChanged,
    required this.onClose,
  });

  final String query;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClose;

  @override
  State<_MobileSearchBar> createState() => _MobileSearchBarState();
}

class _MobileSearchBarState extends State<_MobileSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _MobileSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
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
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search notes...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              _controller.clear();
              widget.onChanged?.call('');
              widget.onClose?.call();
            },
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ── Nav Item ─────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.45);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
