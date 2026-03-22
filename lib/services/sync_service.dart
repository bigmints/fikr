import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../models/note.dart';
import '../models/insights_models.dart';
import '../controllers/app_controller.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import '../services/firebase_service.dart';
import '../controllers/subscription_controller.dart';

/// Key used to persist the last-synced user ID so we can detect
/// same-account re-login vs account switches.
const _kLastSyncedUserKey = 'last_synced_user_id';

class SyncService extends GetxService {
  final StorageService _storage = Get.find<StorageService>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _prefs = const FlutterSecureStorage();

  final RxBool isSyncEnabled = false.obs;
  final RxBool isSyncing = false.obs;
  final Rx<DateTime?> lastSyncTime = Rx<DateTime?>(null);
  final RxString syncError = ''.obs;

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

    // React to plan changes (re-push user record)
    final subController = Get.find<SubscriptionController>();
    ever(subController.currentTier, (tier) async {
      try {
        debugPrint('Sync: Plan changed → ${tier.name}');
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
      debugPrint('Sync: Already in progress, skipping.');
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

    // Load local data
    final localNotes = await _storage.loadNotes();
    final localInsights = await _storage.loadInsightEditions();
    final localTasks = await _storage.loadTasks();
    final localReminders = await _storage.loadReminders();

    // Merge (newer wins)
    final mergedNotes = _mergeNotes(localNotes, cloudNotes);
    final mergedInsights = _mergeInsights(localInsights, cloudInsights);
    final mergedTasks = _mergeTasks(localTasks, cloudTasks);
    final mergedReminders = _mergeReminders(localReminders, cloudReminders);

    // Save merged locally
    await _storage.saveNotes(mergedNotes);
    await _storage.saveInsightEditions(mergedInsights);
    await _storage.saveTasks(mergedTasks);
    await _storage.saveReminders(mergedReminders);

    // Push merged to cloud
    await syncToCloud();

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

    await _storage.saveNotes(cloudNotes);
    await _storage.saveInsightEditions(cloudInsights);
    await _storage.saveTasks(cloudTasks);
    await _storage.saveReminders(cloudReminders);

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
  }

  // ── Refresh in-memory AppController lists ──────────────────────────

  Future<void> _refreshAppController() async {
    try {
      final appController = Get.find<AppController>();
      await appController.reloadAllData();
    } catch (_) {
      // AppController may not be registered yet during startup
    }
  }

  // ── Merge helpers ──────────────────────────────────────────────────

  List<Note> _mergeNotes(List<Note> local, List<Note> cloud) {
    final Map<String, Note> merged = {};
    for (final note in local) {
      merged[note.id] = note;
    }
    for (final cloudNote in cloud) {
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
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('SyncToCloud: No user logged in.');
        return;
      }

      debugPrint('SyncToCloud: Pushing data for ${user.uid}');

      final subController = Get.find<SubscriptionController>();
      if (!subController.canSync) {
        debugPrint('SyncToCloud: Current tier does not support sync.');
        return;
      }

      final notes = await _storage.loadNotes();
      final insights = await _storage.loadInsightEditions();
      final tasks = await _storage.loadTasks();
      final reminders = await _storage.loadReminders();
      final config = await _storage.loadConfig();

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(user.uid);

      // Notes
      for (final note in notes) {
        batch.set(
          userRef.collection('notes').doc(note.id),
          note.toJson(),
          SetOptions(merge: true),
        );
      }

      // Insights
      for (final edition in insights) {
        batch.set(
          userRef.collection('insights').doc(edition.id),
          edition.toJson(),
          SetOptions(merge: true),
        );
      }

      // Tasks
      for (final task in tasks) {
        batch.set(
          userRef.collection('tasks').doc(task.id),
          task.toJson(),
          SetOptions(merge: true),
        );
      }

      // Reminders
      for (final reminder in reminders) {
        batch.set(
          userRef.collection('reminders').doc(reminder.id),
          reminder.toJson(),
          SetOptions(merge: true),
        );
      }

      // User document — only write safe fields; 'plan' is owned by fikr.one backend
      batch.set(userRef, {
        'email': user.email,
        'config': config.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      // Persist this user ID as the last synced account
      await _prefs.write(key: _kLastSyncedUserKey, value: user.uid);

      lastSyncTime.value = DateTime.now();
      syncError.value = '';
      debugPrint('SyncToCloud: Complete.');
    } catch (e) {
      debugPrint('SyncToCloud Error: $e');
      syncError.value = e.toString();
      if (Get.context != null) {
        ToastService.showError(
          Get.context!,
          title: 'Sync Failed',
          description: 'Could not backup data. Please try again.',
        );
      }
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
