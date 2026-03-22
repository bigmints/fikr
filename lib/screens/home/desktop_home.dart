import 'package:fikr/models/app_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/app_controller.dart';
import '../../models/note.dart';
import '../note_detail_screen.dart';
import 'widgets/note_card.dart';

class DesktopHome extends StatelessWidget {
  const DesktopHome({
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
    final width = MediaQuery.of(context).size.width;
    final gridCount = width >= 1600
        ? 4
        : width >= 900
        ? 3
        : 2;

    if (notes.isEmpty) {
      return emptyState;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GridView.builder(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  itemCount: notes.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCount,
                    mainAxisSpacing: 32,
                    crossAxisSpacing: 32,
                    childAspectRatio: gridCount >= 4
                        ? 1.4
                        : gridCount >= 3
                        ? 1.2
                        : gridCount > 1
                        ? 1.4
                        : 2.5,
                  ),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return NoteCard(
                      note: note,
                      onTap: () => NoteDetailScreen.show(context, note),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Obx(() {
          if (!appController.showFilters.value) return const SizedBox.shrink();
          return Row(
            children: [
              const SizedBox(width: 16),
              _FiltersSidebar(allNotes: allNotes),
            ],
          );
        }),
      ],
    );
  }
}

class _FiltersSidebar extends StatelessWidget {
  const _FiltersSidebar({required this.allNotes});

  final List<Note> allNotes;

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Obx(() {
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

      return SizedBox(
        width: 260,
        child: Card(
          margin: const EdgeInsets.fromLTRB(0, 8, 16, 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sort', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: appController.sortOrder.value,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                    DropdownMenuItem(
                      value: 'updated',
                      child: Text('Recently Edited'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      appController.sortOrder.value = value;
                    }
                  },
                ),
                const SizedBox(height: 20),
                Text('Tags', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Expanded(
                  child: ListTileTheme(
                    selectedColor: theme.colorScheme.primary,
                    selectedTileColor: theme.colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isSelected =
                            entry.key == appController.selectedBucket.value;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            selected: isSelected,
                            leading: entry.key == 'All'
                                ? const Opacity(
                                    opacity: 0,
                                    child: Icon(Icons.circle, size: 8),
                                  )
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppConfig.getBucketColor(
                                        entry.key,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            horizontalTitleGap: 0,
                            title: Text(entry.key),
                            trailing: Text(
                              entry.value.toString(),
                              style: textTheme.labelSmall?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                            ),
                            onTap: () {
                              appController.selectedBucket.value = entry.key;
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
