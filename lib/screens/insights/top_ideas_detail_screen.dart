import 'package:flutter/material.dart';
import '../../controllers/theme_controller.dart';
import '../../models/app_config.dart';
import '../../models/insights_models.dart';
import '../../utils/app_typography.dart';
import '../../widgets/tag_chip.dart';

class TopIdeasDetailScreen extends StatelessWidget {
  const TopIdeasDetailScreen({super.key, required this.ideaNotes});
  final List<InsightIdeaNote> ideaNotes;

  static void show(BuildContext context, List<InsightIdeaNote> ideaNotes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopIdeasDetailScreen(ideaNotes: ideaNotes),
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
      body: ideaNotes.isEmpty
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
              itemCount: ideaNotes.length,
              separatorBuilder: (context, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final idea = ideaNotes[index];
                final color = AppConfig.getBucketColor(idea.bucket);

                return Container(
                  decoration: AppPalette.cardDecoration(context),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TagChip(label: idea.bucket, color: color),
                      const SizedBox(height: 12),
                      Text(
                        idea.title,
                        style: AppTypography.titleLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        idea.snippet,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark
                              ? AppPalette.textBodyDark
                              : AppPalette.textBodyLight,
                          height: 1.5,
                        ),
                      ),
                      if (idea.topics.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: idea.topics
                              .map((topic) => TagChip(label: topic))
                              .toList(),
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
