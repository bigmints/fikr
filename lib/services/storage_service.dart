import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:get/get.dart';

import '../models/app_config.dart';
import '../models/insights_models.dart';
import '../models/llm_provider.dart';
import '../models/note.dart';

class StorageService extends GetxService {
  StorageService();

  final _initCompleter = Completer<void>();
  Future<void> get isReady => _initCompleter.future;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  late Directory _baseDir;
  late Directory _audioDir;
  late File _notesFile;
  late File _configFile;
  late File _insightsFile;
  late File _tasksFile;
  late File _remindersFile;

  static const _kOnboardingCompleteKey = 'onboarding_complete';
  static const _kSubscriptionKey = 'subscription_tier';
  static const _kAIDataConsentKey = 'ai_data_consent';

  Future<bool> isOnboardingComplete() async {
    final value = await _secureStorage.read(key: _kOnboardingCompleteKey);
    return value == 'true';
  }

  Future<void> setOnboardingComplete() async {
    await _secureStorage.write(key: _kOnboardingCompleteKey, value: 'true');
  }

  Future<void> saveSubscriptionStatus(String tier) async {
    await _secureStorage.write(key: _kSubscriptionKey, value: tier);
  }

  Future<String> getSubscriptionStatus() async {
    return await _secureStorage.read(key: _kSubscriptionKey) ?? 'free';
  }

  Future<bool> hasAIDataConsent() async {
    final value = await _secureStorage.read(key: _kAIDataConsentKey);
    return value == 'true';
  }

  Future<void> setAIDataConsent(bool consent) async {
    await _secureStorage.write(
      key: _kAIDataConsentKey,
      value: consent ? 'true' : 'false',
    );
  }

  String get audioDirPath => _audioDir.path;

  Future<void> init() async {
    if (_initCompleter.isCompleted) return;
    try {
      _baseDir = await getApplicationSupportDirectory();
      _audioDir = Directory(p.join(_baseDir.path, 'audio'));
      if (!await _audioDir.exists()) {
        await _audioDir.create(recursive: true);
      }
      _notesFile = File(p.join(_baseDir.path, 'notes.json'));
      _configFile = File(p.join(_baseDir.path, 'config.json'));
      _insightsFile = File(p.join(_baseDir.path, 'insight_editions.json'));
      _tasksFile = File(p.join(_baseDir.path, 'tasks.json'));
      _remindersFile = File(p.join(_baseDir.path, 'reminders.json'));
      _initCompleter.complete();
    } catch (e, stack) {
      debugPrint('StorageService Init Error: $e');
      _initCompleter.completeError(e, stack);
    }
  }

  Future<AppConfig> loadConfig() async {
    await isReady;
    final hasConfig = await _configFile.exists();
    if (!hasConfig) {
      return AppConfig.fromJson({});
    }

    final raw = await _configFile.readAsString();
    final data = _decodeJson(raw);

    // Legacy migration: very old format without providers list
    if (data['providers'] == null &&
        data['activeProvider'] == null &&
        data['provider'] != null) {
      return _migrateLegacyConfig(data);
    }

    return AppConfig.fromJson(data);
  }

  /// Migration from very old single-string provider format.
  Future<AppConfig> _migrateLegacyConfig(Map<String, dynamic> data) async {
    final oldProvider = data['provider'] as String? ?? 'openai';
    final oldModel = data['model'] as String? ?? '';
    final oldTranscriptionModel = data['transcriptionModel'] as String? ?? '';
    final oldBaseUrl = data['baseUrl'] as String?;

    final providerType = LLMProviderType.values.firstWhere(
      (e) => e.name == oldProvider,
      orElse: () => LLMProviderType.openai,
    );

    final provider = LLMProvider(
      id: '$oldProvider-default',
      name: providerType.displayName,
      type: providerType,
      baseUrl: oldBaseUrl ?? providerType.defaultBaseUrl,
    );

    // Migrate API key
    final oldKey =
        await _secureStorage.read(key: 'apiKey_$oldProvider') ??
        await _secureStorage.read(key: 'apiKey');
    if (oldKey != null) {
      await saveApiKey(provider.id, oldKey);
    }

    final config = AppConfig(
      activeProvider: provider,
      analysisModel: oldModel,
      transcriptionModel: oldTranscriptionModel,
      language: data['language'] as String? ?? 'en',
      transcriptStyle: data['transcriptStyle'] as String? ?? 'cleaned',
      multiBucket: data['multiBucket'] as bool? ?? true,
      autoStopSilence: data['autoStopSilence'] as bool? ?? true,
      silenceSeconds: data['silenceSeconds'] as int? ?? 5,
      buckets: (data['buckets'] as List<dynamic>? ?? []).cast<String>(),
      themeMode: 'system',
    );

    // Persist migrated config
    await saveConfig(config);
    return config;
  }

  Future<void> saveConfig(AppConfig config) async {
    await isReady;
    await _configFile.writeAsString(jsonEncode(config.toJson()));
  }

  Future<void> saveApiKey(String providerId, String apiKey) async {
    final keyName = 'apiKey_$providerId';
    if (apiKey.isEmpty) {
      await _secureStorage.delete(key: keyName);
    } else {
      await _secureStorage.write(key: keyName, value: apiKey);
    }
  }

  Future<void> deleteApiKey(String providerId) async {
    await _secureStorage.delete(key: 'apiKey_$providerId');
  }

  Future<String?> getApiKey(String providerId) =>
      _secureStorage.read(key: 'apiKey_$providerId');

  Future<List<Note>> loadNotes() async {
    await isReady;
    if (!await _notesFile.exists()) {
      return [];
    }
    final raw = await _notesFile.readAsString();
    return Note.listFromJson(raw);
  }

  Future<void> saveNotes(List<Note> notes) async {
    await isReady;
    await _notesFile.writeAsString(Note.listToJson(notes));
  }

  Future<List<InsightEdition>> loadInsightEditions() async {
    await isReady;
    if (!await _insightsFile.exists()) {
      return [];
    }
    final raw = await _insightsFile.readAsString();
    return InsightEdition.listFromJson(raw);
  }

  Future<void> saveInsightEditions(List<InsightEdition> editions) async {
    await isReady;
    await _insightsFile.writeAsString(InsightEdition.listToJson(editions));
  }

  Future<List<TodoItem>> loadTasks() async {
    await isReady;
    if (!await _tasksFile.exists()) {
      return [];
    }
    final raw = await _tasksFile.readAsString();
    return TodoItem.listFromJson(raw);
  }

  Future<void> saveTasks(List<TodoItem> tasks) async {
    await isReady;
    await _tasksFile.writeAsString(TodoItem.listToJson(tasks));
  }

  Future<List<ReminderItem>> loadReminders() async {
    await isReady;
    if (!await _remindersFile.exists()) {
      return [];
    }
    final raw = await _remindersFile.readAsString();
    return ReminderItem.listFromJson(raw);
  }

  Future<void> saveReminders(List<ReminderItem> reminders) async {
    await isReady;
    await _remindersFile.writeAsString(ReminderItem.listToJson(reminders));
  }

  Future<void> clearAll() async {
    await isReady;
    if (await _notesFile.exists()) {
      await _notesFile.delete();
    }
    if (await _audioDir.exists()) {
      await _audioDir.delete(recursive: true);
    }
    await _audioDir.create(recursive: true);
  }

  Map<String, dynamic> _decodeJson(String raw) {
    if (raw.trim().isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}
