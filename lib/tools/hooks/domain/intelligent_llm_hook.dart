/// IntelligentLlmHook — the sole NBA hook in the system.
///
/// Replaces all previous hard-coded domain hooks. The LLM receives a
/// rich, Fikr-specific prompt containing:
///   - The full content context (text, intent, bucket, topics)
///   - A complete catalogue of available tools with their descriptions
///   - Clear rules about what makes an action relevant
///
/// The LLM decides the top 1-3 most relevant next actions. If nothing is
/// relevant, it returns an empty array — no actions are shown.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../models/action_card.dart';
import '../../../controllers/subscription_controller.dart';
import '../../../services/fikr_api_service.dart';
import '../../../services/openai_service.dart';
import '../../../tools/tool_interface.dart';
import '../../../tools/tool_registry.dart';
import '../hook_engine.dart';

class IntelligentLlmHook extends ActionHook {
  @override
  String get name => 'intelligent_llm';

  @override
  String get description =>
      'Uses the LLM to dynamically determine the top 1-3 most relevant next '
      'best actions based on the captured content and available Fikr tools.';

  @override
  Set<HookTrigger> get triggers => {HookTrigger.onAll};

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  double get minScore => 0.0;

  @override
  int get maxActions => 3;

  // ---------------------------------------------------------------------------
  // canHandle — only skip if there is literally no content or no toolContext
  // ---------------------------------------------------------------------------

  // Debounce: don't re-fire for the same content within 30 seconds
  DateTime? _lastRunAt;
  String? _lastContextHash;

  @override
  bool canHandle(NbaContext ctx) {
    if (ctx.toolContext == null) return false;
    final text = ctx.combinedText.trim();
    final intent = ctx.intent.trim();
    // Require meaningful content (>60 chars) to avoid burning tokens on trivial notes
    if (text.length < 60 && intent.isEmpty) return false;
    // Debounce: skip if we already ran for identical content within 30s
    final hash = '$text:$intent';
    final now = DateTime.now();
    if (_lastContextHash == hash &&
        _lastRunAt != null &&
        now.difference(_lastRunAt!).inSeconds < 30) {
      return false;
    }
    _lastContextHash = hash;
    _lastRunAt = now;
    return true;
  }

  @override
  Future<double> score(NbaContext ctx) async => 1.0;

  // ---------------------------------------------------------------------------
  // generateActions — ask the LLM and parse the response
  // ---------------------------------------------------------------------------

