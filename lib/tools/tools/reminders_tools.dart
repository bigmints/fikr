/// Reminders domain tools — manage time-sensitive reminder items.
library;

import 'dart:async';

import 'package:fikr/tools/app_state_resolver.dart';
import 'package:uuid/uuid.dart';

import '../../models/insights_models.dart';
import '../../services/notification_service.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  reminders.list
// ───────────────────────────────────────────────────────────────────────────

class RemindersListTool extends FikrTool {
  @override
  String get name => 'reminders.list';

  @override
  String get description =>
      'List reminders. Filter by active (not dismissed) or all.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'includeDissmissed': {
        'type': 'boolean',
        'default': false,
        'description': 'Whether to include dismissed reminders.',
      },
    },
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = appState();
      final includeAll = params['includeDissmissed'] as bool? ?? false;

      var items = ctrl.reminders.toList();
      if (!includeAll) {
        items = items.where((r) => !r.isDismissed).toList();
      }

      return ToolResult.ok(items.map((r) => r.toJson()).toList());
    } catch (e) {
      return ToolResult.fail('Failed to list reminders: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  reminders.create
// ───────────────────────────────────────────────────────────────────────────

class RemindersCreateTool extends FikrTool {
  @override
  String get name => 'reminders.create';

  @override
  String get description =>
      'Create a reminder with a title, date, and optional time.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'date': {
        'type': 'string',
        'description': 'ISO 8601 date (e.g. 2026-03-25)',
      },
      'time': {
        'type': 'string',
        'description': 'Optional time (e.g. 14:30)',
      },
      'sourceNoteId': {'type': 'string'},
    },
    'required': ['title', 'date'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = appState();
      final item = ReminderItem(
        id: const Uuid().v4(),
        title: params['title'] as String,
        date: DateTime.parse(params['date'] as String),
        time: params['time'] as String?,
        sourceNoteId: params['sourceNoteId'] as String? ?? '',
      );
      ctrl.reminders.add(item);
      await ctrl.saveReminders();

      // Schedule OS-level notification so it fires even when app is closed
      unawaited(NotificationService.instance.scheduleReminder(item));

      return ToolResult.ok(item.toJson());
    } catch (e) {
      return ToolResult.fail('Failed to create reminder: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  reminders.dismiss
// ───────────────────────────────────────────────────────────────────────────

class RemindersDismissTool extends FikrTool {
  @override
  String get name => 'reminders.dismiss';

  @override
  String get description => 'Dismiss a reminder by ID.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'Reminder ID'},
    },
    'required': ['id'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = appState();
      final id = params['id'] as String;
      final index = ctrl.reminders.indexWhere((r) => r.id == id);
      if (index == -1) return ToolResult.fail('Reminder not found: $id');

      ctrl.reminders[index] = ctrl.reminders[index].copyWith(isDismissed: true);
      await ctrl.saveReminders();

      // Cancel any pending OS notification
      unawaited(NotificationService.instance.cancelReminder(id));

      return ToolResult.ok({'dismissed': id});
    } catch (e) {
      return ToolResult.fail('Failed to dismiss reminder: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  reminders.reschedule
// ───────────────────────────────────────────────────────────────────────────

class RemindersRescheduleTool extends FikrTool {
  @override
  String get name => 'reminders.reschedule';

  @override
  String get description => 'Reschedule a reminder to a new date/time.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'id': {'type': 'string'},
      'date': {'type': 'string', 'description': 'New ISO 8601 date'},
      'time': {'type': 'string', 'description': 'New time (e.g. 14:30)'},
    },
    'required': ['id', 'date'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = appState();
      final id = params['id'] as String;
      final index = ctrl.reminders.indexWhere((r) => r.id == id);
      if (index == -1) return ToolResult.fail('Reminder not found: $id');

      final old = ctrl.reminders[index];
      final updated = ReminderItem(
        id: old.id,
        title: old.title,
        date: DateTime.parse(params['date'] as String),
        time: params['time'] as String? ?? old.time,
        sourceNoteId: old.sourceNoteId,
        isDismissed: false,
      );
      ctrl.reminders[index] = updated;
      await ctrl.saveReminders();

      // Cancel old notification and re-schedule
      unawaited(
        NotificationService.instance.cancelReminder(id).then(
          (_) => NotificationService.instance.scheduleReminder(updated),
        ),
      );

      return ToolResult.ok(ctrl.reminders[index].toJson());
    } catch (e) {
      return ToolResult.fail('Failed to reschedule reminder: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allRemindersTools() => [
      RemindersListTool(),
      RemindersCreateTool(),
      RemindersDismissTool(),
      RemindersRescheduleTool(),
    ];
