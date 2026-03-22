import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../controllers/theme_controller.dart';
import '../../../models/app_config.dart';
import '../note_detail_controller.dart';
import '../../../utils/app_spacing.dart';
import '../../../widgets/tag_chip.dart';

class DetailContent extends StatelessWidget {
  const DetailContent({super.key, required this.controller});

  final NoteDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Obx(() {
      final isEditing = controller.isEditing.value;
      final topics = controller.topics;
      final bucketColor = topics.isNotEmpty
          ? AppConfig.getBucketColor(topics.first)
          : AppPalette.primary;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Metadata row ──
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaChip(
                icon: FeatherIcons.calendar,
                label: DateFormat(
                  'MMM d, yyyy',
                ).format(controller.note.createdAt),
              ),
              _MetaChip(
                icon: FeatherIcons.clock,
                label: DateFormat('h:mm a').format(controller.note.createdAt),
              ),
              if (topics.isNotEmpty)
                _BucketChip(label: topics.first, color: bucketColor),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Title ──
          if (isEditing)
            TextField(
              controller: controller.titleController,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              decoration: InputDecoration(
                hintText: 'Note Title',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintStyle: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              maxLines: null,
            )
          else
            Text(
              controller.titleController.text.isNotEmpty
                  ? controller.titleController.text
                  : 'Untitled Note',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // ── Transcript section ──
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: bucketColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'TRANSCRIPT',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.0,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Content area ──
          if (isEditing)
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.2,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPalette.primary.withValues(alpha: 0.15),
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: controller.textController,
                maxLines: null,
                style: textTheme.bodyLarge?.copyWith(height: 1.7),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Start writing your thoughts...',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            )
          else
            Text(
              controller.textController.text.isNotEmpty
                  ? controller.textController.text
                  : 'No content available.',
              style: textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.7,
              ),
            ),

          // ── Tags ──
          if (topics.length > 1) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Icon(
                  FeatherIcons.tag,
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'TAGS',
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.0,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: topics.skip(1).map((topic) {
                final color = AppConfig.getBucketColor(topic);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TagChip(label: topic, color: color),
                    if (isEditing) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => controller.removeTag(topic),
                        child: Icon(FeatherIcons.x, size: 10, color: color),
                      ),
                    ],
                  ],
                );
              }).toList(),
            ),
          ],

          // ── Add tag (editing mode) ──
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.tagController,
                      decoration: InputDecoration(
                        hintText: 'Add a tag...',
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => controller.addTag(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton.filled(
                    onPressed: () => controller.addTag(),
                    icon: const Icon(FeatherIcons.plus, size: 16),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

/// Compact metadata chip with icon.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colored bucket chip.
class _BucketChip extends StatelessWidget {
  const _BucketChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
