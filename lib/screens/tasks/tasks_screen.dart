import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import '../../controllers/app_controller.dart';

import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import '../../utils/layout.dart';
import '../../widgets/collapsing_header.dart';
import '../../widgets/task_tile.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, this.embedded = true});

  /// When true, rendered as a tab body (no Scaffold/AppBar).
  /// When false, rendered as a pushed screen with its own AppBar.
  final bool embedded;

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TasksScreen(embedded: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!embedded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tasks'), elevation: 0),
        body: _TasksContent(),
      );
    }
    return _TasksContentWithHeader();
  }
}

/// Tasks content wrapped in a CustomScrollView with a collapsing header.
/// Used when embedded as a tab.
class _TasksContentWithHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Obx(() {
      final activeItems = controller.todoItems
          .where((t) => !t.isCompleted)
          .toList();
      final completedItems = controller.todoItems
          .where((t) => t.isCompleted)
          .toList();
      final totalCount = controller.todoItems.length;
      final doneCount = completedItems.length;

      final subtitle = totalCount == 0
          ? 'Your to-dos will appear here'
          : '$doneCount of $totalCount completed';

      final isMobileLayout = !context.isDesktop && !context.isDesktop;

      return Stack(
        children: [
          CustomScrollView(
            slivers: [
              if (isMobileLayout)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: CollapsingSliverHeader(
                    title: 'Tasks',
                    topPadding: topPadding,
                    isDark: isDark,
                    subtitle: subtitle,
                    gradientColors: isDark
                        ? const [
                            Color(0xFFF97316),
                            Color(0xFFFBBF24),
                            Color(0xFFF59E0B),
                          ]
                        : const [
                            Color(0xFFEA580C),
                            Color(0xFFD97706),
                            Color(0xFFCA8A04),
                          ],
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: ResponsiveCenter(
                    maxWidth: kContentMaxWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.xl,
                        bottom: AppSpacing.sm,
                        left: AppSpacing.pageHorizontal,
                        right: AppSpacing.pageHorizontal,
                      ),
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),

              if (controller.todoItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            size: 48,
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks yet',
                            style: AppTypography.headlineSmall.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Record a note and Fikr will find\nyour to-dos automatically,\nor tap + to add one.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: ResponsiveCenter(
                    maxWidth: kContentMaxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pageHorizontal,
                            vertical: AppSpacing.xs,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (activeItems.isNotEmpty)
                                ...activeItems.map(
                                  (todo) => TaskTile(
                                    todo: todo,
                                    onToggle: () =>
                                        controller.toggleTaskComplete(todo.id),
                                    onDelete: () =>
                                        controller.deleteTask(todo.id),
                                    onTap: () => _showEditSheet(
                                        context, controller, todo),
                                    showDate: true,
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.xl,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'All tasks completed! 🎉',
                                      style: AppTypography.titleMedium.copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              if (completedItems.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _CompletedSection(
                                  items: completedItems,
                                  onToggle: controller.toggleTaskComplete,
                                  onDelete: controller.deleteTask,
                                  onEdit: (todo) => _showEditSheet(
                                      context, controller, todo),
                                  onClearAll: () =>
                                      _confirmClearCompleted(context, controller),
                                ),
                              ],
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ── Add Task Button ──
          Positioned(
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 88,
            child: FloatingActionButton.small(
              heroTag: 'add_task',
              onPressed: () => _showAddSheet(context, controller),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 2,
              child: const Icon(Icons.add_rounded, size: 22),
            ),
          ),
        ],
      );
    });
  }
}

/// Original tasks content for pushed-screen usage.
class _TasksContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final theme = Theme.of(context);

    return Obx(() {
      final activeItems = controller.todoItems
          .where((t) => !t.isCompleted)
          .toList();
      final completedItems = controller.todoItems
          .where((t) => t.isCompleted)
          .toList();

      if (controller.todoItems.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 48,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No tasks yet',
                  style: AppTypography.headlineSmall.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Record a note and Fikr will find\nyour to-dos automatically,\nor tap + to add one.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.xs,
        ),
        children: [
          if (activeItems.isNotEmpty) ...[
            ...activeItems.map(
              (todo) => TaskTile(
                todo: todo,
                onToggle: () => controller.toggleTaskComplete(todo.id),
                onDelete: () => controller.deleteTask(todo.id),
                onTap: () => _showEditSheet(context, controller, todo),
                showDate: true,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'All tasks completed! 🎉',
                  style: AppTypography.titleMedium.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          if (completedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _CompletedSection(
              items: completedItems,
              onToggle: controller.toggleTaskComplete,
              onDelete: controller.deleteTask,
              onEdit: (todo) => _showEditSheet(context, controller, todo),
              onClearAll: () => _confirmClearCompleted(context, controller),
            ),
          ],
          const SizedBox(height: 100),
        ],
      );
    });
  }
}

// ── Shared helpers ──

void _showAddSheet(BuildContext context, AppController controller) {
  final textController = TextEditingController();
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Task', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'What do you need to do?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (value) {
                final title = value.trim();
                if (title.isNotEmpty) {
                  controller.addTask(title);
                  Navigator.pop(ctx);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final title = textController.text.trim();
                    if (title.isNotEmpty) {
                      controller.addTask(title);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void _showEditSheet(
  BuildContext context,
  AppController controller,
  dynamic todo,
) {
  final textController = TextEditingController(text: todo.title);
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Task', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Task title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (value) {
                final title = value.trim();
                if (title.isNotEmpty) {
                  controller.updateTaskTitle(todo.id, title);
                  Navigator.pop(ctx);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Delete button
                TextButton.icon(
                  onPressed: () {
                    controller.deleteTask(todo.id);
                    Navigator.pop(ctx);
                  },
                  icon: Icon(
                    FeatherIcons.trash2,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final title = textController.text.trim();
                    if (title.isNotEmpty) {
                      controller.updateTaskTitle(todo.id, title);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void _confirmClearCompleted(BuildContext context, AppController controller) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Clear Completed'),
      content: const Text(
        'Delete all completed tasks? This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            controller.deleteCompletedTasks();
            Navigator.pop(ctx);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

class _CompletedSection extends StatefulWidget {
  const _CompletedSection({
    required this.items,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onClearAll,
  });
  final List items;
  final Function(String) onToggle;
  final Function(String) onDelete;
  final Function(dynamic) onEdit;
  final VoidCallback onClearAll;

  @override
  State<_CompletedSection> createState() => _CompletedSectionState();
}

class _CompletedSectionState extends State<_CompletedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Expand/collapse toggle
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 20,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Completed (${widget.items.length})',
                        style: AppTypography.titleSmall.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Clear all button
            if (_expanded)
              TextButton.icon(
                onPressed: widget.onClearAll,
                icon: Icon(
                  FeatherIcons.trash2,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                label: Text(
                  'Clear all',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        if (_expanded)
          ...widget.items.map(
            (todo) => TaskTile(
              todo: todo,
              onToggle: () => widget.onToggle(todo.id),
              onDelete: () => widget.onDelete(todo.id),
              onTap: () => widget.onEdit(todo),
              showDate: true,
            ),
          ),
      ],
    );
  }
}
