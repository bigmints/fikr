import 'dart:convert';

/// Safely converts a dynamic value to a `List<dynamic>`.
/// Handles null, List, and String (returns empty list for String).
List<dynamic> _safeList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value;
  return [];
}

/// Safely converts a dynamic value to a `List<String>`.
/// Handles null, List, and comma-separated String.
List<String> _safeStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value.where((t) => t != null).map((t) => t.toString()).toList();
  }
  if (value is String && value.isNotEmpty) {
    return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
  return [];
}

class InsightIdeaNote {
  final String title;
  final String snippet;
  final String bucket;
  final List<String> topics;

  const InsightIdeaNote({
    required this.title,
    required this.snippet,
    required this.bucket,
    required this.topics,
  });
}

class FocusArea {
  final String topic;
  final int count;

  const FocusArea({required this.topic, required this.count});
}

class TodoItem {
  final String id;
  final String title;
  final String source;
  final String status; // 'todo', 'done'
  final String description;
  final String sourceNoteId;
  final DateTime createdAt;
  final DateTime? completedAt;

  const TodoItem({
    required this.id,
    required this.title,
    required this.source,
    required this.status,
    this.description = '',
    this.sourceNoteId = '',
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'done';

  TodoItem copyWith({
    String? title,
    String? status,
    String? description,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      source: source,
      status: status ?? this.status,
      description: description ?? this.description,
      sourceNoteId: sourceNoteId,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'status': status,
      'description': description,
      'sourceNoteId': sourceNoteId,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      source: json['source'] as String? ?? '',
      status: json['status'] as String? ?? 'todo',
      description: json['description'] as String? ?? '',
      sourceNoteId: json['sourceNoteId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  static List<TodoItem> listFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TodoItem.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<TodoItem> items) {
    return jsonEncode(items.map((item) => item.toJson()).toList());
  }
}

class ReminderItem {
  final String id;
  final String title;
  final DateTime date;
  final String? time;
  final String sourceNoteId;
  final bool isDismissed;

  const ReminderItem({
    required this.id,
    required this.title,
    required this.date,
    this.time,
    this.sourceNoteId = '',
    this.isDismissed = false,
  });

  ReminderItem copyWith({bool? isDismissed}) {
    return ReminderItem(
      id: id,
      title: title,
      date: date,
      time: time,
      sourceNoteId: sourceNoteId,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'time': time,
      'sourceNoteId': sourceNoteId,
      'isDismissed': isDismissed,
    };
  }

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    return ReminderItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      time: json['time'] as String?,
      sourceNoteId: json['sourceNoteId'] as String? ?? '',
      isDismissed: json['isDismissed'] as bool? ?? false,
    );
  }

  static List<ReminderItem> listFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ReminderItem.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<ReminderItem> items) {
    return jsonEncode(items.map((item) => item.toJson()).toList());
  }
}

class InsightHighlight {
  final String title;
  final String detail;
  final String bucket;
  final String icon;
  final List<String> citations;

  const InsightHighlight({
    required this.title,
    required this.detail,
    required this.bucket,
    required this.icon,
    this.citations = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'detail': detail,
      'bucket': bucket,
      'icon': icon,
      'citations': citations,
    };
  }

  factory InsightHighlight.fromJson(Map<String, dynamic> json) {
    return InsightHighlight(
      title: json['title'] as String? ?? 'Untitled',
      detail: json['detail'] as String? ?? '',
      bucket: json['bucket'] as String? ?? 'General',
      icon: json['icon'] as String? ?? 'idea',
      citations: _safeStringList(json['citations']),
    );
  }
}

class GeneratedInsights {
  final String title;
  final String summary;
  final List<InsightHighlight> highlights;
  final List<String> focus;
  final List<String> nextSteps;
  final List<String> risks;
  final List<String> questions;
  final List<String> workSummaries;
  final List<Map<String, dynamic>> llmTasks;
  final List<Map<String, dynamic>> llmReminders;

  const GeneratedInsights({
    required this.title,
    required this.summary,
    required this.highlights,
    required this.focus,
    required this.nextSteps,
    required this.risks,
    required this.questions,
    required this.workSummaries,
    this.llmTasks = const [],
    this.llmReminders = const [],
  });

  factory GeneratedInsights.fromJson(Map<String, dynamic> json) {
    final highlights = _safeList(json['highlights'])
        .whereType<Map<String, dynamic>>()
        .map(InsightHighlight.fromJson)
        .toList();
    return GeneratedInsights(
      title: json['title'] as String? ?? 'Insights',
      summary: json['summary'] as String? ?? '',
      highlights: highlights,
      focus: _safeStringList(json['focus']),
      nextSteps: _safeStringList(json['next_steps']),
      risks: _safeStringList(json['risks']),
      questions: _safeStringList(json['questions']),
      workSummaries: _safeStringList(json['work_summaries']),
      llmTasks: _safeList(json['tasks'])
          .whereType<Map<String, dynamic>>()
          .toList(),
      llmReminders: _safeList(json['reminders'])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

class InsightEdition {
  final String id;
  final DateTime createdAt;
  final String summary;
  final List<InsightHighlight> highlights;
  final List<String> buckets;

  const InsightEdition({
    required this.id,
    required this.createdAt,
    required this.summary,
    required this.highlights,
    required this.buckets,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'summary': summary,
      'highlights': highlights.map((item) => item.toJson()).toList(),
      'buckets': buckets,
    };
  }

  factory InsightEdition.fromJson(Map<String, dynamic> json) {
    final highlightList = _safeList(json['highlights'])
        .whereType<Map<String, dynamic>>()
        .map(InsightHighlight.fromJson)
        .toList();
    return InsightEdition(
      id: json['id'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      summary: json['summary'] as String? ?? '',
      highlights: highlightList,
      buckets: _safeStringList(json['buckets']),
    );
  }

  static List<InsightEdition> listFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(InsightEdition.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<InsightEdition> editions) {
    return jsonEncode(editions.map((item) => item.toJson()).toList());
  }
}

class LocalInsights {
  final List<String> topWords;
  final List<InsightIdeaNote> ideaNotes;
  final List<FocusArea> focus;
  final List<TodoItem> actions;
  final String editorial;

  const LocalInsights({
    required this.topWords,
    required this.ideaNotes,
    required this.focus,
    required this.actions,
    required this.editorial,
  });
}
