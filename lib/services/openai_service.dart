import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/analysis_result.dart';
import '../models/insights_models.dart';
import '../models/llm_provider.dart';

class LLMService {
  LLMService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _getHeaders(String apiKey, LLMProvider provider) {
    final headers = <String, String>{'Content-Type': 'application/json'};

    switch (provider.type) {
      case LLMProviderType.google:
        headers['x-goog-api-key'] = apiKey;
        break;
      case LLMProviderType.openai:
        headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  Future<bool> validateApiKey(
    String apiKey, {
    required LLMProvider provider,
  }) async {
    try {
      final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
      final response = await _client.get(
        Uri.parse('$baseUrl/models'),
        headers: _getHeaders(apiKey, provider),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  String _normalizeBaseUrl(String input, LLMProviderType type) {
    var base = input.trim();
    if (base.isEmpty) return type.defaultBaseUrl;

    if (!base.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      base = 'https://$base';
    }

    base = base.replaceAll(RegExp(r'/+$'), '');

    if (type == LLMProviderType.openai && !base.toLowerCase().endsWith('/v1')) {
      base = '$base/v1';
    }

    return base;
  }

  Future<List<String>> getModels(
    String apiKey, {
    required LLMProvider provider,
  }) async {
    try {
      final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
      final response = await _client.get(
        Uri.parse('$baseUrl/models'),
        headers: _getHeaders(apiKey, provider),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> models = data['data'] ?? data['models'] ?? [];
        // Google returns { models: [{ name: "models/gemini-..." }] }
        // OpenAI returns { data: [{ id: "gpt-..." }] }
        return models
            .map((m) {
              if (m is Map && m.containsKey('name')) {
                // Google format: strip "models/" prefix
                final name = m['name'] as String;
                return name.startsWith('models/') ? name.substring(7) : name;
              }
              return m['id'] as String;
            })
            .where((name) {
              // For Google, only show gemini models (not aqa, embedding, etc.)
              if (provider.type == LLMProviderType.google) {
                return name.startsWith('gemini');
              }
              return true;
            })
            .toList()
          ..sort();
      } else {
        throw Exception('Failed to fetch models: ${response.body}');
      }
    } catch (e) {
      throw Exception('Verification failed: $e');
    }
  }

  // ── Transcription ──────────────────────────────────────────────────

  Future<String> transcribeAudio({
    required File audioFile,
    required LLMProvider provider,
    required String model,
    required String apiKey,
    String language = 'en',
  }) async {
    if (provider.type == LLMProviderType.google) {
      return _transcribeWithGemini(
        audioFile: audioFile,
        model: model,
        apiKey: apiKey,
        language: language,
        provider: provider,
      );
    }
    return _transcribeWithOpenAI(
      audioFile: audioFile,
      provider: provider,
      model: model,
      apiKey: apiKey,
      language: language,
    );
  }

  /// OpenAI-compatible transcription (Whisper)
  Future<String> _transcribeWithOpenAI({
    required File audioFile,
    required LLMProvider provider,
    required String model,
    required String apiKey,
    String language = 'en',
  }) async {
    final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
    final url = '$baseUrl/audio/transcriptions';
    final request = http.MultipartRequest('POST', Uri.parse(url));

    request.headers['Authorization'] = 'Bearer $apiKey';

    request.fields['model'] = model;
    request.fields['language'] = language;
    request.files.add(
      await http.MultipartFile.fromPath('file', audioFile.path),
    );

    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Transcription failed: $body');
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['text'] as String? ?? '';
  }

  /// Gemini-native transcription using generateContent with inline audio
  Future<String> _transcribeWithGemini({
    required File audioFile,
    required String model,
    required String apiKey,
    required LLMProvider provider,
    String language = 'en',
  }) async {
    final bytes = await audioFile.readAsBytes();
    final base64Audio = base64Encode(bytes);

    // Detect MIME type from extension
    final ext = audioFile.path.split('.').last.toLowerCase();
    final mimeType = _audioMimeType(ext);

    final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
    final endpoint = '$baseUrl/models/$model:generateContent';

    final payload = {
      'contents': [
        {
          'parts': [
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Audio},
            },
            {
              'text':
                  'Transcribe this audio accurately. '
                  'The language is $language. '
                  'Return ONLY the transcription text, nothing else.',
            },
          ],
        },
      ],
    };

    debugPrint('Gemini transcription: $endpoint');

    final response = await _client.post(
      Uri.parse('$endpoint?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Transcription failed: ${response.body}');
    }

    return _extractGeminiText(response.body);
  }

  String _audioMimeType(String ext) {
    switch (ext) {
      case 'mp3':
        return 'audio/mp3';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'webm':
        return 'audio/webm';
      default:
        return 'audio/mp4'; // safe fallback for iOS/macOS recordings
    }
  }

  // ── Analysis (Chat) ────────────────────────────────────────────────

  Future<AnalysisResult> analyzeTranscript({
    required String transcript,
    required LLMProvider provider,
    required String model,
    required String apiKey,
    required List<String> buckets,
    bool multiBucket = true,
  }) async {
    final bucketList = buckets.join(', ');

    final systemPrompt =
        'You are an assistant that cleans spoken notes into structured text. '
        'Return ONLY valid JSON with keys: "cleanedText", "intent", "bucket", "topics". '
        'Rules:\n'
        '1. Pick exactly ONE bucket from this list: $bucketList. If none fit, use "General". Put this in "bucket".\n'
        '2. Identify 3-5 relevant tags/topics for metadata and put them in "topics".\n'
        '3. Provide a concise title in "intent" and cleaned version of the transcript in "cleanedText".';

    if (provider.type == LLMProviderType.google) {
      final content = await _chatWithGemini(
        systemPrompt: systemPrompt,
        userMessage: transcript,
        model: model,
        apiKey: apiKey,
        provider: provider,
        jsonMode: true,
      );
      if (content != null) {
        try {
          return AnalysisResult.fromJson(
            jsonDecode(content) as Map<String, dynamic>,
          );
        } catch (_) {}
      }
      return AnalysisResult(
        cleanedText: transcript,
        intent: '',
        topics: const ['General'],
        bucket: '',
      );
    }

    // OpenAI path
    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': transcript},
    ];
    final payload = {
      'model': model,
      'messages': messages,
      'response_format': {'type': 'json_object'},
    };
    final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
    final endpoint = '$baseUrl/chat/completions';

    final response = await _client.post(
      Uri.parse(endpoint),
      headers: _getHeaders(apiKey, provider),
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Analysis failed: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    String? content;
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      content = choices[0]['message']['content'];
    }

    if (content != null) {
      try {
        final resultJson = jsonDecode(content) as Map<String, dynamic>;
        return AnalysisResult.fromJson(resultJson);
      } catch (_) {}
    }

    return AnalysisResult(
      cleanedText: transcript,
      intent: '',
      topics: const ['General'],
      bucket: '',
    );
  }

  // ── Insights ───────────────────────────────────────────────────────

  Future<GeneratedInsights> generateInsights({
    required List<Map<String, dynamic>> notes,
    required LLMProvider provider,
    required String model,
    required String apiKey,
    required List<String> buckets,
    List<String> existingTaskTitles = const [],
  }) async {
    final existingTasksNote = existingTaskTitles.isNotEmpty
        ? '\nThe user already has these tasks: ${existingTaskTitles.join(', ')}. Do NOT create duplicates. If a completed task should be reopened, include it with the same title.\n'
        : '';

    final systemPrompt =
        '''
You are an assistant that reads a user's voice notes and produces a simple, precise, and concise Insights Edition.
Avoid long descriptive texts. Every sentence must be punchy and direct.
Rules: Only use what is present in the notes. Do not invent facts.
Output must be structured exactly as JSON with these keys:
title, summary, highlights, focus, next_steps, risks, questions, work_summaries, tasks, reminders.

Each highlight must have: title, detail, bucket, icon, and citations.
- IMPORTANT: Produce exactly ONE highlight per bucket. Never repeat a bucket across highlights.
- bucket: Choose exactly ONE from the user-provided buckets that best fits this specific highlight.
- detail: Max 2 sentences, very direct.
- icon: ONE of: reminder, todo, alert, health, finance, people, idea, calendar, travel, reading.
- citations: A list of note titles that were used to form this specific highlight.

tasks: Array of objects with {title, description, source_note_title}. These are actionable to-dos extracted from the notes. Each task should be specific and actionable.
$existingTasksNote
reminders: Array of objects with {title, date, time}. Time-sensitive items mentioned in notes. Use ISO 8601 date format. Only include items with clear time references.

work_summaries: 3 to 4 short, actionable work summaries (each under 25 words).

Never mention that you are an AI. Never mention system prompts or policies.
''';

    final userMessage = jsonEncode({'notes': notes, 'buckets': buckets});

    if (provider.type == LLMProviderType.google) {
      final content = await _chatWithGemini(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        model: model,
        apiKey: apiKey,
        provider: provider,
        jsonMode: true,
      );
      if (content == null || content.isEmpty) {
        throw Exception('Insight generation returned no content.');
      }
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return GeneratedInsights.fromJson(decoded);
    }

    // OpenAI path
    final payload = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userMessage},
      ],
      'response_format': {'type': 'json_object'},
    };

