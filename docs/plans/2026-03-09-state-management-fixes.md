# State Management Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all 37 state management gaps so every user action (API key save, theme change, subscription update, sync, config change) propagates immediately through reactive state across the entire app.

**Architecture:** Surgical in-place fixes using existing GetX patterns — add missing `.refresh()` calls, await un-awaited futures, wire up missing listeners, expose missing Rx fields, and complete incomplete state resets. No architectural changes.

**Tech Stack:** Flutter, Dart, GetX (reactive state), Firebase/Firestore, flutter_secure_storage

---

## Task 1: SubscriptionController — tier never updates after auth

**Files:**
- Modify: `lib/controllers/subscription_controller.dart`
- Modify: `lib/services/firebase_service.dart`

Currently `currentTier` is initialised to `free.obs` and never changed. The FirebaseService exposes a `currentUser` Rx stream but nothing listens to it and updates the tier.

**Step 1: Read both files to understand current state**

Read `lib/controllers/subscription_controller.dart` and `lib/services/firebase_service.dart` fully.

**Step 2: Add tier-refresh logic to SubscriptionController**

In `subscription_controller.dart`, add an `onInit` override that listens to `FirebaseService.currentUser` and calls a new `_refreshTier()` method:

```dart
final _firebase = Get.find<FirebaseService>();

@override
void onInit() {
  super.onInit();
  ever(_firebase.currentUser, (_) => _refreshTier());
  _refreshTier();
}

Future<void> _refreshTier() async {
  final user = _firebase.currentUser.value;
  if (user == null) {
    currentTier.value = SubscriptionTier.free;
    return;
  }
  // Read claims or Firestore profile to determine tier
  final tier = await _firebase.getUserSubscriptionTier(user.uid);
  currentTier.value = tier;
}
```

**Step 3: Add `getUserSubscriptionTier` to FirebaseService**

In `firebase_service.dart`, add:

```dart
Future<SubscriptionTier> getUserSubscriptionTier(String uid) async {
  try {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return SubscriptionTier.free;
    final data = doc.data();
    final tierStr = data?['subscriptionTier'] as String?;
    return SubscriptionTier.values.firstWhere(
      (t) => t.name == tierStr,
      orElse: () => SubscriptionTier.free,
    );
  } catch (e) {
    debugPrint('Error fetching subscription tier: $e');
    return SubscriptionTier.free;
  }
}
```

**Step 4: Also listen for Firestore real-time tier changes**

In `subscription_controller.dart` `onInit`, after `ever(...)`, also set up a Firestore subscription stream so the tier updates live:

```dart
StreamSubscription? _tierSub;

void _listenToTierChanges(String uid) {
  _tierSub?.cancel();
  _tierSub = _firebase.userTierStream(uid).listen((tier) {
    currentTier.value = tier;
  });
}

@override
void onClose() {
  _tierSub?.cancel();
  super.onClose();
}
```

Add `userTierStream` to FirebaseService:

```dart
Stream<SubscriptionTier> userTierStream(String uid) {
  return _firestore.collection('users').doc(uid).snapshots().map((snap) {
    if (!snap.exists) return SubscriptionTier.free;
    final tierStr = snap.data()?['subscriptionTier'] as String?;
    return SubscriptionTier.values.firstWhere(
      (t) => t.name == tierStr,
      orElse: () => SubscriptionTier.free,
    );
  });
}
```

**Step 5: Handle SyncService subscription listener errors**

In `lib/services/sync_service.dart`, find the `ever(subController.currentTier, ...)` call and wrap it:

```dart
ever(subController.currentTier, (tier) async {
  try {
    if (subController.canSync) {
      await _startSync();
    } else {
      await stopSync();
    }
  } catch (e) {
    debugPrint('SyncService: tier change handler error: $e');
  }
});
```

**Step 6: Verify**

Run the app. Log in with a Pro account. Confirm `currentTier` is no longer stuck at `free`. Confirm sync starts automatically.

**Step 7: Commit**

```bash
git add lib/controllers/subscription_controller.dart lib/services/firebase_service.dart lib/services/sync_service.dart
git commit -m "fix: wire SubscriptionController to live Firestore tier updates"
```

