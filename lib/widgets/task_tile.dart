import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controllers/theme_controller.dart';
import '../../models/insights_models.dart';
import '../../utils/app_typography.dart';

/// A reusable task tile used across Insights, Tasks screen, etc.
/// Supports both active and completed states with swipe-to-delete.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.todo,
    required this.onToggle,
    this.onDelete,
    this.onTap,
    this.showSource = true,
    this.showDate = false,
    this.compact = false,
  });

  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool showSource;
  final bool showDate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = todo.isCompleted;

    final tile = InkWell(
      onTap: onTap ?? onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 8 : 12,
          horizontal: 4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox circle — always toggles completion
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 14, top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppPalette.taskAccent : null,
                  border: done
                      ? null
                      : Border.all(color: AppPalette.taskAccent, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: AppTypography.titleSmall.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (showSource && todo.source.isNotEmpty ||
                      showDate ||
                      done && todo.completedAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (showSource && todo.source.isNotEmpty) ...[
                          Icon(
                            Icons.link_rounded,
                            size: 12,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              todo.source,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (showDate && !done) ...[
                          if (showSource && todo.source.isNotEmpty)
                            const SizedBox(width: 12),
                          Text(
                            _formatDate(todo.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ],
                        if (done && todo.completedAt != null) ...[
                          if (showSource && todo.source.isNotEmpty)
                            const SizedBox(width: 12),
                          Text(
                            'Done ${DateFormat('MMM d').format(todo.completedAt!)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Wrap with swipe-to-delete if onDelete is provided
    if (onDelete != null) {
      return Dismissible(
        key: ValueKey(todo.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete!(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: theme.colorScheme.error,
          ),
        ),
        child: tile,
      );
    }

    return tile;
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}
