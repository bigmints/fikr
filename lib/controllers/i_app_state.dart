/// Abstract interface that exposes the observable state and methods
/// that tools operate on. [AppController] implements this interface,
/// and tests can provide a lightweight fake.
library;

import 'package:get/get.dart';
import '../models/insights_models.dart';
import '../models/note.dart';

abstract class IAppState extends GetxController {
  // ── Observable state ──────────────────────────────────────────────────────
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

  // ── Task mutations ───────────────────────────────────────────────────────
  Future<void> toggleTaskComplete(String id);
  Future<void> deleteTask(String id);

  // ── Export ───────────────────────────────────────────────────────────────
  Future<String?> exportAll(String dir);
}
