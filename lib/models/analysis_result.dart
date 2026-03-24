class AnalysisResult {
  AnalysisResult({
    required this.cleanedText,
    required this.intent,
    required this.bucket,
    required this.topics,
  });

  final String cleanedText;
  final String intent;
  final String bucket;
  final List<String> topics;

  Map<String, dynamic> toJson() => {
    'cleanedText': cleanedText,
    'intent': intent,
    'bucket': bucket,
    'topics': topics,
  };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      cleanedText: json['cleanedText'] as String? ?? '',
      intent: json['intent'] as String? ?? '',
      bucket: json['bucket'] as String? ?? 'General',
      topics: _safeStringList(json['topics']),
    );
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
