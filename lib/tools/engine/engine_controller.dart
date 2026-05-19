/// Engine Controller — top-level orchestration layer.
///
/// This controller sits above the tool registry and skill engine.
/// Every domain operation in the app routes through here.
///
/// Architecture contract:
/// - UI → EngineController.executeTool / executeSkill
/// - EngineController → validates → times → executes → logs → records
/// - Tool → operates on IAppState / services → returns ToolResult
/// - EngineController → records ToolInvocation → returns ToolResult to caller
library;

import 'dart:async';



import 'package:get/get.dart';
import 'package:fikr/tools/app_state_resolver.dart';
import 'package:uuid/uuid.dart';

import '../../controllers/subscription_controller.dart';
import '../../models/app_config.dart';
import '../../services/firebase_service.dart';
import '../../services/storage_service.dart';
import '../tool_execution_log.dart';
import '../tool_interface.dart';
import '../tool_registry.dart';
import '../tool_validator.dart';
import '../skill_engine/skill.dart';
import '../skill_engine/skill_executor.dart';
import '../skill_engine/skill_registry.dart';
import 'tool_selector.dart';

class EngineController extends GetxService {
  late final ToolRegistry _toolRegistry;
  late final SkillRegistry _skillRegistry;
  late final SkillExecutor _skillExecutor;
  late final ToolSelector _toolSelector;
  late final ToolExecutionLog _log;

  /// Whether the engine is currently processing any tool.
  final isProcessing = false.obs;

  /// Count of currently in-flight tool invocations.
  final activeCount = 0.obs;

