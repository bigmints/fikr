/// Usage domain tools — fetch and track Pro tier consumption metrics.
library;

import 'package:get/get.dart';

import '../../controllers/subscription_controller.dart';
import '../../services/fikr_api_service.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  usage.fetch
// ───────────────────────────────────────────────────────────────────────────

class UsageFetchTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'usage.fetch';

  @override
  String get description =>
      'Fetch current word-based usage statistics for the authenticated user. '
      'Pro tier only. Returns {"used": N, "limit": N, "resetDate": "..."}. ';

  @override
  Map<String, dynamic> get parametersSchema =>
      {'type': 'object', 'properties': {}};

  @override
  ToolTier get requiredTier => ToolTier.pro;

  @override
  ToolLocation get location => ToolLocation.cloud;

  @override
  List<String> get tags => ['usage', 'billing'];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) =>
      guard(context, () async {
        final sub = Get.find<SubscriptionController>();
        if (!sub.hasManagedVertexAI) {
          return ToolResult.fail(
            'usage.fetch is only available for Pro users.',
            code: ToolResultCode.tierDenied,
            toolName: name,
            traceId: context.traceId,
          );
        }

        context.logger.info('Fetching usage stats from fikr.one');
        final stats = await FikrApiService().getUsageStats();
        context.logger.metric('wordsUsed', stats?.wordsUsed ?? 0);

        final payload = stats == null
            ? {'used': 0, 'limit': 0}
            : {
                'wordsUsed': stats.wordsUsed,
                'wordsLimit': stats.wordsLimit,
                'percentUsed': stats.percentUsed,
                'isNearLimit': stats.isNearLimit,
                'isAtLimit': stats.isAtLimit,
              };

        return ToolResult.ok(
          payload,
        );
      });
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allUsageTools() => [
      UsageFetchTool(),
    ];