---

## Task 2: SyncService — make _refreshAppController async and fix account switch sequencing

**Files:**
- Modify: `lib/services/sync_service.dart`

`_refreshAppController()` uses fire-and-forget `.then()` chains. The account switch also doesn't sequence the clear → pull operations.

**Step 1: Read sync_service.dart fully**

**Step 2: Convert _refreshAppController to async/await**

Find `_refreshAppController()` and rewrite it:

```dart
Future<void> _refreshAppController() async {
  final appController = Get.find<AppController>();
  await appController.loadNotes();
  await appController.loadInsightEditions();
  await appController.loadTasks();
  await appController.loadReminders();
}
```

Note: this requires that `loadNotes()`, `loadInsightEditions()`, `loadTasks()`, `loadReminders()` are public methods on `AppController`. Confirm they exist (they may be named `_loadNotes` etc.). If private, make them public or add public wrappers:

```dart
// In AppController
Future<void> reloadAllData() async {
  await _loadNotes();
  await _loadInsightEditions();
  await _loadTasks();
  await _loadReminders();
}
```

Then in sync_service.dart:
```dart
Future<void> _refreshAppController() async {
  final appController = Get.find<AppController>();
  await appController.reloadAllData();
}
```

**Step 3: Fix account switch to be sequential**

Find the account switch handler (where `_clearLocalData()` is called followed by `_pullCloudData()`). Make it sequential:

```dart
Future<void> _handleAccountSwitch() async {
  await _clearLocalData();
  await _refreshAppController(); // UI shows empty state
  await _pullCloudData();
  await _refreshAppController(); // UI shows cloud data
}
```

**Step 4: Verify**

Run app. Switch accounts. Confirm the UI clears before new data loads (no flash of stale data).

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart lib/controllers/app_controller.dart
git commit -m "fix: make SyncService refresh sequential with proper async/await"
```

---

## Task 3: SyncService — expose isSyncing, lastSyncTime, syncError as Rx fields

**Files:**
- Modify: `lib/services/sync_service.dart`
- Modify: `lib/screens/shells/mobile_shell.dart`
- Modify: `lib/screens/shells/desktop_shell.dart`

Currently `isSyncing` is a plain `bool`. `lastSyncTime` and `syncError` don't exist.

**Step 1: Add reactive fields to SyncService**

```dart
final RxBool isSyncing = false.obs;
final Rx<DateTime?> lastSyncTime = Rx<DateTime?>(null);
final RxString syncError = ''.obs;
```

Remove the old `bool isSyncing = false;` declaration.

**Step 2: Update all assignments**

Replace all `isSyncing = true/false` with `isSyncing.value = true/false`.

On successful sync completion, set:
```dart
lastSyncTime.value = DateTime.now();
syncError.value = '';
```

On sync error, set:
```dart
syncError.value = e.toString();
```

**Step 3: Update shells to show sync status**

In `mobile_shell.dart` and `desktop_shell.dart`, wrap any sync indicator in `Obx()` and use `syncService.isSyncing.value`, `syncService.lastSyncTime.value`, `syncService.syncError.value`.

If no sync indicator currently exists, this task is complete at Step 2.

**Step 4: Update selectedNote after sync refresh**

In `_refreshAppController()` (now properly async from Task 2), add:

```dart
Future<void> _refreshAppController() async {
  final appController = Get.find<AppController>();
  await appController.reloadAllData();
  // If a note is currently selected, refresh it from the updated list
  final selected = appController.selectedNote.value;
  if (selected != null) {
    final refreshed = appController.notes.firstWhereOrNull((n) => n.id == selected.id);
    if (refreshed != null) {
      appController.selectedNote.value = refreshed;
    } else {
      // Note was deleted remotely
      appController.selectedNote.value = null;
    }
  }
}
```

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart lib/screens/shells/mobile_shell.dart lib/screens/shells/desktop_shell.dart
git commit -m "fix: expose isSyncing/lastSyncTime/syncError as Rx, refresh selectedNote after sync"
```

---

## Task 4: Desktop settings — persist theme to config