  @override
  Future<List<RankedAction>> generateActions(NbaContext ctx) async {
    final toolContext = ctx.toolContext!;

    // Build full tool catalogue for the tier
    final registry = ToolRegistry.instance;
    final schemas = registry.schemaForTier(toolContext.planTier);
    final toolCatalogue = _buildToolCatalogue(schemas);

    // Build a rich user message from the NbaContext
    final userMessage = _buildUserMessage(ctx);

    // Build a grounded system prompt
    final systemPrompt = _buildSystemPrompt(toolCatalogue);

    List<ActionCard> cards = [];

    try {
      final sub = Get.find<SubscriptionController>();

      if (sub.hasManagedVertexAI) {
        // Pro tier → fikr.one Vertex AI
        final responseText = await FikrApiService().chat(
          systemPrompt: systemPrompt,
          userMessage: userMessage,
        );
        cards = _parseResponse(responseText);
      } else {
        // BYOK path
        final config = toolContext.config;
        final provider = config.activeProvider;
        if (provider == null) return [];

        final apiKey = await toolContext.storage?.getApiKey(provider.id);
        if (apiKey == null || apiKey.isEmpty) return [];

        final llmService = Get.find<LLMService>();

        cards = await llmService.generateNextBestActions(
          contextText: userMessage,
          systemPrompt: systemPrompt,
          provider: provider,
          
          apiKey: apiKey,
        );
      }
    } catch (e) {
      debugPrint('[IntelligentLlmHook] generateActions error: $e');
    }

    // Validate toolIds against the registry — drop hallucinated tools
    final validatedCards = cards.where((c) {
      if (!c.isToolAction) return true; // URL-only cards are fine
      final exists = registry.has(c.toolId!);
      if (!exists) {
        debugPrint('[IntelligentLlmHook] Dropping card with unknown toolId: "${c.toolId}"');
      }
      return exists;
    }).toList();

    return validatedCards
        .map(
          (c) => RankedAction(
            action: c,
            score: 0.9,
            hookName: name,
            urgency: _mapUrgency(c.metadata['urgency'] as String?),
            priority: _mapPriority(c.metadata['priority'] as String?),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Prompt construction
  // ---------------------------------------------------------------------------

  /// Builds a rich, Fikr-specific system prompt.
  String _buildSystemPrompt(String toolCatalogue) {
    return '''
You are the Next Best Action engine for Fikr, a voice-first productivity app.

Your job is to read content the user just captured (voice note, scan, or insight), then decide the top 1-3 most relevant NEXT ACTIONS — chosen ONLY from the Fikr tool catalogue below. Each action must be executable INSIDE the app with zero additional user input.

## Fikr Tool Catalogue
$toolCatalogue

## Rules
1. Return ONLY a valid JSON array. No markdown, no code fences, no prose. Return `[]` if nothing is clearly relevant.
2. Output at most 3 actions. If only 1 is clearly relevant, return 1. Quality over quantity.
3. Each action MUST use a real `toolId` from the catalogue above.
4. The `parameters` object MUST be pre-filled with values you can infer from the user content — do not leave parameters blank or use placeholders like "<value>".
5. Titles must be ≤ 6 words. Subtitles ≤ 15 words.
6. Do NOT suggest the same tool twice.
7. Do NOT suggest generic actions like "Add to notes" or "Save this".
8. The `reasoning` field must be 1 sentence explaining exactly what in the content triggered this action.
9. Set `urgency` to one of: now, soon, later.
10. Set `priority` to one of: high, medium, low.

## Output Schema
Return a JSON array where each element matches this schema exactly:
{
  "toolId": "tasks.create",
  "type": "custom",
  "title": "Schedule call with John",
  "subtitle": "You mentioned calling John tomorrow",
  "ctaLabel": "Add Task",
  "reasoning": "You said you need to call John about the contract.",
  "parameters": {
    "title": "Call John about the contract",
    "dueDate": "tomorrow",
    "bucket": "Work Life"
  },
  "metadata": {
    "urgency": "soon",
    "priority": "high"
  }
}

Allowed `type` values: buy, recipe, article, post, search, map, read, compare, custom.
Use "custom" unless a different type perfectly matches the action.
''';
  }

  /// Builds a readable tool catalogue from registered tool schemas.
  String _buildToolCatalogue(List<Map<String, dynamic>> schemas) {
    if (schemas.isEmpty) return '(No tools registered)';

    final buffer = StringBuffer();
    for (final tool in schemas) {
      final name = tool['name'] as String? ?? '';
      final desc = tool['description'] as String? ?? '';
      final tier = tool['requiredTier'] as String? ?? 'free';
      buffer.writeln('- [$tier] $name: $desc');
    }
    return buffer.toString().trimRight();
  }

  /// Builds a structured user message from the NbaContext so the LLM
  /// understands what content it is routing.
  String _buildUserMessage(NbaContext ctx) {
    final buffer = StringBuffer();

    buffer.writeln('## Captured Content');

    if (ctx.intent.isNotEmpty) {
      buffer.writeln('Intent / Title: ${ctx.intent}');
    }
    if (ctx.bucket.isNotEmpty && ctx.bucket != 'General') {
      buffer.writeln('Category / Bucket: ${ctx.bucket}');
    }
    if (ctx.allTopics.isNotEmpty) {
      buffer.writeln('Topics: ${ctx.allTopics.join(', ')}');
    }

    final text = ctx.combinedText.trim();
    if (text.isNotEmpty) {
      // Truncate very long notes to avoid token waste
      final truncated =
          text.length > 1500 ? '${text.substring(0, 1500)}…' : text;
      buffer.writeln('\nContent:\n$truncated');
    }

    if (ctx.source == NbaSource.scan && ctx.scan != null) {
      buffer.writeln('\nSource: Image scan');
      buffer.writeln('Scan category: ${ctx.scanCategory}');
    }

    return buffer.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Response parsing
  // ---------------------------------------------------------------------------

  List<ActionCard> _parseResponse(String responseText) {
    try {
      var cleaned = responseText.trim();

      // Strip markdown fences if any model ignores the instruction
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\n?```$'), '');
        cleaned = cleaned.trim();
      }

      final decoded = jsonDecode(cleaned);
      List<dynamic> list;

      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map) {
        // Some models wrap the array: {"actions": [...]}
        if (decoded['actions'] is List) {
          list = decoded['actions'] as List<dynamic>;
        } else {
          // Try the first list value found
          final firstList = decoded.values.whereType<List>().firstOrNull;
          if (firstList != null) {
            list = firstList;
          } else {
            debugPrint('[IntelligentLlmHook] Unexpected JSON shape: $cleaned');
            return [];
          }
        }
      } else {
        return [];
      }

      return list
          .whereType<Map<String, dynamic>>()
          .map(ActionCard.fromJson)
          .take(maxActions)
          .toList();
    } catch (e) {
      debugPrint('[IntelligentLlmHook] Parse error: $e\nRaw: $responseText');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ActionUrgency _mapUrgency(String? raw) {
    switch (raw) {
      case 'now':
        return ActionUrgency.now;
      case 'soon':
        return ActionUrgency.soon;
      case 'later':
        return ActionUrgency.later;
      default:
        return ActionUrgency.soon;
    }
  }

  ActionPriority _mapPriority(String? raw) {
    switch (raw) {
      case 'high':
        return ActionPriority.high;
      case 'low':
        return ActionPriority.low;
      default:
        return ActionPriority.medium;
    }
  }
}
