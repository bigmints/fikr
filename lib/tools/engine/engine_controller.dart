/// Engine Controller — top-level orchestration layer.
///
/// This controller sits above the tool registry and skill engine.
/// It provides a high-level API for the app to invoke tools, run skills,
/// and process user intents through the LLM tool selector.
library;


import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../controllers/subscription_controller.dart';
import '../../models/app_config.dart';
import '../../services/storage_service.dart';
import '../tool_interface.dart';
import '../tool_registry.dart';
import '../skill_engine/skill.dart';
import '../skill_engine/skill_executor.dart';
import '../skill_engine/skill_registry.dart';
import 'tool_selector.dart';

class EngineController extends GetxService {
  late final ToolRegistry _toolRegistry;
  late final SkillRegistry _skillRegistry;
  late final SkillExecutor _skillExecutor;
  late final ToolSelector _toolSelector;

  /// Whether the engine is currently processing.
  final isProcessing = false.obs;

  /// Last execution result summary.
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
  }

  /// Build a [ToolContext] from current app state.
  ToolContext _buildContext() {
    final storage = Get.find<StorageService>();
    AppConfig config;
    try {
      config = Get.find<AppController>().config.value;
    } catch (_) {
      config = AppConfig.fromJson({});
    }

    return ToolContext(
      userId: null,
      planTier: _currentTier(),
      config: config,
      storage: storage,
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

  // ── High-level API ──────────────────────────────────────────────────

  /// Execute a single tool by name with parameters.
  Future<ToolResult> executeTool(
    String toolName,
    Map<String, dynamic> params, {
    ToolContext? context,
  }) async {
    final tool = _toolRegistry.get(toolName);
    if (tool == null) return ToolResult.fail('Tool not found: $toolName');

    final ctx = context ?? _buildContext();
    if (tool.requiredTier.index > ctx.planTier.index) {
      return ToolResult.fail(
        'Tool "$toolName" requires ${tool.requiredTier.name} tier.',
      );
    }

    try {
      isProcessing.value = true;
      return await tool.execute(params, ctx);
    } finally {
      isProcessing.value = false;
    }
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

    try {
      isProcessing.value = true;
      final result = await _skillExecutor.execute(skill, ctx,
          initialVars: initialVars);
      lastResult.value = result.success
          ? 'Skill "$skillName" completed'
          : 'Skill "$skillName" failed: ${result.error}';
      return result;
    } finally {
      isProcessing.value = false;
    }
  }

  /// Process a natural-language intent through the LLM tool selector.
  ///
  /// The selector picks the best tool/skill, then this method executes it.
  Future<ToolResult> processIntent(
    String intent, {
    Map<String, dynamic> additionalContext = const {},
    ToolContext? context,
  }) async {
    final ctx = context ?? _buildContext();

    try {
      isProcessing.value = true;

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
      isProcessing.value = false;
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
}
