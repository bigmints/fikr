import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../utils/app_spacing.dart';
import 'reminders_screen.dart';
import 'insights_history_screen.dart';
import 'widgets/topic_mind_map.dart';

class MobileInsights extends StatelessWidget {
  const MobileInsights({
    super.key,
    required this.mainContent,
    required this.controller,
  });

  final Widget mainContent;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Your morning clarity awaits ✨'
        : hour < 17
        ? 'Patterns emerging from your thoughts 🧠'
        : 'Evening reflections, distilled 🌙';

    final colors = isDark
        ? const [Color(0xFF3CA6A6), Color(0xFF67E8F9), Color(0xFFA78BFA)]
        : const [Color(0xFF0D9488), Color(0xFF2563EB), Color(0xFF7C3AED)];

    return Stack(
      children: [
        // ── Layer 1: Full-screen interactive mind map ──
        Positioned.fill(child: TopicMindMap(notes: controller.notes)),

        // ── Layer 2: Top bar overlay ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(top: topPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isDark ? Colors.black : Colors.white).withValues(
                    alpha: 0.85,
                  ),
                  (isDark ? Colors.black : Colors.white).withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'Insights',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          greeting,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppPalette.textBodyDark
                                : AppPalette.textBodyLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TopBarAction(
                    icon: FeatherIcons.bookOpen,
                    onTap: () => InsightsHistoryScreen.show(context),
                  ),
                  Obx(
                    () => _TopBarAction(
                      icon: FeatherIcons.refreshCw,
                      onTap: controller.insightsUpdating.value
                          ? null
                          : () => controller.captureInsightsEdition(),
                      isLoading: controller.insightsUpdating.value,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Layer 3: Draggable bottom sheet ──
        DraggableScrollableSheet(
          initialChildSize: 0.38,
          minChildSize: 0.12,
          maxChildSize: 0.92,
          snap: true,
          snapSizes: const [0.12, 0.38, 0.92],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppPalette.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Drag handle
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Reminders banner
                  SliverToBoxAdapter(
                    child: Obx(() {
                      final todayReminders = controller.reminders
                          .where((r) => !r.isDismissed && _isToday(r.date))
                          .toList();
                      if (todayReminders.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.7,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Today\'s Reminders',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () =>
                                        RemindersScreen.show(context),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'View All',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...todayReminders
                                  .take(3)
                                  .map(
                                    (r) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.circle, size: 6),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              r.title,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onPrimaryContainer,
                                                  ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                            onPressed: () => controller
                                                .dismissReminder(r.id),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  // Main content
                  SliverToBoxAdapter(child: mainContent),
                  SliverToBoxAdapter(
                    child: SizedBox(height: bottomPadding + 80),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppPalette.textBodyDark : AppPalette.textBodyLight;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon, size: 18, color: color),
      ),
    );
  }
}
