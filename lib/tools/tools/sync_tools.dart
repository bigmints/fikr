/// Sync domain tools — bidirectional data synchronization with Firestore.
library;

import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../services/sync_service.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  sync.push
// ───────────────────────────────────────────────────────────────────────────

class SyncPushTool extends FikrTool {
  @override
  String get name => 'sync.push';

  @override
  String get description => 'Push local data to Firestore (notes, tasks, etc.).';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {},
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
    try {
      final syncService = Get.find<SyncService>();
      await syncService.syncToCloud();
      return ToolResult.ok({'pushed': true});
    } catch (e) {
      return ToolResult.fail('Sync push failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  sync.pull
// ───────────────────────────────────────────────────────────────────────────

class SyncPullTool extends FikrTool {
  @override
  String get name => 'sync.pull';

  @override
  String get description =>
      'Pull data from Firestore and merge with local storage.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {},
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
    try {
      final syncService = Get.find<SyncService>();
      await syncService.syncFromCloud();
      final ctrl = Get.find<AppController>();
      await ctrl.reloadAllData();
      return ToolResult.ok({'pulled': true});
    } catch (e) {
      return ToolResult.fail('Sync pull failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  sync.status
// ───────────────────────────────────────────────────────────────────────────

class SyncStatusTool extends FikrTool {
  @override
  String get name => 'sync.status';

  @override
  String get description => 'Check the current sync status.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {},
  };

  @override
  ToolTier get requiredTier => ToolTier.plus;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      // SyncService is available — report that sync is configured.
      final hasSyncService = GetInstance().isRegistered<SyncService>();
      return ToolResult.ok({
        'syncAvailable': hasSyncService,
      });
    } catch (e) {
      return ToolResult.fail('Failed to check sync status: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allSyncTools() => [
      SyncPushTool(),
      SyncPullTool(),
      SyncStatusTool(),
    ];
