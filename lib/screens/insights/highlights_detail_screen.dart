import 'package:flutter/material.dart';
import '../../controllers/theme_controller.dart';
import '../../models/app_config.dart';
import '../../models/insights_models.dart';
import '../../utils/app_typography.dart';
import '../../widgets/tag_chip.dart';

class HighlightsDetailScreen extends StatelessWidget {
  const HighlightsDetailScreen({super.key, required this.highlights});
  final List<InsightHighlight> highlights;

  static void show(BuildContext context, List<InsightHighlight> highlights) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HighlightsDetailScreen(highlights: highlights),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Highlights', style: AppTypography.titleMedium),
        elevation: 0,
      ),
      body: highlights.isEmpty
          ? Center(
              child: Text(
                'No highlights yet',
                style: AppTypography.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: highlights.length,
              separatorBuilder: (context, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = highlights[index];
                final color = AppConfig.getBucketColor(item.title);

                return Container(
                  decoration: AppPalette.cardDecoration(context),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '#${index + 1}',
                                style: AppTypography.titleSmall.copyWith(
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.bucket.isNotEmpty)
                                  TagChip(label: item.bucket, color: color),
                                const SizedBox(height: 4),
                                Text(
                                  item.title,
                                  style: AppTypography.titleLarge.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.detail,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark
                              ? AppPalette.textBodyDark
                              : AppPalette.textBodyLight,
                          height: 1.5,
                        ),
                      ),
                      if (item.citations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Sources',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...item.citations.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 14,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    c,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
