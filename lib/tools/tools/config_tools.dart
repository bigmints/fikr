/// Config domain tools — read/write app settings.
library;

import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  config.get
// ───────────────────────────────────────────────────────────────────────────

class ConfigGetTool extends FikrTool {
  @override
  String get name => 'config.get';

  @override
  String get description =>
      'Read the current app configuration values (language, buckets, etc.).';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'key': {
        'type': 'string',
        'description':
            'Optional specific key to read (e.g. "language", "buckets"). '
            'If omitted, returns all config.',
      },
    },
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final configJson = context.config.toJson();
      final key = params['key'] as String?;

      if (key != null && key.isNotEmpty) {
        if (!configJson.containsKey(key)) {
          return ToolResult.fail('Unknown config key: $key');
        }
        return ToolResult.ok({key: configJson[key]});
      }

      return ToolResult.ok(configJson);
    } catch (e) {
      return ToolResult.fail('Failed to read config: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  config.set
// ───────────────────────────────────────────────────────────────────────────

class ConfigSetTool extends FikrTool {
  @override
  String get name => 'config.set';

  @override
  String get description =>
      'Update an app configuration value. Supported keys: language, '
      'transcriptStyle, multiBucket, autoStopSilence, silenceSeconds, themeMode.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'key': {'type': 'string', 'description': 'Config key to update.'},
      'value': {'description': 'New value for the key.'},
    },
    'required': ['key', 'value'],
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = Get.find<AppController>();
      final key = params['key'] as String;
      final value = params['value'];

      final current = ctrl.config.value;
      late final updatedConfig = switch (key) {
        'language' => current.copyWith(language: value as String),
        'transcriptStyle' => current.copyWith(transcriptStyle: value as String),
        'multiBucket' => current.copyWith(multiBucket: value as bool),
        'autoStopSilence' => current.copyWith(autoStopSilence: value as bool),
        'silenceSeconds' => current.copyWith(silenceSeconds: value as int),
        'themeMode' => current.copyWith(themeMode: value as String),
        _ => throw ArgumentError('Unsupported config key: $key'),
      };

      await ctrl.updateConfig(updatedConfig);
      return ToolResult.ok({key: value});
    } catch (e) {
      return ToolResult.fail('Failed to update config: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  config.buckets
// ───────────────────────────────────────────────────────────────────────────

class ConfigBucketsTool extends FikrTool {
  @override
  String get name => 'config.buckets';

  @override
  String get description =>
      'Get or update the list of note buckets (categories).';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'buckets': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'New bucket list. If omitted, returns current buckets.',
      },
    },
  };

  @override
  ToolTier get requiredTier => ToolTier.free;

  @override
  ToolLocation get location => ToolLocation.local;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final ctrl = Get.find<AppController>();
      final newBuckets = (params['buckets'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList();

      if (newBuckets != null) {
        await ctrl.updateConfig(
          ctrl.config.value.copyWith(buckets: newBuckets),
        );
        return ToolResult.ok({'buckets': newBuckets});
      }

      return ToolResult.ok({'buckets': context.config.buckets});
    } catch (e) {
      return ToolResult.fail('Failed to manage buckets: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allConfigTools() => [
      ConfigGetTool(),
      ConfigSetTool(),
      ConfigBucketsTool(),
    ];
