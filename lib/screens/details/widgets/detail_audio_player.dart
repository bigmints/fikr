import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import '../../../utils/app_spacing.dart';
import '../note_detail_controller.dart';

class DetailAudioPlayer extends StatelessWidget {
  const DetailAudioPlayer({super.key, required this.controller});

  final NoteDetailController controller;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.hasAudio) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Obx(() {
      final isLoading = controller.isLoadingAudio.value;
      final isPlaying = controller.isPlaying.value;
      final duration = controller.duration.value;
      final position = controller.position.value;
      final progress = duration.inMilliseconds > 0
          ? position.inMilliseconds / duration.inMilliseconds
          : 0.0;

      return Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.sm,
          AppSpacing.pageHorizontal,
          MediaQuery.of(context).padding.bottom + AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.surfaceDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: Row(
          children: [
            // Play / Pause button
            GestureDetector(
              onTap: isLoading ? null : controller.togglePlayback,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isPlaying ? FeatherIcons.pause : FeatherIcons.play,
                        size: 16,
                        color: AppPalette.primary,
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Progress + time
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.06,
                      ),
                      valueColor: AlwaysStoppedAnimation(
                        AppPalette.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  // Time labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