**Files:**
- Modify: `lib/screens/settings/desktop_settings.dart`

Desktop settings calls `themeController.setThemeMode(mode)` but never calls `controller.updateConfig(...)`. Theme resets on restart.

**Step 1: Read desktop_settings.dart**

**Step 2: Find the theme toggle/selector callback**

Find where `setThemeMode` is called (around line 53-54). Change it from:

```dart
themeController.setThemeMode(mode);
```

To:

```dart
themeController.setThemeMode(mode);
await controller.updateConfig(
  controller.config.value.copyWith(themeMode: mode.name),
);
```

Make the callback `async` if it isn't already.

**Step 3: Verify**

Change theme on desktop, restart the app, confirm the theme is preserved.

**Step 4: Commit**

```bash
git add lib/screens/settings/desktop_settings.dart
git commit -m "fix: persist theme selection to config in desktop settings"
```

---

## Task 5: Mobile settings — await async config update

**Files:**
- Modify: `lib/screens/settings/mobile_settings.dart`

The `onSelectionChanged` callback calls `controller.updateConfig(...)` which returns a Future, but the callback doesn't await it. On slow devices this can cause a race.

**Step 1: Read mobile_settings.dart lines 35-55**

**Step 2: Make the callback async**

Find the theme selection callback and make it properly async:

```dart
onSelectionChanged: (modes) async {
  if (modes.isEmpty) return;
  final mode = modes.first;
  themeController.setThemeMode(mode);
  await controller.updateConfig(
    controller.config.value.copyWith(themeMode: mode.name),
  );
},
```

**Step 3: Commit**

```bash
git add lib/screens/settings/mobile_settings.dart
git commit -m "fix: await config update in mobile theme selection"
```

---

## Task 6: ProviderDetailScreen — validate after type change, update canRecord before close

**Files:**
- Modify: `lib/screens/settings/provider_detail_screen.dart`

Two issues: (1) `_validate()` not called after `_selectedType` changes so the save button state is stale; (2) `canRecord` not refreshed before the screen closes after saving.

**Step 1: Read provider_detail_screen.dart fully**

**Step 2: Call _validate() after type change**

Find where `_selectedType` is updated (around line 250). After the `setState(() { _selectedType = newType; })`, add a call to `_validate()`:

```dart
setState(() {
  _selectedType = newType;
});
_validate(); // re-check whether current key is valid for new type
```

**Step 3: Clear API key field on type change**

Optionally clear the key controller text to prevent cross-provider key confusion:

```dart
setState(() {
  _selectedType = newType;
  _apiKeyController.clear();
});
_validate();
```

**Step 4: Ensure canRecord refreshes after save**

Find the save flow (around line 118-143). Ensure `controller.refreshCanRecord()` is called and awaited AFTER `updateConfig`:

```dart
await storageService.saveApiKey(provider.id, _apiKeyController.text.trim());
await controller.updateConfig(newConfig);
await controller.refreshCanRecord(); // explicit, sequential
Navigator.of(context).pop(true);
```

**Step 5: Commit**

```bash
git add lib/screens/settings/provider_detail_screen.dart
git commit -m "fix: revalidate on type change and refresh canRecord before closing provider screen"
```

---

## Task 7: ProviderSetupDialog — fix API key race condition

**Files:**
- Modify: `lib/screens/settings/widgets/provider_setup_dialog.dart`

The save order is: `saveApiKey` → `updateConfig`. But `updateConfig` calls `refreshCanRecord()` which reads the key, and there may be a timing issue if `saveApiKey` hasn't flushed to secure storage yet.

**Step 1: Read provider_setup_dialog.dart lines 125-160**

**Step 2: Ensure sequential execution with explicit await**

Find the save flow and make it strictly sequential:

```dart
// 1. Save key first and await flush
await storageService.saveApiKey(provider.id, _apiKeyController.text.trim());
// 2. Update config
await controller.updateConfig(newConfig);
// 3. Explicitly refresh canRecord after both complete
await controller.refreshCanRecord();
```

Confirm all three calls are awaited in sequence. If the callback is not async, make it async.

