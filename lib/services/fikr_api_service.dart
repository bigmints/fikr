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
  static String get baseUrl =>
      kDebugMode ? 'http://localhost:3000' : 'https://www.fikr.one';

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
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
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

      req.write(
        jsonEncode({'audioBase64': audioBase64, 'mimeType': 'audio/mp4'}),
      );

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

      req.write(jsonEncode({'transcript': transcript, 'buckets': buckets}));

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
      req.write(jsonEncode({'providers': providers}));
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
  /// Returns the current month's AI usage stats for Pro users.
  /// Returns null on failure (treated as unknown / not available).
  Future<ProUsageStats?> getUsageStats() async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$baseUrl/api/user/usage');
      final httpClient = HttpClient();
      final req = await httpClient.getUrl(uri);
      headers.forEach(req.headers.add);
      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        debugPrint(
          'FikrApiService.getUsageStats: ${response.statusCode} $body',
        );
        return null;
      }
      return ProUsageStats.fromJson(jsonDecode(body) as Map<String, dynamic>);
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

      req.write(jsonEncode({
        'notes': notes,
        'buckets': buckets,
        'existingTaskTitles': existingTaskTitles,
      }));

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
// ProUsageStats
// ─────────────────────────────────────────────

class ProUsageStats {
  final String monthKey;
  final int transcribeCalls;
  final int analyzeCalls;
  final int transcribeTokens;
  final int analyzeTokens;
  final int transcribeRemaining;
  final int analyzeRemaining;
  final int transcribeLimit;
  final int analyzeLimit;

  const ProUsageStats({
    required this.monthKey,
    required this.transcribeCalls,
    required this.analyzeCalls,
    required this.transcribeTokens,
    required this.analyzeTokens,
    required this.transcribeRemaining,
    required this.analyzeRemaining,
    required this.transcribeLimit,
    required this.analyzeLimit,
  });

  factory ProUsageStats.fromJson(Map<String, dynamic> json) {
    return ProUsageStats(
      monthKey: json['monthKey'] as String? ?? '',
      transcribeCalls: json['transcribeCalls'] as int? ?? 0,
      analyzeCalls: json['analyzeCalls'] as int? ?? 0,
      transcribeTokens: json['transcribeTokens'] as int? ?? 0,
      analyzeTokens: json['analyzeTokens'] as int? ?? 0,
      transcribeRemaining: json['transcribeRemaining'] as int? ?? 500,
      analyzeRemaining: json['analyzeRemaining'] as int? ?? 500,
      transcribeLimit: json['transcribeLimit'] as int? ?? 500,
      analyzeLimit: json['analyzeLimit'] as int? ?? 500,
    );
  }
}
