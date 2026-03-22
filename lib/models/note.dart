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
  final bool archived;

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
    this.archived = false,
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
    bool? archived,
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
      archived: archived ?? this.archived,
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
      'archived': archived,
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
      topics: (json['topics'] as List<dynamic>? ?? [])
          .where((t) => t != null)
          .map((t) => t.toString())
          .toList(),
      audioPath: json['audioPath'] as String?,
      archived: json['archived'] as bool? ?? false,
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

  static String listToJson(List<Note> notes) {
    final data = {'notes': notes.map((note) => note.toJson()).toList()};
    return jsonEncode(data);
  }
}
