import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// FikrApiService — wraps all fikr.one HTTP API calls.
///
/// Authentication uses a Firebase ID token obtained from the current user
/// (who signed in via the fikr.one custom token flow). This token is sent
/// as a Bearer token in the Authorization header.
///
/// Endpoints covered:
///   GET  /api/user/me        — user profile + plan
///   POST /api/ai/transcribe  — metered transcription (Pro tier)
///   POST /api/ai/analyze     — metered analysis (Pro tier)
class FikrApiService {
  static final FikrApiService _instance = FikrApiService._internal();

  factory FikrApiService() => _instance;

  FikrApiService._internal();

  // Uses LAN IP in debug builds so physical iOS devices can reach the Mac's
  // Next.js dev server. Falls back to production URL in release builds.
  // Update the IP below if your network changes (run: ipconfig getifaddr en0).
  // Always use production — works for real devices and emulators alike.
  // To test against a local fikr.one server:
  //   - Android emulator:  'http://10.0.2.2:3000'
  //   - Real device (LAN): 'http://192.168.1.203:3000' (run: ipconfig getifaddr en0)
  //   - macOS simulator:   'http://localhost:3000'
  static String get baseUrl => 'https://www.fikr.one';

  // ─────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────

  /// Retrieves the current user's Firebase ID token.
  /// Returns null if no user is signed in.
  Future<String?> _getIdToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (e) {
      debugPrint('FikrApiService._getIdToken: $e');
      return null;
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getIdToken();
    if (token == null) {
      debugPrint('FikrApiService._authHeaders: WARNING: getIdToken() returned null! Missing Authorization header.');
    } else {
      debugPrint('FikrApiService._authHeaders: Successfully got token. length=${token.length}');
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _safeWriteJson(HttpClientRequest req, Map<String, dynamic> data) {
    final bodyString = jsonEncode(data);
    req.add(const Utf8Codec(allowMalformed: true).encode(bodyString));
  }

  // ─────────────────────────────────────────────
  // User profile
  // ─────────────────────────────────────────────

  /// GET /api/user/me
  /// Returns user profile + plan. Useful on login to fast-hydrate subscription.
  Future<FikrUserProfile?> getMe() async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/user/me');
      final httpClient = HttpClient();
      final req = await httpClient.getUrl(uri);
      headers.forEach(req.headers.add);
      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        debugPrint('FikrApiService.getMe: ${response.statusCode} $body');
        return null;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      return FikrUserProfile.fromJson(data);
    } catch (e) {
      debugPrint('FikrApiService.getMe: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // AI — Pro tier metered endpoints
  // ─────────────────────────────────────────────

  /// POST /api/ai/transcribe
  ///
  /// Sends audio file to fikr.one for metered transcription via Gemini.
  /// Only valid for Pro tier users — fikr.one enforces this server-side.
  Future<String> transcribeAudio(File audioFile) async {
    try {
      final headers = await _authHeaders();
      final bytes = await audioFile.readAsBytes();
      final audioBase64 = base64Encode(bytes);

      final uri = Uri.parse('$baseUrl/api/ai/transcribe');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      headers.forEach(req.headers.add);

      _safeWriteJson(req, {'audioBase64': audioBase64, 'mimeType': 'audio/mp4'});

      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Transcription failed: ${response.statusCode} $body');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['transcript'] as String? ?? '';
    } catch (e) {
      debugPrint('FikrApiService.transcribeAudio: $e');
      rethrow;
    }
  }

  /// POST /api/ai/analyze
  ///
  /// Sends transcript + buckets to fikr.one for metered analysis via Gemini.
  /// Only valid for Pro tier users — fikr.one enforces this server-side.
  Future<Map<String, dynamic>> analyzeTranscript({
    required String transcript,
    required List<String> buckets,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/ai/analyze');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      headers.forEach(req.headers.add);

      _safeWriteJson(req, {'transcript': transcript, 'buckets': buckets});

      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Analysis failed: ${response.statusCode} $body');
      }

      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('FikrApiService.analyzeTranscript: $e');
      rethrow;
    }
  }

  /// POST /api/ai/vision
  ///
  /// Sends image to fikr.one for metered analysis via Gemini 2.0 Flash Multimodal.
  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    try {
      final headers = await _authHeaders();
      final bytes = await File(imagePath).readAsBytes();
      final imageBase64 = base64Encode(bytes);
      final extension = imagePath.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';

      final uri = Uri.parse('$baseUrl/api/ai/vision');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      headers.forEach(req.headers.add);

      _safeWriteJson(req, {
        'imageBase64': imageBase64,
        'mimeType': mimeType,
      });

      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Vision analysis failed: ${response.statusCode} $body');
      }

      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('FikrApiService.analyzeImage: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // API Key sync (Plus/Pro tier — calls fikr.one)
  // ─────────────────────────────────────────────

  /// POST /api/user/keys
  ///
  /// Pushes all local API key provider entries to fikr.one for safe-keeping.
  /// Each entry is { id, name, type, apiKey }.
  /// Only succeeds for Plus/Pro users — fikr.one enforces server-side.
  Future<bool> pushApiKeys(List<Map<String, String>> providers) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/user/keys');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      headers.forEach(req.headers.add);
      _safeWriteJson(req, {'providers': providers});
      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        debugPrint('FikrApiService.pushApiKeys: ${response.statusCode} $body');
        return false;
      }
      debugPrint(
        'FikrApiService.pushApiKeys: OK (${providers.length} providers)',
      );
      return true;
    } catch (e) {
      debugPrint('FikrApiService.pushApiKeys: $e');
      return false;
    }
  }

