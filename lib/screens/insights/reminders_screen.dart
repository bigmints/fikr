import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/app_controller.dart';
import '../../models/insights_models.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RemindersScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders'), elevation: 0),
      body: Obx(() {
        final activeReminders = controller.reminders
            .where((r) => !r.isDismissed)
            .toList();
        final dismissedReminders = controller.reminders
            .where((r) => r.isDismissed)
            .toList();

        if (controller.reminders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 48,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text('No reminders', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Reminders will be extracted\nfrom your voice notes.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (activeReminders.isNotEmpty) ...[
              ...activeReminders.map(
                (reminder) => _ReminderTile(
                  reminder: reminder,
                  onDismiss: () => controller.dismissReminder(reminder.id),
                ),
              ),
            ],
            if (dismissedReminders.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Dismissed',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              ...dismissedReminders.map(
                (reminder) =>
                    _ReminderTile(reminder: reminder, isDismissed: true),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    this.onDismiss,
    this.isDismissed = false,
  });
  final ReminderItem reminder;
  final VoidCallback? onDismiss;
  final bool isDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDismissed
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : null,
      child: ListTile(
        leading: Icon(
          Icons.notifications_active_rounded,
          color: isDismissed
              ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
              : theme.colorScheme.primary,
        ),
        title: Text(
          reminder.title,
          style: isDismissed
              ? theme.textTheme.bodyLarge?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                )
              : theme.textTheme.bodyLarge,
        ),
        subtitle: Text(
          _formatReminderDate(reminder),
          style: theme.textTheme.labelSmall,
        ),
        trailing: isDismissed
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
              ),
      ),
    );
  }

  String _formatReminderDate(ReminderItem reminder) {
    final formatted = DateFormat('MMM d, y').format(reminder.date);
    if (reminder.time != null && reminder.time!.isNotEmpty) {
      return '$formatted at ${reminder.time}';
    }
    return formatted;
  }
}
