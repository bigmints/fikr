import 'package:fikr/models/note.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'insights/desktop_insights.dart';
import 'insights/mobile_insights.dart';
import 'insights/widgets/insight_components.dart';
import 'insights/widgets/insight_sections.dart';
import 'insights/widgets/topic_mind_map.dart';

import '../utils/app_spacing.dart';
import '../utils/app_typography.dart';
import '../utils/layout.dart';

import '../controllers/app_controller.dart';
import '../models/insights_models.dart';
import '../widgets/empty_state.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.isDesktop;
        final isTablet = constraints.isTablet;
        final useWideLayout = isDesktop || isTablet;
        return Obx(() {
          if (controller.insightsUpdating.value) {
            return _InsightUpdateCard(
              status: controller.insightsUpdateStatus.value,
            );
          }

          if (controller.notes.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Your intellectual journey awaits',
              description:
                  'Every profound realization begins with a single thought. Record your first note and watch your tapestry of wisdom unfold.',
            );
          }

          if (controller.notes.length < 5) {
            return EmptyState(
              icon: Icons.eco_outlined,
              title: 'Gathering the seeds of wisdom',
              description:
                  'You\'ve started something beautiful. Capture at least 5 notes (${controller.notes.length}/5) to help our AI begin weaving your thoughts into meaningful patterns and insights.',
            );
          }

          final localInsights = controller.buildLocalInsights(controller.notes);
          final generated = controller.generatedInsights.value;

          if (generated == null && localInsights.ideaNotes.isEmpty) {
            return EmptyState(
              icon: Icons.insights_outlined,
              title: 'Let your thoughts talk to each other',
              description:
                  'Your mind has been busy. Let our AI uncover the beautiful connections between your ideas and reveal the wisdom you\'ve already captured.',
              action: FilledButton.icon(
                onPressed: () => controller.captureInsightsEdition(),
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: const Text('Discover My Insights'),
              ),
            );
          }

          final ideaNotes = localInsights.ideaNotes;

          // Compute bucket distribution
          final bucketCounts = <String, int>{};
          for (final note in controller.notes) {
            bucketCounts[note.bucket] = (bucketCounts[note.bucket] ?? 0) + 1;
          }

          final mainContent = _InsightsMainContent(
            localInsights: localInsights,
            generatedInsights: generated,
            ideaNotes: ideaNotes,
            notes: controller.notes,
            selectedBuckets: controller.selectedInsightBuckets,
            isDesktop: useWideLayout,
            bucketCounts: bucketCounts,
            onGenerateInsights: () => controller.captureInsightsEdition(),
          );

          if (!useWideLayout) {
            return MobileInsights(
              mainContent: mainContent,
              controller: controller,
            );
          }

          return DesktopInsights(
            mainContent: mainContent,
            controller: controller,
          );
        });
      },
    );
  }
}

class _InsightUpdateCard extends StatelessWidget {
  const _InsightUpdateCard({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text('Updating Insights', style: AppTypography.titleMedium),
                const SizedBox(height: 8),
                Text(
                  status.isNotEmpty ? status : 'Analyzing your thoughts...',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightsMainContent extends StatelessWidget {
  const _InsightsMainContent({
    required this.localInsights,
    required this.generatedInsights,
    required this.ideaNotes,
    required this.notes,
    required this.selectedBuckets,
    required this.isDesktop,
    required this.bucketCounts,
    this.onGenerateInsights,
  });

  final LocalInsights localInsights;
  final GeneratedInsights? generatedInsights;
  final List<InsightIdeaNote> ideaNotes;
  final List<Note> notes;
  final List<String> selectedBuckets;
  final bool isDesktop;
  final Map<String, int> bucketCounts;
  final VoidCallback? onGenerateInsights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gen = generatedInsights;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Mind Map (desktop only — mobile renders it as background)
        if (isDesktop) SizedBox(height: 400, child: TopicMindMap(notes: notes)),

        // 2. Highlights (horizontal cards)
        TopIdeasSection(ideaNotes: ideaNotes),
        SizedBox(height: AppSpacing.md),

        // 3. AI Summary
        if (gen != null && gen.summary.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(label: 'SUMMARY'),
                SizedBox(height: AppSpacing.sm),
                Text(
                  gen.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.6,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),

        // 4. Next Steps
        if (gen != null) NextStepsSection(steps: gen.nextSteps),

        // 5. Questions & Risks
        if (gen != null)
          QuestionsRisksSection(questions: gen.questions, risks: gen.risks),

        // 6. Focus Areas
        FocusAreasSection(bucketCounts: bucketCounts),

        // 7. Work Summaries
        if (gen != null) WorkSummariesSection(summaries: gen.workSummaries),

        // 8. Generate Insights CTA (when no AI insights yet)
        if (gen == null && onGenerateInsights != null)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
            ),
            child: Column(
              children: [
                SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onGenerateInsights,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Generate AI Insights'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Analyze your notes to unlock summaries, next steps, and more',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),

        SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
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
        const SizedBox(width: 8),
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
