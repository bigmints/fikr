/// Comprehensive unit tests for Fikr tool engine — notes, tasks, reminders.
///
/// Uses a lightweight [_FakeAppState] (extends IAppState) registered in GetX
/// to avoid any Firebase, AudioPlayer, or platform-channel dependencies.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'package:fikr/models/note.dart';
import 'package:fikr/models/analysis_result.dart';
import 'package:fikr/models/app_config.dart';
import 'package:fikr/models/insights_models.dart';
import 'package:fikr/controllers/i_app_state.dart';
import 'package:fikr/tools/tool_interface.dart';
import 'package:fikr/tools/tool_registry.dart';
import 'package:fikr/tools/tools/notes_tools.dart';
import 'package:fikr/tools/tools/tasks_tools.dart';
import 'package:fikr/tools/tools/reminders_tools.dart';
import 'package:fikr/tools/tools/notifications_tools.dart';
import 'package:fikr/tools/skill_engine/skill.dart';
import 'package:fikr/tools/skill_engine/skill_executor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake App State
// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight test double. Extends IAppState so `Get.find<IAppState>()` works.
class _FakeAppState extends IAppState {
  @override
  final Rx<AppConfig> config = AppConfig.fromJson({}).obs;

  @override
  final RxList<Note> notes = <Note>[].obs;

  @override
  final RxList<TodoItem> todoItems = <TodoItem>[].obs;

  @override
  final RxList<ReminderItem> reminders = <ReminderItem>[].obs;

  // Counters for asserting persistence was called.
  int saveNotesCalls = 0;
  int saveTasksCalls = 0;
  int saveRemindersCalls = 0;

  @override
  Future<void> saveNotes() async => saveNotesCalls++;

  @override
  Future<void> saveTasks() async => saveTasksCalls++;

  @override
  Future<void> saveReminders() async => saveRemindersCalls++;

  @override
  Future<void> updateNote(Note updated) async {
    final i = notes.indexWhere((n) => n.id == updated.id);
    if (i != -1) notes[i] = updated;
    saveNotesCalls++;
  }

  @override
  Future<void> archiveNote(String id) async {
    final i = notes.indexWhere((n) => n.id == id);
    if (i != -1) notes[i] = notes[i].copyWith(archived: true);
    saveNotesCalls++;
  }

  @override
  Future<void> deleteNote(String id) async {
    notes.removeWhere((n) => n.id == id);
    saveNotesCalls++;
  }

  @override
  Future<void> toggleTaskComplete(String id) async {
    final i = todoItems.indexWhere((t) => t.id == id);
    if (i != -1) {
      final t = todoItems[i];
      todoItems[i] = t.copyWith(
        status: t.isCompleted ? 'todo' : 'done',
        completedAt: t.isCompleted ? null : DateTime.now(),
      );
    }
    saveTasksCalls++;
  }

  @override
  Future<void> deleteTask(String id) async {
    todoItems.removeWhere((t) => t.id == id);
    saveTasksCalls++;
  }

  @override
  Future<void> deleteCompletedTasks() async {
    todoItems.removeWhere((t) => t.isCompleted);
    saveTasksCalls++;
  }

  @override
  Future<String?> exportAll(String dir) async => '$dir/fikr-export.md';

  @override
  Future<Note> finalizeNote({
    required String id,
    required DateTime createdAt,
    required String audioPath,
    required String transcript,
    required AnalysisResult analysis,
    String transcriptStyle = 'cleaned',
  }) async {
    final note = Note(
      id: id,
      createdAt: createdAt,
      updatedAt: createdAt,
      title: 'Finalized',
      text: transcript,
      transcript: transcript,
      intent: '',
      bucket: 'General',
      topics: [],
    );
    notes.insert(0, note);
    saveNotesCalls++;
    return note;
  }

  @override
  Future<Note> createEmptyNote() async {
    final note = Note(
      id: 'draft',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      title: '',
      text: '',
      transcript: '',
      intent: '',
      bucket: 'General',
      topics: [],
    );
    notes.insert(0, note);
    return note;
  }

  @override
  Future<void> playAudio(Note note) async {}

  @override
  Future<void> updateNoteAudioUrl(String noteId, String audioUrl) async {}

  @override
  Future<void> updateConfig(AppConfig updatedConfig) async {}

  @override
  Future<void> reloadAllData() async {}
}


// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Note makeNote({
  String? id,
  String title = 'Test Note',
  String text = 'Hello world',
  String bucket = 'General',
  List<String>? topics,
}) {
  final now = DateTime.now();
  return Note(
    id: id ?? const Uuid().v4(),
    createdAt: now,
    updatedAt: now,
    title: title,
    text: text,
    transcript: '',
    intent: title,
    bucket: bucket,
    topics: topics ?? [],
  );
}

TodoItem makeTask({
  String? id,
  String title = 'Test Task',
  String status = 'todo',
}) =>
    TodoItem(
      id: id ?? const Uuid().v4(),
      title: title,
      source: '',
      status: status,
      createdAt: DateTime.now(),
    );

ReminderItem makeReminder({String? id, String title = 'Test Reminder'}) =>
    ReminderItem(
      id: id ?? const Uuid().v4(),
      title: title,
      date: DateTime.now().add(const Duration(days: 1)),
      sourceNoteId: '',
    );

ToolContext emptyCtx() => ToolContext(
      userId: null,
      planTier: ToolTier.free,
      config: AppConfig.fromJson({}),
      // storage omitted — local tools use IAppState via Get.find, never context.storage.
    );

// ─────────────────────────────────────────────────────────────────────────────
// Test suite
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late _FakeAppState state;

  setUp(() {
    Get.reset();
    state = Get.put<IAppState>(_FakeAppState()) as _FakeAppState;
  });

  tearDown(() => Get.reset());

  // ── ToolResult contract ─────────────────────────────────────────────────────
  group('ToolResult', () {
    test('ok() — success=true, data set, error null', () {
      final r = ToolResult.ok({'x': 1});
      expect(r.success, isTrue);
      expect(r.data, {'x': 1});
      expect(r.error, isNull);
    });

    test('fail() — success=false, error set, data null', () {
      final r = ToolResult.fail('boom');
      expect(r.success, isFalse);
      expect(r.error, 'boom');
      expect(r.data, isNull);
    });

    test('toSchemaMap() includes required keys', () {
      final map = NotesListTool().toSchemaMap();
      expect(map['name'], 'notes.list');
      expect(map['requiredTier'], 'free');
      expect(map['location'], 'local');
      expect(map['parameters'], isA<Map>());
    });
  });

  // ── notes.list ─────────────────────────────────────────────────────────────
  group('notes.list', () {
    final tool = NotesListTool();

    test('returns [] when store is empty', () async {
      final r = await tool.execute({}, emptyCtx());
      expect(r.success, isTrue);
      expect(r.data as List, isEmpty);
    });

    test('returns all notes with no filters', () async {
      state.notes.addAll([makeNote(title: 'A'), makeNote(title: 'B')]);
      final r = await tool.execute({}, emptyCtx());
      expect((r.data as List).length, 2);
    });

    test('filters by bucket', () async {
      state.notes.addAll([
        makeNote(bucket: 'Work', title: 'Work Note'),
        makeNote(bucket: 'Home', title: 'Home Note'),
      ]);
      final r = await tool.execute({'bucket': 'Work'}, emptyCtx());
      expect((r.data as List).length, 1);
      expect((r.data as List).first['bucket'], 'Work');
    });

    test('filters by keyword search (title)', () async {
      state.notes.addAll([
        makeNote(title: 'Flutter best practices'),
        makeNote(title: 'React hooks guide'),
      ]);
      final r = await tool.execute({'search': 'flutter'}, emptyCtx());
      expect((r.data as List).length, 1);
    });

    test('filters by keyword search (body text)', () async {
      state.notes.addAll([
        makeNote(title: 'Note 1', text: 'Mentions Dart streams'),
        makeNote(title: 'Note 2', text: 'About Kotlin coroutines'),
      ]);
      final r = await tool.execute({'search': 'dart'}, emptyCtx());
      expect((r.data as List).length, 1);
    });

    test('respects limit param', () async {
      for (var i = 0; i < 10; i++) {
        state.notes.add(makeNote(title: 'N$i'));
      }
      final r = await tool.execute({'limit': 3}, emptyCtx());
      expect((r.data as List).length, 3);
    });

    test('sort=oldest returns earliest note first', () async {
      final now = DateTime.now();
      state.notes.addAll([
        Note(id: 'b', createdAt: now, updatedAt: now, title: 'New',
            text: '', transcript: '', intent: '', bucket: 'G', topics: []),
        Note(id: 'a', createdAt: now.subtract(const Duration(days: 3)),
            updatedAt: now, title: 'Old', text: '', transcript: '',
            intent: '', bucket: 'G', topics: []),
      ]);
      final r = await tool.execute({'sort': 'oldest'}, emptyCtx());
      expect((r.data as List).first['title'], 'Old');
    });

    test('sort=newest (default) returns latest note first', () async {
      final now = DateTime.now();
      state.notes.addAll([
        Note(id: 'b', createdAt: now, updatedAt: now, title: 'New',
            text: '', transcript: '', intent: '', bucket: 'G', topics: []),
        Note(id: 'a', createdAt: now.subtract(const Duration(days: 3)),
            updatedAt: now, title: 'Old', text: '', transcript: '',
            intent: '', bucket: 'G', topics: []),
      ]);
      final r = await tool.execute({}, emptyCtx());
      expect((r.data as List).first['title'], 'New');
    });

    test('CRITICAL: excludes archived notes by default (deleted-note bug)', () async {
      final now = DateTime.now();
      state.notes.addAll([
        Note(id: 'live', createdAt: now, updatedAt: now, title: 'Live Note',
            text: 'visible', transcript: '', intent: '', bucket: 'G', topics: [],
            archived: false),
        Note(id: 'dead', createdAt: now, updatedAt: now, title: 'Deleted Note',
            text: 'should not appear in insights', transcript: '', intent: '',
            bucket: 'G', topics: [], archived: true),
      ]);
      final r = await tool.execute({}, emptyCtx());
      final titles = (r.data as List).map((n) => n['title']).toList();
      expect(titles, contains('Live Note'));
      expect(titles, isNot(contains('Deleted Note')));
    });

    test('includes archived notes when excludeArchived=false', () async {
      final now = DateTime.now();
      state.notes.addAll([
        Note(id: 'live2', createdAt: now, updatedAt: now, title: 'Live',
            text: '', transcript: '', intent: '', bucket: 'G', topics: [], archived: false),
        Note(id: 'dead2', createdAt: now, updatedAt: now, title: 'Archived',
            text: '', transcript: '', intent: '', bucket: 'G', topics: [], archived: true),
      ]);
      final r = await tool.execute({'excludeArchived': false}, emptyCtx());
      expect((r.data as List).length, 2);
    });
  });


  // ── notes.get ──────────────────────────────────────────────────────────────
  group('notes.get', () {
    test('returns full note by id', () async {
      state.notes.add(makeNote(id: 'n42', title: 'Hello World'));
      final r = await NotesGetTool().execute({'id': 'n42'}, emptyCtx());
      expect(r.success, isTrue);
      expect((r.data as Map)['title'], 'Hello World');
    });

    test('returns failure for unknown id', () async {
      final r = await NotesGetTool().execute({'id': 'missing-id'}, emptyCtx());
      expect(r.success, isFalse);
      expect(r.error, contains('missing-id'));
    });
  });

  // ── notes.create ───────────────────────────────────────────────────────────
  group('notes.create', () {
    test('inserts note at top of list', () async {
      state.notes.add(makeNote(title: 'Existing'));
      final r = await NotesCreateTool().execute({
        'title': 'New Note',
        'text': 'Some body',
        'bucket': 'Ideas',
        'topics': ['ai', 'ux'],
      }, emptyCtx());
      expect(r.success, isTrue);
      expect(state.notes.length, 2);
      expect(state.notes.first.title, 'New Note');
      expect(state.notes.first.topics, ['ai', 'ux']);
      expect(state.saveNotesCalls, 1);
    });

    test('uses defaults when optional fields absent', () async {
      await NotesCreateTool().execute({'title': 'Min'}, emptyCtx());
      expect(state.notes.first.bucket, 'General');
      expect(state.notes.first.topics, isEmpty);
    });
  });

  // ── notes.update ───────────────────────────────────────────────────────────
  group('notes.update', () {
    test('updates title and bucket in place', () async {
      state.notes.add(makeNote(id: 'u1', title: 'Draft', bucket: 'Work'));
      final r = await NotesUpdateTool().execute({
        'id': 'u1',
        'title': 'Published',
        'bucket': 'Archive',
      }, emptyCtx());
      expect(r.success, isTrue);
      expect(state.notes.first.title, 'Published');
      expect(state.notes.first.bucket, 'Archive');
    });

    test('fails gracefully for unknown id', () async {
      final r = await NotesUpdateTool().execute({'id': 'ghost'}, emptyCtx());
      expect(r.success, isFalse);
    });
  });

  // ── notes.archive ──────────────────────────────────────────────────────────
  group('notes.archive', () {
    test('sets archived=true on the note', () async {
      state.notes.add(makeNote(id: 'arch1'));
      final r = await NotesArchiveTool().execute({'id': 'arch1'}, emptyCtx());
      expect(r.success, isTrue);
      expect(state.notes.first.archived, isTrue);
    });
  });

  // ── notes.delete ───────────────────────────────────────────────────────────
  group('notes.delete', () {
    test('removes note from list and persists', () async {
      state.notes.add(makeNote(id: 'del1'));
      final r = await NotesDeleteTool().execute({'id': 'del1'}, emptyCtx());
      expect(r.success, isTrue);
      expect(state.notes, isEmpty);
      expect(state.saveNotesCalls, greaterThan(0));
    });
  });

  // ── notes.search ───────────────────────────────────────────────────────────
  group('notes.search', () {
    test('finds notes matching query', () async {
      state.notes.addAll([
        makeNote(title: 'Dart unit testing'),
        makeNote(title: 'Python scripting basics'),
      ]);
      final r = await NotesSearchTool().execute({'query': 'unit'}, emptyCtx());
      expect(r.success, isTrue);
      expect((r.data as List).length, 1);
    });

    test('returns empty for no match', () async {
      state.notes.add(makeNote(title: 'Nothing here'));
      final r = await NotesSearchTool().execute({'query': 'flutter'}, emptyCtx());
      expect((r.data as List), isEmpty);
    });
  });

  // ── tasks.list ─────────────────────────────────────────────────────────────
  group('tasks.list', () {
    final tool = TasksListTool();

    test('returns all tasks with no filter', () async {
      state.todoItems.addAll([makeTask(), makeTask(status: 'done')]);
      final r = await tool.execute({}, emptyCtx());
      expect((r.data as List).length, 2);
    });

    test('status=todo filters only pending tasks', () async {
      state.todoItems.addAll([
        makeTask(title: 'Pending'),
        makeTask(title: 'Done', status: 'done'),
      ]);
      final r = await tool.execute({'status': 'todo'}, emptyCtx());
      expect((r.data as List).length, 1);
      expect((r.data as List).first['title'], 'Pending');
    });

    test('status=done filters only completed tasks', () async {
      state.todoItems.addAll([
        makeTask(title: 'Pending'),
        makeTask(title: 'Done', status: 'done'),
      ]);
      final r = await tool.execute({'status': 'done'}, emptyCtx());
      expect((r.data as List).length, 1);
      expect((r.data as List).first['title'], 'Done');
    });

    test('respects limit', () async {
      for (var i = 0; i < 8; i++) {
        state.todoItems.add(makeTask(title: 'T$i'));
      }
      final r = await tool.execute({'limit': 5}, emptyCtx());
      expect((r.data as List).length, 5);
    });
  });

  // ── tasks.create ───────────────────────────────────────────────────────────
  group('tasks.create', () {
    test('creates task with status=todo by default', () async {
      final r = await TasksCreateTool().execute({
        'title': 'Write release notes',
        'description': 'Cover all v2 changes',
      }, emptyCtx());
      expect(r.success, isTrue);
      expect(state.todoItems.length, 1);
      expect(state.todoItems.first.title, 'Write release notes');
      expect(state.todoItems.first.status, 'todo');
      expect(state.saveTasksCalls, 1);
    });
  });

  // ── tasks.update ───────────────────────────────────────────────────────────
  group('tasks.update', () {
    test('updates title and marks done', () async {
      state.todoItems.add(makeTask(id: 'tu1', title: 'Old'));
      final r = await TasksUpdateTool().execute({
        'id': 'tu1',
        'title': 'Revised',
        'status': 'done',
      }, emptyCtx());
      expect(r.success, isTrue);
      expect(state.todoItems.first.title, 'Revised');
      expect(state.todoItems.first.isCompleted, isTrue);
    });

    test('fails for unknown task id', () async {
      final r = await TasksUpdateTool().execute({'id': 'ghost'}, emptyCtx());
      expect(r.success, isFalse);
      expect(r.error, contains('ghost'));
    });
  });

  // ── tasks.complete ─────────────────────────────────────────────────────────
  group('tasks.complete', () {
    test('todo → done on first toggle', () async {
      state.todoItems.add(makeTask(id: 'tc1'));
      final r = await TasksCompleteTool().execute({'id': 'tc1'}, emptyCtx());
      expect(r.success, isTrue);
      expect(state.todoItems.first.isCompleted, isTrue);
    });

    test('done → todo on second toggle', () async {
      state.todoItems.add(makeTask(id: 'tc2', status: 'done'));
      await TasksCompleteTool().execute({'id': 'tc2'}, emptyCtx());
      expect(state.todoItems.first.isCompleted, isFalse);
    });
  });

  // ── tasks.delete ───────────────────────────────────────────────────────────
  group('tasks.delete', () {
    test('removes task from list', () async {
      state.todoItems.add(makeTask(id: 'td1'));
      final r = await TasksDeleteTool().execute({'id': 'td1'}, emptyCtx());
      expect(r.success, isTrue);
      expect(state.todoItems, isEmpty);
    });
  });

  // ── tasks.link_note ────────────────────────────────────────────────────────
  group('tasks.link_note', () {
    test('links sourceNoteId to the given note', () async {
      state.todoItems.add(makeTask(id: 'tl1'));
      final r = await TasksLinkNoteTool().execute(
          {'taskId': 'tl1', 'noteId': 'note-99'}, emptyCtx());
      expect(r.success, isTrue);
      expect(state.todoItems.first.sourceNoteId, 'note-99');
    });

    test('fails for unknown task', () async {
      final r = await TasksLinkNoteTool().execute(
          {'taskId': 'ghost', 'noteId': 'n1'}, emptyCtx());
      expect(r.success, isFalse);
    });
  });

  // ── reminders.list ─────────────────────────────────────────────────────────
  group('reminders.list', () {
    test('returns only active (non-dismissed) by default', () async {
      state.reminders.addAll([
        makeReminder(title: 'Active'),
        ReminderItem(
          id: 'dim',
          title: 'Dismissed',
          date: DateTime.now(),
          sourceNoteId: '',
          isDismissed: true,
        ),
      ]);
      final r = await RemindersListTool().execute({}, emptyCtx());
      expect(r.success, isTrue);
      expect((r.data as List).length, 1);
      expect((r.data as List).first['title'], 'Active');
    });

    test('includes dismissed when includeDissmissed=true', () async {
      state.reminders.addAll([
        makeReminder(title: 'Active'),
        ReminderItem(
          id: 'dim2',
          title: 'Dismissed',
          date: DateTime.now(),
          sourceNoteId: '',
          isDismissed: true,
        ),
      ]);
      final r = await RemindersListTool()
          .execute({'includeDissmissed': true}, emptyCtx());
      expect((r.data as List).length, 2);
    });
  });

  // ── reminders.create ───────────────────────────────────────────────────────
  group('reminders.create', () {
    test('creates reminder with date + optional time', () async {
      final r = await RemindersCreateTool().execute({
        'title': 'Doctor visit',
        'date': '2026-04-15',
        'time': '10:30',
      }, emptyCtx());
      expect(r.success, isTrue);
      expect(state.reminders.length, 1);
      expect(state.reminders.first.title, 'Doctor visit');
      expect(state.reminders.first.time, '10:30');
      expect(state.reminders.first.date.month, 4);
      expect(state.saveRemindersCalls, 1);
    });

    test('creates without time (time=null)', () async {
      await RemindersCreateTool().execute(
          {'title': 'No time', 'date': '2026-05-01'}, emptyCtx());
      expect(state.reminders.first.time, isNull);
    });

    test('fails with invalid date string', () async {
      final r = await RemindersCreateTool().execute(
          {'title': 'Bad date', 'date': 'not-a-date'}, emptyCtx());
      expect(r.success, isFalse);
    });
  });

  // ── reminders.dismiss ──────────────────────────────────────────────────────
  group('reminders.dismiss', () {
    test('sets isDismissed=true', () async {
      state.reminders.add(makeReminder(id: 'rd1'));
      final r = await RemindersDismissTool().execute({'id': 'rd1'}, emptyCtx());
      expect(r.success, isTrue);
      expect(state.reminders.first.isDismissed, isTrue);
    });

    test('fails for unknown reminder id', () async {
      final r = await RemindersDismissTool().execute({'id': 'ghost'}, emptyCtx());
      expect(r.success, isFalse);
    });
  });

  // ── reminders.reschedule ───────────────────────────────────────────────────
  group('reminders.reschedule', () {
    test('updates date, clears isDismissed, sets new time', () async {
      state.reminders.add(ReminderItem(
        id: 'rr1',
        title: 'Old reminder',
        date: DateTime(2026, 1, 1),
        sourceNoteId: '',
        isDismissed: true,
      ));
      final r = await RemindersRescheduleTool().execute({
        'id': 'rr1',
        'date': '2026-06-20',
        'time': '14:00',
      }, emptyCtx());
      expect(r.success, isTrue);
      expect(state.reminders.first.isDismissed, isFalse);
      expect(state.reminders.first.date.month, 6);
      expect(state.reminders.first.date.day, 20);
      expect(state.reminders.first.time, '14:00');
    });

    test('fails for unknown reminder id', () async {
      final r = await RemindersRescheduleTool().execute(
          {'id': 'ghost', 'date': '2026-01-01'}, emptyCtx());
      expect(r.success, isFalse);
    });
  });

  // ── Tool metadata ──────────────────────────────────────────────────────────
  group('Tool metadata integrity', () {
    test('all notes tools: tier=free, location=local', () {
      for (final t in allNotesTools()) {
        expect(t.requiredTier, ToolTier.free,
            reason: '${t.name} should be free tier');
        expect(t.location, ToolLocation.local,
            reason: '${t.name} should be local');
      }
    });

    test('all tasks tools: tier=free', () {
      for (final t in allTasksTools()) {
        expect(t.requiredTier, ToolTier.free, reason: t.name);
      }
    });

    test('all reminders tools: tier=free', () {
      for (final t in allRemindersTools()) {
        expect(t.requiredTier, ToolTier.free, reason: t.name);
      }
    });

    test('every tool has name + description + parametersSchema', () {
      final all = [
        ...allNotesTools(),
        ...allTasksTools(),
        ...allRemindersTools(),
        ...allNotificationsTools(),
      ];
      for (final t in all) {
        expect(t.name, isNotEmpty, reason: 'missing tool name');
        expect(t.description, isNotEmpty,
            reason: '${t.name}: missing description');
        expect(t.parametersSchema, isA<Map>(),
            reason: '${t.name}: parametersSchema must be a Map');
      }
    });

    test('tool names are globally unique', () {
      final all = [
        ...allNotesTools(),
        ...allTasksTools(),
        ...allRemindersTools(),
        ...allNotificationsTools(),
      ];
      final names = all.map((t) => t.name).toList();
      expect(
        names.toSet().length,
        names.length,
        reason: 'Duplicate tool names detected',
      );
    });
    test('all notifications tools metadata', () {
      for (final t in allNotificationsTools()) {
        expect(t.name, isNotEmpty);
        if (t is NotifyPushTool) {
          expect(t.requiredTier, ToolTier.plus);
          expect(t.location, ToolLocation.cloud);
        } else {
          expect(t.requiredTier, ToolTier.free);
          expect(t.location, ToolLocation.local);
        }
      }
    });
  });

  // ── Integration: mock data seed ────────────────────────────────────────────
  group('Integration: mock data pipeline', () {
    setUp(() {
      // Rich mock dataset mirroring real usage
      state.notes.addAll([
        makeNote(id: 'n-1', title: 'Launch plan', bucket: 'Work',
            text: 'Ship v2 by Q2', topics: ['product', 'roadmap']),
        makeNote(id: 'n-2', title: 'Book recommendations', bucket: 'Personal',
            text: 'Ask Pretheesh for reading list', topics: ['books']),
        makeNote(id: 'n-3', title: 'API design notes', bucket: 'Work',
            text: 'REST vs gRPC discussion', topics: ['engineering']),
        makeNote(id: 'n-4', title: 'Meeting notes', bucket: 'Work',
            text: 'Q1 planning session', topics: ['meetings']),
      ]);

      state.todoItems.addAll([
        makeTask(id: 't-1', title: 'Draft roadmap doc'),
        makeTask(id: 't-2', title: 'Review design PR', status: 'done'),
        makeTask(id: 't-3', title: 'Write unit tests'),
        makeTask(id: 't-4', title: 'Deploy to staging', status: 'done'),
      ]);

      state.reminders.addAll([
        makeReminder(id: 'r-1', title: 'Team standup'),
        makeReminder(id: 'r-2', title: 'Sprint review'),
        ReminderItem(
          id: 'r-3',
          title: 'Old reminder (dismissed)',
          date: DateTime(2025, 1, 1),
          sourceNoteId: '',
          isDismissed: true,
        ),
      ]);
    });

    test('bucket filter: Work notes → 3 results', () async {
      final r = await NotesListTool().execute({'bucket': 'Work'}, emptyCtx());
      expect((r.data as List).length, 3);
    });

    test('keyword search: "api" → 1 result', () async {
      final r = await NotesSearchTool().execute({'query': 'api'}, emptyCtx());
      expect((r.data as List).length, 1);
      expect((r.data as List).first['title'], 'API design notes');
    });

    test('task status filter: todo → 2 pending tasks', () async {
      final r = await TasksListTool().execute({'status': 'todo'}, emptyCtx());
      expect((r.data as List).length, 2);
    });

    test('task status filter: done → 2 completed tasks', () async {
      final r = await TasksListTool().execute({'status': 'done'}, emptyCtx());
      expect((r.data as List).length, 2);
    });

    test('reminder list: active only → 2 (excludes dismissed)', () async {
      final r = await RemindersListTool().execute({}, emptyCtx());
      expect((r.data as List).length, 2);
    });

    test('reminder list: all → 3 (includes dismissed)', () async {
      final r = await RemindersListTool()
          .execute({'includeDissmissed': true}, emptyCtx());
      expect((r.data as List).length, 3);
    });

    test('full note lifecycle: create → update → archive → delete', () async {
      // create
      await NotesCreateTool().execute(
          {'title': 'Draft spec', 'bucket': 'Work'}, emptyCtx());
      final id = state.notes.firstWhere((n) => n.title == 'Draft spec').id;

      // update
      await NotesUpdateTool()
          .execute({'id': id, 'title': 'Final spec'}, emptyCtx());
      expect(state.notes.firstWhere((n) => n.id == id).title, 'Final spec');

      // archive
      await NotesArchiveTool().execute({'id': id}, emptyCtx());
      expect(state.notes.firstWhere((n) => n.id == id).archived, isTrue);

      // delete
      await NotesDeleteTool().execute({'id': id}, emptyCtx());
      expect(state.notes.any((n) => n.id == id), isFalse);
    });

    test('full task lifecycle: create → complete → un-complete → delete', () async {
      await TasksCreateTool().execute({'title': 'Fix bug #42'}, emptyCtx());
      final id = state.todoItems
          .firstWhere((t) => t.title == 'Fix bug #42').id;

      // complete
      await TasksCompleteTool().execute({'id': id}, emptyCtx());
      expect(state.todoItems.firstWhere((t) => t.id == id).isCompleted, isTrue);

      // un-complete
      await TasksCompleteTool().execute({'id': id}, emptyCtx());
      expect(state.todoItems.firstWhere((t) => t.id == id).isCompleted, isFalse);

      // delete
      await TasksDeleteTool().execute({'id': id}, emptyCtx());
      expect(state.todoItems.any((t) => t.id == id), isFalse);
    });

    test('full reminder lifecycle: create → dismiss → reschedule', () async {
      await RemindersCreateTool().execute(
          {'title': 'Dentist', 'date': '2026-05-10'}, emptyCtx());
      final id =
          state.reminders.firstWhere((r) => r.title == 'Dentist').id;

      await RemindersDismissTool().execute({'id': id}, emptyCtx());
      expect(state.reminders.firstWhere((r) => r.id == id).isDismissed, isTrue);

      await RemindersRescheduleTool().execute(
          {'id': id, 'date': '2026-05-20', 'time': '09:30'}, emptyCtx());
      final rescheduled = state.reminders.firstWhere((r) => r.id == id);
      expect(rescheduled.isDismissed, isFalse);
      expect(rescheduled.date.day, 20);
      expect(rescheduled.time, '09:30');
    });

    test('link task to note + verify note retrieval', () async {
      await TasksLinkNoteTool()
          .execute({'taskId': 't-1', 'noteId': 'n-1'}, emptyCtx());
      expect(
          state.todoItems.firstWhere((t) => t.id == 't-1').sourceNoteId,
          'n-1');

      final noteResult =
          await NotesGetTool().execute({'id': 'n-1'}, emptyCtx());
      expect(noteResult.success, isTrue);
      expect((noteResult.data as Map)['title'], 'Launch plan');
    });
  });

  // ── tasks.delete_completed ────────────────────────────────────────────────
  group('tasks.delete_completed', () {
    test('removes all completed tasks, leaves pending intact', () async {
      state.todoItems.addAll([
        makeTask(id: 'dc-1', title: 'Keep this', status: 'todo'),
        makeTask(id: 'dc-2', title: 'Delete this', status: 'done'),
        makeTask(id: 'dc-3', title: 'Also delete', status: 'done'),
      ]);
      final r = await TasksDeleteCompletedTool().execute({}, emptyCtx());
      expect(r.success, isTrue);
      expect(state.todoItems.length, 1);
      expect(state.todoItems.first.title, 'Keep this');
      expect(state.saveTasksCalls, greaterThan(0));
    });

    test('succeeds with no-op when no completed tasks exist', () async {
      state.todoItems.addAll([
        makeTask(title: 'Pending 1'),
        makeTask(title: 'Pending 2'),
      ]);
      final r = await TasksDeleteCompletedTool().execute({}, emptyCtx());
      expect(r.success, isTrue);
      expect(state.todoItems.length, 2);
    });

    test('empties list when all tasks are completed', () async {
      state.todoItems.addAll([
        makeTask(id: 'dc-4', status: 'done'),
        makeTask(id: 'dc-5', status: 'done'),
      ]);
      final r = await TasksDeleteCompletedTool().execute({}, emptyCtx());
      expect(r.success, isTrue);
      expect(state.todoItems, isEmpty);
    });
  });

  // ── SkillExecutor — parallel group execution ───────────────────────────────
  group('SkillExecutor parallel groups', () {
    /// Minimal fake tool that resolves after [delay] and stores its output.
    FikrTool makeFakeTool(String toolName, dynamic output, {Duration delay = Duration.zero}) {
      return _DelayedFakeTool(toolName, output, delay);
    }

    test('parallel steps execute concurrently and both outputs are stored', () async {
      final registry = ToolRegistry.forTesting();
      registry.registerAll([
        makeFakeTool('tool.a', {'val': 'A'}),
        makeFakeTool('tool.b', {'val': 'B'}),
      ]);

      final skill = Skill(
        name: 'parallel_test',
        description: 'Tests parallel execution',
        steps: const [
          SkillStep(toolName: 'tool.a', input: {}, outputKey: 'resultA', parallel: true),
          SkillStep(toolName: 'tool.b', input: {}, outputKey: 'resultB', parallel: true),
        ],
      );

      final executor = SkillExecutor(registry: registry);
      final ctx = emptyCtx();
      final result = await executor.execute(skill, ctx);

      expect(result.success, isTrue);
      expect(result.variables['resultA'], {'val': 'A'});
      expect(result.variables['resultB'], {'val': 'B'});
    });

    test('parallel step failure with fail policy aborts skill', () async {
      final registry = ToolRegistry.forTesting();
      registry.registerAll([
        makeFakeTool('tool.ok', {'ok': true}),
        _FailingFakeTool('tool.fail'),
      ]);

      final skill = Skill(
        name: 'parallel_fail_test',
        description: 'Fails on one parallel branch',
        steps: const [
          SkillStep(toolName: 'tool.ok', input: {}, outputKey: 'ok', parallel: true),
          SkillStep(
            toolName: 'tool.fail',
            input: {},
            outputKey: 'fail',
            parallel: true,
            onError: StepErrorPolicy.fail,
          ),
        ],
      );

      final executor = SkillExecutor(registry: registry);
      final result = await executor.execute(skill, emptyCtx());

      expect(result.success, isFalse);
      expect(result.error, isNotEmpty);
    });

    test('parallel step failure with skip policy allows skill to complete', () async {
      final registry = ToolRegistry.forTesting();
      registry.registerAll([
        makeFakeTool('tool.good', {'val': 'good'}),
        _FailingFakeTool('tool.bad'),
      ]);

      final skill = Skill(
        name: 'parallel_skip_test',
        description: 'Skips failed parallel branch',
        steps: const [
          SkillStep(toolName: 'tool.good', input: {}, outputKey: 'good', parallel: true),
          SkillStep(
            toolName: 'tool.bad',
            input: {},
            outputKey: 'bad',
            parallel: true,
            onError: StepErrorPolicy.skip,
          ),
        ],
      );

      final executor = SkillExecutor(registry: registry);
      final result = await executor.execute(skill, emptyCtx());

      expect(result.success, isTrue);
      expect(result.variables['good'], {'val': 'good'});
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake tools for SkillExecutor tests
// ─────────────────────────────────────────────────────────────────────────────

class _DelayedFakeTool extends FikrTool {
  _DelayedFakeTool(this._name, this._output, this._delay);
  final String _name;
  final dynamic _output;
  final Duration _delay;

  @override String get name => _name;
  @override String get description => 'Fake tool: $_name';
  @override Map<String, dynamic> get parametersSchema =>
      {'type': 'object', 'properties': {}};
  @override ToolTier get requiredTier => ToolTier.free;
  @override ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    if (_delay > Duration.zero) await Future<void>.delayed(_delay);
    return ToolResult.ok(_output);
  }
}

class _FailingFakeTool extends FikrTool {
  _FailingFakeTool(this._name);
  final String _name;

  @override String get name => _name;
  @override String get description => 'Failing fake tool';
  @override Map<String, dynamic> get parametersSchema =>
      {'type': 'object', 'properties': {}};
  @override ToolTier get requiredTier => ToolTier.free;
  @override ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async =>
      ToolResult.fail('Intentional failure from $_name');
}
