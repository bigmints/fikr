import 'package:flutter/material.dart';
import '../../../controllers/theme_controller.dart';
import '../../../models/app_config.dart';
import '../../../models/insights_models.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../../../widgets/tag_chip.dart';
import '../top_ideas_detail_screen.dart';
import '../highlights_detail_screen.dart';

class TopIdeasSection extends StatefulWidget {
  const TopIdeasSection({super.key, required this.ideaNotes});
  final List<InsightIdeaNote> ideaNotes;

  @override
  State<TopIdeasSection> createState() => _TopIdeasSectionState();
}

class _TopIdeasSectionState extends State<TopIdeasSection> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ideas = widget.ideaNotes.take(5).toList();
    if (ideas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header — uses page-level horizontal padding
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Text(
                'Highlights',
                style: AppTypography.titleMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    TopIdeasDetailScreen.show(context, widget.ideaNotes),
                child: Text(
                  'See All',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal scrolling cards
        SizedBox(
          height: 220,
          child: ListView.separated(
            // Match page horizontal padding on both sides
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
            ),
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: ideas.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final idea = ideas[index];
              final color = AppConfig.getBucketColor(idea.bucket);

              return SizedBox(
                width: 280,
                child: Container(
                  decoration: AppPalette.cardDecoration(context),
                  child: GestureDetector(
                    onTap: () =>
                        TopIdeasDetailScreen.show(context, widget.ideaNotes),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.cardInner),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TagChip(label: idea.bucket, color: color),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            idea.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              idea.snippet,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppPalette.textBodyDark
                                    : AppPalette.textBodyLight,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class HighlightTile extends StatelessWidget {
  const HighlightTile({super.key, required this.item, required this.index});
  final InsightHighlight item;
  final int index;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = AppConfig.getBucketColor(item.title);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: AppPalette.cardDecoration(context),
      child: GestureDetector(
        onTap: () => HighlightsDetailScreen.show(context, [item]),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardInner),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '#$index',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  if (item.citations.isNotEmpty)
                    Text(
                      '${item.citations.length} sources',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (item.bucket.isNotEmpty) ...[
                TagChip(label: item.bucket, color: color),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(
                item.title.isNotEmpty ? item.title : 'Highlight #$index',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.detail.isNotEmpty
                    ? item.detail
                    : 'Tap to read this highlight.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppPalette.textBodyDark
                      : AppPalette.textBodyLight,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
