import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/action_card.dart';
import '../models/scan.dart';

import '../services/storage_service.dart';
import '../tools/engine/engine_controller.dart';
import 'app_controller.dart';

/// Mirrors the audio workflow from AppController/AudioSyncService:
///   1. Pick image
///   2. Save locally
///   3. Show optimistic processing card
///   4. Send to AI via vision.analyse tool
///   5. Save result to local storage + Firestore
///   6. Upload image to GCS in background (Plus/Pro)
///   7. Auto-navigate to ScanDetailScreen
class VisionController extends GetxController {
  final StorageService _localStorage = Get.find<StorageService>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  final RxList<Scan> scans = <Scan>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadScans();
  }

  Future<void> _loadScans() async {
    scans.value = (await _localStorage.loadScans())
        .where((s) => !s.archived)
        .toList();
  }

  // ── Entry point ────────────────────────────────────────────────────────────

  Future<void> pickAndAnalyse(ImageSource source) async {
    final appController = Get.find<AppController>();

    final XFile? picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    // Gate: need either a configured provider or Pro managed AI
    final provider = appController.config.value.activeProvider;
    final isPro = appController.subscription.hasManagedVertexAI;
    if (!isPro && provider == null) {
      Get.snackbar(
        'Not Configured',
        'Fikr isn\'t set up yet. Go to Settings → AI Service.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final id = const Uuid().v4();
    final now = DateTime.now();

    // ── Step 1: Save original locally + create compressed thumb ──────────
    final paths = await _persistImage(File(picked.path), id);
    final localPath = paths.$1;   // original — goes to GCS on Plus/Pro
    final thumbPath = paths.$2;   // compressed — used for LLM only

    // ── Step 2: Optimistic processing card ────────────────────────────
    final dummyScan = Scan(
      id: id,
      createdAt: now,
      updatedAt: now,
      title: 'Analyzing Image...',
      description: 'Identifying objects and generating actions...',
      imagePath: localPath,
      thumbPath: thumbPath,
      isProcessing: true,
    );
    scans.insert(0, dummyScan);
    scans.refresh();

    try {
      // ── Step 3: Send THUMB to AI (not original) ──────────────────────
      final engine = Get.find<EngineController>();
      final result = await engine.executeTool('vision.analyse', {
        'imagePath': thumbPath ?? localPath, // fallback to original if compress failed
      });

      if (!result.success) {
        _removeProcessingCard(id);
        
        final errStr = result.error ?? 'Image analysis failed.';
        String userMessage = 'Image analysis failed.';
        if (errStr.contains('401') || errStr.contains('403')) {
          userMessage = 'Invalid API key. Please check your API key in Settings.';
        } else if (errStr.contains('insufficient_quota') || errStr.contains('exceeded') || errStr.contains('RESOURCE_EXHAUSTED')) {
          userMessage = 'API quota exceeded. Please check your billing or plan with your provider.';
        } else if (errStr.contains('429') || errStr.contains('limit')) {
          userMessage = 'Monthly limit reached. Resets on the 1st of next month.';
        } else if (errStr.contains('SocketException') || errStr.contains('ClientException')) {
          userMessage = 'Network error. Please check your internet connection.';
        }

        Get.snackbar(
          'Analysis Failed',
          userMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
        return;
      }

      final analysis = result.data as Map<String, dynamic>;

      // Safety check: if the backend/model flagged the content, block it
      final isBlocked = analysis['blocked'] == true;
      final finalScan = dummyScan.copyWith(
        title: isBlocked
            ? 'Content Blocked'
            : (analysis['title'] as String? ?? 'Scanned Image'),
        description: isBlocked
            ? (analysis['reason'] as String? ?? 'This image was flagged by safety filters.')
            : (analysis['description'] as String? ?? ''),
        category: isBlocked ? 'other' : (analysis['category'] as String? ?? 'other'),
        actions: isBlocked
            ? const []
            : (analysis['actions'] as List<dynamic>? ?? [])
                .map((a) => ActionCard.fromJson(a as Map<String, dynamic>))
                .toList(),
        isProcessing: false,
        updatedAt: DateTime.now(),
      );

      _replaceScan(id, finalScan);
      await _saveScanLocally();

      // Sync to Firestore if user can sync
      if (appController.subscription.canSync) {
        unawaited(_syncScanToFirestore(finalScan));
      }

      // ── Step 5: Upload image to GCS in background (Plus/Pro) ─────────────
      unawaited(_uploadImageInBackground(finalScan));


      // Refresh usage counters for Pro users
      if (isPro) unawaited(appController.fetchUsageStats());
    } catch (e) {
      debugPrint('[VisionController] Error: $e');
      _removeProcessingCard(id);
      
      final errStr = e.toString();
      String userMessage = 'Failed to analyze image. Please try again.';
      if (errStr.contains('401') || errStr.contains('403')) {
        userMessage = 'Invalid API key. Please check your API key in Settings.';
      } else if (errStr.contains('insufficient_quota') || errStr.contains('exceeded') || errStr.contains('RESOURCE_EXHAUSTED')) {
        userMessage = 'API quota exceeded. Please check your billing or plan with your provider.';
      } else if (errStr.contains('429') || errStr.contains('limit')) {
        userMessage = 'Monthly limit reached. Resets on the 1st of next month.';
      }

      Get.snackbar(
        'Error',
        userMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  // ── Archive ────────────────────────────────────────────────────────────────

  Future<void> archiveScan(String id) async {
    final index = scans.indexWhere((s) => s.id == id);
    if (index == -1) return;
    scans.removeAt(index);
    await _saveScanLocally();
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  /// Copies the picked image into the app's local documents directory (original),
  /// then creates a compressed thumbnail (max 1024px / 75% quality) for LLM dispatch.
  ///
  /// Returns (originalPath, thumbPath). thumbPath may be null if compression fails
  /// — callers should fall back to the original in that case.
  Future<(String, String?)> _persistImage(File source, String id) async {
    final ext = p.extension(source.path).replaceFirst('.', '');
    final safeExt = ext.isEmpty ? 'jpg' : ext;

    // Original — saved as-is, used for GCS upload
    final originalDest = File('${_localStorage.audioDirPath}/scan_$id.$safeExt');
    await originalDest.writeAsBytes(await source.readAsBytes());

    // Compressed thumb — max 1024px wide/tall, 75% quality JPEG
    String? thumbPath;
    try {
      final thumbDest = File('${_localStorage.audioDirPath}/scan_${id}_thumb.jpg');
      final result = await FlutterImageCompress.compressAndGetFile(
        originalDest.absolute.path,
        thumbDest.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      if (result != null) {
        thumbPath = result.path;
        debugPrint('[VisionController] Compressed: ${await source.length()} → ${await result.length()} bytes');
      }
    } catch (e) {
      debugPrint('[VisionController] Compression failed, using original: $e');
    }

    return (originalDest.path, thumbPath);
  }

  void _replaceScan(String id, Scan updated) {
    final index = scans.indexWhere((s) => s.id == id);
    if (index != -1) {
      scans[index] = updated;
    } else {
      scans.insert(0, updated);
    }
    scans.refresh();
  }

  void _removeProcessingCard(String id) {
    scans.removeWhere((s) => s.id == id);
    scans.refresh();
  }

  Future<void> _saveScanLocally() async {
    await _localStorage.saveScans(scans.toList());
  }

  /// Write a single Scan document to Firestore — mirrors saveNotes → syncToCloud.
  Future<void> _syncScanToFirestore(Scan scan) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans')
          .doc(scan.id)
          .set(scan.toJson());
      debugPrint('[VisionController] Synced scan ${scan.id} to Firestore');
    } catch (e) {
      debugPrint('[VisionController] Firestore sync error: $e');
    }
  }

  /// Upload image to Firebase Storage: `images/{uid}/{scanId}.{ext}`
  /// Fire-and-forget — updates the scan with the download URL on success.
  Future<void> _uploadImageInBackground(Scan scan) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.isAnonymous) return;

      final appController = Get.find<AppController>();
      if (!appController.subscription.canSync) return;

      final imagePath = scan.imagePath;
      if (imagePath == null || imagePath.isEmpty) return;

      File localFile = File(imagePath);
      if (!await localFile.exists()) {
        localFile = File(p.join(_localStorage.audioDirPath, p.basename(imagePath)));
      }
      if (!await localFile.exists()) return;

      final ext = p.extension(imagePath).replaceFirst('.', '');
      final cloudPath = 'images/${user.uid}/${scan.id}.$ext';
      final ref = _firebaseStorage.ref(cloudPath);

      debugPrint('[VisionController] Uploading image ${scan.id} → $cloudPath');

      await ref.putFile(
        localFile,
        SettableMetadata(
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          customMetadata: {'scanId': scan.id},
        ),
      );

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('[VisionController] Upload complete → $downloadUrl');

      final updated = scan.copyWith(imageUrl: downloadUrl, updatedAt: DateTime.now());
      _replaceScan(scan.id, updated);
      await _saveScanLocally();

      // Update Firestore with the cloud URL too
      if (appController.subscription.canSync) {
        unawaited(_syncScanToFirestore(updated));
      }
    } catch (e) {
      debugPrint('[VisionController] Background upload failed: $e');
    }
  }
}
