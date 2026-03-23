import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../controllers/theme_controller.dart';
import '../../../models/app_config.dart';
import '../../../models/note.dart';
import '../../../utils/app_typography.dart';
import '../../../widgets/tag_chip.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteCard({super.key, required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mainTopic = note.bucket;
    final bucketColor = AppConfig.getBucketColor(mainTopic);

    final textBodyColor = isDark
        ? AppPalette.textBodyDark
        : AppPalette.textBodyLight;
    final textLabelColor = isDark
        ? AppPalette.textLabelDark
        : AppPalette.textLabelLight;

    return Hero(
      tag: 'note-${note.id}',
      child: GestureDetector(
        onTap: note.isProcessing ? null : onTap,
        child: Container(
          decoration: AppPalette.cardDecoration(context),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title.isNotEmpty ? note.title : 'Untitled Note',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (note.isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  color: textBodyColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TagChip(label: mainTopic, color: bucketColor),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, y').format(note.createdAt),
                    style: AppTypography.labelSmall.copyWith(
                      color: textLabelColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
