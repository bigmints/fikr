import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import 'package:fikr/screens/insights_screen.dart';
import 'package:fikr/screens/new_home_screen.dart';
import 'package:fikr/screens/settings_screen.dart';
import 'package:fikr/screens/settings/widgets/provider_setup_dialog.dart';
import 'package:fikr/screens/tasks/tasks_screen.dart';
import 'package:fikr/screens/shells/desktop_shell.dart';
import 'package:fikr/screens/shells/mobile_shell.dart';
import 'package:fikr/screens/insights/widgets/insight_dialogs.dart';

import '../utils/layout.dart';

import '../controllers/app_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/record_controller.dart';

class HomeShell extends StatelessWidget {
  HomeShell({super.key});

  final NavigationController navController = Get.put(NavigationController());
  final RecordController recordController = Get.put(RecordController());

  final List<Widget> _screens = const [
    NewHomeScreen(),
    InsightsScreen(),
    TasksScreen(),
    SettingsScreen(),
  ];

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Notes';
      case 1:
        return 'Insights';
      case 2:
        return 'Tasks';
      case 3:
        return 'Settings';
      default:
        return 'Notes';
    }
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _handleRecord(
    BuildContext context,
    AppController appController,
    RecordController recordController,
    NavigationController navController,
  ) async {
    if (!appController.canRecord.value && !recordController.isRecording.value) {
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const ProviderSetupDialog(),
          fullscreenDialog: true,
        ),
      );

      if (success == true) {
        // Give a tiny delay for state to settle/UI to pop completely
        await Future.delayed(const Duration(milliseconds: 300));
        recordController.startRecording();
      }
      return;
    }
    recordController.toggleRecording();
  }

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = isDesktopConstraints(constraints);
        return Obx(() {
          final index = navController.index.value;

          final bodyContent = Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey(index),
                  child: _screens[index],
                ),
              ),
              Obx(() {
                final isRecording = recordController.isRecording.value;
                if (!isRecording) return const SizedBox.shrink();
                return Positioned(
                  bottom: wide ? 24 : 80,
                  left: 24,
                  right: 24,
                  child: Center(
                    child: _RecordingIndicator(
                      elapsed: recordController.elapsedSeconds.value,
                      level: recordController.visualLevel.value,
                      formatDuration: _formatDuration,
                    ),
                  ),
                );
              }),
              Obx(() {
                final isLoading = appController.loading.value;
                if (!isLoading) return const SizedBox.shrink();
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 3,
                  ),
                );
              }),
            ],
          );

          if (wide) {
            return Scaffold(
              body: DesktopShell(
                index: index,
                title: _titleForIndex(index),
                body: bodyContent,
                onSelect: (i) {
                  if (i != 0) {
                    navController.closeSearch();
                    appController.clearSearch();
                  }
                  navController.setIndex(i);
                },
                onRecord: () => _handleRecord(
                  context,
                  appController,
                  recordController,
                  navController,
                ),
                showFilters: appController.showFilters.value,
                onToggleFilters: () => appController.showFilters.value =
                    !appController.showFilters.value,
                onSettings: () {
                  navController.closeSearch();
                  appController.clearSearch();
                  navController.setIndex(3);
                },
                insightsActions: index == 1
                    ? _buildInsightsActions(context, appController)
                    : null,
                isSearching: navController.isSearching.value,
                searchQuery: appController.searchQuery.value,
                onSearchChanged: (q) => appController.searchQuery.value = q,
                onSearchToggle: () {
                  navController.toggleSearch();
                  if (!navController.isSearching.value) {
                    appController.clearSearch();
                  }
                },
              ),
            );
          } else {
            return MobileShell(
              index: index,
              title: _titleForIndex(index),
              body: bodyContent,
              hideAppBar: true, // All tabs use collapsing headers
              onSelect: (i) {
                if (i != 0) {
                  navController.closeSearch();
                  appController.clearSearch();
                }
                navController.setIndex(i);
              },
              onRecord: () => _handleRecord(
                context,
                appController,
                recordController,
                navController,
              ),
              isSearching: navController.isSearching.value,
              searchQuery: appController.searchQuery.value,
              onSearchChanged: (q) => appController.searchQuery.value = q,
              onSearchToggle: () {
                navController.toggleSearch();
                if (!navController.isSearching.value) {
                  appController.clearSearch();
                }
              },
            );
          }
        });
      },
    );
  }

  Widget _buildInsightsActions(BuildContext context, AppController controller) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => showInsightsBucketDialog(context, controller),
          icon: const Icon(FeatherIcons.tag, size: 18),
          tooltip: 'Buckets',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => showInsightsHistoryDialog(context, controller),
          icon: const Icon(FeatherIcons.clock, size: 18),
          tooltip: 'History',
        ),
        const SizedBox(width: 8),
        Obx(
          () => IconButton(
            onPressed: controller.insightsUpdating.value
                ? null
                : controller.captureInsightsEdition,
            icon: controller.insightsUpdating.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(FeatherIcons.refreshCw, size: 18),
            tooltip: 'Update Insights',
          ),
        ),
      ],
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({
    required this.elapsed,
    required this.level,
    required this.formatDuration,
  });

  final int elapsed;
  final double level;
  final String Function(int) formatDuration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            formatDuration(elapsed),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 60,
            height: 20,
            child: CustomPaint(painter: _WaveformPainter(level: level)),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.level});
  final double level;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final random = math.Random(42);
    for (int i = 0; i < 10; i++) {
      final h =
          (size.height * 0.3) +
          (size.height * 0.7 * level * random.nextDouble());
      final x = (size.width / 9) * i;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.level != level;
}
