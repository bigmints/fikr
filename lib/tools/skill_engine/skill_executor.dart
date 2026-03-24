/// Skill Executor — DAG runner that executes skill steps sequentially,
/// with support for parallel groups, conditional execution, and forEach.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../tool_interface.dart';
import '../tool_registry.dart';
import 'skill.dart';

class SkillExecutor {
  SkillExecutor({
    ToolRegistry? registry,
  }) : _registry = registry ?? ToolRegistry.instance;

  final ToolRegistry _registry;

  /// Execute a skill with the given initial variables and context.
  ///
  /// [initialVars] are pre-populated variables (e.g. `$config.buckets`).
  Future<SkillExecutionResult> execute(
    Skill skill,
    ToolContext context, {
    Map<String, dynamic> initialVars = const {},
  }) async {
    final vars = Map<String, dynamic>.from(initialVars);
    final stepResults = <StepExecutionResult>[];
    var stepIndex = 0;

    // Collect consecutive parallel steps into groups
    final groups = _buildExecutionGroups(skill.steps);

    for (final group in groups) {
      if (group.length == 1 && !group.first.parallel) {
        // Sequential step
        final step = group.first;
        final result = await _executeStep(
          step, stepIndex, vars, context,
        );
        stepResults.add(result);

        if (!result.result.success && step.onError == StepErrorPolicy.fail) {
          return SkillExecutionResult(
            skillName: skill.name,
            success: false,
            variables: vars,
            failedStep: stepIndex,
            error: result.result.error,
            stepResults: stepResults,
          );
        }
        stepIndex++;
      } else {
        // Parallel group — run all concurrently
        final futures = <Future<StepExecutionResult>>[];
        final indices = <int>[];
        for (final step in group) {
          futures.add(_executeStep(step, stepIndex, vars, context));
          indices.add(stepIndex);
          stepIndex++;
        }
        final results = await Future.wait(futures);
        stepResults.addAll(results);

        // Check for failures in the group
        for (var i = 0; i < results.length; i++) {
          final r = results[i];
          if (!r.result.success &&
              group[i].onError == StepErrorPolicy.fail) {
            return SkillExecutionResult(
              skillName: skill.name,
              success: false,
              variables: vars,
              failedStep: indices[i],
              error: r.result.error,
              stepResults: stepResults,
            );
          }
        }
      }
    }

    return SkillExecutionResult(
      skillName: skill.name,
      success: true,
      variables: vars,
      stepResults: stepResults,
    );
  }

  // ── Step execution ──────────────────────────────────────────────────

  Future<StepExecutionResult> _executeStep(
    SkillStep step,
    int index,
    Map<String, dynamic> vars,
    ToolContext context,
  ) async {
    // Check condition
    if (step.condition != null && !_evaluateCondition(step.condition!, vars)) {
      return StepExecutionResult(
        stepIndex: index,
        toolName: step.toolName,
        result: ToolResult.ok(null),
        skipped: true,
      );
    }

    // Resolve tool
    final tool = _registry.get(step.toolName);
    if (tool == null) {
      return StepExecutionResult(
        stepIndex: index,
        toolName: step.toolName,
        result: ToolResult.fail('Tool not found: ${step.toolName}'),
      );
    }

    // forEach — iterate over an array
    if (step.forEach != null) {
      return _executeForEach(step, index, vars, context, tool);
    }

    // Resolve input params
    final params = _resolveInputs(step.input, vars);

    // Execute
    ToolResult result;
    try {
      result = await tool.execute(params, context);
    } catch (e) {
      if (step.onError == StepErrorPolicy.retryOnce) {
        try {
          result = await tool.execute(params, context);
        } catch (retryError) {
          result = ToolResult.fail('Retry failed: $retryError');
        }
      } else {
        result = ToolResult.fail('$e');
      }
    }

    // Store output
    if (result.success && step.outputKey != null) {
      switch (step.outputMode) {
        case StepOutputMode.store:
          vars[step.outputKey!] = result.data;
          break;
        case StepOutputMode.merge:
          if (result.data is Map<String, dynamic>) {
            vars.addAll(result.data as Map<String, dynamic>);
          } else {
            vars[step.outputKey!] = result.data;
          }
          break;
        case StepOutputMode.discard:
          break;
      }
    }

    return StepExecutionResult(
      stepIndex: index,
      toolName: step.toolName,
      result: result,
    );
  }

