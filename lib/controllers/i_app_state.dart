/// Abstract interface that exposes the observable state and methods
/// that tools operate on. [AppController] implements this interface,
/// and tests can provide a lightweight fake.
///
/// Architecture rule: Tools ONLY mutate state through these interface methods.
/// No tool may reach into AppController directly or call services bypassing this.
library;

import 'package:get/get.dart';
import '../models/analysis_result.dart';
import '../models/insights_models.dart';
import '../models/note.dart';
import '../models/app_config.dart';

abstract class IAppState extends GetxController {
  // ── Observable state ──────────────────────────────────────────────────────
  Rx<AppConfig> get config;
  RxList<Note> get notes;
  RxList<TodoItem> get todoItems;
  RxList<ReminderItem> get reminders;

  // ── Persistence ──────────────────────────────────────────────────────────
  Future<void> saveNotes();
  Future<void> saveTasks();
  Future<void> saveReminders();

  // ── Note mutations ───────────────────────────────────────────────────────
  Future<void> updateNote(Note updated);
  Future<void> archiveNote(String id);
  Future<void> deleteNote(String id);

  /// Finalize a note from AI analysis result, insert into state, and persist.
  ///
  /// This is the canonical path for note creation after the AI pipeline.
  /// Called by the [notes.finalize] tool.
  Future<Note> finalizeNote({
    required String id,
    required DateTime createdAt,
    required String audioPath,
    required String transcript,
    required AnalysisResult analysis,
    String transcriptStyle,
  });

  /// Create an empty draft note and insert it at the top of the list.
  Future<Note> createEmptyNote();

  // ── Task mutations ───────────────────────────────────────────────────────
  Future<void> toggleTaskComplete(String id);
  Future<void> deleteTask(String id);
  Future<void> deleteCompletedTasks();

  // ── Export ───────────────────────────────────────────────────────────────
  Future<String?> exportAll(String dir);

  // ── Audio ─────────────────────────────────────────────────────────────────
  Future<void> playAudio(Note note);

  // ── Audio URL update after upload ─────────────────────────────────────────
  Future<void> updateNoteAudioUrl(String noteId, String audioUrl);

  // ── Config ───────────────────────────────────────────────────────────────
  Future<void> updateConfig(AppConfig updatedConfig);

  // ── Sync ─────────────────────────────────────────────────────────────────
  Future<void> reloadAllData();
}
