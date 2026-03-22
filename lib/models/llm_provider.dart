enum LLMProviderType { openai, google, openrouter }

extension LLMProviderTypeExtension on LLMProviderType {
  String get displayName {
    switch (this) {
      case LLMProviderType.openai:
        return 'OpenAI';
      case LLMProviderType.google:
        return 'Google Gemini';
      case LLMProviderType.openrouter:
        return 'OpenRouter';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case LLMProviderType.openai:
        return 'https://api.openai.com/v1';
      case LLMProviderType.google:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case LLMProviderType.openrouter:
        return 'https://openrouter.ai/api/v1';
    }
  }

  String get defaultAnalysisModel {
    switch (this) {
      case LLMProviderType.openai:
        return 'gpt-4o';
      case LLMProviderType.google:
        return 'gemini-2.0-flash';
      case LLMProviderType.openrouter:
        return 'google/gemini-2.0-flash-001';
    }
  }

  String get defaultTranscriptionModel {
    switch (this) {
      case LLMProviderType.openai:
        return 'whisper-1';
      case LLMProviderType.google:
        return 'gemini-2.0-flash';
      case LLMProviderType.openrouter:
        return 'google/gemini-2.0-flash-001';
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
    return LLMProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      type: LLMProviderType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LLMProviderType.openai,
      ),
      baseUrl: json['baseUrl'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
