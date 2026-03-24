/// Tool Selector — LLM-driven router that maps user intent to tools/skills.
///
/// This is **system-prompt-based** (no chat UI). The selector builds a system
/// prompt containing all available tool/skill schemas, sends it to the LLM
/// with the user's intent, and parses the structured JSON response to
/// determine which tools/skills to invoke.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../controllers/subscription_controller.dart';
import '../../services/fikr_api_service.dart';
import '../../services/firebase_service.dart';
import '../../services/openai_service.dart';

import '../tool_interface.dart';
import '../tool_registry.dart';
import '../skill_engine/skill_registry.dart';

// ---------------------------------------------------------------------------
// ToolSelection — the result of the selector
// ---------------------------------------------------------------------------

/// What the LLM decided to invoke.
sealed class ToolSelection {
  const ToolSelection();
}

/// A single tool call.
class SingleToolCall extends ToolSelection {
  const SingleToolCall({
    required this.toolName,
    required this.arguments,
  });

  final String toolName;
  final Map<String, dynamic> arguments;
}

/// A skill invocation.
class SkillInvocation extends ToolSelection {
  const SkillInvocation({
    required this.skillName,
    required this.arguments,
  });

  final String skillName;
  final Map<String, dynamic> arguments;
}

/// Multiple tool calls (ad-hoc plan).
class MultiToolPlan extends ToolSelection {
  const MultiToolPlan({required this.calls});

  final List<SingleToolCall> calls;
}

/// No tool could handle the intent.
class NoMatch extends ToolSelection {
  const NoMatch({required this.reason});
  final String reason;
}

// ---------------------------------------------------------------------------
// ToolSelector
// ---------------------------------------------------------------------------

class ToolSelector {
  ToolSelector({
    ToolRegistry? toolRegistry,
    SkillRegistry? skillRegistry,
  })  : _toolRegistry = toolRegistry ?? ToolRegistry.instance,
        _skillRegistry = skillRegistry ?? SkillRegistry.instance;

  final ToolRegistry _toolRegistry;
  final SkillRegistry _skillRegistry;

  /// Build the system prompt containing available tools and skills.
  String buildSystemPrompt(ToolTier userTier) {
    final tools = _toolRegistry.schemaForTier(userTier);
    final skills = _skillRegistry.schemaForTier(userTier);

    return '''You are Fikr's tool selector. Given a user intent, you select the appropriate tool or skill.

## Available Tools
${const JsonEncoder.withIndent('  ').convert(tools)}

## Available Skills
${const JsonEncoder.withIndent('  ').convert(skills)}

## Response Format
Respond with ONLY valid JSON. Choose one of these formats:

### Single tool call:
```json
{"type": "tool", "name": "tool.name", "arguments": {...}}
```

### Skill invocation:
```json
{"type": "skill", "name": "skill_name", "arguments": {...}}
```

### Multiple tool calls (when no single tool/skill fits):
```json
{"type": "multi", "calls": [{"name": "tool.name", "arguments": {...}}, ...]}
```

### No match:
```json
{"type": "none", "reason": "explanation"}
```

## Rules
1. Always prefer a skill over individual tool calls if a matching skill exists.
2. Only include arguments that are relevant and available.
3. For variable references in skills, pass the actual values as arguments.
4. Never hallucinate tool or skill names — only use ones from the lists above.
''';
  }

  /// Select tools/skills for a given intent.
  ///
  /// Routes to BYOK (Free/Plus) or managed Vertex AI (Pro) based on tier.
  Future<ToolSelection> select(
    String intent,
    ToolContext context, {
    Map<String, dynamic> additionalContext = const {},
  }) async {
    final systemPrompt = buildSystemPrompt(context.planTier);
    final userMessage = _buildUserMessage(intent, additionalContext);

    try {
      final responseText = await _callLLM(systemPrompt, userMessage, context);
      return _parseResponse(responseText);
    } catch (e) {
      debugPrint('ToolSelector error: $e');
      return NoMatch(reason: 'Tool selection failed: $e');
    }
  }

  String _buildUserMessage(
    String intent,
    Map<String, dynamic> additionalContext,
  ) {
    final buffer = StringBuffer('User intent: $intent');
    if (additionalContext.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Additional context:');
      buffer.writeln(const JsonEncoder.withIndent('  ').convert(additionalContext));
    }
    return buffer.toString();
  }

  Future<String> _callLLM(
    String systemPrompt,
    String userMessage,
    ToolContext context,
  ) async {
    final sub = Get.find<SubscriptionController>();

    // Pro tier → fikr.one Vertex AI
    if (sub.hasManagedVertexAI) {
      return FikrApiService().chat(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
      );
    }

    // BYOK path
    final config = context.config;
    final provider = config.activeProvider;
    if (provider == null) {
      throw StateError('No AI provider configured.');
    }

    final apiKey = await context.storage.getApiKey(provider.id);
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Missing API key.');
    }

    final byokModels = FirebaseService().getByokModels(provider.type);
    final llmService = Get.find<LLMService>();

    return llmService.chatCompletion(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      provider: provider,
      model: byokModels.analysis,
      apiKey: apiKey,
    );
  }

  ToolSelection _parseResponse(String responseText) {
    try {
      // Strip markdown code fences if present
      var cleaned = responseText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\n?```$'), '');
        cleaned = cleaned.trim();
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final type = json['type'] as String;

      switch (type) {
        case 'tool':
          return SingleToolCall(
            toolName: json['name'] as String,
            arguments:
                (json['arguments'] as Map<String, dynamic>?) ?? {},
          );
        case 'skill':
          return SkillInvocation(
            skillName: json['name'] as String,
            arguments:
                (json['arguments'] as Map<String, dynamic>?) ?? {},
          );
        case 'multi':
          final calls = (json['calls'] as List<dynamic>).map((c) {
            final call = c as Map<String, dynamic>;
            return SingleToolCall(
              toolName: call['name'] as String,
              arguments:
                  (call['arguments'] as Map<String, dynamic>?) ?? {},
            );
          }).toList();
          return MultiToolPlan(calls: calls);
        case 'none':
          return NoMatch(reason: json['reason'] as String? ?? 'No match');
        default:
          return NoMatch(reason: 'Unknown selection type: $type');
      }
    } catch (e) {
      return NoMatch(reason: 'Failed to parse LLM response: $e');
    }
  }
}
