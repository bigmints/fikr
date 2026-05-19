import 'note_content_type.dart';

class AnalysisResult {
  AnalysisResult({
    required this.cleanedText,
    required this.intent,
    required this.bucket,
    required this.topics,
    this.contentType = NoteContentType.general,
  });

  final String cleanedText;
  final String intent;
  final String bucket;

  /// Fikr Studio content type — ONE of the 13 canonical types.
  final NoteContentType contentType;

  /// Legacy topics field — kept for backward compat but should be empty
  /// going forward. The [contentType] field replaces free-form topics.
  final List<String> topics;

  Map<String, dynamic> toJson() => {
    'cleanedText': cleanedText,
    'intent': intent,
    'bucket': bucket,
    'contentType': contentType.name,
    'topics': topics,
  };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      cleanedText: json['cleanedText'] as String? ?? '',
      intent: json['intent'] as String? ?? '',
      bucket: json['bucket'] as String? ?? 'General',
      contentType: NoteContentType.fromString(json['contentType'] as String?),
      // topics: accept from LLM but constrain to valid Studio type names only.
      // Free-form strings are filtered out — only canonical type names survive.
      topics: _clampToStudioTypes(json['topics']),
    );
  }

  /// Accepts a raw LLM topics value and filters it to only Studio type names.
  /// This prevents free-form topics like "Fikr App Flutter" from polluting state.
  static List<String> _clampToStudioTypes(dynamic value) {
    final validNames = NoteContentType.values.map((t) => t.name).toSet();
    final raw = _safeStringList(value);
    final filtered = raw.where((t) => validNames.contains(t.toLowerCase())).toList();
    return filtered;
  }

  static List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}
