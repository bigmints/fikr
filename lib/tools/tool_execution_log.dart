/// Tool Execution Log — global ring-buffer of all tool invocations.
///
/// Every call through [EngineController.executeTool] or [executeSkill] is
/// recorded here. Provides real-time observability, failure diagnostics,
/// and an audit trail for debugging.
library;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'tool_interface.dart';

/// Maximum number of invocations retained in memory.
const _kMaxHistory = 500;

/// GetxService that accumulates [ToolInvocation] records and exposes them
/// reactively to the UI.
class ToolExecutionLog extends GetxService {
  static ToolExecutionLog get instance {
    if (!GetInstance().isRegistered<ToolExecutionLog>()) {
      Get.put(ToolExecutionLog(), permanent: true);
    }
    return Get.find<ToolExecutionLog>();
  }


  /// Full invocation history (newest first, capped at [_kMaxHistory]).
  final RxList<ToolInvocation> history = <ToolInvocation>[].obs;

  /// Only the failed invocations from [history].
  List<ToolInvocation> get recentFailures =>
      history.where((i) => i.failed).toList();

  /// All invocations for a specific tool name.
  List<ToolInvocation> invocationsFor(String toolName) =>
      history.where((i) => i.toolName == toolName).toList();

  /// All invocations within the last N seconds.
  List<ToolInvocation> recentWithin(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return history.where((i) => i.invokedAt.isAfter(cutoff)).toList();
  }

  /// Record a completed invocation.
  void record(ToolInvocation inv) {
    history.insert(0, inv);
    if (history.length > _kMaxHistory) {
      history.removeRange(_kMaxHistory, history.length);
    }
    if (kDebugMode) {
      if (inv.failed) {
        debugPrint(
          '[ToolLog] ✗ FAIL  ${inv.toolName} | ${inv.result.code.name} '
          '| ${inv.result.error} | trace=${inv.traceId}',
        );
      } else {
        debugPrint(
          '[ToolLog] ✓ OK    ${inv.toolName} | ${inv.duration?.inMilliseconds}ms '
          '| trace=${inv.traceId}',
        );
      }
      // Print any structured log entries emitted by the tool itself
      for (final entry in inv.logEntries) {
        debugPrint(
          '[ToolLog]   └─ ${entry.level.name.toUpperCase().padRight(5)} '
          '${inv.toolName}: ${entry.message}'
          '${entry.data != null ? ' | ${entry.data}' : ''}'
          '${entry.exception != null ? '\n         ↳ ${entry.exception}' : ''}',
        );
      }
    }
  }

  /// Clear all history (tests / user-triggered reset).
  void clear() => history.clear();

  /// Export the last [limit] invocations as JSON for diagnostics.
  List<Map<String, dynamic>> export({int limit = 50}) {
    return history.take(limit).map((inv) => {
      'traceId': inv.traceId,
      'tool': inv.toolName,
      'caller': inv.callerToolName,
      'skill': inv.skillName,
      'invokedAt': inv.invokedAt.toIso8601String(),
      'success': inv.result.success,
      'code': inv.result.code.name,
      'error': inv.result.error,
      'durationMs': inv.duration?.inMilliseconds,
      'logs': inv.logEntries.map((e) => {
        'level': e.level.name,
        'msg': e.message,
        't': e.timestamp.toIso8601String(),
        if (e.data != null) 'data': e.data,
      }).toList(),
    }).toList();
  }
}
