/// Notifications domain tools — in-app and push notifications.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';

import '../../services/fikr_api_service.dart';
import '../../services/toast_service.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  notify.in_app
// ───────────────────────────────────────────────────────────────────────────

class NotifyInAppTool extends FikrTool with FikrToolMixin {
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
  List<String> get tags => ['notify', 'ui'];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) => guard(context, () async {
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
  });
}

// ───────────────────────────────────────────────────────────────────────────
//  notify.push
// ───────────────────────────────────────────────────────────────────────────

class NotifyPushTool extends FikrTool with FikrToolMixin {
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
  List<String> get tags => ['notify', 'push'];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) => guard(context, () async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      return ToolResult.fail('No FCM token available on this device.');
    }
    
    final title = params['title'] as String;
    final body = params['body'] as String;
    
    final success = await FikrApiService().sendPushNotification(
      token: token,
      title: title,
      body: body,
    );
    
    if (success) {
      return ToolResult.ok({'notified': true, 'push_sent': true});
    } else {
      return ToolResult.fail('Backend failed to send push notification.');
    }
  });
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allNotificationsTools() => [
      NotifyInAppTool(),
      NotifyPushTool(),
    ];
