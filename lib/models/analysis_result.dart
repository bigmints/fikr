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

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      cleanedText: json['cleanedText'] as String? ?? '',
      intent: json['intent'] as String? ?? '',
      bucket: json['bucket'] as String? ?? 'General',
      topics: (json['topics'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}