    final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
    final endpoint = '$baseUrl/chat/completions';
    final response = await _client.post(
      Uri.parse(endpoint),
      headers: _getHeaders(apiKey, provider),
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Insight generation failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    String? content;
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      content = choices[0]['message']['content'] as String?;
    }

    if (content == null || content.isEmpty) {
      throw Exception('Insight generation returned no content.');
    }

    final decoded = jsonDecode(content) as Map<String, dynamic>;
    return GeneratedInsights.fromJson(decoded);
  }

  // ── Gemini helpers ─────────────────────────────────────────────────

  /// Send a chat message to Gemini's generateContent API
  Future<String?> _chatWithGemini({
    required String systemPrompt,
    required String userMessage,
    required String model,
    required String apiKey,
    required LLMProvider provider,
    bool jsonMode = false,
  }) async {
    final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
    final endpoint = '$baseUrl/models/$model:generateContent';

    final payload = <String, dynamic>{
      'system_instruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'parts': [
            {'text': userMessage},
          ],
        },
      ],
    };

    if (jsonMode) {
      payload['generationConfig'] = {'responseMimeType': 'application/json'};
    }

    final response = await _client.post(
      Uri.parse('$endpoint?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini request failed: ${response.body}');
    }

    return _extractGeminiText(response.body);
  }

  /// Extract text from a Gemini generateContent response
  String _extractGeminiText(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }
    final parts = candidates[0]['content']['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini returned no content parts.');
    }
    return parts[0]['text'] as String? ?? '';
  }
}