  /// GET /api/user/keys
  ///
  /// Pulls stored API key provider entries from fikr.one.
  /// Returns a list of { id, name, type, apiKey } maps, or empty list on failure.
  Future<List<Map<String, String>>> pullApiKeys() async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/user/keys');
      final httpClient = HttpClient();
      final req = await httpClient.getUrl(uri);
      headers.forEach(req.headers.add);
      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        debugPrint('FikrApiService.pullApiKeys: ${response.statusCode} $body');
        return [];
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final raw = data['providers'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => {
              'id': e['id'] as String? ?? '',
              'name': e['name'] as String? ?? '',
              'type': e['type'] as String? ?? '',
              'apiKey': e['apiKey'] as String? ?? '',
            },
          )
          .toList();
    } catch (e) {
      debugPrint('FikrApiService.pullApiKeys: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // Usage stats (Pro tier)
  // ─────────────────────────────────────────────

  /// GET /api/user/usage
  ///
  /// Returns the current month's word-based usage stats.
  /// Available for all plans (Free returns unlimited).
  Future<FikrUsageStats?> getUsageStats() async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/user/usage');
      final httpClient = HttpClient();
      final req = await httpClient.getUrl(uri);
      headers.forEach(req.headers.add);
      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        debugPrint('FikrApiService.getUsageStats: ${response.statusCode} $body');
        return null;
      }
      return FikrUsageStats.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('FikrApiService.getUsageStats: $e');
      return null;
    }
  }
  // ─────────────────────────────────────────────
  // AI — Insights generation (Pro tier)
  // ─────────────────────────────────────────────

  /// POST /api/ai/insights
  ///
  /// Sends notes + buckets to fikr.one for metered insights generation via Gemini.
  /// Only valid for Pro tier users — fikr.one enforces this server-side.
  Future<Map<String, dynamic>> generateInsights({
    required List<Map<String, dynamic>> notes,
    required List<String> buckets,
    List<String> existingTaskTitles = const [],
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/ai/insights');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      headers.forEach(req.headers.add);

      _safeWriteJson(req, {
        'notes': notes,
        'buckets': buckets,
        'existingTaskTitles': existingTaskTitles,
      });

      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Insights generation failed: ${response.statusCode} $body');
      }

      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('FikrApiService.generateInsights: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Chat completion (Pro tier — tool selector)
  // ─────────────────────────────────────────────

  /// POST /api/ai/chat
  ///
  /// General-purpose chat completion via fikr.one Vertex AI.
  /// Used by the tool selector for intent → tool routing.
  Future<String> chat({
    required String systemPrompt,
    required String userMessage,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/ai/chat');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      headers.forEach(req.headers.add);

      _safeWriteJson(req, {
        'systemPrompt': systemPrompt,
        'userMessage': userMessage,
      });

      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Chat failed: ${response.statusCode} $body');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['response'] as String? ?? '';
    } catch (e) {
      debugPrint('FikrApiService.chat: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // OpenRouter proxy (all tiers — managed key)
  // ─────────────────────────────────────────────

  /// POST /api/ai/openrouter
  ///
  /// Plain-text chat via OpenRouter using the server-side API key.
  /// Available to all users (Free, Plus, Pro).
  Future<String> openRouterChat({
    required String systemPrompt,
    required String userMessage,
    String model = 'google/gemini-2.0-flash-lite-001',
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/ai/openrouter');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      headers.forEach(req.headers.add);

      _safeWriteJson(req, {
        'model': model,
        'systemPrompt': systemPrompt,
        'userMessage': userMessage,
      });

      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('OpenRouter chat failed: ${response.statusCode} $body');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['response'] as String? ?? '';
    } catch (e) {
      debugPrint('FikrApiService.openRouterChat: $e');
      rethrow;
    }
  }

  /// POST /api/ai/openrouter (vision path)
  ///
  /// Sends a base64 image to OpenRouter via fikr.one for multimodal analysis.
  /// Defaults to gemini-2.0-flash-lite-001 (vision-capable, cheap).
  Future<Map<String, dynamic>> openRouterVision({
    required String imageBase64,
    String mimeType = 'image/jpeg',
    String model = 'google/gemini-2.0-flash-lite-001',
    String? prompt,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/ai/openrouter');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      headers.forEach(req.headers.add);

      _safeWriteJson(req, {
        'model': model,
        'imageBase64': imageBase64,
        'mimeType': mimeType,
        if (prompt != null) 'prompt': prompt,
      });

      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('OpenRouter vision failed: ${response.statusCode} $body');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      // The response field contains the raw JSON string from the LLM
      final rawResponse = data['response'] as String? ?? '{}';
      try {
        return jsonDecode(rawResponse) as Map<String, dynamic>;
      } catch (_) {
        // If the model didn't return valid JSON, wrap it
        return {'description': rawResponse, 'title': 'Scanned Image', 'actions': []};
      }
    } catch (e) {
      debugPrint('FikrApiService.openRouterVision: $e');
      rethrow;
    }
  }
  // ─────────────────────────────────────────────
  // Push Notifications
  // ─────────────────────────────────────────────

  /// POST /api/notify/push
  /// Sends a push notification via Firebase Cloud Messaging.
  Future<bool> sendPushNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/notify/push');
      final httpClient = HttpClient();
      final req = await httpClient.postUrl(uri);
      headers.forEach(req.headers.add);

      _safeWriteJson(req, {
        'token': token,
        'title': title,
        'body': body,
      });

      final response = await req.close();
      final respBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        debugPrint('FikrApiService.sendPushNotification: ${response.statusCode} $respBody');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('FikrApiService.sendPushNotification: $e');
      return false;
    }
  }
}

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class FikrUserProfile {
  final String uid;
  final String? email;
  final String? name;
  final String? picture;
  final String plan;
  final bool canSync;
  final bool hasManagedAI;

  const FikrUserProfile({
    required this.uid,
    this.email,
    this.name,
    this.picture,
    required this.plan,
    required this.canSync,
    required this.hasManagedAI,
  });

  factory FikrUserProfile.fromJson(Map<String, dynamic> json) {
    return FikrUserProfile(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
      plan: json['plan'] as String? ?? 'free',
      canSync: json['canSync'] as bool? ?? false,
      hasManagedAI: json['hasManagedAI'] as bool? ?? false,
    );
  }
}

// ─────────────────────────────────────────────
// FikrUsageStats — word-based quota model
// ─────────────────────────────────────────────

class FikrUsageStats {
  final String monthKey;
  final String plan;
  final int    wordsUsed;
  final int    wordsLimit;        // -1 = unlimited
  final int    wordsRemaining;    // -1 = unlimited
  final int    topUpWordsGranted;
  final double percentUsed;       // 0.0–100.0
  final String resetAt;

  // Breakdown
  final int transcribeWords;
  final int analyzeWords;
  final int insightsWords;
  final int chatWords;
  final int studioWords;

  bool get isUnlimited  => wordsLimit == -1;
  bool get isNearLimit  => percentUsed >= 80.0 && !isAtLimit;
  bool get isAtLimit    => !isUnlimited && wordsRemaining <= 0;

  String get formattedLimit => isUnlimited ? 'Unlimited' : _fmt(wordsLimit);

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}k';
    return n.toString();
  }

  const FikrUsageStats({
    required this.monthKey,
    required this.plan,
    required this.wordsUsed,
    required this.wordsLimit,
    required this.wordsRemaining,
    required this.topUpWordsGranted,
    required this.percentUsed,
    required this.resetAt,
    required this.transcribeWords,
    required this.analyzeWords,
    required this.insightsWords,
    required this.chatWords,
    required this.studioWords,
  });

  factory FikrUsageStats.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> op(String key) {
      final raw = json['breakdown']?[key];
      return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    }
    return FikrUsageStats(
      monthKey:          json['monthKey']          as String? ?? '',
      plan:              json['plan']              as String? ?? 'free',
      wordsUsed:         json['wordsUsed']         as int?    ?? 0,
      wordsLimit:        json['wordsLimit']        as int?    ?? -1,
      wordsRemaining:    json['wordsRemaining']    as int?    ?? -1,
      topUpWordsGranted: json['topUpWordsGranted'] as int?    ?? 0,
      percentUsed:       (json['percentUsed']      as num?    ?? 0).toDouble(),
      resetAt:           json['resetAt']           as String? ?? '',
      transcribeWords:   op('transcribe')['words'] as int?    ?? 0,
      analyzeWords:      op('analyze')['words']    as int?    ?? 0,
      insightsWords:     op('insights')['words']   as int?    ?? 0,
      chatWords:         op('chat')['words']       as int?    ?? 0,
      studioWords:       op('studio')['words']     as int?    ?? 0,
    );
  }

  FikrUsageStats copyWith({
    int?    wordsUsed,
    int?    wordsRemaining,
    double? percentUsed,
  }) {
    return FikrUsageStats(
      monthKey:          monthKey,
      plan:              plan,
      wordsUsed:         wordsUsed         ?? this.wordsUsed,
      wordsLimit:        wordsLimit,
      wordsRemaining:    wordsRemaining    ?? this.wordsRemaining,
      topUpWordsGranted: topUpWordsGranted,
      percentUsed:       percentUsed       ?? this.percentUsed,
      resetAt:           resetAt,
      transcribeWords:   transcribeWords,
      analyzeWords:      analyzeWords,
      insightsWords:     insightsWords,
      chatWords:         chatWords,
      studioWords:       studioWords,
    );
  }
}

// Alias kept for backward compat during migration
typedef ProUsageStats = FikrUsageStats;
