# ADR 002 — IAppState Interface Contract

**Date:** 2026-05-04
**Status:** Accepted
**Scope:** `fikr/` Flutter app

---

## Context

Tools need to mutate reactive app state (notes, tasks, reminders) but must not be coupled to the concrete `AppController` implementation. Direct `Get.find<AppController>()` calls in tools would create a hard dependency, making tool unit tests require a full controller setup.

---

## Decision

All tools that need to mutate or read reactive state use `Get.find<IAppState>()` — the abstract interface — never `Get.find<AppController>()` directly.

`AppController` implements `IAppState`. In tests, `_FakeAppState` implements it without Firebase or AudioPlayer.

```dart
abstract class IAppState extends GetxController {
  RxList<Note> get notes;
  RxList<TodoItem> get todoItems;
  RxList<ReminderItem> get reminders;

  Future<void> saveNotes();
  Future<void> saveTasks();
  Future<void> saveReminders();
  Future<void> updateNote(Note updated);
  Future<void> archiveNote(String id);
  Future<void> deleteNote(String id);
  Future<void> toggleTaskComplete(String id);
  Future<void> deleteTask(String id);
  Future<void> deleteCompletedTasks();
  Future<void> dismissReminder(String id);
  Future<Note> finalizeNote({...});
  Future<Note> createEmptyNote();
  Future<void> playAudio(Note note);
  Future<void> updateNoteAudioUrl(String noteId, String audioUrl);
  Future<String?> exportAll(String dir);
}
```

---

## Consequences

**Positive:**
- Tool unit tests use `_FakeAppState` — no Firebase, AudioPlayer, or GetX bootstrap needed
- `AppController` can be refactored without changing any tool code
- Tools are substitutable in different host environments

**Negative:**
- Any new capability that a tool needs to expose must be added to the `IAppState` interface first — minor overhead
- Interface can drift from `AppController` if not kept in sync

**Testing rule:** Use `ToolRegistry.forTesting()` and inject `_FakeAppState`. Minimum test cases per tool: success path, failure/unknown-id path, tier gate (if applicable), archived-note exclusion.
