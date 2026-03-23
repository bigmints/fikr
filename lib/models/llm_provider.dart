enum LLMProviderType { openai, google }

extension LLMProviderTypeExtension on LLMProviderType {
  String get displayName {
    switch (this) {
      case LLMProviderType.openai:
        return 'OpenAI';
      case LLMProviderType.google:
        return 'Google Gemini';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case LLMProviderType.openai:
        return 'https://api.openai.com/v1';
      case LLMProviderType.google:
        return 'https://generativelanguage.googleapis.com/v1beta';
    }
  }

  /// Hardcoded fallback — only used if Remote Config is unreachable.
  String get fallbackAnalysisModel {
    switch (this) {
      case LLMProviderType.openai:
        return 'gpt-4o';
      case LLMProviderType.google:
        return 'gemini-2.0-flash';
    }
  }

  /// Hardcoded fallback — only used if Remote Config is unreachable.
  String get fallbackTranscriptionModel {
    switch (this) {
      case LLMProviderType.openai:
        return 'whisper-1';
      case LLMProviderType.google:
        return 'gemini-2.0-flash';
    }
  }
}

class LLMProvider {
  LLMProvider({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    this.isActive = true,
  });

  final String id;
  final String name;
  final LLMProviderType type;
  final String baseUrl;
  final bool isActive;

  LLMProvider copyWith({
    String? id,
    String? name,
    LLMProviderType? type,
    String? baseUrl,
    bool? isActive,
  }) {
    return LLMProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'baseUrl': baseUrl,
      'isActive': isActive,
    };
  }

  factory LLMProvider.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    // Map legacy 'openrouter' entries to 'google' (graceful migration)
    final type = LLMProviderType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => LLMProviderType.google,
    );
    return LLMProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      baseUrl: json['baseUrl'] as String? ?? type.defaultBaseUrl,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
