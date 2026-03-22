import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../controllers/theme_controller.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../../../models/app_config.dart';

// ─────────────────────────────────────────────────────────
// Next Steps — surface GeneratedInsights.nextSteps
// ─────────────────────────────────────────────────────────
class NextStepsSection extends StatelessWidget {
  const NextStepsSection({super.key, required this.steps});
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: FeatherIcons.arrowRight, label: 'NEXT STEPS'),
          SizedBox(height: AppSpacing.sm),
          ...steps.take(5).map((step) => _StepTile(text: step)),
          SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Open Questions & Risks
// ─────────────────────────────────────────────────────────
class QuestionsRisksSection extends StatelessWidget {
  const QuestionsRisksSection({
    super.key,
    required this.questions,
    required this.risks,
  });
  final List<String> questions;
  final List<String> risks;

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty && risks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (questions.isNotEmpty) ...[
            _SectionHeader(
              icon: FeatherIcons.helpCircle,
              label: 'OPEN QUESTIONS',
            ),
            SizedBox(height: AppSpacing.sm),
            ...questions
                .take(4)
                .map(
                  (q) => _AlertCard(
                    text: q,
                    color: AppPalette.primary,
                    icon: FeatherIcons.helpCircle,
                  ),
                ),
            SizedBox(height: AppSpacing.lg),
          ],
          if (risks.isNotEmpty) ...[
            _SectionHeader(icon: FeatherIcons.alertTriangle, label: 'RISKS'),
            SizedBox(height: AppSpacing.sm),
            ...risks
                .take(3)
                .map(
                  (r) => _AlertCard(
                    text: r,
                    color: const Color(0xFFE67E22),
                    icon: FeatherIcons.alertTriangle,
                  ),
                ),
            SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.text,
    required this.color,
    required this.icon,
  });
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.xs),
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.15 : 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Focus Areas — proportional bars
// ─────────────────────────────────────────────────────────
class FocusAreasSection extends StatelessWidget {
  const FocusAreasSection({super.key, required this.bucketCounts});
  final Map<String, int> bucketCounts;

  @override
  Widget build(BuildContext context) {
    if (bucketCounts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort by count descending
    final sorted = bucketCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.first.value;
    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title matching Highlights style
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Focus Areas',
              style: AppTypography.titleMedium.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          ...sorted.map((entry) {
            final ratio = entry.value / maxCount;
            final pct = ((entry.value / total) * 100).round();
            final color = AppConfig.getBucketColor(entry.key);
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${entry.value} notes · $pct%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.05,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: isDark ? 0.8 : 0.6),
                                color.withValues(alpha: isDark ? 0.4 : 0.25),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Work Summaries
// ─────────────────────────────────────────────────────────
class WorkSummariesSection extends StatelessWidget {
  const WorkSummariesSection({super.key, required this.summaries});
  final List<String> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: FeatherIcons.fileText, label: 'WEEKLY RECAP'),
          SizedBox(height: AppSpacing.sm),
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: AppPalette.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: summaries.take(5).map((s) {
                return Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          s,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Shared section header
// ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        Icon(
          icon,
          size: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
