/// Utility domain tools — pure functions with no side effects.
///
/// These are micro-tools for text manipulation, ID generation, formatting,
/// and other helpers that any other tool or skill step can invoke.
/// Having them as named tools makes every transformation traceable.
library;

import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  util.generate_id
// ───────────────────────────────────────────────────────────────────────────

class UtilGenerateIdTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'util.generate_id';

  @override
  String get description =>
      'Generate a new UUID v4. Returns {"id": "<uuid>"}. '
      'Use this in skills whenever a new entity ID is needed.';

  @override
  Map<String, dynamic> get parametersSchema =>
      {'type': 'object', 'properties': {}};

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  List<String> get tags => ['util', 'id'];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) =>
      guard(context, () async {
        final id = const Uuid().v4();
        return ToolResult.ok({'id': id});
      });
}

// ───────────────────────────────────────────────────────────────────────────
//  util.generate_title
// ───────────────────────────────────────────────────────────────────────────

class UtilGenerateTitleTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'util.generate_title';

  @override
  String get description =>
      'Generate a fallback title from a raw text string by taking the first '
      'N words. Returns {"title": "..."}. Used when AI analysis has no intent.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'description': 'Source text to extract title from.',
          },
          'maxWords': {
            'type': 'integer',
            'default': 8,
            'description': 'Max number of words in the title.',
          },
          'maxChars': {
            'type': 'integer',
            'default': 60,
            'description': 'Max characters before truncation.',
          },
        },
        'required': ['text'],
      };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  List<String> get tags => ['util', 'text'];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) =>
      guard(context, () async {
        final text = (params['text'] as String? ?? '').trim();
        final maxWords = params['maxWords'] as int? ?? 8;
        final maxChars = params['maxChars'] as int? ?? 60;

        if (text.isEmpty) {
          return ToolResult.ok({'title': 'Voice Note'});
        }

        final words = text.split(RegExp(r'\s+'));
        final snippet = words.take(maxWords).join(' ');
        final truncated = snippet.length > maxChars
            ? '${snippet.substring(0, maxChars)}…'
            : snippet;
        final ellipsis = words.length > maxWords ? '…' : '';
        final raw = '$truncated$ellipsis';
        final title = raw.isNotEmpty
            ? raw[0].toUpperCase() + raw.substring(1)
            : 'Voice Note';

        return ToolResult.ok({'title': title});
      });
}

// ───────────────────────────────────────────────────────────────────────────
//  util.text_sanitize
// ───────────────────────────────────────────────────────────────────────────

class UtilTextSanitizeTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'util.text_sanitize';

  @override
  String get description =>
      'Strip null bytes, lone surrogates, and non-printable control characters '
      'from a string to make it Firestore-safe. Returns {"text": "..."}. '
      'Always call this before saving AI-generated content.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': 'Text to sanitize.'},
        },
        'required': ['text'],
      };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  List<String> get tags => ['util', 'text', 'sanitize'];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) =>
      guard(context, () async {
        final raw = params['text'] as String? ?? '';
        // Remove null bytes and control chars except tabs/newlines
        final sanitized = raw
            .replaceAll('\u0000', '')
            .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
            .replaceAll(
              RegExp(r'[\uD800-\uDFFF]'),
              '',
            ); // lone surrogates
        return ToolResult.ok(
          {'text': sanitized},
        );
      });
}

// ───────────────────────────────────────────────────────────────────────────
//  util.timestamp_now
// ───────────────────────────────────────────────────────────────────────────

class UtilTimestampNowTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'util.timestamp_now';

  @override
  String get description =>
      'Returns the current UTC timestamp as ISO 8601 string and unix ms. '
      'Returns {"iso": "...", "unixMs": 1234567890}.';

  @override
  Map<String, dynamic> get parametersSchema =>
      {'type': 'object', 'properties': {}};

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  List<String> get tags => ['util', 'time'];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) =>
      guard(context, () async {
        final now = DateTime.now();
        return ToolResult.ok({
          'iso': now.toIso8601String(),
          'unixMs': now.millisecondsSinceEpoch,
        });
      });
}

// ───────────────────────────────────────────────────────────────────────────
//  util.truncate_text
// ───────────────────────────────────────────────────────────────────────────

class UtilTruncateTextTool extends FikrTool with FikrToolMixin {
  @override
  String get name => 'util.truncate_text';

  @override
  String get description =>
      'Truncate text to a maximum character length, appending "…" if needed. '
      'Returns {"text": "...", "truncated": true/false}.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'text': {'type': 'string'},
          'maxLength': {'type': 'integer', 'default': 140},
        },
        'required': ['text'],
      };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  List<String> get tags => ['util', 'text'];

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) =>
      guard(context, () async {
        final text = params['text'] as String? ?? '';
        final maxLength = params['maxLength'] as int? ?? 140;
        if (text.length <= maxLength) {
          return ToolResult.ok({'text': text, 'truncated': false});
        }
        return ToolResult.ok({
          'text': '${text.substring(0, math.min(maxLength, text.length))}…',
          'truncated': true,
        });
      });
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allUtilTools() => [
      UtilGenerateIdTool(),
      UtilGenerateTitleTool(),
      UtilTextSanitizeTool(),
      UtilTimestampNowTool(),
      UtilTruncateTextTool(),
    ];
