import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/analysis_result.dart';
import '../models/insights_models.dart';
import '../models/llm_provider.dart';
import '../models/action_card.dart';
import '../models/note_content_type.dart';
import '../tools/prompts/vision_prompt.dart';

/// Comma-separated Studio content type values for use in LLM prompts.
final String _kStudioContentTypes = NoteContentType.promptValues;

class LLMService {
  LLMService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ── JSON mode helpers ──────────────────────────────────────────────

  /// Returns true if this provider+model combination supports the OpenAI-style
  /// `response_format: {type: 'json_object'}` API parameter.
  ///
  /// Rules:
  /// - Gemini provider → always false (uses `generationConfig.responseMimeType` instead)
  /// - OpenRouter + google/* model → false (Gemini-backed, rejects the param)
  /// - OpenRouter + anthropic/* model → false
  /// - OpenRouter + openai/* or unknown → true
  /// - OpenAI → true
  bool _supportsJsonObjectFormat(LLMProvider provider, String model) {
    if (provider.type == LLMProviderType.gemini) return false;
    if (provider.type == LLMProviderType.openrouter) {
      if (model.startsWith('google/'))    return false;
      if (model.startsWith('anthropic/')) return false;
    }
    return true;
  }

  /// Appends a strict JSON instruction to a system prompt.
  /// Used for OpenRouter+Gemini models that don't accept response_format.
  String _injectJsonInstruction(String systemPrompt) {
    return '$systemPrompt\n\nIMPORTANT: Your response MUST be valid JSON only. '
        'No markdown, no code fences, no commentary — output the raw JSON object directly.';
  }

