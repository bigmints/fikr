import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/subscription_tier.dart';

/// FirebaseService — manages Firebase SDK state for fikr.
///
/// Auth is exclusively handled by fikr.one. This service:
///   1. Signs into Firebase using a custom token obtained from fikr.one.
///   2. Reads/streams subscription tier from Firestore (written by fikr.one).
///   3. For Pro tier, provides Vertex AI transcription + analysis.
///      (Free/Plus users call their own LLM provider directly — not via this service.)
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() => _instance;

  FirebaseService._internal();

  late GenerativeModel _model;
  late FirebaseRemoteConfig _remoteConfig;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _initialized = false;
  Rx<User?> currentUser = Rx<User?>(null);

  /// Initialize Firebase services. Call once from main().
  Future<void> initialize() async {
    if (_initialized) return;

    // Sync current user state immediately (avoids null window on app start)
    currentUser.value = _auth.currentUser;
    currentUser.bindStream(_auth.authStateChanges());

    try {
      // Vertex AI (Gemini Flash) — used for Pro tier managed AI
      _model = FirebaseAI.vertexAI().generativeModel(model: 'gemini-2.0-flash');

      // Remote Config
      _remoteConfig = FirebaseRemoteConfig.instance;
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await _remoteConfig.setDefaults(const {
        'allowed_models':
            '{"chat": ["gemini-2.0-flash"], "transcription": ["gemini-2.0-flash"]}',
      });
      await _remoteConfig.fetchAndActivate();

      _initialized = true;
      debugPrint('FirebaseService: initialized (Vertex AI + Remote Config).');
    } catch (e) {
      debugPrint('FirebaseService: Error initializing: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Auth — fikr.one custom token flow only
  // ─────────────────────────────────────────────

  /// Sign in using a Firebase custom token obtained from fikr.one.
  /// This is the ONLY auth path in the app.
  Future<User?> signInWithCustomToken(String token) async {
    try {
      final credential = await _auth.signInWithCustomToken(token);
      return credential.user;
    } catch (e) {
      debugPrint('FirebaseService.signInWithCustomToken: $e');
      rethrow;
    }
  }

  /// Sign out of Firebase. Also clears the Firestore listener state.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Delete the current user's account and all associated Firestore data.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;
      final userDoc = firestore.collection('users').doc(uid);

      // Remove all subcollections
      for (final sub in ['notes', 'insights', 'tasks', 'reminders', 'usage']) {
        final snap = await userDoc.collection(sub).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }

      // Remove the root user document and then the auth record
      await userDoc.delete();
      await user.delete();
    } catch (e) {
      debugPrint('FirebaseService.deleteAccount: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Subscription tier (Firestore)
  // ─────────────────────────────────────────────

  /// One-time read of the user's plan from Firestore.
  Future<SubscriptionTier> getUserSubscriptionTier(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return SubscriptionTier.free;
      final tierStr = doc.data()?['plan'] as String?;
      return SubscriptionTier.values.firstWhere(
        (t) => t.name == tierStr,
        orElse: () => SubscriptionTier.free,
      );
    } catch (e) {
      debugPrint('FirebaseService.getUserSubscriptionTier: $e');
      return SubscriptionTier.free;
    }
  }

  /// Real-time stream of the user's plan. Updates instantly when fikr.one
  /// changes the plan field (e.g., after a Stripe payment).
  Stream<SubscriptionTier> userTierStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return SubscriptionTier.free;
          final tierStr = snap.data()?['plan'] as String?;
          return SubscriptionTier.values.firstWhere(
            (t) => t.name == tierStr,
            orElse: () => SubscriptionTier.free,
          );
        });
  }

  // ─────────────────────────────────────────────
  // Remote Config
  // ─────────────────────────────────────────────

  Map<String, List<String>> getAllowedModels() {
    if (!_initialized) return {};
    try {
      final jsonString = _remoteConfig.getString('allowed_models');
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      );
    } catch (e) {
      debugPrint('FirebaseService.getAllowedModels: $e');
      return {};
    }
  }

  // ─────────────────────────────────────────────
  // Vertex AI (Pro tier managed AI)
  // ─────────────────────────────────────────────

  /// Transcribe audio using Gemini Flash (Vertex AI).
  /// Called for Pro tier users when the AI request is handled in-app.
  /// For the fully metered path, use FikrApiService.transcribeAudio() instead.
  Future<String> transcribeAudio(File audioFile) async {
    if (!_initialized) await initialize();

    try {
      final bytes = await audioFile.readAsBytes();
      const mimeType = 'audio/mp4';

      final content = [
        Content.multi([
          TextPart('Please transcribe this audio file accurately.'),
          InlineDataPart(mimeType, bytes),
        ]),
      ];

      final response = await _model.generateContent(content);
      return response.text ?? '';
    } catch (e) {
      debugPrint('FirebaseService.transcribeAudio (Vertex AI): $e');
      rethrow;
    }
  }

  /// Analyze transcript using Gemini Flash (Vertex AI).
  /// Called for Pro tier users. For metered path, use FikrApiService.analyzeTranscript().
  Future<Map<String, dynamic>> analyzeTranscript({
    required String transcript,
    required List<String> buckets,
  }) async {
    if (!_initialized) await initialize();

    final bucketList = buckets.join(', ');
    final prompt = '''
You are an assistant that cleans spoken notes into structured text.
Return ONLY valid JSON with keys: "cleanedText", "intent", "bucket", "topics".
Rules:
1. Pick exactly ONE bucket from this list: $bucketList. If none fit, use "General". Put this in "bucket".
2. Identify 3-5 relevant tags/topics for metadata and put them in "topics".
3. Provide a concise title in "intent" and cleaned version of the transcript in "cleanedText".

Transcript:
$transcript
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final text = response.text;

      if (text == null) throw Exception('No response from Vertex AI');

      final cleanJson =
          text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('FirebaseService.analyzeTranscript (Vertex AI): $e');
      rethrow;
    }
  }
}