**Step 3: Commit**

```bash
git add lib/screens/settings/widgets/provider_setup_dialog.dart
git commit -m "fix: ensure sequential API key save → config update → canRecord refresh"
```

---

## Task 8: AppController — fix clearAll() to reset all reactive state

**Files:**
- Modify: `lib/controllers/app_controller.dart`

`clearAll()` clears notes and storage but leaves `selectedNote`, `selectedBucket`, `searchQuery`, `insightEditions`, `todoItems`, `reminders` with stale values.

**Step 1: Read clearAll() in app_controller.dart**

**Step 2: Add complete state reset**

```dart
Future<void> clearAll() async {
  await storageService.clearAll();
  notes.clear();
  insightEditions.clear();
  todoItems.clear();
  reminders.clear();
  selectedNote.value = null;
  selectedBucket.value = 'All';
  searchQuery.value = '';
  errorMessage.value = '';
  loading.value = false;
}
```

Add any other Rx fields that have non-null/non-default values that should be cleared.

**Step 3: Commit**

```bash
git add lib/controllers/app_controller.dart
git commit -m "fix: clearAll() resets all reactive state fields"
```

---

## Task 9: AppController — fix loading state not cleared on early returns

**Files:**
- Modify: `lib/controllers/app_controller.dart`

In `addNoteFromAudio()`, some early return paths exit without setting `loading.value = false`.

**Step 1: Read addNoteFromAudio() in app_controller.dart (lines 240-340)**

**Step 2: Identify every early return and guard clause**

Look for all `return;` statements inside `addNoteFromAudio()`. Each one that executes while `loading.value` might be `true` needs a reset before returning.

Pattern to apply:
```dart
if (someCondition) {
  loading.value = false;
  return;
}
```

**Step 3: Alternatively wrap body in try/finally**

If there are many early returns, the cleanest fix is:

```dart
Future<void> addNoteFromAudio(...) async {
  loading.value = true;
  try {
    // ... all existing logic including early returns can stay
  } finally {
    loading.value = false;
  }
}
```

This guarantees `loading` is always cleared regardless of path. Prefer this approach.

**Step 4: Commit**

```bash
git add lib/controllers/app_controller.dart
git commit -m "fix: ensure loading state cleared on all exit paths in addNoteFromAudio"
```

---

## Task 10: AppController — await task and reminder saves

**Files:**
- Modify: `lib/controllers/app_controller.dart`

`_mergeGeneratedTasks()` and `_mergeGeneratedReminders()` call `_saveTasks()` and `_saveReminders()` but don't await them. On app close immediately after, data may not persist.

**Step 1: Read _mergeGeneratedTasks() and _mergeGeneratedReminders()**

**Step 2: Make saves awaited**

If `_saveTasks()` returns a Future, await it:

```dart
Future<void> _mergeGeneratedTasks(List<TodoItem> newTasks) async {
  // ... existing merge logic ...
  await _saveTasks();
}

Future<void> _mergeGeneratedReminders(List<ReminderItem> newReminders) async {
  // ... existing merge logic ...
  await _saveReminders();
}
```

Ensure all callers of these methods also await them.

**Step 3: Also ensure toggleTaskComplete and dismissReminder await saves**

```dart
Future<void> toggleTaskComplete(String taskId) async {
  todoItems.value = todoItems.map((t) => t.id == taskId ? t.copyWith(isCompleted: !t.isCompleted) : t).toList();
  await _saveTasks();
}

Future<void> dismissReminder(String reminderId) async {
  reminders.value = reminders.map((r) => r.id == reminderId ? r.copyWith(isDismissed: true) : r).toList();
  await _saveReminders();
}
```

**Step 4: Commit**

```bash
git add lib/controllers/app_controller.dart
git commit -m "fix: await task and reminder saves to prevent data loss on app close"
```

---

## Task 11: AppController — add .refresh() after insights list mutation

**Files:**
- Modify: `lib/controllers/app_controller.dart`

`insightEditions.insert(0, edition)` mutates the list but may not trigger all Obx() widgets. Add explicit refresh.

**Step 1: Find captureInsightsEdition() around lines 617-723**