  Map<String, String> _getHeaders(String apiKey, LLMProvider provider) {
    final headers = <String, String>{'Content-Type': 'application/json'};

    switch (provider.type) {
      case LLMProviderType.gemini:
        headers['x-goog-api-key'] = apiKey;
        break;
      case LLMProviderType.openai:
        headers['Authorization'] = 'Bearer $apiKey';
        break;
      case LLMProviderType.openrouter:
        headers['Authorization'] = 'Bearer $apiKey';
        headers['HTTP-Referer'] = 'https://fikr.one';
        headers['X-Title'] = 'Fikr';
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
              if (provider.type == LLMProviderType.gemini) {
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
    required String apiKey,
    String language = 'en',
  }) async {
    final model = provider.resolveModel('transcription');
    if (provider.type == LLMProviderType.gemini) {
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
    required String apiKey,
    required List<String> buckets,
    bool multiBucket = true,
  }) async {
    final model = provider.resolveModel('analysis');
    final bucketList = buckets.join(', ');

    final systemPrompt =
        'You are an assistant that cleans spoken notes into structured text. '
        'Return ONLY valid JSON with keys: "cleanedText", "intent", "bucket", "contentType". '
        'Rules:\n'
        '1. Pick exactly ONE bucket from this list: $bucketList. If none fit, use "General". Put this in "bucket".\n'
        '2. Classify the note into ONE content type from this exact list: $_kStudioContentTypes. Put this in "contentType".\n'
        '   - idea: a new concept, product feature, creative thought\n'
        '   - task: something actionable to do\n'
        '   - question: an open question or something to investigate\n'
        '   - reflection: personal insight, lesson learned, retrospective\n'
        '   - claim: a factual or opinionated statement\n'
        '   - entity: a person, company, product, or place\n'
        '   - quote: a verbatim or paraphrased quote from someone\n'
        '   - reference: a link, book, article, or resource to revisit\n'
        '   - definition: explaining a concept or term\n'
        '   - opinion: a personal view or evaluation\n'
        '   - narrative: a story, experience, or sequence of events\n'
        '   - comparison: comparing two or more things\n'
        '   - general: anything else\n'
        '3. Provide a concise title in "intent" and cleaned version of the transcript in "cleanedText".';


    if (provider.type == LLMProviderType.gemini) {
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

    // OpenAI / OpenRouter path
    final jsonOk = _supportsJsonObjectFormat(provider, model);
    final effectiveSystem = jsonOk ? systemPrompt : _injectJsonInstruction(systemPrompt);

    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': effectiveSystem},
      {'role': 'user', 'content': transcript},
    ];
    final payload = <String, dynamic>{
      'model': model,
      'messages': messages,
      if (jsonOk) 'response_format': {'type': 'json_object'},
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
        // Strip markdown fences in case the model wraps its output
        final cleaned = content
            .replaceAll(RegExp(r'^```json\n?', multiLine: true), '')
            .replaceAll(RegExp(r'\n?```$',    multiLine: true), '')
            .trim();
        final resultJson = jsonDecode(cleaned) as Map<String, dynamic>;
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
    required String apiKey,
    required List<String> buckets,
    List<String> existingTaskTitles = const [],
  }) async {
    final model = provider.resolveModel('analysis');
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

    if (provider.type == LLMProviderType.gemini) {
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

    // OpenAI / OpenRouter path
    final jsonOk = _supportsJsonObjectFormat(provider, model);
    final effectiveSystem = jsonOk ? systemPrompt : _injectJsonInstruction(systemPrompt);

    final payload = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': effectiveSystem},
        {'role': 'user', 'content': userMessage},
      ],
      if (jsonOk) 'response_format': {'type': 'json_object'},
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

    // Strip markdown fences in case the model wraps its output
    final cleaned = content
        .replaceAll(RegExp(r'^```json\n?', multiLine: true), '')
        .replaceAll(RegExp(r'\n?```$',    multiLine: true), '')
        .trim();
    final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
    return GeneratedInsights.fromJson(decoded);
  }

  // ── Vision ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> analyzeImage({
    required File imageFile,
    required LLMProvider provider,
    required String apiKey,
  }) async {
    final model = provider.resolveModel('vision');
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    if (provider.type == LLMProviderType.gemini) {
      final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
      final endpoint = '$baseUrl/models/$model:generateContent';

      final payload = {
        'system_instruction': {
          'parts': [
            {'text': visionSystemPrompt},
          ],
        },
        'contents': [
          {
            'parts': [
              {
                'inline_data': {'mime_type': mimeType, 'data': base64Image},
              },
              {
                'text': 'Analyze this image.',
              },
            ],
          },
        ],
        'generationConfig': {'responseMimeType': 'application/json'},
        // Safety filters: block medium+ for sensitive categories
        'safetySettings': [
          {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',  'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          {'category': 'HARM_CATEGORY_HARASSMENT',         'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH',        'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
        ],
      };

      final response = await _client.post(
        Uri.parse('$endpoint?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gemini request failed: ${response.body}');
      }

      // Check if Gemini blocked the content via safetyRatings
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = raw['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        final blocked = raw['promptFeedback']?['blockReason'] as String?;
        if (blocked != null) {
          return {'blocked': true, 'reason': 'Image blocked by safety filter: $blocked'};
        }
        throw Exception('Gemini returned no candidates.');
      }
      final finishReason = candidates[0]['finishReason'] as String?;
      if (finishReason == 'SAFETY') {
        return {'blocked': true, 'reason': 'Image was flagged by Gemini safety filters.'};
      }

      final content = _extractGeminiText(response.body);
      return jsonDecode(content) as Map<String, dynamic>;
    } else {
      // OpenAI path
      final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
      final endpoint = '$baseUrl/chat/completions';

      final payload = {
        'model': model,
        'messages': [
          {'role': 'system', 'content': visionSystemPrompt},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Analyze this image.'},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$base64Image'
                }
              }
            ]
          }
        ],
        'response_format': {'type': 'json_object'},
      };

      final response = await _client.post(
        Uri.parse(endpoint),
        headers: _getHeaders(apiKey, provider),
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Chat completion failed: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final content = choices[0]['message']['content'] as String?;
        if (content != null) {
           return jsonDecode(content) as Map<String, dynamic>;
        }
      }
      throw Exception('OpenAI returned no content.');
    }
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

  // ── General chat completion (for tool selector) ─────────────────────

  /// Public entry point for a system-prompt + user-message chat call.
  ///
  /// Returns the raw text response from the LLM. Used by the tool selector
  /// and any generic chat needs.
  Future<String> chatCompletion({
    required String systemPrompt,
    required String userMessage,
    required LLMProvider provider,
    required String apiKey,
    String? modelOverride,
    bool jsonMode = true,
  }) async {
    final model = modelOverride ?? provider.resolveModel('tools');
    if (provider.type == LLMProviderType.gemini) {
      final result = await _chatWithGemini(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        model: model,
        apiKey: apiKey,
        provider: provider,
        jsonMode: jsonMode,
      );
      return result ?? '';
    }

    // OpenAI / OpenRouter path
    final jsonOk = jsonMode && _supportsJsonObjectFormat(provider, model);
    final effectiveSystem = (jsonMode && !jsonOk)
        ? _injectJsonInstruction(systemPrompt)
        : systemPrompt;

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': effectiveSystem},
      {'role': 'user', 'content': userMessage},
    ];
    final payload = <String, dynamic>{
      'model': model,
      'messages': messages,
      if (jsonOk) 'response_format': {'type': 'json_object'},
    };
    final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
    final endpoint = '$baseUrl/chat/completions';

    final response = await _client.post(
      Uri.parse(endpoint),
      headers: _getHeaders(apiKey, provider),
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Chat completion failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      return choices[0]['message']['content'] as String? ?? '';
    }
    return '';
  }

  // ── Next Best Actions ───────────────────────────────────────────────

  /// Calls the LLM with an externally-provided [systemPrompt] and [contextText].
  ///
  /// The system prompt is built by [IntelligentLlmHook] and contains the full
  /// Fikr tool catalogue plus strict output rules. This method handles the
  /// provider routing (Gemini vs. OpenAI-compatible) and JSON parsing.
  Future<List<ActionCard>> generateNextBestActions({
    required String contextText,
    required String systemPrompt,
    required LLMProvider provider,
    required String apiKey,
  }) async {
    final model = provider.resolveModel('tools');
    try {
      String jsonResponse = '';
      if (provider.type == LLMProviderType.gemini) {
        final content = await _chatWithGemini(
          systemPrompt: systemPrompt,
          userMessage: contextText,
          model: model,
          apiKey: apiKey,
          provider: provider,
          jsonMode: true,
        );
        jsonResponse = content ?? '[]';
      } else {
        // OpenAI / OpenRouter path
        final jsonOk = _supportsJsonObjectFormat(provider, model);
        final effectiveSystem = jsonOk ? systemPrompt : _injectJsonInstruction(systemPrompt);

        final messages = <Map<String, String>>[
          {'role': 'system', 'content': effectiveSystem},
          {'role': 'user', 'content': contextText},
        ];
        final payload = <String, dynamic>{
          'model': model,
          'messages': messages,
          if (jsonOk) 'response_format': {'type': 'json_object'},
        };
        final baseUrl = _normalizeBaseUrl(provider.baseUrl, provider.type);
        final endpoint = '$baseUrl/chat/completions';

        final response = await _client.post(
          Uri.parse(endpoint),
          headers: _getHeaders(apiKey, provider),
          body: jsonEncode(payload),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            jsonResponse = choices[0]['message']['content'] as String? ?? '[]';
          }
        }
      }

      return _parseActionCards(jsonResponse);
    } catch (e) {
      debugPrint('[LLMService] generateNextBestActions error: $e');
      return [];
    }
  }

  List<ActionCard> _parseActionCards(String jsonStr) {
    try {
      // Strip any stray markdown fences
      var cleaned = jsonStr.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\n?```$'), '');
        cleaned = cleaned.trim();
      }

      final decoded = jsonDecode(cleaned);
      final List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map) {
        // Handle {"actions": [...]} or any first-List value
        if (decoded['actions'] is List) {
          list = decoded['actions'] as List<dynamic>;
        } else {
          final firstList = decoded.values.whereType<List>().firstOrNull;
          list = firstList ?? [];
        }
      } else {
        return [];
      }
      return list.whereType<Map<String, dynamic>>().map(ActionCard.fromJson).toList();
    } catch (e) {
      debugPrint('[LLMService] Error parsing ActionCards JSON: $e');
      return [];
    }
  }
}
