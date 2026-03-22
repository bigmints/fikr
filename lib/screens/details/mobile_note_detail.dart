import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import '../../controllers/theme_controller.dart';
import '../../utils/app_spacing.dart';
import 'note_detail_controller.dart';
import 'widgets/detail_audio_player.dart';
import 'widgets/detail_content.dart';

class MobileNoteDetail extends StatelessWidget {
  const MobileNoteDetail({super.key, required this.controller, this.onClose});

  final NoteDetailController controller;
  final VoidCallback? onClose;

  void _close(BuildContext context) {
    if (onClose != null) {
      onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Compact inline action bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxs,
                AppSpacing.xxs,
                AppSpacing.xs,
                0,
              ),
              child: Row(
                children: [
                  _PillButton(
                    icon: FeatherIcons.chevronLeft,
                    onTap: () => _close(context),
                  ),
                  const Spacer(),
                  Obx(
                    () => _PillButton(
                      icon: controller.isEditing.value
                          ? FeatherIcons.check
                          : FeatherIcons.edit2,
                      accent: controller.isEditing.value,
                      onTap: () {
                        if (controller.isEditing.value) {
                          controller.saveEdit();
                        } else {
                          controller.isEditing.value = true;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  _PillButton(
                    icon: FeatherIcons.trash2,
                    destructive: true,
                    onTap: () async {
                      final confirmed = await _showDeleteDialog(context);
                      if (confirmed == true) {
                        await controller.deleteNote();
                        if (context.mounted) _close(context);
                      }
                    },
                  ),
                ],
              ),
            ),

            // ── Scrollable content ──
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.sm,
                  AppSpacing.pageHorizontal,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailContent(controller: controller),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),

            // ── Bottom-pinned audio player ──
            DetailAudioPlayer(controller: controller),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Compact rounded icon button used in the action bar.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool accent;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color fg;
    Color bg;
    if (destructive) {
      fg = theme.colorScheme.error.withValues(alpha: 0.8);
      bg = theme.colorScheme.error.withValues(alpha: 0.08);
    } else if (accent) {
      fg = AppPalette.primary;
      bg = AppPalette.primary.withValues(alpha: 0.1);
    } else {
      fg = theme.colorScheme.onSurface.withValues(alpha: 0.7);
      bg = theme.colorScheme.onSurface.withValues(alpha: 0.06);
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
  }
}
