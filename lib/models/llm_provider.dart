// ── Provider types ──────────────────────────────────────────────────────────

enum LLMProviderType { openai, gemini, openrouter }

extension LLMProviderTypeExtension on LLMProviderType {
  String get displayName {
    switch (this) {
      case LLMProviderType.openai:
        return 'OpenAI';
      case LLMProviderType.gemini:
        return 'Google Gemini';
      case LLMProviderType.openrouter:
        return 'OpenRouter';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case LLMProviderType.openai:
        return 'https://api.openai.com/v1';
      case LLMProviderType.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case LLMProviderType.openrouter:
        return 'https://openrouter.ai/api/v1';
    }
  }
}

// ── Task preset names ───────────────────────────────────────────────────────
// Mirrors the @preset/fikr-* names used in fikr-pad and fikr.one.

class FikrPreset {
  static const analysis      = '@preset/fikr-analysis';
  static const tools         = '@preset/fikr-tools';
  static const transcription = '@preset/fikr-transcription';
  static const vision        = '@preset/fikr-vision';
  static const embedding     = '@preset/fikr-embedding';
}

// ── Preset model IDs per task per provider ──────────────────────────────────
// Null = use the model stored in LLMProvider.customModelName (custom provider).

/// Default model IDs per task per provider.
///
/// - OpenAI / Gemini: concrete model IDs used directly.
/// - OpenRouter BYOK: concrete model IDs that MIRROR what the @preset/fikr-*
///   server presets route to. This means BYOK OpenRouter users get the same
///   model quality as Pro managed users — just using their own API key.
///   When the server presets are updated, also update this table to match.
const Map<String, Map<LLMProviderType, String?>> kPresetModels = {
  'analysis': {
    LLMProviderType.openai:            'gpt-4o-mini',
    LLMProviderType.gemini:            'gemini-2.0-flash-lite',
    LLMProviderType.openrouter:        'google/gemini-2.0-flash-001',  // mirrors @preset/fikr-analysis
  },
  'tools': {
    LLMProviderType.openai:            'gpt-4o-mini',
    LLMProviderType.gemini:            'gemini-2.0-flash-lite',
    LLMProviderType.openrouter:        'google/gemini-2.0-flash-001',  // mirrors @preset/fikr-tools
  },
  'transcription': {
    LLMProviderType.openai:            'whisper-1',
    LLMProviderType.gemini:            'gemini-2.0-flash',
    LLMProviderType.openrouter:        'openai/whisper-large-v3',      // mirrors @preset/fikr-transcription
  },
  'vision': {
    LLMProviderType.openai:            'gpt-4o-mini',
    LLMProviderType.gemini:            'gemini-2.0-flash',
    LLMProviderType.openrouter:        'google/gemini-2.0-flash-001',  // mirrors @preset/fikr-vision
  },
  'embedding': {
    LLMProviderType.openai:            'text-embedding-3-small',
    LLMProviderType.gemini:            'text-embedding-004',
    LLMProviderType.openrouter:        'openai/text-embedding-3-small', // mirrors @preset/fikr-embedding
  },
};

// ── Available model IDs per task per provider (for settings UI pickers) ──────

const Map<String, Map<LLMProviderType, List<String>>> kAvailableModels = {
  'analysis': {
    LLMProviderType.openai:     ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1', 'gpt-4.1-mini', 'o4-mini'],
    LLMProviderType.gemini:     ['gemini-2.0-flash-lite', 'gemini-2.0-flash', 'gemini-2.5-pro-preview-03-25', 'gemini-1.5-pro'],
    LLMProviderType.openrouter: [
      'google/gemini-2.0-flash-lite-001',
      'google/gemini-2.5-pro-preview-03-25',
      'anthropic/claude-sonnet-4-5',
      'openai/gpt-4o',
      'openai/gpt-4o-mini',
      'deepseek/deepseek-chat',
      'mistralai/mistral-small-3.2-24b-instruct',
    ],
  },
  'tools': {
    LLMProviderType.openai:     ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini'],
    LLMProviderType.gemini:     ['gemini-2.0-flash-lite', 'gemini-2.0-flash'],
    LLMProviderType.openrouter: ['google/gemini-2.0-flash-lite-001', 'openai/gpt-4o-mini', 'deepseek/deepseek-chat'],
  },
  'transcription': {
    LLMProviderType.openai:     ['whisper-1', 'gpt-4o-transcribe', 'gpt-4o-mini-transcribe'],
    LLMProviderType.gemini:     ['gemini-2.0-flash', 'gemini-2.0-flash-lite', 'gemini-1.5-pro'],
    LLMProviderType.openrouter: ['openai/whisper-large-v3', 'openai/gpt-4o-transcribe'],
  },
  'vision': {
    LLMProviderType.openai:     ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1'],
    LLMProviderType.gemini:     ['gemini-2.0-flash', 'gemini-2.0-flash-lite', 'gemini-2.5-pro-preview-03-25'],
    LLMProviderType.openrouter: [
      'google/gemini-2.0-flash-lite-001',
      'google/gemini-2.0-flash-001',
      'openai/gpt-4o-mini',
      'anthropic/claude-sonnet-4-5',
    ],
  },
  'embedding': {
    LLMProviderType.openai:     ['text-embedding-3-small', 'text-embedding-3-large', 'text-embedding-ada-002'],
    LLMProviderType.gemini:     ['text-embedding-004', 'gemini-embedding-exp-03-07'],
    LLMProviderType.openrouter: ['openai/text-embedding-3-small', 'openai/text-embedding-3-large'],
  },
};

