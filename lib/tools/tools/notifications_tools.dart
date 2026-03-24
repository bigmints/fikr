/// Notifications domain tools — in-app and push notifications.
library;


import 'package:get/get.dart';

import '../../services/toast_service.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  notify.in_app
// ───────────────────────────────────────────────────────────────────────────

class NotifyInAppTool extends FikrTool {
  @override
  String get name => 'notify.in_app';

  @override
  String get description =>
      'Show an in-app toast notification (success, error, or info).';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'description': 'Notification title.'},
      'description': {'type': 'string', 'description': 'Notification body.'},
      'type': {
        'type': 'string',
        'enum': ['success', 'error', 'info'],
        'default': 'info',
      },
    },
    'required': ['title'],
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
      final ctx = Get.context;
      if (ctx == null) return ToolResult.fail('No UI context available.');

      final title = params['title'] as String;
      final desc = params['description'] as String? ?? '';
      final type = params['type'] as String? ?? 'info';

      switch (type) {
        case 'success':
          ToastService.showSuccess(ctx, title: title, description: desc);
          break;
        case 'error':
          ToastService.showError(ctx, title: title, description: desc);
          break;
        default:
          ToastService.showInfo(ctx, title: title, description: desc);
      }

      return ToolResult.ok({'notified': true, 'type': type});
    } catch (e) {
      return ToolResult.fail('Notification failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  notify.push (placeholder — FCM implementation in Phase 5)
// ───────────────────────────────────────────────────────────────────────────

class NotifyPushTool extends FikrTool {
  @override
  String get name => 'notify.push';

  @override
  String get description =>
      'Send a push notification via Firebase Cloud Messaging. '
      'Requires Plus or Pro tier.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'body': {'type': 'string'},
    },
    'required': ['title', 'body'],
  };

  @override
  ToolTier get requiredTier => ToolTier.plus;

  @override
  ToolLocation get location => ToolLocation.cloud;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    // Phase 5 — FCM send via fikr.one
    return ToolResult.fail('Push notifications not yet implemented.');
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allNotificationsTools() => [
      NotifyInAppTool(),
      NotifyPushTool(),
    ];
