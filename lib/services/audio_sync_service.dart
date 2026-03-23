import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../controllers/subscription_controller.dart';
import 'storage_service.dart';

/// Manages audio file synchronization between local device storage and
/// Firebase Cloud Storage.
///
/// Strategy:
///   • Always play from **local** file (instant, offline, zero cost).
///   • For Plus/Pro users, upload a **backup** to GCS after local save.
///   • On new device / reinstall, download from GCS → local → play.
///   • If local file is missing, fall back to a GCS download URL.
class AudioSyncService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final StorageService _localStorage = Get.find<StorageService>();

  /// GCS path: `audio/{uid}/{noteId}.{ext}`
  String _cloudPath(String uid, String noteId, String extension) =>
      'audio/$uid/$noteId.$extension';

  // ── Upload ─────────────────────────────────────────────────────────

  /// Uploads the audio file to Firebase Storage **in the background**.
  /// No-op if the user is not on a sync-eligible tier.
  Future<String?> uploadAudio({
    required String noteId,
    required String localPath,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.isAnonymous) return null;

      final sub = Get.find<SubscriptionController>();
      if (!sub.canSync) return null;

      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('[AudioSync] File not found: $localPath');
        return null;
      }

      final ext = p.extension(localPath).replaceFirst('.', '');
      final cloudPath = _cloudPath(user.uid, noteId, ext);
      final ref = _storage.ref(cloudPath);

      debugPrint('[AudioSync] Uploading $noteId to $cloudPath');

      await ref.putFile(
        file,
        SettableMetadata(
          contentType: _mimeType(ext),
          customMetadata: {'noteId': noteId},
        ),
      );

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('[AudioSync] Upload complete → $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('[AudioSync] Upload failed for $noteId: $e');
      return null;
    }
  }

  // ── Download ───────────────────────────────────────────────────────

  /// Downloads the audio file from Firebase Storage to local storage.
  /// Returns the local path on success, null on failure.
  Future<String?> downloadAudio({
    required String noteId,
    required String audioUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Determine extension from URL or default to m4a
      final ext = _extensionFromUrl(audioUrl);
      final localPath =
          p.join(_localStorage.audioDirPath, '$noteId.$ext');
      final localFile = File(localPath);

      // Skip if already downloaded
      if (await localFile.exists()) {
        debugPrint('[AudioSync] Already cached locally: $localPath');
        return localPath;
      }

      debugPrint('[AudioSync] Downloading $noteId from cloud');

      // Try using the download URL directly
      final ref = _storage.refFromURL(audioUrl);
      final data = await ref.getData();
      if (data == null) return null;

      await localFile.parent.create(recursive: true);
      await localFile.writeAsBytes(data);

      debugPrint('[AudioSync] Downloaded to $localPath');
      return localPath;
    } catch (e) {
      debugPrint('[AudioSync] Download failed for $noteId: $e');
      return null;
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────

  /// Deletes the audio file from Firebase Storage.
  Future<void> deleteAudio({
    required String noteId,
    String? audioUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (audioUrl != null && audioUrl.isNotEmpty) {
        final ref = _storage.refFromURL(audioUrl);
        await ref.delete();
        debugPrint('[AudioSync] Deleted cloud audio for $noteId');
      }
    } catch (e) {
      debugPrint('[AudioSync] Delete failed for $noteId: $e');
    }
  }

  // ── Bulk sync: download missing audio for synced notes ─────────────

  /// For each note that has an `audioUrl` but no local file, download
  /// the audio. Called during sync pull operations.
  Future<void> downloadMissingAudio(List<Map<String, dynamic>> notesJson) async {
    for (final noteJson in notesJson) {
      final noteId = noteJson['id'] as String? ?? '';
      final audioUrl = noteJson['audioUrl'] as String? ?? '';
      final audioPath = noteJson['audioPath'] as String? ?? '';

      if (audioUrl.isEmpty || noteId.isEmpty) continue;

      // Check if local file exists
      if (audioPath.isNotEmpty && await File(audioPath).exists()) continue;

      await downloadAudio(noteId: noteId, audioUrl: audioUrl);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'm4a':
      case 'aac':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'webm':
        return 'audio/webm';
      default:
        return 'audio/mp4';
    }
  }

  String _extensionFromUrl(String url) {
    try {
      // Firebase Storage URLs have the path encoded; extract extension
      final uri = Uri.parse(url);
      final pathSegment = Uri.decodeComponent(uri.pathSegments.last);
      final ext = p.extension(pathSegment).replaceFirst('.', '');
      return ext.isNotEmpty ? ext : 'm4a';
    } catch (_) {
      return 'm4a';
    }
  }
}
