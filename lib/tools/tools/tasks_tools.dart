/// Tasks domain tools — CRUD for To Do items.
library;

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../controllers/app_controller.dart';
import '../../models/insights_models.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  tasks.list
// ───────────────────────────────────────────────────────────────────────────

class TasksListTool extends FikrTool {
  @override
  String get name => 'tasks.list';

  @override
  String get description =>
      'List tasks filtered by status. Returns an array of task objects.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'status': {
        'type': 'string',
        'enum': ['all', 'todo', 'done'],
        'default': 'all',
        'description': 'Filter by completion status.',
      },
      'limit': {'type': 'integer', 'default': 50},
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
      final status = params['status'] as String? ?? 'all';
      final limit = params['limit'] as int? ?? 50;

      var items = ctrl.todoItems.toList();

      if (status == 'todo') {
        items = items.where((t) => !t.isCompleted).toList();
      } else if (status == 'done') {
        items = items.where((t) => t.isCompleted).toList();
      }

      if (items.length > limit) {
        items = items.sublist(0, limit);
      }

      return ToolResult.ok(items.map((t) => t.toJson()).toList());
    } catch (e) {
      return ToolResult.fail('Failed to list tasks: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  tasks.create
// ───────────────────────────────────────────────────────────────────────────

class TasksCreateTool extends FikrTool {
  @override
  String get name => 'tasks.create';

  @override
  String get description =>
      'Create a new task with title, description, and optional source note.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'description': 'Task title'},
      'description': {'type': 'string', 'description': 'Task description'},
      'source': {'type': 'string', 'description': 'Source context'},
      'sourceNoteId': {
        'type': 'string',
        'description': 'ID of the note this task was extracted from',
      },
    },
    'required': ['title'],
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
      final item = TodoItem(
        id: const Uuid().v4(),
        title: params['title'] as String,
        source: params['source'] as String? ?? '',
        status: 'todo',
        description: params['description'] as String? ?? '',
        sourceNoteId: params['sourceNoteId'] as String? ?? '',
        createdAt: DateTime.now(),
      );
      ctrl.todoItems.add(item);
      await ctrl.saveTasks();
      return ToolResult.ok(item.toJson());
    } catch (e) {
      return ToolResult.fail('Failed to create task: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  tasks.update
// ───────────────────────────────────────────────────────────────────────────

class TasksUpdateTool extends FikrTool {
  @override
  String get name => 'tasks.update';

  @override
  String get description => 'Update a task\'s title, description, or status.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'Task ID'},
      'title': {'type': 'string'},
      'description': {'type': 'string'},
      'status': {'type': 'string', 'enum': ['todo', 'done']},
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
      final index = ctrl.todoItems.indexWhere((t) => t.id == id);
      if (index == -1) return ToolResult.fail('Task not found: $id');

      final existing = ctrl.todoItems[index];
      final updated = existing.copyWith(
        title: params['title'] as String?,
        description: params['description'] as String?,
        status: params['status'] as String?,
        completedAt: (params['status'] as String?) == 'done'
            ? DateTime.now()
            : null,
      );
      ctrl.todoItems[index] = updated;
      await ctrl.saveTasks();
      return ToolResult.ok(updated.toJson());
    } catch (e) {
      return ToolResult.fail('Failed to update task: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  tasks.complete
// ───────────────────────────────────────────────────────────────────────────

class TasksCompleteTool extends FikrTool {
  @override
  String get name => 'tasks.complete';

  @override
  String get description => 'Toggle a task\'s completion status.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'Task ID'},
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
      await ctrl.toggleTaskComplete(params['id'] as String);
      return ToolResult.ok({'toggled': params['id']});
    } catch (e) {
      return ToolResult.fail('Failed to toggle task: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  tasks.delete
// ───────────────────────────────────────────────────────────────────────────

class TasksDeleteTool extends FikrTool {
  @override
  String get name => 'tasks.delete';

  @override
  String get description => 'Delete a task by ID.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'Task ID'},
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
      await ctrl.deleteTask(params['id'] as String);
      return ToolResult.ok({'deleted': params['id']});
    } catch (e) {
      return ToolResult.fail('Failed to delete task: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  tasks.link_note
// ───────────────────────────────────────────────────────────────────────────

class TasksLinkNoteTool extends FikrTool {
  @override
  String get name => 'tasks.link_note';

  @override
  String get description => 'Associate a task with a source note by ID.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'taskId': {'type': 'string'},
      'noteId': {'type': 'string'},
    },
    'required': ['taskId', 'noteId'],
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
      final taskId = params['taskId'] as String;
      final noteId = params['noteId'] as String;

      final index = ctrl.todoItems.indexWhere((t) => t.id == taskId);
      if (index == -1) return ToolResult.fail('Task not found: $taskId');

      // TodoItem.sourceNoteId is final — recreate with new value.
      final old = ctrl.todoItems[index];
      ctrl.todoItems[index] = TodoItem(
        id: old.id,
        title: old.title,
        source: old.source,
        status: old.status,
        description: old.description,
        sourceNoteId: noteId,
        createdAt: old.createdAt,
        completedAt: old.completedAt,
      );
      await ctrl.saveTasks();
      return ToolResult.ok({'linked': taskId, 'to': noteId});
    } catch (e) {
      return ToolResult.fail('Failed to link task: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allTasksTools() => [
      TasksListTool(),
      TasksCreateTool(),
      TasksUpdateTool(),
      TasksCompleteTool(),
      TasksDeleteTool(),
      TasksLinkNoteTool(),
    ];