  /// Last execution result summary string.
  final lastResult = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    _toolRegistry = ToolRegistry.instance;
    _skillRegistry = SkillRegistry.instance;
    _skillExecutor = SkillExecutor(registry: _toolRegistry);
    _toolSelector = ToolSelector(
      toolRegistry: _toolRegistry,
      skillRegistry: _skillRegistry,
    );
    _log = ToolExecutionLog.instance;
  }

  // ── Context building ────────────────────────────────────────────────

  /// Build a [ToolContext] from current app state.
  ToolContext _buildContext({String? traceId, String? callerToolName}) {
    final storage = Get.find<StorageService>();
    AppConfig config;
    try {
      config = appState().config.value;
    } catch (_) {
      config = AppConfig.fromJson({});
    }

    String? userId;
    try {
      final firebase = Get.find<FirebaseService>();
      userId = firebase.currentUser.value?.uid;
    } catch (_) {}

    return ToolContext(
      userId: userId,
      planTier: _currentTier(),
      config: config,
      storage: storage,
      traceId: traceId ?? const Uuid().v4(),
      callerToolName: callerToolName,
    );
  }

  ToolTier _currentTier() {
    try {
      final sub = Get.find<SubscriptionController>();
      if (sub.isPro) return ToolTier.pro;
      if (sub.isPlus) return ToolTier.plus;
    } catch (_) {}
    return ToolTier.free;
  }

  // ── Core execution with tracing ─────────────────────────────────────

  /// Execute a single tool by name with parameters.
  ///
  /// Wraps execution with: trace ID → validation → timing → logging → recording.
  Future<ToolResult> executeTool(
    String toolName,
    Map<String, dynamic> params, {
    ToolContext? context,
    String? skillName,
  }) async {
    final ctx = context ?? _buildContext();
    final invokedAt = DateTime.now();
    activeCount.value++;
    if (activeCount.value == 1) isProcessing.value = true;

    ToolResult result = ToolResult.notFound(toolName);

    try {
      // 1. Resolve tool
      final tool = _toolRegistry.get(toolName);
      if (tool == null) {
        return result;
      }

      // 2. Tier gate
      if (tool.requiredTier.index > ctx.planTier.index) {
        result = ToolResult.tierDenied(toolName, tool.requiredTier);
        return result;
      }

      // 3. Validation
      final validationError = ToolValidator.instance.validate(
        toolName,
        params,
        tool.parametersSchema,
        ctx.traceId,
      );
      if (validationError != null) {
        result = validationError;
        return result;
      }

      // 4. Timed execution
      final stopwatch = Stopwatch()..start();
      try {
        result = await tool.execute(params, ctx);
        stopwatch.stop();

        // Stamp timing + tool name + traceId onto the result
        result = result.success
            ? ToolResult.okMeta(
                result.data,
                toolName: toolName,
                traceId: ctx.traceId,
                duration: stopwatch.elapsed,
              )
            : ToolResult.fail(
                result.error ?? 'Unknown error',
                code: result.code,
                toolName: toolName,
                traceId: ctx.traceId,
                duration: stopwatch.elapsed,
              );
      } catch (e, st) {
        stopwatch.stop();
        ctx.logger.error('Unhandled tool exception', exception: e, stack: st);
        result = ToolResult.fail(
          e.toString(),
          toolName: toolName,
          traceId: ctx.traceId,
          duration: stopwatch.elapsed,
        );
      }
    } finally {
      // 5. Record in global log
      _log.record(ToolInvocation(
        traceId: ctx.traceId,
        toolName: toolName,
        invokedAt: invokedAt,
        result: result,
        logEntries: ctx.logger.entries,
        callerToolName: ctx.callerToolName,
        skillName: skillName,
        params: _safeParams(params),
      ));

      activeCount.value--;
      if (activeCount.value == 0) isProcessing.value = false;

      lastResult.value = result.success
          ? '✓ $toolName'
          : '✗ $toolName: ${result.error}';
    }

    return result;
  }

  /// Execute a skill by name with initial variables.
  Future<SkillExecutionResult> executeSkill(
    String skillName, {
    Map<String, dynamic> initialVars = const {},
    ToolContext? context,
  }) async {
    final skill = _skillRegistry.get(skillName);
    if (skill == null) {
      return SkillExecutionResult(
        skillName: skillName,
        success: false,
        variables: {},
        error: 'Skill not found: $skillName',
      );
    }

    final ctx = context ?? _buildContext();

    if (skill.requiredTier.index > ctx.planTier.index) {
      return SkillExecutionResult(
        skillName: skillName,
        success: false,
        variables: {},
        error: 'Skill "$skillName" requires ${skill.requiredTier.name} tier.',
      );
    }

    activeCount.value++;
    if (activeCount.value == 1) isProcessing.value = true;

    try {
      final result = await _skillExecutor.execute(
        skill,
        ctx,
        initialVars: initialVars,
        onStepExecute: (stepToolName, stepParams, stepCtx) =>
            executeTool(stepToolName, stepParams, context: stepCtx, skillName: skillName),
      );

      lastResult.value = result.success
          ? '✓ skill:$skillName'
          : '✗ skill:$skillName: ${result.error}';
      return result;
    } finally {
      activeCount.value--;
      if (activeCount.value == 0) isProcessing.value = false;
    }
  }

  /// Process a natural-language intent through the LLM tool selector.
  Future<ToolResult> processIntent(
    String intent, {
    Map<String, dynamic> additionalContext = const {},
    ToolContext? context,
  }) async {
    final ctx = context ?? _buildContext();

    try {
      activeCount.value++;
      if (activeCount.value == 1) isProcessing.value = true;

      final selection = await _toolSelector.select(
        intent,
        ctx,
        additionalContext: additionalContext,
      );

      switch (selection) {
        case SingleToolCall(:final toolName, :final arguments):
          return await executeTool(toolName, arguments, context: ctx);

        case SkillInvocation(:final skillName, :final arguments):
          final result = await executeSkill(skillName,
              initialVars: arguments, context: ctx);
          return result.success
              ? ToolResult.ok(result.variables)
              : ToolResult.fail(result.error ?? 'Skill failed');

        case MultiToolPlan(:final calls):
          final results = <String, dynamic>{};
          for (final call in calls) {
            final r =
                await executeTool(call.toolName, call.arguments, context: ctx);
            results[call.toolName] = r.success ? r.data : r.error;
            if (!r.success) {
              return ToolResult.fail(
                'Multi-tool plan failed at ${call.toolName}: ${r.error}',
              );
            }
          }
          return ToolResult.ok(results);

        case NoMatch(:final reason):
          return ToolResult.fail(reason);
      }
    } finally {
      activeCount.value--;
      if (activeCount.value == 0) isProcessing.value = false;
    }
  }

  // ── Registry introspection ──────────────────────────────────────────

  /// Available tools for the current user's tier.
  List<FikrTool> get availableTools =>
      _toolRegistry.toolsForTier(_currentTier());

  /// Available skills for the current user's tier.
  List<Skill> get availableSkills =>
      _skillRegistry.skillsForTier(_currentTier());

  /// Number of registered tools.
  int get toolCount => _toolRegistry.count;

  /// Number of registered skills.
  int get skillCount => _skillRegistry.count;

  /// Tool registry domain summary (for debug/settings UI).
  Map<String, List<String>> get toolDomainSummary =>
      _toolRegistry.domainSummary;

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Strip sensitive keys from params before logging.
  Map<String, dynamic> _safeParams(Map<String, dynamic> params) {
    const sensitiveKeys = {'apiKey', 'secret', 'password', 'token', 'key'};
    return {
      for (final e in params.entries)
        e.key: sensitiveKeys.contains(e.key.toLowerCase()) ? '[REDACTED]' : e.value,
    };
  }
}