**Step 2: Add refresh after insert**

```dart
insightEditions.insert(0, edition);
insightEditions.refresh(); // trigger Obx() rebuild
await saveInsightEditions();
```

**Step 3: Use try/catch to prevent inconsistent state on save failure**

```dart
final tempEditions = List<InsightEdition>.from(insightEditions);
insightEditions.insert(0, edition);
insightEditions.refresh();
try {
  await saveInsightEditions();
} catch (e) {
  // Roll back in-memory state if save failed
  insightEditions.value = tempEditions;
  insightEditions.refresh();
  errorMessage.value = 'Failed to save insights: $e';
  rethrow;
}
```

**Step 4: Commit**

```bash
git add lib/controllers/app_controller.dart
git commit -m "fix: add refresh() after insights insert and rollback on save failure"
```

---

## Task 12: AppController — strengthen updateNote to force Obx rebuild

**Files:**
- Modify: `lib/controllers/app_controller.dart`

`updateNote()` does `notes[index] = updated` (in-place mutation). While GetX ObxList should detect this, add explicit refresh to guarantee rebuilds.

**Step 1: Find updateNote() around lines 460-465**

**Step 2: Add refresh after assignment**

```dart
Future<void> updateNote(Note updated) async {
  final index = notes.indexWhere((n) => n.id == updated.id);
  if (index == -1) return;
  notes[index] = updated;
  notes.refresh(); // force Obx rebuild
  // If this note is currently selected, update it
  if (selectedNote.value?.id == updated.id) {
    selectedNote.value = updated;
  }
  await saveNotes();
}
```

**Step 3: Commit**

```bash
git add lib/controllers/app_controller.dart
git commit -m "fix: add notes.refresh() in updateNote and sync selectedNote"
```

---

## Task 13: AppController — clear error message on success operations

**Files:**
- Modify: `lib/controllers/app_controller.dart`

Successful operations like `saveActiveModel()` don't clear `errorMessage.value`. Stale errors persist.

**Step 1: Find all success paths that don't clear errorMessage**

Search for places where an operation completes successfully without `errorMessage.value = ''`.

Key locations:
- `saveActiveModel()`
- `saveNotes()` on success
- `addNoteFromAudio()` on success
- `updateConfig()` — check if it clears the error

**Step 2: Add error clear on success**

Pattern to apply at the start of any mutating method:
```dart
errorMessage.value = '';
```

Or add it at the end of the successful path:
```dart
// end of successful flow
errorMessage.value = '';
```

**Step 3: Commit**

```bash
git add lib/controllers/app_controller.dart
git commit -m "fix: clear errorMessage on successful operations"
```

---

## Task 14: AppController — validate activeProvider on app resume

**Files:**
- Modify: `lib/controllers/app_controller.dart`

If the API key for the active provider was deleted externally, config still references it. Add validation on initialize and on resume.

**Step 1: Find initialize() in app_controller.dart**

**Step 2: Add provider validation after config load**

```dart
Future<void> _validateActiveProvider() async {
  final config = this.config.value;
  final provider = config.activeProvider;
  if (provider == null) return;
  final key = await storageService.getApiKey(provider.id);
  if (key == null || key.isEmpty) {
    // Key missing — update canRecord
    canRecord.value = false;
    // Optionally clear the provider reference
    // await updateConfig(config.copyWith(activeProvider: null));
  }
}
```

Call this in `initialize()` after config is loaded.

**Step 3: Also call on app resume**

Override `onResumed()` in `AppController` (GetX WidgetsBindingObserver support):

```dart
@override
void onResumed() {
  _validateActiveProvider();
}
```

If `AppController` doesn't already extend `GetxController` with lifecycle support, add `WidgetsBindingObserver`:

```dart
class AppController extends GetxController with WidgetsBindingObserver {
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validateActiveProvider();
    }
  }
}
```

**Step 4: Commit**

```bash
git add lib/controllers/app_controller.dart
git commit -m "fix: validate activeProvider API key on init and app resume"
```

---

## Task 15: AppController — ensure deleteNote resets selectedNote when deleted via cloud

