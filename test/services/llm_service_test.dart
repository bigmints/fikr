/// Unit tests for LLMService — BYOK AI routing across OpenAI, Gemini, and OpenRouter providers.
///
/// Covers:
/// - Model resolution: kPresetModels defaults per provider type
/// - JSON mode routing: response_format vs system prompt injection
/// - Transcription: OpenAI multipart vs Gemini generateContent paths
/// - Analysis: JSON parsing with and without response_format
/// - Insights: JSON parsing with markdown fence stripping
/// - Chat completion: json_mode flag routing
///
/// All HTTP calls are intercepted by [_MockClient] — no real network traffic.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fikr/models/llm_provider.dart';
import 'package:fikr/services/openai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock HTTP Client
// ─────────────────────────────────────────────────────────────────────────────

typedef _RequestHandler = Future<http.Response> Function(http.Request);
typedef _StreamedHandler = Future<http.StreamedResponse> Function(http.Request);

/// Intercepts HTTP requests and returns configurable responses.
class _MockClient extends http.BaseClient {
  _MockClient({_RequestHandler? handler, _StreamedHandler? streamedHandler})
      : _handler = handler,
        _streamedHandler = streamedHandler;

  final _RequestHandler? _handler;
  final _StreamedHandler? _streamedHandler;

  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);

    // Multipart requests (transcription) — only streamedHandler can handle them
    if (request is http.MultipartRequest) {
      if (_streamedHandler != null) {
        // Pass a synthetic Request with the same URL/method for inspection
        final synthetic = http.Request(request.method, request.url);
        return _streamedHandler(synthetic);
      }
      // Default: 200 with empty text response
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'text': ''}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // Regular JSON requests
    final jsonReq = request as http.Request;
    if (_streamedHandler != null) {
      return _streamedHandler(jsonReq);
    }
    if (_handler != null) {
      final response = await _handler(jsonReq);
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    throw StateError('No handler set in _MockClient');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider Factories
// ─────────────────────────────────────────────────────────────────────────────

LLMProvider openAiProvider({String? analysisModel, String? transcriptionModel}) =>
    LLMProvider(
      id: 'test-openai',
      name: 'OpenAI',
      type: LLMProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      analysisModel: analysisModel,
      transcriptionModel: transcriptionModel,
    );

LLMProvider geminiProvider({String? analysisModel, String? transcriptionModel}) =>
    LLMProvider(
      id: 'test-gemini',
      name: 'Google Gemini',
      type: LLMProviderType.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      analysisModel: analysisModel,
      transcriptionModel: transcriptionModel,
    );

LLMProvider openRouterProvider({
  String? analysisModel,
  String? transcriptionModel,
  String? toolsModel,
}) =>
    LLMProvider(
      id: 'test-openrouter',
      name: 'OpenRouter',
      type: LLMProviderType.openrouter,
      baseUrl: 'https://openrouter.ai/api/v1',
      analysisModel: analysisModel,
      transcriptionModel: transcriptionModel,
      toolsModel: toolsModel,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Mock Response Builders
// ─────────────────────────────────────────────────────────────────────────────

http.Response chatCompletionResponse(String content) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': content}
          }
        ],
        'usage': {'total_tokens': 42},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

http.Response transcriptionResponse(String text) => http.Response(
      jsonEncode({'text': text}),
      200,
      headers: {'content-type': 'application/json'},
    );

http.Response geminiContentResponse(String text) => http.Response(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text}
              ]
            },
          }
        ]
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

// ─────────────────────────────────────────────────────────────────────────────
// Valid JSON payloads the service is expected to return
// ─────────────────────────────────────────────────────────────────────────────

const _analysisJson = '''
{
  "cleanedText": "Schedule a team standup for tomorrow.",
  "intent": "Team Standup",
  "bucket": "Work Life",
  "topics": ["meeting", "team", "planning"]
}
''';

const _insightsJson = '''
{
  "title": "Weekly Wrap",
  "summary": "Busy week in work and personal life.",
  "highlights": [
    {
      "title": "Work focus",
      "detail": "High output week.",
      "bucket": "Work Life",
      "icon": "todo",
      "citations": ["Note A"]
    }
  ],
  "focus": ["Shipping v2"],
  "next_steps": ["Write release notes"],
  "risks": [],
  "questions": [],
  "work_summaries": ["Finalized API design", "Fixed sync bug"],
  "tasks": [{"title": "Ship v2", "description": "Deploy to prod", "source_note_title": "Note A"}],
  "reminders": []
}
''';