  Future<StepExecutionResult> _executeForEach(
    SkillStep step,
    int index,
    Map<String, dynamic> vars,
    ToolContext context,
    FikrTool tool,
  ) async {
    final iterableRef = step.forEach!;
    final items = _resolveVariable(iterableRef, vars);
    if (items is! List) {
      return StepExecutionResult(
        stepIndex: index,
        toolName: step.toolName,
        result: ToolResult.fail(
          'forEach reference "$iterableRef" is not a list.',
        ),
      );
    }

    final results = <dynamic>[];
    for (final item in items) {
      // Make $item available
      vars['item'] = item;
      final params = _resolveInputs(step.input, vars);
      try {
        final r = await tool.execute(params, context);
        if (r.success) results.add(r.data);
      } catch (e) {
        debugPrint('forEach step ${step.toolName} failed for item: $e');
      }
    }
    vars.remove('item');

    if (step.outputKey != null) {
      vars[step.outputKey!] = results;
    }

    return StepExecutionResult(
      stepIndex: index,
      toolName: step.toolName,
      result: ToolResult.ok(results),
    );
  }

  // ── Variable resolution ─────────────────────────────────────────────

  /// Resolve all `$variable` references in an input map.
  Map<String, dynamic> _resolveInputs(
    Map<String, dynamic> input,
    Map<String, dynamic> vars,
  ) {
    final resolved = <String, dynamic>{};
    for (final entry in input.entries) {
      resolved[entry.key] = _resolveValue(entry.value, vars);
    }
    return resolved;
  }

  dynamic _resolveValue(dynamic value, Map<String, dynamic> vars) {
    if (value is String && value.startsWith(r'$')) {
      return _resolveVariable(value, vars);
    }
    if (value is Map<String, dynamic>) {
      return _resolveInputs(value, vars);
    }
    if (value is List) {
      return value.map((v) => _resolveValue(v, vars)).toList();
    }
    return value;
  }

  /// Resolve a `$variable.path` reference against the variable context.
  dynamic _resolveVariable(String ref, Map<String, dynamic> vars) {
    // Strip leading $
    final path = ref.substring(1);
    final parts = path.split('.');

    dynamic current = vars;
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
      if (current == null) return null;
    }
    return current;
  }

  // ── Condition evaluation ────────────────────────────────────────────

  /// Evaluate a simple condition: `$variable` → truthy check.
  bool _evaluateCondition(String condition, Map<String, dynamic> vars) {
    if (condition.startsWith(r'$')) {
      final value = _resolveVariable(condition, vars);
      return _isTruthy(value);
    }
    // Negation: !$variable
    if (condition.startsWith(r'!$')) {
      final value = _resolveVariable(condition.substring(1), vars);
      return !_isTruthy(value);
    }
    return true;
  }

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    if (value is num) return value != 0;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  // ── Execution group building ────────────────────────────────────────

  /// Group consecutive parallel steps together.
  List<List<SkillStep>> _buildExecutionGroups(List<SkillStep> steps) {
    final groups = <List<SkillStep>>[];
    List<SkillStep>? currentParallel;

    for (final step in steps) {
      if (step.parallel) {
        currentParallel ??= [];
        currentParallel.add(step);
      } else {
        if (currentParallel != null) {
          groups.add(currentParallel);
          currentParallel = null;
        }
        groups.add([step]);
      }
    }
    if (currentParallel != null) {
      groups.add(currentParallel);
    }

    return groups;
  }
}
