/// Notes domain tools — CRUD operations on the user's notes.
library;

import 'dart:io';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:uuid/uuid.dart';

import '../../controllers/app_controller.dart';
import '../../models/note.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  notes.list
// ───────────────────────────────────────────────────────────────────────────

class NotesListTool extends FikrTool {
  @override
  String get name => 'notes.list';

  @override
  String get description =>
      'List notes filtered by bucket, date range, or search query. '
      'Returns an array of note summaries (id, title, bucket, createdAt).';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'bucket': {
        'type': 'string',
        'description': 'Filter by bucket name. Use "All" for no filter.',
      },
      'search': {
        'type': 'string',
        'description': 'Full-text search query.',
      },
      'limit': {
        'type': 'integer',
        'description': 'Max number of notes to return.',
        'default': 50,
      },
      'sort': {
        'type': 'string',
        'enum': ['newest', 'oldest', 'updated'],
        'default': 'newest',
      },
    },
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = Get.find<AppController>();
      final bucket = params['bucket'] as String? ?? 'All';
      final search = params['search'] as String? ?? '';
      final limit = params['limit'] as int? ?? 50;
      final sort = params['sort'] as String? ?? 'newest';

      var notes = ctrl.notes.toList();

      // Bucket filter
      if (bucket != 'All') {
        notes = notes.where((n) => n.bucket == bucket).toList();
      }

      // Search filter
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        notes = notes.where((n) {
          return n.title.toLowerCase().contains(q) ||
              n.text.toLowerCase().contains(q) ||
              n.transcript.toLowerCase().contains(q) ||
              n.bucket.toLowerCase().contains(q) ||
              n.topics.any((t) => t.toLowerCase().contains(q));
        }).toList();
      }

      // Sort
      notes.sort((a, b) {
        switch (sort) {
          case 'oldest':
            return a.createdAt.compareTo(b.createdAt);
          case 'updated':
            return b.updatedAt.compareTo(a.updatedAt);
          default:
            return b.createdAt.compareTo(a.createdAt);
        }
      });

      // Limit
      if (notes.length > limit) {
        notes = notes.sublist(0, limit);
      }

      return ToolResult.ok(
        notes
            .map((n) => {
                  'id': n.id,
                  'title': n.title,
                  'bucket': n.bucket,
                  'createdAt': n.createdAt.toIso8601String(),
                  'topics': n.topics,
                })
            .toList(),
      );
    } catch (e) {
      return ToolResult.fail('Failed to list notes: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  notes.get
// ───────────────────────────────────────────────────────────────────────────

class NotesGetTool extends FikrTool {
  @override
  String get name => 'notes.get';

  @override
  String get description =>
      'Get a single note by ID. Returns full note data including transcript.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'Note ID'},
    },
    'required': ['id'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = Get.find<AppController>();
      final id = params['id'] as String;
      final note = ctrl.notes.firstWhereOrNull((n) => n.id == id);
      if (note == null) return ToolResult.fail('Note not found: $id');
      return ToolResult.ok(note.toJson());
    } catch (e) {
      return ToolResult.fail('Failed to get note: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  notes.create
// ───────────────────────────────────────────────────────────────────────────

class NotesCreateTool extends FikrTool {
  @override
  String get name => 'notes.create';

  @override
  String get description =>
      'Create a new note with title, text, bucket, and topics.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'text': {'type': 'string'},
      'transcript': {'type': 'string'},
      'bucket': {'type': 'string', 'default': 'General'},
      'topics': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = Get.find<AppController>();
      final now = DateTime.now();
      final note = Note(
        id: const Uuid().v4(),
        createdAt: now,
        updatedAt: now,
        title: params['title'] as String? ?? '',
        text: params['text'] as String? ?? '',
        transcript: params['transcript'] as String? ?? '',
        intent: params['title'] as String? ?? '',
        bucket: params['bucket'] as String? ?? 'General',
        topics: (params['topics'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
      ctrl.notes.insert(0, note);
      await ctrl.saveNotes();
      return ToolResult.ok(note.toJson());
    } catch (e) {
      return ToolResult.fail('Failed to create note: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  notes.update
// ───────────────────────────────────────────────────────────────────────────

class NotesUpdateTool extends FikrTool {
  @override
  String get name => 'notes.update';

  @override
  String get description => 'Update fields of an existing note by ID.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'Note ID'},
      'title': {'type': 'string'},
      'text': {'type': 'string'},
      'bucket': {'type': 'string'},
      'topics': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['id'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = Get.find<AppController>();
      final id = params['id'] as String;
      final existing = ctrl.notes.firstWhereOrNull((n) => n.id == id);
      if (existing == null) return ToolResult.fail('Note not found: $id');

      final updated = existing.copyWith(
        title: params['title'] as String?,
        text: params['text'] as String?,
        bucket: params['bucket'] as String?,
        topics: (params['topics'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        updatedAt: DateTime.now(),
      );

      await ctrl.updateNote(updated);
      return ToolResult.ok(updated.toJson());
    } catch (e) {
      return ToolResult.fail('Failed to update note: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  notes.archive
// ───────────────────────────────────────────────────────────────────────────

class NotesArchiveTool extends FikrTool {
  @override
  String get name => 'notes.archive';

  @override
  String get description => 'Archive (soft-delete) a note by ID.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'Note ID'},
    },
    'required': ['id'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = Get.find<AppController>();
      await ctrl.archiveNote(params['id'] as String);
      return ToolResult.ok({'archived': params['id']});
    } catch (e) {
      return ToolResult.fail('Failed to archive note: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  notes.delete
// ───────────────────────────────────────────────────────────────────────────

class NotesDeleteTool extends FikrTool {
  @override
  String get name => 'notes.delete';

  @override
  String get description =>
      'Permanently delete a note and its audio file by ID.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'Note ID'},
    },
    'required': ['id'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = Get.find<AppController>();
      await ctrl.deleteNote(params['id'] as String);
      return ToolResult.ok({'deleted': params['id']});
    } catch (e) {
      return ToolResult.fail('Failed to delete note: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  notes.search
// ───────────────────────────────────────────────────────────────────────────

class NotesSearchTool extends FikrTool {
  @override
  String get name => 'notes.search';

  @override
  String get description =>
      'Full-text search across all notes. '
      'Searches title, text, transcript, bucket, and topics.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'query': {'type': 'string', 'description': 'Search query'},
      'limit': {'type': 'integer', 'default': 20},
    },
    'required': ['query'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    // Delegate to notes.list with search param
    final listTool = NotesListTool();
    return listTool.execute({
      'search': params['query'],
      'limit': params['limit'] ?? 20,
    }, context);
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  notes.export
// ───────────────────────────────────────────────────────────────────────────

class NotesExportTool extends FikrTool {
  @override
  String get name => 'notes.export';

  @override
  String get description =>
      'Export all notes as a markdown file to a directory.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'directory': {
        'type': 'string',
        'description':
            'Absolute path to export directory. If empty, uses default.',
      },
    },
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = Get.find<AppController>();
      String? dir = params['directory'] as String?;

      if (dir == null || dir.isEmpty) {
        if (Platform.isMacOS || Platform.isWindows) {
          return ToolResult.fail(
            'Directory picker required on desktop — use the UI.',
          );
        }
        final docs = await getApplicationDocumentsDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
        dir = p.join(docs.path, 'fikr-export', timestamp);
      }

      final result = await ctrl.exportAll(dir);
      if (result == null) {
        return ToolResult.fail('No notes to export.');
      }
      return ToolResult.ok({'exportedTo': result});
    } catch (e) {
      return ToolResult.fail('Failed to export notes: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience: get all notes tools
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allNotesTools() => [
      NotesListTool(),
      NotesGetTool(),
      NotesCreateTool(),
      NotesUpdateTool(),
      NotesArchiveTool(),
      NotesDeleteTool(),
      NotesSearchTool(),
      NotesExportTool(),
    ];
