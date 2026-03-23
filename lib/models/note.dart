import 'dart:convert';

class Note {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final String text;
  final String transcript;
  final String intent;
  final String bucket;
  final List<String> topics;
  final String? audioPath;
  final String? audioUrl;
  final bool archived;
  final bool isProcessing;

  Note({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    required this.text,
    required this.transcript,
    required this.intent,
    this.bucket = 'General',
    required this.topics,
    this.audioPath,
    this.audioUrl,
    this.archived = false,
    this.isProcessing = false,
  });

  String get snippet => text.isNotEmpty
      ? text
      : (transcript.isNotEmpty ? transcript : 'No content');

  Note copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    String? text,
    String? transcript,
    String? intent,
    String? bucket,
    List<String>? topics,
    String? audioPath,
    String? audioUrl,
    bool? archived,
    bool? isProcessing,
  }) {
    return Note(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      text: text ?? this.text,
      transcript: transcript ?? this.transcript,
      intent: intent ?? this.intent,
      bucket: bucket ?? this.bucket,
      topics: topics ?? this.topics,
      audioPath: audioPath ?? this.audioPath,
      audioUrl: audioUrl ?? this.audioUrl,
      archived: archived ?? this.archived,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'title': title,
      'text': text,
      'transcript': transcript,
      'intent': intent,
      'bucket': bucket,
      'topics': topics,
      'audioPath': audioPath,
      'audioUrl': audioUrl,
      'archived': archived,
      'isProcessing': isProcessing,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      transcript: json['transcript'] as String? ?? '',
      intent: json['intent'] as String? ?? '',
      bucket: json['bucket'] as String? ?? 'General',
      topics: _parseStringList(json['topics']),
      audioPath: json['audioPath'] as String?,
      audioUrl: json['audioUrl'] as String?,
      archived: json['archived'] as bool? ?? false,
      isProcessing: json['isProcessing'] as bool? ?? false,
    );
  }

  static List<Note> listFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return [];
      final items = (decoded['notes'] as List<dynamic>? ?? []);
      return items
          .whereType<Map<String, dynamic>>()
          .map((item) => Note.fromJson(item))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Safely parses a JSON value that should be a `List<String>` but may arrive
  /// as a plain String (legacy Firestore data) or null.
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.where((t) => t != null).map((t) => t.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  static String listToJson(List<Note> notes) {
    final data = {'notes': notes.map((note) => note.toJson()).toList()};
    return jsonEncode(data);
  }
}