// ── LLMProvider model ───────────────────────────────────────────────────────

class LLMProvider {
  LLMProvider({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    // Per-task overrides. null = use preset default for this provider.
    this.analysisModel,
    this.toolsModel,
    this.transcriptionModel,
    this.visionModel,
    this.embeddingModel,
    this.isActive = true,
  });

  final String id;
  final String name;
  final LLMProviderType type;
  final String baseUrl;

  // Per-task model overrides (null → preset default)
  final String? analysisModel;
  final String? toolsModel;
  final String? transcriptionModel;
  final String? visionModel;
  final String? embeddingModel;

  final bool isActive;

  String resolveModel(String taskKey) {
    final override = _override(taskKey);
    if (override != null && override.isNotEmpty) return override;
    return kPresetModels[taskKey]?[type] ?? '';
  }

  String? _override(String taskKey) {
    switch (taskKey) {
      case 'analysis':      return analysisModel;
      case 'tools':         return toolsModel;
      case 'transcription': return transcriptionModel;
      case 'vision':        return visionModel;
      case 'embedding':     return embeddingModel;
      default:              return null;
    }
  }

  LLMProvider copyWith({
    String? id,
    String? name,
    LLMProviderType? type,
    String? baseUrl,
    String? analysisModel,
    String? toolsModel,
    String? transcriptionModel,
    String? visionModel,
    String? embeddingModel,
    bool? isActive,
  }) {
    return LLMProvider(
      id:                 id                 ?? this.id,
      name:               name               ?? this.name,
      type:               type               ?? this.type,
      baseUrl:            baseUrl            ?? this.baseUrl,
      analysisModel:      analysisModel      ?? this.analysisModel,
      toolsModel:         toolsModel         ?? this.toolsModel,
      transcriptionModel: transcriptionModel ?? this.transcriptionModel,
      visionModel:        visionModel        ?? this.visionModel,
      embeddingModel:     embeddingModel     ?? this.embeddingModel,
      isActive:           isActive           ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':                 id,
      'name':               name,
      'type':               type.name,
      'baseUrl':            baseUrl,
      if (analysisModel      != null) 'analysisModel':      analysisModel,
      if (toolsModel         != null) 'toolsModel':         toolsModel,
      if (transcriptionModel != null) 'transcriptionModel': transcriptionModel,
      if (visionModel        != null) 'visionModel':        visionModel,
      if (embeddingModel     != null) 'embeddingModel':     embeddingModel,
      'isActive':           isActive,
    };
  }

  factory LLMProvider.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'openrouter';

    // Migration map for old type names
    final typeMap = {
      'google': LLMProviderType.gemini,           // old: google → gemini
      'openai': LLMProviderType.openai,
      'openrouter': LLMProviderType.openrouter,
      'gemini': LLMProviderType.gemini,
    };
    final type = typeMap[typeStr] ?? LLMProviderType.openrouter;
    return LLMProvider(
      id:                 json['id'] as String,
      name:               json['name'] as String,
      type:               type,
      baseUrl:            json['baseUrl'] as String? ?? type.defaultBaseUrl,
      analysisModel:      json['analysisModel']      as String?,
      toolsModel:         json['toolsModel']         as String?,
      transcriptionModel: json['transcriptionModel'] as String?,
      visionModel:        json['visionModel']        as String?,
      embeddingModel:     json['embeddingModel']     as String?,
      isActive:           json['isActive'] as bool? ?? true,
    );
  }
}
