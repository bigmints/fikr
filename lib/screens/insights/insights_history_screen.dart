import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/app_config.dart';
import '../../models/insights_models.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import '../../widgets/tag_chip.dart';
import 'highlights_detail_screen.dart';

class InsightsHistoryScreen extends StatelessWidget {
  const InsightsHistoryScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InsightsHistoryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Journal', style: AppTypography.titleMedium),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Obx(() {
        final editions = controller.insightEditions;
        if (editions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 48,
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No editions yet',
                    style: AppTypography.headlineSmall.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate insights and they will be saved here as editions.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Group editions by date
        final grouped = <String, List<InsightEdition>>{};
        for (final edition in editions) {
          final key = DateFormat('MMM d, y').format(edition.createdAt);
          grouped.putIfAbsent(key, () => []).add(edition);
        }
        final dateKeys = grouped.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.md,
          ),
          itemCount: dateKeys.length,
          itemBuilder: (context, dateIndex) {
            final dateLabel = dateKeys[dateIndex];
            final dayEditions = grouped[dateLabel]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dateIndex > 0) const SizedBox(height: AppSpacing.lg),
                // ── Date header ──
                Padding(
                  padding: const EdgeInsets.only(
                    left: 28, // align with timeline content
                    bottom: AppSpacing.sm,
                  ),
                  child: Text(
                    _friendlyDate(dayEditions.first.createdAt),
                    style: AppTypography.titleSmall.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // ── Timeline entries for this date ──
                ...List.generate(dayEditions.length, (i) {
                  final edition = dayEditions[i];
                  final isLast =
                      i == dayEditions.length - 1 &&
                      dateIndex == dateKeys.length - 1;

                  return _TimelineEntry(
                    edition: edition,
                    isLast: isLast,
                    isDark: isDark,
                  );
                }),
              ],
            );
          },
        );
      }),
    );
  }

  String _friendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date); // "Monday"
    return DateFormat('MMM d, y').format(date);
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.edition,
    required this.isLast,
    required this.isDark,
  });

  final InsightEdition edition;
  final bool isLast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = DateFormat('h:mm a').format(edition.createdAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline rail ──
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Dot
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                    border: Border.all(
                      color: isDark
                          ? theme.colorScheme.surface
                          : theme.colorScheme.surface,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Content card ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                decoration: AppPalette.cardDecoration(context),
                padding: const EdgeInsets.all(AppSpacing.cardInner),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time label
                    Text(
                      timeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Summary
                    Text(
                      edition.summary,
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Highlights chips
                    if (edition.highlights.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: edition.highlights.map((h) {
                          final color = AppConfig.getBucketColor(h.bucket);
                          return GestureDetector(
                            onTap: () =>
                                HighlightsDetailScreen.show(context, [h]),
                            child: TagChip(label: h.bucket, color: color),
                          );
                        }).toList(),
                      ),
                    ],

                    // Buckets used
                    if (edition.buckets.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              edition.buckets.join(', '),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