**Files:**
- Modify: `lib/controllers/app_controller.dart`
- Modify: `lib/services/sync_service.dart`

`deleteNote()` checks if `selectedNote` matches, but cloud-initiated deletions bypass this check.

**Step 1: In `_refreshAppController()` / `reloadAllData()` added in Task 2, add stale selectedNote check**

This was already handled in Task 3. Confirm it's in place:

```dart
final selected = appController.selectedNote.value;
if (selected != null) {
  final stillExists = appController.notes.any((n) => n.id == selected.id);
  if (!stillExists) {
    appController.selectedNote.value = null;
  }
}
```

**Step 2: Confirm deleteNote() already handles direct deletes**

Read `deleteNote()` and confirm it sets `selectedNote.value = null` when the deleted note is selected. If not, add it.

**Step 3: Commit (if any changes needed)**

```bash
git add lib/controllers/app_controller.dart lib/services/sync_service.dart
git commit -m "fix: clear selectedNote when note is deleted via cloud sync"
```

---

## Task 16: AppController — searchQuery clear doesn't reset bucket filter

**Files:**
- Modify: `lib/controllers/app_controller.dart`

`clearSearch()` only resets `searchQuery` but not `selectedBucket`. After clearing search, user is still filtered to a specific bucket which is confusing.

**Step 1: Read clearSearch() in app_controller.dart**

**Step 2: Decide whether to also reset selectedBucket**

This is a UX decision. Two options:
- **Option A:** Reset `selectedBucket` to `'All'` in `clearSearch()` — clean slate
- **Option B:** Keep bucket filter, only clear text search — preserves user's browsing context

Based on the app's intent as a note-organizer, **Option B** is more appropriate. The search clear and bucket filter are independent controls.

If the current `clearSearch()` only resets `searchQuery`, it is **already correct**. Verify this.

If `clearSearch()` also accidentally resets `selectedBucket`, fix that.

**Step 3: Commit (only if change was needed)**

```bash
git add lib/controllers/app_controller.dart
git commit -m "fix: clarify clearSearch only resets text query, not bucket filter"
```

---

## Task 17: FirebaseService — handle stale currentUser on initialize

**Files:**
- Modify: `lib/services/firebase_service.dart`

If `initialize()` is called after the user is already logged in, there's a brief moment where `currentUser.value` is null before the stream emits.

**Step 1: Read firebase_service.dart initialize() and currentUser setup**

**Step 2: Pre-populate currentUser synchronously before binding stream**

```dart
// Set immediately from FirebaseAuth.instance.currentUser (synchronous)
currentUser.value = FirebaseAuth.instance.currentUser;

// Then bind stream for ongoing updates
currentUser.bindStream(FirebaseAuth.instance.authStateChanges());
```

The synchronous read eliminates the brief null window.

**Step 3: Commit**

```bash
git add lib/services/firebase_service.dart
git commit -m "fix: pre-populate currentUser synchronously before binding auth stream"
```

---

## Task 18: Final verification pass

**Step 1: Run the app on macOS**

```bash
flutter run -d macos
```

**Step 2: Walk through each scenario and verify reactive updates**

Checklist:
- [ ] Change API key → `canRecord` updates immediately, recording button enables/disables
- [ ] Change theme on desktop → theme persists after hot restart
- [ ] Change theme on mobile → theme persists after hot restart
- [ ] Change provider type in settings → key field clears, validation resets
- [ ] Log in with Pro account → sync indicator appears, managed AI unlocked
- [ ] Trigger cloud sync → isSyncing shows true then false, lastSyncTime updates
- [ ] Delete a note from another device → selectedNote clears if it was open
- [ ] Generate insights → list refreshes immediately without manual reload
- [ ] Toggle task complete → persists after close/reopen
- [ ] Clear all data → all state resets (no stale bucket filter, no selected note)
- [ ] Switch accounts → UI clears before new data loads

**Step 3: Run static analysis**

```bash
flutter analyze
```

Fix any warnings introduced by changes.

**Step 4: Final commit**

```bash
git add -A
git commit -m "fix: complete state management audit — all 37 gaps resolved"
```