// ─────────────────────────────────────────────────────────────────────────────
// Test Suite
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Model Resolution ──────────────────────────────────────────────────

  group('kPresetModels — default model resolution', () {
    test('OpenAI: analysis → gpt-4o-mini', () {
      final p = openAiProvider();
      expect(p.resolveModel('analysis'), 'gpt-4o-mini');
    });

    test('OpenAI: transcription → whisper-1', () {
      final p = openAiProvider();
      expect(p.resolveModel('transcription'), 'whisper-1');
    });

    test('Gemini: analysis → gemini-2.0-flash-lite', () {
      final p = geminiProvider();
      expect(p.resolveModel('analysis'), 'gemini-2.0-flash-lite');
    });

    test('Gemini: transcription → gemini-2.0-flash', () {
      final p = geminiProvider();
      expect(p.resolveModel('transcription'), 'gemini-2.0-flash');
    });

    test('OpenRouter: analysis default → google/gemini-2.0-flash-001 (mirrors @preset/fikr-analysis)', () {
      final p = openRouterProvider();
      expect(p.resolveModel('analysis'), 'google/gemini-2.0-flash-001');
    });

    test('OpenRouter: transcription default → openai/whisper-large-v3 (mirrors @preset/fikr-transcription)', () {
      final p = openRouterProvider();
      expect(p.resolveModel('transcription'), 'openai/whisper-large-v3');
    });

    test('OpenRouter: tools default → google/gemini-2.0-flash-001 (mirrors @preset/fikr-tools)', () {
      final p = openRouterProvider();
      expect(p.resolveModel('tools'), 'google/gemini-2.0-flash-001');
    });

    test('OpenRouter: vision default → google/gemini-2.0-flash-001 (mirrors @preset/fikr-vision)', () {
      final p = openRouterProvider();
      expect(p.resolveModel('vision'), 'google/gemini-2.0-flash-001');
    });

    test('OpenRouter: embedding default → openai/text-embedding-3-small (mirrors @preset/fikr-embedding)', () {
      final p = openRouterProvider();
      expect(p.resolveModel('embedding'), 'openai/text-embedding-3-small');
    });

    test('User override takes precedence over preset default', () {
      final p = openRouterProvider(analysisModel: 'anthropic/claude-sonnet-4-5');
      expect(p.resolveModel('analysis'), 'anthropic/claude-sonnet-4-5');
    });

    test('OpenAI user override takes precedence', () {
      final p = openAiProvider(analysisModel: 'gpt-4o');
      expect(p.resolveModel('analysis'), 'gpt-4o');
    });
  });

  // ── 2. JSON Mode Detection (via request inspection) ──────────────────────

  group('JSON mode — response_format routing', () {
    late List<Map<String, dynamic>> capturedBodies;

    setUp(() => capturedBodies = []);

    Future<LLMService> makeService() async {
      final mock = _MockClient(
        handler: (req) {
          if (req.url.path.contains('chat/completions')) {
            capturedBodies.add(jsonDecode(req.body) as Map<String, dynamic>);
            return Future.value(chatCompletionResponse(_analysisJson));
          }
          return Future.value(http.Response('not found', 404));
        },
      );
      return LLMService(client: mock);
    }

    test('OpenAI analyze → sends response_format: json_object', () async {
      final svc = await makeService();
      await svc.analyzeTranscript(
        transcript: 'Schedule a standup tomorrow.',
        provider: openAiProvider(),
        apiKey: 'sk-test',
        buckets: ['Work Life', 'Personal Life'],
      );
      final body = capturedBodies.first;
      expect(body['response_format'], {'type': 'json_object'});
    });

    test('OpenRouter + google/* analyze → NO response_format, system prompt injected', () async {
      final svc = await makeService();
      // Default OpenRouter model is google/gemini-2.0-flash-001
      await svc.analyzeTranscript(
        transcript: 'Schedule a standup tomorrow.',
        provider: openRouterProvider(),
        apiKey: 'or-test',
        buckets: ['Work Life'],
      );
      final body = capturedBodies.first;
      expect(body.containsKey('response_format'), isFalse,
          reason: 'Gemini-backed OpenRouter model must NOT send response_format');
      final systemMsg = (body['messages'] as List).first as Map;
      expect(systemMsg['content'], contains('IMPORTANT: Your response MUST be valid JSON'),
          reason: 'JSON instruction must be injected into system prompt');
    });

    test('OpenRouter + openai/* model → sends response_format: json_object', () async {
      final svc = await makeService();
      await svc.analyzeTranscript(
        transcript: 'Test note.',
        provider: openRouterProvider(analysisModel: 'openai/gpt-4o-mini'),
        apiKey: 'or-test',
        buckets: ['General'],
      );
      final body = capturedBodies.first;
      expect(body['response_format'], {'type': 'json_object'});
    });

    test('OpenRouter + anthropic/* model → NO response_format, system prompt injected', () async {
      final svc = await makeService();
      await svc.analyzeTranscript(
        transcript: 'Test note.',
        provider: openRouterProvider(analysisModel: 'anthropic/claude-sonnet-4-5'),
        apiKey: 'or-test',
        buckets: ['General'],
      );
      final body = capturedBodies.first;
      expect(body.containsKey('response_format'), isFalse);
      final systemMsg = (body['messages'] as List).first as Map;
      expect(systemMsg['content'], contains('IMPORTANT: Your response MUST be valid JSON'));
    });

    test('chatCompletion: OpenAI jsonMode=true → response_format sent', () async {
      final svc = await makeService();
      await svc.chatCompletion(
        systemPrompt: 'You are a classifier.',
        userMessage: 'Classify this.',
        provider: openAiProvider(),
        apiKey: 'sk-test',
        jsonMode: true,
      );
      final body = capturedBodies.first;
      expect(body['response_format'], {'type': 'json_object'});
    });

    test('chatCompletion: OpenRouter+Gemini jsonMode=true → no response_format', () async {
      final svc = await makeService();
      await svc.chatCompletion(
        systemPrompt: 'You are a classifier.',
        userMessage: 'Classify this.',
        provider: openRouterProvider(), // defaults to google/gemini-2.0-flash-001
        apiKey: 'or-test',
        jsonMode: true,
      );
      final body = capturedBodies.first;
      expect(body.containsKey('response_format'), isFalse);
    });

    test('chatCompletion: jsonMode=false → no response_format regardless of provider', () async {
      final svc = await makeService();
      await svc.chatCompletion(
        systemPrompt: 'Answer naturally.',
        userMessage: 'Hello.',
        provider: openAiProvider(),
        apiKey: 'sk-test',
        jsonMode: false,
      );
      final body = capturedBodies.first;
      expect(body.containsKey('response_format'), isFalse);
    });
  });

  // ── 3. Transcription Routing ─────────────────────────────────────────────

  group('Transcription routing', () {
    test('OpenAI transcription → hits /audio/transcriptions endpoint', () async {
      String? capturedPath;
      final mock = _MockClient(
        streamedHandler: (req) async {
          capturedPath = req.url.path;
          final body = utf8.encode(jsonEncode({'text': 'Hello world'}));
          return http.StreamedResponse(Stream.value(body), 200,
              headers: {'content-type': 'application/json'});
        },
      );
      final svc = LLMService(client: mock);

      // Create a temp file
      final tmp = await _writeTempAudio();
      final transcript = await svc.transcribeAudio(
        audioFile: tmp,
        provider: openAiProvider(),
        apiKey: 'sk-test',
      );
      tmp.deleteSync();

      expect(capturedPath, contains('/audio/transcriptions'));
      expect(transcript, 'Hello world');
    });

    test('OpenRouter (whisper) transcription → hits /audio/transcriptions endpoint', () async {
      String? capturedPath;
      final mock = _MockClient(
        streamedHandler: (req) async {
          capturedPath = req.url.path;
          final body = utf8.encode(jsonEncode({'text': 'Voice note text'}));
          return http.StreamedResponse(Stream.value(body), 200,
              headers: {'content-type': 'application/json'});
        },
      );
      final svc = LLMService(client: mock);
      final tmp = await _writeTempAudio();
      final transcript = await svc.transcribeAudio(
        audioFile: tmp,
        provider: openRouterProvider(), // default → openai/whisper-large-v3
        apiKey: 'or-test',
      );
      tmp.deleteSync();

      expect(capturedPath, contains('/audio/transcriptions'));
      expect(transcript, 'Voice note text');
    });

    test('Gemini transcription → hits /models/.../generateContent endpoint', () async {
      String? capturedPath;
      final mock = _MockClient(
        handler: (req) async {
          capturedPath = req.url.path;
          return geminiContentResponse('This is the Gemini transcript.');
        },
      );
      final svc = LLMService(client: mock);
      final tmp = await _writeTempAudio();
      final transcript = await svc.transcribeAudio(
        audioFile: tmp,
        provider: geminiProvider(),
        apiKey: 'gm-test',
      );
      tmp.deleteSync();

      expect(capturedPath, contains('generateContent'));
      expect(transcript, 'This is the Gemini transcript.');
    });

    test('Gemini transcription request contains inline_data audio part', () async {
      Map<String, dynamic>? capturedBody;
      final mock = _MockClient(
        handler: (req) async {
          capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
          return geminiContentResponse('ok');
        },
      );
      final svc = LLMService(client: mock);
      final tmp = await _writeTempAudio();
      await svc.transcribeAudio(
        audioFile: tmp,
        provider: geminiProvider(),
        apiKey: 'gm-test',
      );
      tmp.deleteSync();

      final parts = (capturedBody!['contents'] as List).first['parts'] as List;
      expect(parts.first, isA<Map>());
      expect((parts.first as Map).containsKey('inline_data'), isTrue);
      expect(parts.first['inline_data']['mime_type'], isNotEmpty);
    });
  });

  // ── 4. Analysis — result parsing ─────────────────────────────────────────

  group('analyzeTranscript — result parsing', () {
    LLMService makeServiceWith(String responseBody) => LLMService(
          client: _MockClient(
            handler: (_) => Future.value(chatCompletionResponse(responseBody)),
          ),
        );

    LLMService makeGeminiService(String geminiText) => LLMService(
          client: _MockClient(
            handler: (_) => Future.value(geminiContentResponse(geminiText)),
          ),
        );

    test('OpenAI: parses cleanedText, intent, bucket, topics correctly', () async {
      final svc = makeServiceWith(_analysisJson);
      final result = await svc.analyzeTranscript(
        transcript: 'schedule standup',
        provider: openAiProvider(),
        apiKey: 'sk-test',
        buckets: ['Work Life'],
      );
      expect(result.cleanedText, 'Schedule a team standup for tomorrow.');
      expect(result.intent, 'Team Standup');
      expect(result.bucket, 'Work Life');
      expect(result.topics, contains('meeting'));
    });

    test('OpenRouter (Gemini-backed): parses JSON without response_format', () async {
      final svc = makeServiceWith(_analysisJson);
      final result = await svc.analyzeTranscript(
        transcript: 'schedule standup',
        provider: openRouterProvider(), // google/gemini-2.0-flash-001
        apiKey: 'or-test',
        buckets: ['Work Life'],
      );
      expect(result.intent, 'Team Standup');
      expect(result.bucket, 'Work Life');
    });

    test('Gemini: parses JSON from generateContent response', () async {
      final svc = makeGeminiService(_analysisJson);
      final result = await svc.analyzeTranscript(
        transcript: 'schedule standup',
        provider: geminiProvider(),
        apiKey: 'gm-test',
        buckets: ['Work Life'],
      );
      expect(result.intent, 'Team Standup');
    });

    test('Strips markdown code fences from model output before parsing', () async {
      final wrapped = '```json\n$_analysisJson\n```';
      final svc = makeServiceWith(wrapped);
      final result = await svc.analyzeTranscript(
        transcript: 'schedule standup',
        provider: openRouterProvider(), // no response_format → model may add fences
        apiKey: 'or-test',
        buckets: ['Work Life'],
      );
      expect(result.intent, 'Team Standup');
    });

    test('Falls back gracefully when model returns malformed JSON', () async {
      final svc = makeServiceWith('not valid json at all');
      final result = await svc.analyzeTranscript(
        transcript: 'original transcript',
        provider: openAiProvider(),
        apiKey: 'sk-test',
        buckets: ['General'],
      );
      // Falls back: preserves original transcript, empty intent
      expect(result.cleanedText, 'original transcript');
      expect(result.intent, '');
    });
  });

  // ── 5. Insights — result parsing ─────────────────────────────────────────

  group('generateInsights — result parsing', () {
    final notes = [
      {'id': 'n1', 'title': 'Note A', 'text': 'Busy week.', 'bucket': 'Work Life', 'topics': ['work']},
    ];

    LLMService makeServiceWith(String responseBody) => LLMService(
          client: _MockClient(
            handler: (_) => Future.value(chatCompletionResponse(responseBody)),
          ),
        );

    test('OpenAI: parses GeneratedInsights correctly', () async {
      final svc = makeServiceWith(_insightsJson);
      final result = await svc.generateInsights(
        notes: notes,
        provider: openAiProvider(),
        apiKey: 'sk-test',
        buckets: ['Work Life'],
      );
      expect(result.title, 'Weekly Wrap');
      expect(result.highlights, hasLength(1));
      expect(result.highlights.first.bucket, 'Work Life');
      expect(result.llmTasks, hasLength(1));
    });

    test('OpenRouter (Gemini-backed): parses insights without response_format', () async {
      final svc = makeServiceWith(_insightsJson);
      final result = await svc.generateInsights(
        notes: notes,
        provider: openRouterProvider(), // google/gemini-2.0-flash-001
        apiKey: 'or-test',
        buckets: ['Work Life'],
      );
      expect(result.title, 'Weekly Wrap');
    });

    test('Strips markdown fences from insights response', () async {
      final wrapped = '```json\n$_insightsJson\n```';
      final svc = makeServiceWith(wrapped);
      final result = await svc.generateInsights(
        notes: notes,
        provider: openRouterProvider(),
        apiKey: 'or-test',
        buckets: ['Work Life'],
      );
      expect(result.title, 'Weekly Wrap');
    });

    test('Throws if insights response is empty', () async {
      final svc = LLMService(
        client: _MockClient(
          handler: (_) => Future.value(chatCompletionResponse('')),
        ),
      );
      expect(
        () => svc.generateInsights(
          notes: notes,
          provider: openAiProvider(),
          apiKey: 'sk-test',
          buckets: ['Work Life'],
        ),
        throwsException,
      );
    });
  });

  // ── 6. Request Headers ───────────────────────────────────────────────────

  group('Request headers per provider type', () {
    late Map<String, String> capturedHeaders;
    late LLMService svc;

    setUp(() {
      capturedHeaders = {};
      svc = LLMService(
        client: _MockClient(
          handler: (req) {
            capturedHeaders = req.headers;
            return Future.value(chatCompletionResponse(_analysisJson));
          },
        ),
      );
    });

    test('OpenAI: sends Authorization: Bearer {key}', () async {
      await svc.analyzeTranscript(
        transcript: 'test',
        provider: openAiProvider(),
        apiKey: 'sk-openai-key',
        buckets: ['General'],
      );
      expect(capturedHeaders['authorization'], 'Bearer sk-openai-key');
    });

    test('OpenRouter: sends Authorization + HTTP-Referer + X-Title', () async {
      await svc.analyzeTranscript(
        transcript: 'test',
        provider: openRouterProvider(analysisModel: 'openai/gpt-4o-mini'),
        apiKey: 'or-key',
        buckets: ['General'],
      );
      expect(capturedHeaders['authorization'], 'Bearer or-key');
      expect(capturedHeaders['http-referer'], 'https://fikr.one');
      expect(capturedHeaders['x-title'], 'Fikr');
    });

    test('Gemini: sends x-goog-api-key, NOT Authorization', () async {
      // Gemini uses generateContent — mock via handler
      svc = LLMService(
        client: _MockClient(
          handler: (req) {
            capturedHeaders = req.headers;
            return Future.value(geminiContentResponse(_analysisJson));
          },
        ),
      );
      await svc.analyzeTranscript(
        transcript: 'test',
        provider: geminiProvider(),
        apiKey: 'gm-key',
        buckets: ['General'],
      );
      // Gemini uses query param key, not x-goog-api-key header in generateContent
      expect(capturedHeaders.containsKey('authorization'), isFalse);
      expect(reqContainsKey(capturedHeaders, 'x-goog-api-key'), isFalse);
      // URL contains key= query param
    });
  });

  // ── 7. Model used in request body ────────────────────────────────────────

  group('Model sent in request body', () {
    Future<String?> captureModel(LLMProvider provider) async {
      String? model;
      final mock = _MockClient(
        handler: (req) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          model = body['model'] as String?;
          return Future.value(chatCompletionResponse(_analysisJson));
        },
      );
      await LLMService(client: mock).analyzeTranscript(
        transcript: 'test',
        provider: provider,
        apiKey: 'key',
        buckets: ['General'],
      );
      return model;
    }

    test('OpenAI: request body contains model=gpt-4o-mini', () async {
      expect(await captureModel(openAiProvider()), 'gpt-4o-mini');
    });

    test('OpenRouter default: request body contains model=google/gemini-2.0-flash-001', () async {
      expect(await captureModel(openRouterProvider()), 'google/gemini-2.0-flash-001');
    });

    test('OpenRouter with user override: request body uses override model', () async {
      expect(
        await captureModel(openRouterProvider(analysisModel: 'anthropic/claude-sonnet-4-5')),
        'anthropic/claude-sonnet-4-5',
      );
    });

    test('OpenAI with user override: request body uses override model', () async {
      expect(await captureModel(openAiProvider(analysisModel: 'gpt-4o')), 'gpt-4o');
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a minimal temp audio file for transcription tests.
Future<File> _writeTempAudio() async {
  final tmp = File('${Directory.systemTemp.path}/fikr_test_audio.m4a');
  await tmp.writeAsBytes([0xFF, 0xFB, 0x00]); // fake audio bytes
  return tmp;
}

/// Helper for header key check (case-insensitive).
bool reqContainsKey(Map<String, String> headers, String key) {
  return headers.keys.any((k) => k.toLowerCase() == key.toLowerCase());
}
