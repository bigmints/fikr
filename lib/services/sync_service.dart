import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../models/note.dart';
import '../models/scan.dart';
import '../models/insights_models.dart';
import '../models/llm_provider.dart';
import '../controllers/app_controller.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import '../services/firebase_service.dart';
import '../services/fikr_api_service.dart';
import '../controllers/subscription_controller.dart';
import 'audio_sync_service.dart';

/// Key used to persist the last-synced user ID so we can detect
/// same-account re-login vs account switches.
const _kLastSyncedUserKey = 'last_synced_user_id';

/// Removes characters that Firestore rejects with "string contains invalid characters":
///   • Null bytes (U+0000)
///   • C0 control characters (except \t, \n, \r which are valid in text)
///   • Lone Unicode surrogates (U+D800–U+DFFF) — valid in Dart Strings but
///     illegal in Firestore's UTF-8 storage layer
/// Also truncates at 500 KB to stay well under Firestore's 1 MiB field limit.
String _sanitizeString(String s) {
  // 1. Remove null bytes — the most common cause
  var cleaned = s.replaceAll('\x00', '');

  // 2. Remove C0 control characters (keep \t=0x09, \n=0x0A, \r=0x0D)
  cleaned = cleaned.replaceAll(RegExp(r'[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

  // 3. Strip lone Unicode surrogates (U+D800–U+DFFF).
  //    Firestore's protobuf layer requires valid UTF-8; surrogates are not.
  //    Dart strings can hold lone surrogates as code units, so we must check
  //    rune-by-rune and rebuild the string without them.
  final hasSurrogate = cleaned.codeUnits.any((u) => u >= 0xD800 && u <= 0xDFFF);
  if (hasSurrogate) {
    final buf = StringBuffer();
    for (final codeUnit in cleaned.codeUnits) {
      if (codeUnit < 0xD800 || codeUnit > 0xDFFF) {
        buf.writeCharCode(codeUnit);
      }
    }
    cleaned = buf.toString();
  }

  // 4. Truncate at 500 KB (Firestore max field is ~1 MiB)
  if (cleaned.length > 500000) {
    cleaned = cleaned.substring(0, 500000);
  }
  return cleaned;
}

/// Recursively sanitizes all string values in a JSON-like map.
/// Lists of strings are also sanitized element-by-element.
Map<String, dynamic> _sanitizeMap(Map<String, dynamic> data) {
  return data.map((key, value) {
    if (value is String) return MapEntry(key, _sanitizeString(value));
    if (value is List) {
      return MapEntry(
        key,
        value.map((e) => e is String ? _sanitizeString(e) : e).toList(),
      );
    }
    if (value is Map<String, dynamic>) return MapEntry(key, _sanitizeMap(value));
    return MapEntry(key, value);
  });
}

class SyncService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();
  /// Named Firestore database for Flutter app data.
  /// Uses 'prod-fikr' in release builds and 'dev-fikr' in debug/profile.
  /// Per architecture doc: no app data lives in the (default) database.
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: FirebaseFirestore.instance.app,
    databaseId: kReleaseMode ? 'prod-fikr' : 'dev-fikr',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _prefs = const FlutterSecureStorage();

  final RxBool isSyncEnabled = false.obs;
  final RxBool isSyncing = false.obs;
  final Rx<DateTime?> lastSyncTime = Rx<DateTime?>(null);
  final RxString syncError = ''.obs;

  /// When a login sync is requested while another is in progress, we
  /// store the pending user so we can re-trigger after the current one.
  User? _pendingLoginUser;

  @override
  void onInit() {
    super.onInit();

    // React to auth changes
    ever(FirebaseService().currentUser, (user) {
      debugPrint('Sync: Auth changed → ${user?.uid ?? 'signed-out'}');
      if (user != null && !user.isAnonymous) {
        _handleLogin(user);
      }
      // Logout: do nothing — keep local data in place.
    });

    // React to plan changes — refresh UI immediately, then sync if eligible.
    final subController = Get.find<SubscriptionController>();
    ever(subController.currentTier, (tier) async {
      try {
        debugPrint('Sync: Plan changed → ${tier.name}');
        // Immediately refresh the app controller so the UI reflects the new
        // tier (canRecord, canSync, etc.) without requiring a restart.
        await _refreshAppController();
        if (subController.canSync) {
          await _startSync();
        } else {
          debugPrint('Sync: Tier does not support sync, skipping.');
        }
      } catch (e) {
        debugPrint('SyncService: tier change handler error: $e');
      }
    });

    // Boot check: if already logged in, sync immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseService().currentUser.value;
      if (user != null && !user.isAnonymous) {
        debugPrint('Sync: User found on boot, starting sync.');
        _handleLogin(user);
      }
    });
  }


  // ── Core login handler ─────────────────────────────────────────────

  /// Decides what to do when a user logs in:
  ///  • Same account as last sync → bidirectional merge (newer wins)
  ///  • Different account          → clear local, pull cloud data
  ///  • First-ever login           → push local notes to cloud
  Future<void> _handleLogin(User user) async {
    if (isSyncing.value) {
      // Don't drop the request — queue it so we retry after the current sync.
      debugPrint('Sync: Already in progress, queuing user ${user.uid}.');
      _pendingLoginUser = user;
      return;
    }
    isSyncing.value = true;
    isSyncEnabled.value = true;

    try {
      // Give SubscriptionController a moment to resolve the tier from
      // Firestore so that syncToCloud() sees the correct plan. Without
      // this, the tier is still the default (free) and the push is skipped.
      final subController = Get.find<SubscriptionController>();
      for (int i = 0; i < 10; i++) {
        if (subController.canSync) break;
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final lastSyncedUid = await _prefs.read(key: _kLastSyncedUserKey);
      debugPrint('Sync: Current=${user.uid}, LastSynced=$lastSyncedUid');

      if (lastSyncedUid == null) {
        // ── First-ever login: push local data to cloud ──────────
        debugPrint('Sync: First login — pushing local data to cloud.');
        await syncToCloud();
        await _prefs.write(key: _kLastSyncedUserKey, value: user.uid);
        await _refreshAppController();
      } else if (lastSyncedUid == user.uid) {
        // ── Same account re-login: bidirectional merge ──────────
        debugPrint('Sync: Same account — merging.');
        await _syncBidirectional();
        await _refreshAppController();
      } else {
        // ── Different account: clear local, pull new user's data ─
        debugPrint('Sync: Account switch — clearing local & pulling cloud.');
        await _clearLocalData();
        await _refreshAppController(); // UI shows empty state
        await _pullCloudData(user.uid);
        await _prefs.write(key: _kLastSyncedUserKey, value: user.uid);
        await _refreshAppController(); // UI shows cloud data
      }
      lastSyncTime.value = DateTime.now();
      syncError.value = '';
    } catch (e) {
      debugPrint('Sync Error: $e');
      syncError.value = e.toString();
    } finally {
      isSyncing.value = false;

      // Process any queued login request that arrived while we were syncing.
      final pending = _pendingLoginUser;
      _pendingLoginUser = null;
      if (pending != null) {
        debugPrint('Sync: Processing queued login for ${pending.uid}.');
        await _handleLogin(pending);
      }
    }
  }

  // ── Backward-compat wrapper used by plan-change listener ───────────

  Future<void> _startSync() async {
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      await _handleLogin(user);
    }
  }

  // ── Bidirectional merge (same account) ─────────────────────────────

  Future<void> _syncBidirectional() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);

    // Snapshot of the previous sync time — items missing from cloud that were
    // last modified BEFORE this time were deleted on another device/Firestore.
    final prevSyncTime = lastSyncTime.value;

    // Pull cloud notes & insights
    final cloudNotesSnap = await userRef.collection('notes').get();
    final cloudNotes = cloudNotesSnap.docs
        .map((d) => Note.fromJson(d.data()))
        .toList();

    final cloudInsightsSnap = await userRef.collection('insights').get();
    final cloudInsights = cloudInsightsSnap.docs
        .map((d) => InsightEdition.fromJson(d.data()))
        .toList();

    final cloudTasksSnap = await userRef.collection('tasks').get();
    final cloudTasks = cloudTasksSnap.docs
        .map((d) => TodoItem.fromJson(d.data()))
        .toList();

    final cloudRemindersSnap = await userRef.collection('reminders').get();
    final cloudReminders = cloudRemindersSnap.docs
        .map((d) => ReminderItem.fromJson(d.data()))
        .toList();

    final cloudScansSnap = await userRef.collection('scans').get();
    final cloudScans = cloudScansSnap.docs
        .map((d) => Scan.fromJson(d.data()))
        .toList();

    // Build cloud ID sets for deletion detection
    final cloudNoteIds     = {for (final n in cloudNotes)     n.id};
    final cloudInsightIds  = {for (final i in cloudInsights)  i.id};
    final cloudTaskIds     = {for (final t in cloudTasks)     t.id};
    final cloudReminderIds = {for (final r in cloudReminders) r.id};
    final cloudScanIds     = {for (final s in cloudScans)     s.id};

    // Load local data
    final localNotes     = await _storage.loadNotes();
    final localInsights  = await _storage.loadInsightEditions();
    final localTasks     = await _storage.loadTasks();
    final localReminders = await _storage.loadReminders();
    final localScans     = await _storage.loadScans();

    // ── Deletion propagation (cloud-deleted → remove locally) ──────────
    // An item is treated as cloud-deleted when ALL of:
    //   • It is absent from Firestore, AND
    //   • It was last modified BEFORE the previous sync completed
    //     (so it existed on the server during the last sync and was
    //      removed since then — not a brand-new local item).
    List<Note>           filteredLocalNotes     = localNotes;
    List<InsightEdition> filteredLocalInsights  = localInsights;
    List<TodoItem>       filteredLocalTasks     = localTasks;
    List<ReminderItem>   filteredLocalReminders = localReminders;
    List<Scan>           filteredLocalScans     = localScans;

    if (prevSyncTime != null) {
      filteredLocalNotes = localNotes.where((n) {
        if (cloudNoteIds.contains(n.id)) return true;
        if (n.updatedAt.isAfter(prevSyncTime)) return true; // new local note
        return false; // absent from cloud & predates last sync → cloud-deleted
      }).toList();

      filteredLocalInsights = localInsights.where((i) {
        if (cloudInsightIds.contains(i.id)) return true;
        if (i.createdAt.isAfter(prevSyncTime)) return true;
        return false;
      }).toList();

      filteredLocalTasks = localTasks.where((t) {
        if (cloudTaskIds.contains(t.id)) return true;
        if (t.createdAt.isAfter(prevSyncTime)) return true;
        return false;
      }).toList();

      filteredLocalReminders = localReminders.where((r) {
        if (cloudReminderIds.contains(r.id)) return true;
        if (r.date.isAfter(prevSyncTime)) return true;
        return false;
      }).toList();

      filteredLocalScans = localScans.where((s) {
        if (cloudScanIds.contains(s.id)) return true;
        if (s.updatedAt.isAfter(prevSyncTime)) return true;
        return false;
      }).toList();

      final dn = localNotes.length     - filteredLocalNotes.length;
      final di = localInsights.length  - filteredLocalInsights.length;
      final dt = localTasks.length     - filteredLocalTasks.length;
      final dr = localReminders.length - filteredLocalReminders.length;
      final ds = localScans.length     - filteredLocalScans.length;
      if (dn + di + dt + dr + ds > 0) {
        debugPrint(
          'Sync: Deletion propagation — removed locally: '
          'notes=$dn, insights=$di, tasks=$dt, reminders=$dr, scans=$ds',
        );
      }
    }

    // Merge — newer wins; _mergeNotes also filters garbage Studio notes
    final mergedNotes     = _mergeNotes(filteredLocalNotes, cloudNotes);
    final mergedInsights  = _mergeInsights(filteredLocalInsights, cloudInsights);
    final mergedTasks     = _mergeTasks(filteredLocalTasks, cloudTasks);
    final mergedReminders = _mergeReminders(filteredLocalReminders, cloudReminders);
    final mergedScans     = _mergeScans(filteredLocalScans, cloudScans);

    // Save merged locally
    await _storage.saveNotes(mergedNotes);
    await _storage.saveInsightEditions(mergedInsights);
    await _storage.saveTasks(mergedTasks);
    await _storage.saveReminders(mergedReminders);
    await _storage.saveScans(mergedScans);

    // Download missing audio/images in the background
    _downloadMissingAudioForNotes(mergedNotes);
    _downloadMissingImagesForScans(mergedScans);

    // Push merged to cloud (includes API key push)
    await syncToCloud();

    // Pull any remote keys we might be missing locally
    await _pullRemoteApiKeys();

    debugPrint(
      'Sync: Merge complete. Notes: ${mergedNotes.length}, '
      'Insights: ${mergedInsights.length}, '
      'Tasks: ${mergedTasks.length}, '
      'Reminders: ${mergedReminders.length}',
    );
  }

  // ── Pull cloud data (account switch) ───────────────────────────────

  Future<void> _pullCloudData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    final cloudNotesSnap = await userRef.collection('notes').get();
    final cloudNotes = cloudNotesSnap.docs
        .map((d) => Note.fromJson(d.data()))
        .toList();

    final cloudInsightsSnap = await userRef.collection('insights').get();
    final cloudInsights = cloudInsightsSnap.docs
        .map((d) => InsightEdition.fromJson(d.data()))
        .toList();

    final cloudTasksSnap = await userRef.collection('tasks').get();
    final cloudTasks = cloudTasksSnap.docs
        .map((d) => TodoItem.fromJson(d.data()))
        .toList();

    final cloudRemindersSnap = await userRef.collection('reminders').get();
    final cloudReminders = cloudRemindersSnap.docs
        .map((d) => ReminderItem.fromJson(d.data()))
        .toList();

    final cloudScansSnap = await userRef.collection('scans').get();
    final cloudScans = cloudScansSnap.docs
        .map((d) => Scan.fromJson(d.data()))
        .toList();

    await _storage.saveNotes(cloudNotes);
    await _storage.saveInsightEditions(cloudInsights);
    await _storage.saveTasks(cloudTasks);
    await _storage.saveReminders(cloudReminders);
    await _storage.saveScans(cloudScans);

    // Download missing audio files in the background
    _downloadMissingAudioForNotes(cloudNotes);
    // Download missing scan images in the background (Plus/Pro — Free has no imageUrl)
    _downloadMissingImagesForScans(cloudScans);

    // Pull API keys from fikr.one into local secure storage (Plus/Pro only)
    await _pullRemoteApiKeys();

    debugPrint(
      'Sync: Pulled cloud data. Notes: ${cloudNotes.length}, '
      'Insights: ${cloudInsights.length}, '
      'Tasks: ${cloudTasks.length}, '
      'Reminders: ${cloudReminders.length}',
    );
  }

  // ── Clear local data (account switch only) ─────────────────────────

  Future<void> _clearLocalData() async {
    debugPrint('Sync: Clearing local data for account switch.');
    await _storage.saveNotes([]);
    await _storage.saveInsightEditions([]);
    await _storage.saveTasks([]);
    await _storage.saveReminders([]);
    await _storage.saveScans([]);
  }

  // ── Refresh in-memory AppController lists ──────────────────────────

  Future<void> _refreshAppController() async {
    try {
      final appController = Get.find<AppController>();
      await appController.reloadAllData();
      // Also refresh canRecord so Pro/Plus UI updates immediately.
      await appController.refreshCanRecord();
    } catch (_) {
      // AppController may not be registered yet during startup
    }
  }

  // ── Audio download for synced notes ─────────────────────────────────

  /// Downloads audio from Firebase Storage for notes that have a cloud
  /// URL but no local file. Runs as fire-and-forget background work.
  void _downloadMissingAudioForNotes(List<Note> notes) {
    try {
      final audioSync = Get.find<AudioSyncService>();
      final jsonList = notes.map((n) => n.toJson()).toList();
      // Fire and forget — don't block the sync flow
      audioSync.downloadMissingAudio(jsonList).catchError((e) {
        debugPrint('SyncService: Background audio download error: $e');
      });
    } catch (e) {
      debugPrint('SyncService: Could not start audio download: $e');
    }
  }

  // ── Image download for synced scans ─────────────────────────────────

  /// Downloads scan images from Firebase Storage for scans that have a cloud
  /// [imageUrl] but no valid local [imagePath]. Mirrors audio download pattern.
  ///
  /// Free users never have [imageUrl] set, so this is a no-op for them.
  /// Runs as fire-and-forget background work after bidirectional merge or pull.
  void _downloadMissingImagesForScans(List<Scan> scans) {
    final toDownload = scans.where((s) {
      if (s.imageUrl == null || s.imageUrl!.isEmpty) return false;
      // Skip if local file already exists
      if (s.imagePath != null && s.imagePath!.isNotEmpty) {
        final local = File(s.imagePath!);
        if (local.existsSync()) return false;
      }
      return true;
    }).toList();

    if (toDownload.isEmpty) return;

    debugPrint('SyncService: Downloading images for ${toDownload.length} scans...');

    for (final scan in toDownload) {
      _downloadScanImage(scan).catchError((e) {
        debugPrint('SyncService: Failed to download image for scan ${scan.id}: $e');
      });
    }
  }

  /// Downloads a single scan image from its [imageUrl] and saves it locally.
  /// Updates the [Scan] record in local storage with the new [imagePath].
  Future<void> _downloadScanImage(Scan scan) async {
    try {
      final url = scan.imageUrl!;
      final ext = url.contains('.png') ? 'png' : 'jpg';

      // Derive a stable local path from the scan id
      final localPath = '${_storage.audioDirPath}/scan_${scan.id}.$ext';
      final localFile = File(localPath);
      if (localFile.existsSync()) return; // already downloaded

      final httpClient = HttpClient();
      final req = await httpClient.getUrl(Uri.parse(url));
      final response = await req.close();
      if (response.statusCode != 200) return;

      final bytes = await response.fold<List<int>>(
        [],
        (acc, chunk) => acc..addAll(chunk),
      );
      await localFile.writeAsBytes(bytes);
      debugPrint('[SyncService] Downloaded scan image: $localPath (${bytes.length} bytes)');

      // Update the scan's imagePath in local storage
      final localScans = await _storage.loadScans();
      final updated = scan.copyWith(imagePath: localPath, updatedAt: DateTime.now());
      final updatedScans = localScans.map((s) => s.id == scan.id ? updated : s).toList();
      await _storage.saveScans(updatedScans);
    } catch (e) {
      debugPrint('[SyncService] _downloadScanImage error: $e');
    }
  }


  // ── Merge helpers ──────────────────────────────────────────────────

  /// Returns true for notes that were leaked by the old Fikr Studio
  /// Two-Way Sync or its error-catch blocks. These should never appear
  /// in the personal Fikr notes collection.
  static bool _isGarbageNote(Note note) {
    const patterns = [
      'executeMcp error:',
      'Failed to updateDoc!',
      'Failed to updateDoc notification!',
    ];
    final t = note.text.trimLeft();
    final tr = note.transcript.trimLeft();
    return patterns.any((p) => t.startsWith(p) || tr.startsWith(p));
  }

  List<Note> _mergeNotes(List<Note> local, List<Note> cloud) {
    final Map<String, Note> merged = {};
    for (final note in local) {
      if (_isGarbageNote(note)) continue; // drop Studio pollution from local
      merged[note.id] = note;
    }
    for (final cloudNote in cloud) {
      if (_isGarbageNote(cloudNote)) continue; // drop Studio pollution from cloud
      final existing = merged[cloudNote.id];
      if (existing == null || cloudNote.updatedAt.isAfter(existing.updatedAt)) {
        merged[cloudNote.id] = cloudNote;
      }
    }
    return merged.values.toList();
  }

  List<InsightEdition> _mergeInsights(
    List<InsightEdition> local,
    List<InsightEdition> cloud,
  ) {
    final Map<String, InsightEdition> merged = {};
    for (final edition in local) {
      merged[edition.id] = edition;
    }
    for (final cloudEdition in cloud) {
      if (!merged.containsKey(cloudEdition.id)) {
        merged[cloudEdition.id] = cloudEdition;
      }
    }
    return merged.values.toList();
  }

  List<TodoItem> _mergeTasks(List<TodoItem> local, List<TodoItem> cloud) {
    final Map<String, TodoItem> merged = {};
    for (final task in local) {
      merged[task.id] = task;
    }
    for (final cloudTask in cloud) {
      final existing = merged[cloudTask.id];
      if (existing == null || cloudTask.createdAt.isAfter(existing.createdAt)) {
        merged[cloudTask.id] = cloudTask;
      }
    }
    return merged.values.toList();
  }

  List<ReminderItem> _mergeReminders(
    List<ReminderItem> local,
    List<ReminderItem> cloud,
  ) {
    final Map<String, ReminderItem> merged = {};
    for (final reminder in local) {
      merged[reminder.id] = reminder;
    }
    for (final cloudReminder in cloud) {
      if (!merged.containsKey(cloudReminder.id)) {
        merged[cloudReminder.id] = cloudReminder;
      }
    }
    return merged.values.toList();
  }

  List<Scan> _mergeScans(
    List<Scan> local,
    List<Scan> cloud,
  ) {
    final Map<String, Scan> merged = {};
    for (final scan in local) {
      merged[scan.id] = scan;
    }
    for (final cloudScan in cloud) {
      final existing = merged[cloudScan.id];
      if (existing == null || cloudScan.updatedAt.isAfter(existing.updatedAt)) {
        merged[cloudScan.id] = cloudScan;
      }
    }
    return merged.values.toList();
  }

  // ── Public: push to cloud ──────────────────────────────────────────

  /// Delete a specific note from Firestore so it won't come back on sync.
  Future<void> deleteNoteFromCloud(String noteId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .doc(noteId)
          .delete();
      debugPrint('Sync: Deleted note $noteId from cloud.');
    } catch (e) {
      debugPrint('Sync: Error deleting note from cloud: $e');
    }
  }

  Future<void> syncToCloud() async {
    debugPrint('SyncToCloud: START');
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('SyncToCloud: No user logged in.');
        return;
      }

      debugPrint('SyncToCloud: Pushing data for ${user.uid}');

      final subController = Get.find<SubscriptionController>();
      debugPrint('SyncToCloud: tier=${subController.currentTier.value.name}, canSync=${subController.canSync}');
      if (!subController.canSync) {
        debugPrint('SyncToCloud: Tier does not support sync — aborting.');
        syncError.value = 'Sync unavailable on current plan (${subController.currentTier.value.name}). Ensure you are logged in as Pro.';
        return;
      }

      final notes     = await _storage.loadNotes();
      final insights  = await _storage.loadInsightEditions();
      final tasks     = await _storage.loadTasks();
      final reminders = await _storage.loadReminders();
      final scans     = await _storage.loadScans();
      final config    = await _storage.loadConfig();
      debugPrint(
        'SyncToCloud: Loaded — '
        'notes=${notes.length}, insights=${insights.length}, '
        'tasks=${tasks.length}, reminders=${reminders.length}, '
        'scans=${scans.length}. Total writes estimate: '
        '${notes.length + insights.length + tasks.length + reminders.length + scans.length + 1}',
      );

      final userRef = _firestore.collection('users').doc(user.uid);

      // Firestore hard-caps a WriteBatch at 500 operations.
      // _ChunkedBatch auto-flushes every 400 writes to stay safely under the limit
      // and avoid INVALID_ARGUMENT errors on large datasets.
      final writer = _ChunkedBatch(_firestore);

      // Notes — sanitize all string fields to prevent Firestore
      // "string contains invalid characters" errors from null bytes in transcripts.
      // Also skip any Studio error-message notes that leaked into local storage.
      for (final note in notes) {
        if (note.isProcessing) continue;
        if (note.id.isEmpty) {
          debugPrint('SyncToCloud: Skipping note with empty id (corrupt record)');
          continue;
        }
        if (_isGarbageNote(note)) {
          debugPrint('SyncToCloud: Skipping garbage note ${note.id}');
          continue;
        }
        writer.set(
          userRef.collection('notes').doc(note.id),
          _sanitizeMap(note.toJson()),
        );
      }

      // Insights
      for (final edition in insights) {
        if (edition.id.isEmpty) {
          debugPrint('SyncToCloud: Skipping insight with empty id (corrupt record)');
          continue;
        }
        writer.set(
          userRef.collection('insights').doc(edition.id),
          _sanitizeMap(edition.toJson()),
        );
      }

      // Tasks
      for (final task in tasks) {
        if (task.id.isEmpty) {
          debugPrint('SyncToCloud: Skipping task with empty id (corrupt record)');
          continue;
        }
        writer.set(
          userRef.collection('tasks').doc(task.id),
          _sanitizeMap(task.toJson()),
        );
      }

      // Reminders
      for (final reminder in reminders) {
        if (reminder.id.isEmpty) {
          debugPrint('SyncToCloud: Skipping reminder with empty id (corrupt record)');
          continue;
        }
        writer.set(
          userRef.collection('reminders').doc(reminder.id),
          _sanitizeMap(reminder.toJson()),
        );
      }

      // Scans
      for (final scan in scans) {
        if (scan.id.isEmpty) {
          debugPrint('SyncToCloud: Skipping scan with empty id (corrupt record)');
          continue;
        }
        writer.set(
          userRef.collection('scans').doc(scan.id),
          _sanitizeMap(scan.toJson()),
        );
      }

      // User root document — only safe fields; 'plan' is owned by fikr.one Admin SDK
      writer.setRaw(userRef, {
        'email': user.email,
        'config': config.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await writer.commit();

      debugPrint(
        'SyncToCloud: Committed ${writer.totalWrites} writes '
        'across ${writer.totalBatches} batch(es). '
        'Notes: ${notes.length}, Insights: ${insights.length}, '
        'Tasks: ${tasks.length}, Reminders: ${reminders.length}',
      );

      // Push API keys to fikr.one (Plus/Pro — server enforces plan)
      await _pushLocalApiKeys(config);

      // Persist this user ID as the last synced account
      await _prefs.write(key: _kLastSyncedUserKey, value: user.uid);

      lastSyncTime.value = DateTime.now();
      syncError.value = '';
    } catch (e, st) {
      // Log the FULL error and stack so it appears in Xcode/device console.
      // This is the only way to diagnose failures in the production binary.
      debugPrint('═══════════════════════════════════════');
      debugPrint('SyncToCloud FAILED');
      debugPrint('Error type : ${e.runtimeType}');
      debugPrint('Error      : $e');
      debugPrint('Stack      : $st');
      debugPrint('═══════════════════════════════════════');
      syncError.value = '${e.runtimeType}: $e';
      if (Get.context != null) {
        ToastService.showError(
          Get.context!,
          title: 'Sync Failed',
          description: e.toString().length > 80
              ? '${e.toString().substring(0, 80)}…'
              : e.toString(),
        );
      }
    }
  }


  // ── API Key sync helpers ────────────────────────────────────────────

  /// Reads all provider API keys from secure storage and pushes them to
  /// fikr.one via [FikrApiService.pushApiKeys]. Fires-and-forgets errors
  /// (a key sync failure must never block the main data sync).
  Future<void> _pushLocalApiKeys(dynamic config) async {
    try {
      final loadedConfig = await _storage.loadConfig();
      final provider = loadedConfig.activeProvider;
      if (provider == null) return;

      final apiKey = await _storage.getApiKey(provider.id);
      if (apiKey == null || apiKey.isEmpty) return;

      await FikrApiService().pushApiKeys([
        {
          'id': provider.id,
          'name': provider.name,
          'type': provider.type.name,
          'apiKey': apiKey,
        },
      ]);
    } catch (e) {
      debugPrint('SyncService._pushLocalApiKeys: $e');
    }
  }

  /// Pulls API keys from fikr.one and writes them into local secure storage.
  /// If the local config has no active provider, it also restores the full
  /// provider config (type, name, baseUrl) so the app is immediately usable.
  Future<void> _pullRemoteApiKeys() async {
    try {
      final remoteKeys = await FikrApiService().pullApiKeys();
      if (remoteKeys.isEmpty) {
        debugPrint('SyncService._pullRemoteApiKeys: No remote keys found.');
        return;
      }

      // Always save remote keys to secure storage.
      // Remote is authoritative for keys set/updated via fikr.one web.
      for (final entry in remoteKeys) {
        final id = entry['id'] ?? '';
        final key = entry['apiKey'] ?? '';
        if (id.isNotEmpty && key.isNotEmpty) {
          await _storage.saveApiKey(id, key);
          debugPrint('SyncService._pullRemoteApiKeys: Stored key for provider $id');
        }
      }

      // If no activeProvider is configured locally, reconstruct it from the
      // first remote entry so the app can use AI immediately.
      final config = await _storage.loadConfig();
      if (config.activeProvider == null && remoteKeys.isNotEmpty) {
        final first = remoteKeys.first;
        final typeStr = first['type'] ?? 'openai';
        final providerType = LLMProviderType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => LLMProviderType.openai,
        );
        final provider = LLMProvider(
          id: first['id'] ?? '$typeStr-restored',
          name: first['name']?.isNotEmpty == true
              ? first['name']!
              : providerType.displayName,
          type: providerType,
          baseUrl: providerType.defaultBaseUrl,
        );
        // Models come from Remote Config now — no need to set them here.
        // The app will read them dynamically from FirebaseService.getByokModels().
        final updatedConfig = config.copyWith(
          activeProvider: provider,
        );
        await _storage.saveConfig(updatedConfig);
        debugPrint(
          'SyncService._pullRemoteApiKeys: Restored provider config '
          '"${provider.name}" (${provider.type.name}).',
        );

        // Refresh the in-memory app state so the UI reflects the new provider
        await _refreshAppController();
      }
    } catch (e) {
      debugPrint('SyncService._pullRemoteApiKeys: $e');
    }
  }

  // ── Legacy public accessor (used by auth_screen, settings, etc.) ───

  /// Kept for backward compatibility with screens that call syncFromCloud.
  Future<void> syncFromCloud() async {
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      await _handleLogin(user);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChunkedBatch — Firestore batch writer that auto-flushes at 400 ops
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps Firestore batched writes and auto-commits every [_maxPerBatch]
/// operations so callers never hit the Firestore 500-op hard limit.
///
/// Usage:
///   final writer = _ChunkedBatch(firestore);
///   writer.set(ref, data);           // subcollection docs (merge: true)
///   writer.setRaw(userRef, topData); // root user doc (merge: true, no sanitize)
///   await writer.commit();           // flushes any remaining writes
class _ChunkedBatch {
  _ChunkedBatch(this._firestore);

  final FirebaseFirestore _firestore;

  static const int _maxPerBatch = 400;

  WriteBatch _current = FirebaseFirestore.instance.batch();
  int _currentCount   = 0;
  int _totalWrites    = 0;
  int _totalBatches   = 0;

  int get totalWrites  => _totalWrites;
  int get totalBatches => _totalBatches;

  /// Queues a merge-set for a subcollection document.
  void set(DocumentReference ref, Map<String, dynamic> data) {
    _current.set(ref, data, SetOptions(merge: true));
    _currentCount++;
    _totalWrites++;
    if (_currentCount >= _maxPerBatch) {
      _pendingBatches.add(_current);
      _current      = _firestore.batch();
      _currentCount = 0;
    }
  }

  /// Queues a merge-set for the root user document (no JSON sanitization).
  void setRaw(DocumentReference ref, Map<String, dynamic> data) {
    _current.set(ref, data, SetOptions(merge: true));
    _currentCount++;
    _totalWrites++;
    if (_currentCount >= _maxPerBatch) {
      _pendingBatches.add(_current);
      _current      = _firestore.batch();
      _currentCount = 0;
    }
  }

  final List<WriteBatch> _pendingBatches = [];

  /// Commits all queued batches sequentially.
  Future<void> commit() async {
    // Add the last partial batch if it has any writes
    if (_currentCount > 0) {
      _pendingBatches.add(_current);
    }
    _totalBatches = _pendingBatches.length;
    for (final batch in _pendingBatches) {
      await batch.commit();
    }
    _pendingBatches.clear();
  }
}
