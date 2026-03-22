import 'package:flutter/material.dart';

import 'llm_provider.dart';

class AppConfig {
  AppConfig({
    required this.activeProvider,
    required this.analysisModel,
    required this.transcriptionModel,
    required this.language,
    required this.transcriptStyle,
    required this.multiBucket,
    required this.autoStopSilence,
    required this.silenceSeconds,
    required this.buckets,
    required this.themeMode,
  });

  /// The single active LLM provider (OpenAI, Google Gemini, OpenRouter).
  final LLMProvider? activeProvider;

  /// Model used for analysis (chat completions / generateContent).
  final String analysisModel;

  /// Model used for transcription.
  final String transcriptionModel;

  final String language;
  final String transcriptStyle;
  final bool multiBucket;
  final bool autoStopSilence;
  final int silenceSeconds;
  final List<String> buckets;
  final String themeMode;

  AppConfig copyWith({
    LLMProvider? activeProvider,
    bool clearProvider = false,
    String? analysisModel,
    String? transcriptionModel,
    String? language,
    String? transcriptStyle,
    bool? multiBucket,
    bool? autoStopSilence,
    int? silenceSeconds,
    List<String>? buckets,
    String? themeMode,
  }) {
    return AppConfig(
      activeProvider: clearProvider
          ? null
          : (activeProvider ?? this.activeProvider),
      analysisModel: analysisModel ?? this.analysisModel,
      transcriptionModel: transcriptionModel ?? this.transcriptionModel,
      language: language ?? this.language,
      transcriptStyle: transcriptStyle ?? this.transcriptStyle,
      multiBucket: multiBucket ?? this.multiBucket,
      autoStopSilence: autoStopSilence ?? this.autoStopSilence,
      silenceSeconds: silenceSeconds ?? this.silenceSeconds,
      buckets: buckets ?? this.buckets,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeProvider': activeProvider?.toJson(),
      'analysisModel': analysisModel,
      'transcriptionModel': transcriptionModel,
      'language': language,
      'transcriptStyle': transcriptStyle,
      'multiBucket': multiBucket,
      'autoStopSilence': autoStopSilence,
      'silenceSeconds': silenceSeconds,
      'buckets': buckets,
      'themeMode': themeMode,
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    // ── Migration: old multi-provider format → single provider ──
    LLMProvider? provider;
    if (json['activeProvider'] != null) {
      provider = LLMProvider.fromJson(
        json['activeProvider'] as Map<String, dynamic>,
      );
    } else if (json['providers'] != null) {
      // Legacy: pick the first provider from the old list
      final list = json['providers'] as List<dynamic>;
      if (list.isNotEmpty) {
        provider = LLMProvider.fromJson(list.first as Map<String, dynamic>);
      }
    }

    // Legacy model migration
    final analysisModel =
        json['analysisModel'] as String? ??
        json['selectedChatModel'] as String? ??
        '';
    final transcriptionModel =
        json['transcriptionModel'] as String? ??
        json['selectedTranscriptionModel'] as String? ??
        '';

    return AppConfig(
      activeProvider: provider,
      analysisModel: analysisModel,
      transcriptionModel: transcriptionModel,
      language: json['language'] as String? ?? 'en',
      transcriptStyle: json['transcriptStyle'] as String? ?? 'cleaned',
      multiBucket: json['multiBucket'] as bool? ?? true,
      autoStopSilence: json['autoStopSilence'] as bool? ?? true,
      silenceSeconds: json['silenceSeconds'] as int? ?? 5,
      buckets: (json['buckets'] as List<dynamic>? ?? _defaultBuckets)
          .cast<String>(),
      themeMode: json['themeMode'] as String? ?? 'system',
    );
  }

  static Color getBucketColor(String bucket) {
    final Map<String, Color> maps = {
      'Personal Life': const Color.fromARGB(255, 255, 0, 8),
      'Health & Fitness': const Color.fromARGB(255, 0, 255, 13),
      'Work Life': const Color.fromARGB(255, 1, 196, 255),
      'Finance': const Color.fromARGB(255, 255, 204, 0),
      'General': const Color.fromARGB(255, 0, 102, 255),
    };

    if (maps.containsKey(bucket)) return maps[bucket]!;

    int hash = 5381;
    for (int i = 0; i < bucket.length; i++) {
      hash = ((hash << 5) + hash) + bucket.codeUnitAt(i);
    }
    hash = hash.abs();

    final double hue = (hash % 360).toDouble();
    const double saturation = 0.5;
    const double lightness = 0.85;

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  static const List<String> _defaultBuckets = [
    'Personal Life',
    'Health & Fitness',
    'Work Life',
    'Finance',
    'General',
  ];
}
