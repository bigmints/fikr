/// AI domain tools — transcription, analysis, insights, and extraction.
///
/// These tools abstract over the BYOK (Free/Plus) and managed (Pro) AI paths.
/// The tool executor checks the user's tier and routes to the appropriate
/// service: [LLMService] for BYOK or [FikrApiService] for Pro.
library;

import 'dart:io';

import 'package:get/get.dart';


import '../../controllers/subscription_controller.dart';

import '../../services/fikr_api_service.dart';
import '../../services/firebase_service.dart';
import '../../services/openai_service.dart';

import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  ai.transcribe
// ───────────────────────────────────────────────────────────────────────────

class AiTranscribeTool extends FikrTool {
  @override
  String get name => 'ai.transcribe';

  @override
  String get description =>
      'Transcribe an audio file to text. Routes to BYOK (user key) or '
      'managed Vertex AI depending on the user\'s plan.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'audioPath': {
        'type': 'string',
        'description': 'Absolute path to the audio file.',
      },
      'language': {
        'type': 'string',
        'default': 'en',
        'description': 'ISO language code.',
      },
    },
    'required': ['audioPath'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local; // cloud for Pro, handled inside

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final audioPath = params['audioPath'] as String;
      final language = params['language'] as String? ?? context.config.language;
      final audioFile = File(audioPath);

      if (!audioFile.existsSync()) {
        return ToolResult.fail('Audio file not found: $audioPath');
      }

      final sub = Get.find<SubscriptionController>();

      // Pro tier → Managed Vertex AI via fikr.one
      if (sub.hasManagedVertexAI) {
        final transcript = await FikrApiService().transcribeAudio(audioFile);
        return ToolResult.ok({'transcript': transcript});
      }

      // BYOK path
      final provider = context.config.activeProvider;
      if (provider == null) {
        return ToolResult.fail('No AI provider configured. Go to Settings.');
      }

      final apiKey = await context.storage.getApiKey(provider.id);
      if (apiKey == null || apiKey.isEmpty) {
        return ToolResult.fail('Missing API key. Go to Settings.');
      }

      final byokModels = FirebaseService().getByokModels(provider.type);
      final llmService = Get.find<LLMService>();

      final transcript = await llmService.transcribeAudio(
        audioFile: audioFile,
        provider: provider,
        model: byokModels.transcription,
        apiKey: apiKey,
        language: language,
      );

      return ToolResult.ok({'transcript': transcript});
    } catch (e) {
      return ToolResult.fail('Transcription failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  ai.analyze
// ───────────────────────────────────────────────────────────────────────────

class AiAnalyzeTool extends FikrTool {
  @override
  String get name => 'ai.analyze';

  @override
  String get description =>
      'Analyze a transcript: extract title, classify bucket, identify topics, '
      'and produce a cleaned version of the text.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'transcript': {'type': 'string', 'description': 'Raw transcript text.'},
      'buckets': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Available bucket names.',
      },
    },
    'required': ['transcript'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final transcript = params['transcript'] as String;
      final buckets = (params['buckets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          context.config.buckets;

      final sub = Get.find<SubscriptionController>();

      // Pro tier → fikr.one
      if (sub.hasManagedVertexAI) {
        final data = await FikrApiService().analyzeTranscript(
          transcript: transcript,
          buckets: buckets,
        );
        return ToolResult.ok(data);
      }

      // BYOK path
      final provider = context.config.activeProvider;
      if (provider == null) {
        return ToolResult.fail('No AI provider configured.');
      }

      final apiKey = await context.storage.getApiKey(provider.id);
      if (apiKey == null || apiKey.isEmpty) {
        return ToolResult.fail('Missing API key.');
      }

      final byokModels = FirebaseService().getByokModels(provider.type);
      final llmService = Get.find<LLMService>();

      final result = await llmService.analyzeTranscript(
        transcript: transcript,
        provider: provider,
        model: byokModels.analysis,
        apiKey: apiKey,
        buckets: buckets,
        multiBucket: context.config.multiBucket,
      );

      return ToolResult.ok(result.toJson());
    } catch (e) {
      return ToolResult.fail('Analysis failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  ai.insights
// ───────────────────────────────────────────────────────────────────────────

class AiInsightsTool extends FikrTool {
  @override
  String get name => 'ai.insights';

  @override
  String get description =>
      'Generate insights from a batch of notes: highlights, focus areas, '
      'next steps, risks, work summaries, tasks, and reminders.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'notes': {
        'type': 'array',
        'description': 'Array of note objects (id, title, text, bucket, topics).',
      },
      'buckets': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'existingTaskTitles': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Existing task titles to avoid duplicates.',
      },
    },
    'required': ['notes'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final notes = (params['notes'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final buckets = (params['buckets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          context.config.buckets;
      final existingTitles = (params['existingTaskTitles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];

      final sub = Get.find<SubscriptionController>();

      // Pro tier → fikr.one
      if (sub.hasManagedVertexAI) {
        final data = await FikrApiService().generateInsights(
          notes: notes,
          buckets: buckets,
          existingTaskTitles: existingTitles,
        );
        return ToolResult.ok(data);
      }

      // BYOK path
      final provider = context.config.activeProvider;
      if (provider == null) {
        return ToolResult.fail('No AI provider configured.');
      }

      final apiKey = await context.storage.getApiKey(provider.id);
      if (apiKey == null || apiKey.isEmpty) {
        return ToolResult.fail('Missing API key.');
      }

      final byokModels = FirebaseService().getByokModels(provider.type);
      final llmService = Get.find<LLMService>();

      final result = await llmService.generateInsights(
        notes: notes,
        provider: provider,
        model: byokModels.analysis,
        apiKey: apiKey,
        buckets: buckets,
        existingTaskTitles: existingTitles,
      );

      return ToolResult.ok({
        'title': result.title,
        'summary': result.summary,
        'highlights': result.highlights.map((h) => h.toJson()).toList(),
        'focus': result.focus,
        'nextSteps': result.nextSteps,
        'risks': result.risks,
        'questions': result.questions,
        'workSummaries': result.workSummaries,
        'tasks': result.llmTasks,
        'reminders': result.llmReminders,
      });
    } catch (e) {
      return ToolResult.fail('Insight generation failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  ai.summarize
// ───────────────────────────────────────────────────────────────────────────

class AiSummarizeTool extends FikrTool {
  @override
  String get name => 'ai.summarize';

  @override
  String get description =>
      'Summarize a single note or a group of notes into a concise paragraph.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'text': {
        'type': 'string',
        'description': 'Text to summarize.',
      },
      'maxSentences': {
        'type': 'integer',
        'default': 3,
        'description': 'Maximum sentences in summary.',
      },
    },
    'required': ['text'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    // Placeholder — will use the LLM chat in Phase 2 when skill engine lands.
    // For now, return first N sentences as a simple summarizer.
    try {
      final text = params['text'] as String;
      final maxSentences = params['maxSentences'] as int? ?? 3;

      final sentences = text
          .split(RegExp(r'[.!?]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(maxSentences)
          .toList();

      return ToolResult.ok({'summary': '${sentences.join('. ')}.'});
    } catch (e) {
      return ToolResult.fail('Summarization failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  ai.extract_actions
// ───────────────────────────────────────────────────────────────────────────

class AiExtractActionsTool extends FikrTool {
  @override
  String get name => 'ai.extract_actions';

  @override
  String get description =>
      'Extract actionable to-do items from text or transcript.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'text': {'type': 'string', 'description': 'Source text.'},
    },
    'required': ['text'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    // Placeholder — in Phase 2 this will route through the LLM with a
    // system prompt for action extraction. For now, return empty.
    return ToolResult.ok({'actions': <Map<String, dynamic>>[]});
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  ai.extract_reminders
// ───────────────────────────────────────────────────────────────────────────

class AiExtractRemindersTool extends FikrTool {
  @override
  String get name => 'ai.extract_reminders';

  @override
  String get description =>
      'Extract time-sensitive reminders from text or transcript.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'text': {'type': 'string', 'description': 'Source text.'},
    },
    'required': ['text'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    // Placeholder — Phase 2.
    return ToolResult.ok({'reminders': <Map<String, dynamic>>[]});
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allAiTools() => [
      AiTranscribeTool(),
      AiAnalyzeTool(),
      AiInsightsTool(),
      AiSummarizeTool(),
      AiExtractActionsTool(),
      AiExtractRemindersTool(),
    ];
