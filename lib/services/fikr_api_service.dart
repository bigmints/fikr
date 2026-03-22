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

  // Override in tests or staging
  static const String baseUrl = 'https://www.fikr.one';

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

      req.write(jsonEncode({
        'audioBase64': audioBase64,
        'mimeType': 'audio/mp4',
      }));

      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception(
          'Transcription failed: ${response.statusCode} $body',
        );
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

      req.write(jsonEncode({
        'transcript': transcript,
        'buckets': buckets,
      }));

      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception(
          'Analysis failed: ${response.statusCode} $body',
        );
      }

      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('FikrApiService.analyzeTranscript: $e');
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
