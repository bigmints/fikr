import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/navigation_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/app_config.dart';
import '../../models/note.dart';
import '../../widgets/collapsing_header.dart';
import '../../utils/app_spacing.dart';
import '../note_detail_screen.dart';
import '../../utils/layout.dart';
import 'widgets/note_card.dart';

class MobileHome extends StatelessWidget {
  const MobileHome({
    super.key,
    required this.notes,
    required this.allNotes,
    required this.emptyState,
  });

  final List<Note> notes;
  final List<Note> allNotes;
  final Widget emptyState;

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final isDesktop = context.isDesktop;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    final buckets = appController.config.value.buckets;
    final bucketCounts = <String, int>{'All': allNotes.length};
    for (final bucket in buckets) {
      bucketCounts[bucket] = 0;
    }
    for (final note in allNotes) {
      final bucket = note.bucket;
      bucketCounts[bucket] = (bucketCounts[bucket] ?? 0) + 1;
    }

    final entries =
        bucketCounts.entries
            .where(
              (e) =>
                  e.key == 'All' ||
                  e.key == appController.selectedBucket.value ||
                  e.value > 0,
            )
            .toList()
          ..sort((a, b) {
            if (a.key == 'All') return -1;
            if (b.key == 'All') return 1;
            return b.value.compareTo(a.value);
          });

    final groupedNotes = _groupNotes(notes, appController.groupBy.value);

    final noteCount = allNotes.length;
    final subtitle = noteCount == 0
        ? 'Start capturing your thoughts'
        : '$noteCount note${noteCount == 1 ? '' : 's'} captured';

    return CustomScrollView(
      slivers: [
        // Collapsing header
        SliverPersistentHeader(
          pinned: true,
          delegate: CollapsingSliverHeader(
            title: 'Notes',
            topPadding: topPadding,
            isDark: isDark,
            subtitle: subtitle,
            gradientColors: isDark
                ? const [
                    Color(0xFF3CA6A6),
                    Color(0xFF34D399),
                    Color(0xFF67E8F9),
                  ]
                : const [
                    Color(0xFF059669),
                    Color(0xFF0D9488),
                    Color(0xFF0891B2),
                  ],
            actions: [
              HeaderActionButton(
                icon: FeatherIcons.edit2,
                onTap: () async {
                  final note = await appController.createEmptyNote();
                  if (context.mounted) {
                    NoteDetailScreen.show(context, note);
                  }
                },
              ),
              if (allNotes.isNotEmpty)
                HeaderActionButton(
                  icon: FeatherIcons.search,
                  onTap: () {
                    final navController = Get.find<NavigationController>();
                    navController.toggleSearch();
                    if (!navController.isSearching.value) {
                      appController.clearSearch();
                    }
                  },
                ),
            ],
          ),
        ),

        // Search bar (below header)
        Obx(() {
          final navController = Get.find<NavigationController>();
          if (!navController.isSearching.value) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
                vertical: AppSpacing.xs,
              ),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      navController.closeSearch();
                      appController.clearSearch();
                    },
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (q) => appController.searchQuery.value = q,
              ),
            ),
          );
        }),

        // Bucket filter chips
        notes.isEmpty
            ? const SliverToBoxAdapter(child: SizedBox.shrink())
            : SliverToBoxAdapter(
                child: Padding(
                  padding: isDesktop
                      ? const EdgeInsets.all(0)
                      : EdgeInsets.all(AppSpacing.pageHorizontal),
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final selected =
                            entry.key == appController.selectedBucket.value;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (entry.key != 'All') ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppConfig.getBucketColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(entry.key),
                            ],
                          ),
                          selected: selected,
                          onSelected: (_) {
                            appController.selectedBucket.value = entry.key;
                          },
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                          selectedColor: AppPalette.primary,
                          backgroundColor: Colors.transparent,
                          shape: const StadiumBorder(
                            side: BorderSide(style: BorderStyle.none),
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppPalette.primary
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.3,
                                  ),
                            width: 1,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

        // Note list or empty state
        if (notes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: emptyState,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = groupedNotes[index];
                if (item is String) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      item,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: Colors.grey),
                    ),
                  );
                } else if (item is Note) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: NoteCard(
                      note: item,
                      onTap: () => NoteDetailScreen.show(context, item),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }, childCount: groupedNotes.length),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  List<dynamic> _groupNotes(List<Note> notes, String groupBy) {
    if (notes.isEmpty) return [];
    if (groupBy == 'none') return notes;

    final grouped = <String, List<Note>>{};
    for (final note in notes) {
      String key;
      final date = note.createdAt;
      final now = DateTime.now();

      if (groupBy == 'day') {
        if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          key = 'Today';
        } else if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day - 1) {
          key = 'Yesterday';
        } else {
          key = DateFormat('MMMM d, y').format(date);
        }
      } else if (groupBy == 'week') {
        final diff = now.difference(date).inDays;
        if (diff < 7) {
          key = 'This Week';
        } else if (diff < 14) {
          key = 'Last Week';
        } else {
          key = 'Older';
        }
      } else {
        key = DateFormat('MMMM y').format(date);
      }
      grouped.putIfAbsent(key, () => []).add(note);
    }

    final result = <dynamic>[];
    for (final entry in grouped.entries) {
      result.add(entry.key.toUpperCase());
      result.addAll(entry.value);
    }
    return result;
  }
}
