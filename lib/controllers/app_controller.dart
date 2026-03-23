import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:fikr/models/insights_models.dart';
import 'subscription_controller.dart';

import '../models/analysis_result.dart';
import '../models/app_config.dart';
import '../models/llm_provider.dart';
import '../models/note.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import '../services/sync_service.dart';
import '../services/firebase_service.dart';
import '../services/fikr_api_service.dart';
import '../services/widget_service.dart';
import '../widgets/ai_data_consent_dialog.dart';
import 'theme_controller.dart';
import 'package:flutter/material.dart';

class AppController extends GetxController with WidgetsBindingObserver {
  AppController({StorageService? storageService, LLMService? llmService})
    : storage = storageService ?? Get.find<StorageService>(),
      openAI = llmService ?? Get.find<LLMService>(),
      subscription = Get.put(SubscriptionController());

  final StorageService storage;
  final LLMService openAI;
  final SubscriptionController subscription;
  final AudioPlayer _player = AudioPlayer();

  final Rx<AppConfig> config = AppConfig(
    activeProvider: null,
    analysisModel: '',
    transcriptionModel: '',
    language: 'en',
    transcriptStyle: 'cleaned',
    multiBucket: true,
    autoStopSilence: true,
    silenceSeconds: 5,
    buckets: const [
      'Personal Life',
      'Health & Fitness',
      'Work Life',
      'Finance',
      'General',
    ],
    themeMode: 'system',
  ).obs;

  final RxList<Note> notes = <Note>[].obs;
  final Rx<Note?> selectedNote = Rx<Note?>(null);
  final RxString selectedBucket = 'All'.obs;
  final RxString sortOrder = 'newest'.obs;
  final RxString groupBy = 'day'.obs;
  final RxBool showFilters = false.obs;
  final RxString searchQuery = ''.obs;
  final RxBool loading = false.obs;
  final RxBool canRecord = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<TodoItem> todoItems = <TodoItem>[].obs;
  final RxList<ReminderItem> reminders = <ReminderItem>[].obs;
  final RxList<InsightEdition> insightEditions = <InsightEdition>[].obs;
  final Rx<GeneratedInsights?> generatedInsights = Rx<GeneratedInsights?>(null);
  final RxBool insightsUpdating = false.obs;
  final RxString insightsUpdateStatus = ''.obs;
  final RxList<String> selectedInsightBuckets = <String>[].obs;

  /// Usage stats for Pro tier users. Null when not Pro or not yet fetched.
  final Rx<ProUsageStats?> proUsageStats = Rx<ProUsageStats?>(null);

  List<Note> get filteredNotes {
    var filtered = selectedBucket.value == 'All'
        ? notes.toList()
        : notes.where((note) {
            return note.bucket == selectedBucket.value;
          }).toList();

    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((note) {
        return note.title.toLowerCase().contains(query) ||
            note.text.toLowerCase().contains(query) ||
            note.transcript.toLowerCase().contains(query) ||
            note.bucket.toLowerCase().contains(query) ||
            note.topics.any((t) => t.toLowerCase().contains(query));
      }).toList();
    }

    filtered.sort((a, b) {
      switch (sortOrder.value) {
        case 'oldest':
          return a.createdAt.compareTo(b.createdAt);
        case 'updated':
          return b.updatedAt.compareTo(a.updatedAt);
        case 'newest':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return filtered;
  }

  void clearSearch() {
    searchQuery.value = '';
  }

  Future<void> initialize() async {
    await storage.init();

    // Initialize services
    Get.put(SyncService()); // Inject SyncService

    final loadedConfig = await storage.loadConfig();
    config.value = loadedConfig;

    // Apply saved theme
    final modeStr = loadedConfig.themeMode;
    final mode = ThemeMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => ThemeMode.system,
    );
    Get.find<ThemeController>().setThemeMode(mode);

    // Initialize Remote Config & Fetch Models
    try {
      final firebaseService = FirebaseService();
      await firebaseService.initialize();
      // In a real app, you would fetch remote config here and update
      // available models in `LLMProvider` or similar.
      // e.g., config.allowedModels = firebaseService.getAllowedModels();
    } catch (e) {
      debugPrint('Failed to init Firebase Service/Remote Config: $e');
    }

    notes.value = (await storage.loadNotes())
        .where((note) => !note.archived)
        .toList();

    // Check if we need to reset to the new bucket system
    final expectedBuckets = [
      'Personal Life',
      'Health & Fitness',
      'Work Life',
      'Finance',
      'General',
    ];
    final currentBuckets = config.value.buckets;
    final needsReset =
        currentBuckets.length != expectedBuckets.length ||
        !currentBuckets.every((b) => expectedBuckets.contains(b));

    if (needsReset) {
      await updateConfig(config.value.copyWith(buckets: expectedBuckets));
      await clearAll();
      await loadMockNotes();
    }

    insightEditions.value = await storage.loadInsightEditions();
    todoItems.value = await storage.loadTasks();
    reminders.value = await storage.loadReminders();
    if (todoItems.isEmpty) {
      todoItems.value = _extractActionItems(notes);
      await _saveTasks();
    }
    await refreshCanRecord();
    await _validateActiveProvider();

  }

  Future<void> updateConfig(AppConfig next) async {
    await storage.saveConfig(next);
    config.value = next;
    errorMessage.value = '';
    await refreshCanRecord();
  }

  Future<void> saveActiveModel(String model, {required bool isChat}) async {
    final next = isChat
        ? config.value.copyWith(analysisModel: model)
        : config.value.copyWith(transcriptionModel: model);
    await updateConfig(next);
  }

  Future<void> refreshCanRecord() async {
    final provider = config.value.activeProvider;

    debugPrint(
      'CanRecord check: provider=${provider?.name ?? 'none'}, '
      'type=${provider?.type.name ?? 'none'}',
    );

    if (provider == null) {
      debugPrint('CanRecord: No provider configured.');
      canRecord.value = false;
      return;
    }

    try {
      final apiKey = await storage.getApiKey(provider.id);

      debugPrint(
        'CanRecord: apiKey=${apiKey != null && apiKey.isNotEmpty ? 'present' : 'MISSING'}',
      );

      if (subscription.isPro) {
        canRecord.value = true;
        return;
      }

      canRecord.value = apiKey != null && apiKey.isNotEmpty;
      debugPrint('CanRecord: result=${canRecord.value}');
    } catch (e) {
      debugPrint('CanRecord error: $e');
      canRecord.value = false;
    }
  }

  Future<Note> createEmptyNote() async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final note = Note(
      id: id,
      createdAt: now,
      updatedAt: now,
      title: '',
      text: '',
      transcript: '',
      intent: '',
      bucket: 'General',
      topics: const [],
      audioPath: null,
      archived: false,
    );
    notes.insert(0, note);
    await saveNotes();
    return note;
  }

  Future<void> addNoteFromAudio(File tempAudioFile) async {
    errorMessage.value = '';

    final provider = config.value.activeProvider;
    final analysisModel = config.value.analysisModel;
    final transcriptionModel = config.value.transcriptionModel;

    if (provider == null) {
      errorMessage.value = 'Fikr isn\'t set up yet. Go to Settings.';
      return;
    }

    // Ensure user has consented to AI data sharing (App Store 5.1.1 / 5.1.2)
    if (!await _ensureAIConsent(provider)) return;

    // Check for Managed AI (Pro/Pro+)
    if (subscription.hasManagedVertexAI) {
      await _processWithManagedAI(tempAudioFile);
      return;
    }

    final apiKey = await storage.getApiKey(provider.id);
    if (apiKey == null || apiKey.isEmpty) {
      errorMessage.value = 'Missing API key. Go to Settings.';
      return;
    }

    try {
      final id = const Uuid().v4();
      final timestamp = DateTime.now();
      final audioPath = await _persistAudio(tempAudioFile, id);

      final dummyNote = Note(
        id: id,
        createdAt: timestamp,
        updatedAt: timestamp,
        title: 'Transcribing...',
        text: 'Your voice note is being processed.',
        transcript: '',
        intent: '',
        bucket: 'General',
        topics: const [],
        audioPath: audioPath,
        isProcessing: true,
      );
      notes.insert(0, dummyNote);
      notes.refresh();

      final transcript = await openAI.transcribeAudio(
        audioFile: File(audioPath),
        provider: provider,
        model: transcriptionModel,
        apiKey: apiKey,
        language: config.value.language,
      );

      if (transcript.trim().isEmpty) {
        notes.removeWhere((n) => n.id == id);
        notes.refresh();
        if (Get.context != null) {
          ToastService.showInfo(
            Get.context!,
            title: 'Nothing to save',
            description: 'No speech detected in the recording.',
          );
        }
        return;
      }

      final dummyAnalyze = dummyNote.copyWith(title: 'Analyzing...', text: 'Extracting insights from your note.');
      final index = notes.indexWhere((n) => n.id == id);
      if (index != -1) {
        notes[index] = dummyAnalyze;
        notes.refresh();
      }

      final analysis = await openAI.analyzeTranscript(
        transcript: transcript,
        provider: provider,
        model: analysisModel,
        apiKey: apiKey,
        buckets: config.value.buckets,
        multiBucket: config.value.multiBucket,
      );

      await _finalizeNoteCreation(
        id,
        timestamp,
        audioPath,
        transcript,
        analysis,
      );
    } catch (error) {
      debugPrint('Note processing error: $error');
      // On failure, remove the dummy note so it doesn't stay stuck
      if (notes.isNotEmpty && notes.first.isProcessing) {
         notes.removeWhere((n) => n.isProcessing && n.title.contains('...'));
         notes.refresh();
      }
      
      final errStr = error.toString();
      String userMessage;
      if (errStr.contains('401') || errStr.contains('403')) {
        userMessage = 'Invalid API key. Please check your API key in Settings.';
      } else if (errStr.contains('insufficient_quota') ||
          errStr.contains('exceeded')) {
        userMessage =
            'API quota exceeded. Please check your billing or plan with your provider.';
      } else if (errStr.contains('429')) {
        userMessage = 'Rate limited. Please wait a moment and try again.';
      } else if (errStr.contains('SocketException') ||
          errStr.contains('ClientException')) {
        userMessage = 'Network error. Please check your internet connection.';
      } else {
        userMessage =
            'Note processing failed. Please check your provider settings.';
      }
      _notifyError(userMessage);
    }
  }

  Future<void> fetchUsageStats() async {
    if (!subscription.hasManagedVertexAI) return;
    try {
      final stats = await FikrApiService().getUsageStats();
      proUsageStats.value = stats;
    } catch (e) {
      debugPrint('AppController.fetchUsageStats: $e');
    }
  }

  Future<void> _processWithManagedAI(File tempAudioFile) async {
    try {
      final id        = const Uuid().v4();
      final timestamp = DateTime.now();
      final audioPath = await _persistAudio(tempAudioFile, id);

      final dummyNote = Note(
        id: id,
        createdAt: timestamp,
        updatedAt: timestamp,
        title: 'Transcribing...',
        text: 'Your voice note is being processed by Cloud AI.',
        transcript: '',
        intent: '',
        bucket: 'General',
        topics: const [],
        audioPath: audioPath,
        isProcessing: true,
      );
      notes.insert(0, dummyNote);
      notes.refresh();

      final fikrApi = FikrApiService();

      // 1. Transcribe via fikr.one metered endpoint
      final String transcript;
      try {
        transcript = await fikrApi.transcribeAudio(File(audioPath));
      } catch (e) {
        notes.removeWhere((n) => n.id == id);
        notes.refresh();
        final errStr = e.toString();
        if (errStr.contains('429') || errStr.contains('limit')) {
          _notifyError(
            'Monthly transcription limit reached (500/month). '
            'Resets on the 1st of next month.',
          );
        } else {
          _notifyError('Transcription failed. Please try again.');
        }
        return;
      }

      if (transcript.trim().isEmpty) {
        notes.removeWhere((n) => n.id == id);
        notes.refresh();
        if (Get.context != null) {
          ToastService.showInfo(
            Get.context!,
            title: 'Nothing to save',
            description: 'No speech detected in the recording.',
          );
        }
        return;
      }

      final dummyAnalyze = dummyNote.copyWith(title: 'Analyzing...', text: 'Extracting insights from your note.');
      final index = notes.indexWhere((n) => n.id == id);
      if (index != -1) {
        notes[index] = dummyAnalyze;
        notes.refresh();
      }

      // 2. Analyze via fikr.one metered endpoint
      final Map<String, dynamic> analysisData;
      try {
        analysisData = await fikrApi.analyzeTranscript(
          transcript: transcript,
          buckets: config.value.buckets,
        );
      } catch (e) {
        notes.removeWhere((n) => n.id == id);
        notes.refresh();
        final errStr = e.toString();
        if (errStr.contains('429') || errStr.contains('limit')) {
          _notifyError(
            'Monthly analysis limit reached (500/month). '
            'Resets on the 1st of next month.',
          );
        } else {
          _notifyError('Analysis failed. Please try again.');
        }
        return;
      }

      final analysis = AnalysisResult.fromJson(analysisData);
      await _finalizeNoteCreation(id, timestamp, audioPath, transcript, analysis);

      // Refresh usage counters after a successful note creation
      unawaited(fetchUsageStats());
    } catch (error) {
      debugPrint('Managed AI processing error: $error');
      if (notes.isNotEmpty && notes.first.isProcessing) {
         notes.removeWhere((n) => n.isProcessing && n.title.contains('...'));
         notes.refresh();
      }
      _notifyError('Note processing failed. Please try again.');
    }
  }

  Future<void> _finalizeNoteCreation(
    String id,
    DateTime timestamp,
    String audioPath,
    String transcript,
    AnalysisResult analysis,
  ) async {
    final cleanedText = config.value.transcriptStyle == 'cleaned'
        ? analysis.cleanedText
        : transcript;

    final note = Note(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      title: analysis.intent.isNotEmpty
          ? analysis.intent
          : _generateFallbackTitle(transcript),
      text: cleanedText,
      transcript: transcript,
      intent: analysis.intent,
      bucket: analysis.bucket,
      topics: analysis.topics,
      audioPath: audioPath,
      archived: false,
      isProcessing: false,
    );

    final index = notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      notes[index] = note;
    } else {
      notes.insert(0, note);
    }
    notes.refresh();
    await saveNotes();
    // Notify native widget of the latest note.
    unawaited(
      WidgetService.updateLastNote(
        note.title.isNotEmpty ? note.title : note.snippet,
      ),
    );
  }

  /// Generates a short, meaningful title from the first few words of a transcript.
  String _generateFallbackTitle(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return 'Voice Note';

    final words = trimmed.split(RegExp(r'\s+'));
    const maxWords = 8;
    final snippet = words.take(maxWords).join(' ');
    final title = snippet.length > 50
        ? '${snippet.substring(0, 50)}…'
        : snippet;
    final ellipsis = words.length > maxWords ? '…' : '';

    // Capitalize first letter
    final result = '$title$ellipsis';
    return result[0].toUpperCase() + result.substring(1);
  }

  Future<String> _persistAudio(File tempAudioFile, String id) async {
    final extension = tempAudioFile.path.split('.').last;
    final destination = File('${storage.audioDirPath}/$id.$extension');
    await destination.writeAsBytes(await tempAudioFile.readAsBytes());
    return destination.path;
  }

  Future<void> saveNotes() async {
    await storage.saveNotes(notes.toList());
    if (subscription.canSync) {
      Get.find<SyncService>().syncToCloud();
    }
  }

  Future<void> saveInsightEditions() async {
    await storage.saveInsightEditions(insightEditions.toList());
  }

  Future<void> updateNote(Note updated) async {
    final index = notes.indexWhere((note) => note.id == updated.id);
    if (index == -1) return;
    notes[index] = updated;
    notes.refresh();
    if (selectedNote.value?.id == updated.id) {
      selectedNote.value = updated;
    }
    await saveNotes();
  }

  Future<void> archiveNote(String id) async {
    final index = notes.indexWhere((note) => note.id == id);
    if (index == -1) return;
    notes[index] = notes[index].copyWith(
      archived: true,
      updatedAt: DateTime.now(),
    );
    notes.removeAt(index);
    await saveNotes();
  }

  Future<void> deleteNote(String id) async {
    final existing = notes.firstWhereOrNull((note) => note.id == id);
    notes.removeWhere((note) => note.id == id);
    await saveNotes();
    if (selectedNote.value?.id == id) {
      selectedNote.value = null;
    }
    final audioPath = existing?.audioPath;
    if (audioPath != null) {
      try {
        final file = File(audioPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    // Delete from Firestore so it won't come back on sync
    if (subscription.canSync) {
      Get.find<SyncService>().deleteNoteFromCloud(id);
    }
  }

  Future<void> updateNoteTopics(Note note, List<String> topics) async {
    final updated = note.copyWith(topics: topics, updatedAt: DateTime.now());
    _ensureBuckets(topics);
    await updateNote(updated);
  }

  Future<void> updateNoteWithBuckets(Note updated) async {
    await updateNote(updated);
  }

  Future<void> playAudio(Note note) async {
    if (note.audioPath == null) return;
    try {
      await _player.setFilePath(note.audioPath!);
      await _player.play();
    } catch (_) {}
  }

  Future<String?> pickExportDirectory() async {
    if (Platform.isMacOS || Platform.isWindows) {
      return getDirectoryPath();
    }
    final docs = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final exportDir = Directory(
      p.join(docs.path, 'voice-to-thoughts', timestamp),
    );
    await exportDir.create(recursive: true);
    return exportDir.path;
  }

  Future<String?> exportAll(String directoryPath) async {
    final allNotes = await storage.loadNotes();
    if (allNotes.isEmpty) return null;
    final exportDir = Directory(directoryPath);
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final md = _exportNotesContent(allNotes, isMarkdown: true);
    final mdFile = File(p.join(exportDir.path, 'notes.md'));
    await mdFile.writeAsString(md);

    // On mobile: open share sheet so user can save/AirDrop the markdown file
    if (Platform.isIOS || Platform.isAndroid) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(mdFile.path, mimeType: 'text/markdown')],
          subject: 'Fikr Notes Export',
        ),
      );
    }

    return exportDir.path;
  }


  /// Reloads all in-memory data from local storage.
  /// Called by SyncService after a sync operation completes.
  Future<void> reloadAllData() async {
    notes.value = (await storage.loadNotes())
        .where((note) => !note.archived)
        .toList();

    // After reloading notes, check if selectedNote still exists in the list.
    final selected = selectedNote.value;
    if (selected != null) {
      final refreshed = notes.firstWhereOrNull((n) => n.id == selected.id);
      if (refreshed == null) {
        // Note was deleted remotely — clear the selection.
        selectedNote.value = null;
      } else if (refreshed != selected) {
        // Note was updated remotely — refresh the selected view.
        selectedNote.value = refreshed;
      }
    }

    insightEditions.value = await storage.loadInsightEditions();
    todoItems.value = await storage.loadTasks();
    reminders.value = await storage.loadReminders();
  }

  Future<void> clearAll() async {
    await storage.clearAll();
    notes.clear();
    insightEditions.clear();
    todoItems.clear();
    reminders.clear();
    selectedNote.value = null;
    selectedBucket.value = 'All';
    searchQuery.value = '';
    errorMessage.value = '';
    loading.value = false;
  }

  Future<void> loadMockNotes() async {
    final seeded = _buildMockNotes();
    notes.value = seeded;
    await saveNotes();
  }

  LocalInsights buildLocalInsights(List<Note> notes) {
    final ideas = _extractIdeas(notes);
    final focus = _extractFocusAreas(notes);
    final actions = _extractActionItems(notes);
    final editorial = _buildEditorialSummary(ideas, focus, notes.length);
    return LocalInsights(
      topWords: ideas.$1,
      ideaNotes: ideas.$2,
      focus: focus,
      actions: actions,
      editorial: editorial,
    );
  }

  Future<void> toggleTaskComplete(String id) async {
    todoItems.value = todoItems.map((item) {
      if (item.id != id) return item;
      if (item.isCompleted) {
        return item.copyWith(status: 'todo', clearCompletedAt: true);
      } else {
        return item.copyWith(status: 'done', completedAt: DateTime.now());
      }
    }).toList();
    await _saveTasks();
  }

  Future<void> dismissReminder(String id) async {
    reminders.value = reminders.map((item) {
      if (item.id != id) return item;
      return item.copyWith(isDismissed: true);
    }).toList();
    await _saveReminders();
  }

  Future<void> _saveTasks() async {
    await storage.saveTasks(todoItems.toList());
  }

  Future<void> _saveReminders() async {
    await storage.saveReminders(reminders.toList());
  }

  Future<void> captureInsightsEdition() async {
    if (insightsUpdating.value) return;
    insightsUpdating.value = true;
    insightsUpdateStatus.value = 'Collecting your notes...';

    try {
      final provider = config.value.activeProvider;
      if (provider == null) {
        _notifyError('Fikr isn\'t set up yet.');
        return;
      }
      final apiKey = await storage.getApiKey(provider.id);
      if (apiKey == null || apiKey.isEmpty) {
        _notifyError('Missing API key.');
        return;
      }

      // Ensure user has consented to AI data sharing
      if (!await _ensureAIConsent(provider)) return;

      insightsUpdateStatus.value = 'Analyzing your notes...';
      final activeBuckets = selectedInsightBuckets.toList();
      final filtered = activeBuckets.isEmpty
          ? notes.toList()
          : notes.where((note) {
              return note.topics.any((topic) => activeBuckets.contains(topic));
            }).toList();
      if (filtered.isEmpty) {
        _notifyError('No notes in the selected buckets.');
        return;
      }

      // Filter out notes without meaningful content
      final meaningful = filtered.where((note) {
        final content = note.text.isNotEmpty ? note.text : note.transcript;
        return content.trim().length >= 10;
      }).toList();

      if (meaningful.isEmpty) {
        _notifyError('Your notes don\'t have enough content for analysis yet.');
        return;
      }

      final payloadNotes = meaningful
          .map(
            (note) => {
              'title': note.title,
              'text': note.text.isNotEmpty ? note.text : note.transcript,
              'topics': note.topics,
              'createdAt': note.createdAt.toIso8601String(),
            },
          )
          .toList();

      insightsUpdateStatus.value = 'Synthesizing themes...';
      final existingTitles = todoItems.map((t) => t.title).toList();
      final generated = await openAI.generateInsights(
        notes: payloadNotes,
        provider: provider,
        model: config.value.analysisModel,
        apiKey: apiKey,
        buckets: activeBuckets,
        existingTaskTitles: existingTitles,
      );

      insightsUpdateStatus.value = 'Generating insights...';
      generatedInsights.value = generated;

      if (generated.llmTasks.isNotEmpty) {
        await _mergeGeneratedTasks(generated.llmTasks);
      } else if (generated.nextSteps.isNotEmpty) {
        // Fallback: convert nextSteps strings into tasks
        final fallbackTasks = generated.nextSteps
            .take(5)
            .map(
              (step) => <String, dynamic>{
                'title': step,
                'source_note_title': 'LLM insight',
              },
            )
            .toList();
        await _mergeGeneratedTasks(fallbackTasks);
      }

      if (generated.llmReminders.isNotEmpty) {
        await _mergeGeneratedReminders(generated.llmReminders);
      }

      insightsUpdateStatus.value = 'Saving this edition...';
      final highlights = generated.highlights
          .take(3)
          .map(
            (item) => InsightHighlight(
              title: item.title,
              detail: item.detail,
              bucket: item.bucket,
              icon: item.icon,
            ),
          )
          .toList();
      final edition = InsightEdition(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        summary: generated.summary.isNotEmpty
            ? generated.summary
            : 'No summary available yet.',
        highlights: highlights,
        buckets: activeBuckets,
      );
      final snapshot = List<InsightEdition>.from(insightEditions);
      insightEditions.insert(0, edition);
      insightEditions.refresh();
      try {
        await saveInsightEditions();
      } catch (e) {
        insightEditions.value = snapshot;
        insightEditions.refresh();
        _notifyError('Failed to save insights. Please try again.');
        return;
      }
    } catch (error) {
      _notifyError(error.toString());
    } finally {
      insightsUpdating.value = false;
      insightsUpdateStatus.value = '';
    }
  }

  void _ensureBuckets(List<String> topics) {
    // No longer expanding buckets automatically
  }

  /// Checks whether the user has consented to AI data sharing.
  /// If not, shows the consent dialog. Returns `true` if consent was given.
  Future<bool> _ensureAIConsent(LLMProvider provider) async {
    final hasConsent = await storage.hasAIDataConsent();
    if (hasConsent) return true;

    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return false;

    final agreed = await AIDataConsentDialog.show(ctx, provider: provider);
    if (agreed) {
      await storage.setAIDataConsent(true);
      return true;
    }
    return false;
  }

  void _notifyError(String message) {
    errorMessage.value = message;
    if (Get.context != null) {
      ToastService.showError(
        Get.context!,
        title: 'Error',
        description: message,
      );
    }
  }

  Future<void> _mergeGeneratedTasks(List<Map<String, dynamic>> llmTasks) async {
    final existingTitles = todoItems
        .map((t) => t.title.trim().toLowerCase())
        .toSet();

    for (final taskData in llmTasks) {
      final title = (taskData['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;

      final normalizedTitle = title.toLowerCase();

      // Check for duplicate by title similarity
      final isDuplicate = existingTitles.any((existing) {
        return existing == normalizedTitle ||
            _similarEnough(existing, normalizedTitle);
      });

      if (isDuplicate) {
        // Check if a matching completed task should be reopened
        final matchIndex = todoItems.indexWhere(
          (t) =>
              t.isCompleted &&
              _similarEnough(t.title.trim().toLowerCase(), normalizedTitle),
        );
        if (matchIndex != -1) {
          todoItems[matchIndex] = todoItems[matchIndex].copyWith(
            status: 'todo',
            clearCompletedAt: true,
          );
        }
        continue;
      }

      todoItems.add(
        TodoItem(
          id: 'llm-${DateTime.now().microsecondsSinceEpoch}-${todoItems.length}',
          title: title,
          source: taskData['source_note_title'] as String? ?? 'LLM insight',
          status: 'todo',
          description: taskData['description'] as String? ?? '',
          createdAt: DateTime.now(),
        ),
      );
      existingTitles.add(normalizedTitle);
    }
    await _saveTasks();
  }

  Future<void> _mergeGeneratedReminders(
    List<Map<String, dynamic>> llmReminders,
  ) async {
    for (final data in llmReminders) {
      final title = (data['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;

      DateTime date;
      try {
        date = DateTime.parse(data['date'] as String);
      } catch (_) {
        date = DateTime.now();
      }

      // Avoid duplicate reminders
      final exists = reminders.any(
        (r) => r.title.toLowerCase() == title.toLowerCase(),
      );
      if (exists) continue;

      reminders.add(
        ReminderItem(
          id: 'rem-${DateTime.now().microsecondsSinceEpoch}-${reminders.length}',
          title: title,
          date: date,
          time: data['time'] as String?,
        ),
      );
    }
    await _saveReminders();
  }

  bool _similarEnough(String a, String b) {
    if (a == b) return true;
    // Simple containment check for reasonable dedup
    if (a.length > 10 && b.length > 10) {
      return a.contains(b) || b.contains(a);
    }
    return false;
  }

  (List<String>, List<InsightIdeaNote>) _extractIdeas(List<Note> notes) {
    final wordCounts = <String, int>{};
    for (final note in notes) {
      final text =
          '${note.title} ${note.text.isNotEmpty ? note.text : note.transcript}';
      for (final word in _tokenize(text)) {
        wordCounts[word] = (wordCounts[word] ?? 0) + 1;
      }
    }
    final topWords = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ideaNotes = notes.take(5).map((note) {
      final snippet = (note.text.isNotEmpty ? note.text : note.transcript)
          .trim();
      return InsightIdeaNote(
        title: note.title.isNotEmpty ? note.title : 'Untitled',
        snippet: snippet.length > 140 ? snippet.substring(0, 140) : snippet,
        bucket: note.bucket,
        topics: note.topics,
      );
    }).toList();

    return (topWords.take(6).map((entry) => entry.key).toList(), ideaNotes);
  }

  List<FocusArea> _extractFocusAreas(List<Note> notes) {
    final counts = <String, int>{};
    for (final note in notes) {
      for (final topic in note.topics) {
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(6)
        .map((entry) => FocusArea(topic: entry.key, count: entry.value))
        .toList();
  }

  List<TodoItem> _extractActionItems(List<Note> notes) {
    final items = <TodoItem>[];
    final matcher = RegExp(
      r'^(todo|next|plan|need|should|finish|build|ship|call|email)',
      caseSensitive: false,
    );
    for (final note in notes) {
      final text = note.text.isNotEmpty ? note.text : note.transcript;
      final lines = text.split(RegExp(r'\n|\. '));
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (matcher.hasMatch(trimmed)) {
          items.add(
            TodoItem(
              id: 'todo-${note.id}-${items.length}',
              title: trimmed,
              source: note.title.isNotEmpty ? note.title : 'Note',
              status: 'todo',
              createdAt: note.createdAt,
            ),
          );
        }
      }
    }
    return items.take(8).toList();
  }

  String _buildEditorialSummary(
    (List<String>, List<InsightIdeaNote>) ideas,
    List<FocusArea> focus,
    int notesCount,
  ) {
    final themeLine = ideas.$1.isNotEmpty
        ? 'The through-line is ${ideas.$1.take(3).join(', ')}.'
        : 'A clear through-line hasn\'t formed yet.';
    final focusLine = focus.isNotEmpty
        ? 'Your attention clusters around ${focus.take(2).map((entry) => entry.topic).join(' and ')}.'
        : 'Tags are still light, so focus patterns are emerging.';
    final momentumLine = notesCount > 0
        ? 'You captured $notesCount notes - momentum is building.'
        : 'Start capturing notes to build momentum.';
    return [themeLine, focusLine, momentumLine].join(' ');
  }

  List<String> _tokenize(String text) {
    final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ');
    return cleaned
        .split(RegExp(r'\\s+'))
        .where((word) => word.length > 2 && !_stopwords.contains(word))
        .toList();
  }

  List<Note> _buildMockNotes() {
    const templates = [
      'While browsing, I thought: {idea}.',
      'Captured an idea: {idea}.',
      'Need to remember: {idea}.',
      'Quick note from a walk: {idea}.',
      'Late night thought: {idea}.',
      'Problem to solve: {idea}.',
      'Next step: {idea}.',
      'Reminder for later: {idea}.',
      'This keeps coming up: {idea}.',
      'Action item: {idea}.',
    ];
    const ideaPool = [
      'I just heard a song and want to learn it on guitar',
      'saw an ad while driving about a new investment plan',
      'test a simple pasta recipe tonight',
      'try baking sourdough with a new starter',
      'build a habit tracker for workouts',
      'outline the onboarding flow for the new app',
      'create a budget for subscriptions this month',
      'review credit card statements for Q1',
      'set a reminder to pay rent on the 1st',
      'research index funds vs mutual funds',
      'plan a low carb meal prep for the week',
      'add dark mode to the notes app',
      'design a clean settings screen for mobile',
      'learn a new chord progression on guitar',
      'watch a tutorial on Flutter animations',
      'refactor the API client to reduce latency',
      'schedule a call with my mentor',
      'brainstorm ideas for a side project',
      'write a quick outline for the launch blog post',
      'practice fingerstyle for 20 minutes',
      'try a new curry recipe with coconut milk',
      'improve search by tags and keywords',
      'ship a daily summary email',
      'create a quick capture widget for the browser',
      'plan a weekend trip to the mountains',
      'collect ideas for a travel packing list',
      'test the mobile layout on smaller screens',
      'draft a simple pricing page',
      'build a progress dashboard',
      'set up automatic backups for notes',
      'learn basic music theory',
      'save for a new laptop over 6 months',
      'try a vegetarian chili recipe',
      'review expenses and reduce dining out',
      'organize the feature roadmap by priority',
      'record a demo video for the landing page',
      'learn a new language for 15 minutes daily',
      'read about audio transcription models',
      'add a loading state after recording',
      'clean up the onboarding copy',
      'test the export flow for notes',
      'log the crash report from today',
      'track sleep and hydration this week',
      'book a health checkup this month',
      'plan a savings goal for travel',
      'consider a new guitar practice routine',
      'cook a quick stir fry with vegetables',
      'prepare a grocery list for the week',
      'set up a reminder for insurance renewal',
      'review tax documents this weekend',
      'prototype a new tags UI',
      'experiment with a new note layout',
      'plan a learning path for Flutter',
      'create a small budgeting spreadsheet',
      'schedule a dentist appointment',
      'organize study notes by topic',
      'watch a video on investing basics',
      'start a weekly meal plan',
      'make a list of app features for MVP',
      'test audio playback on macOS',
      'improve the insights screen layout',
      'design a minimal sidebar',
      'create a to do list from notes automatically',
      'add a new bucket for cooking ideas',
      'capture a note about a new podcast episode',
      'plan a daily routine for practice',
      'update the README with setup steps',
      'review current project milestones',
    ];
    const titles = [
      'Quick capture',
      'Walk note',
      'Browsing idea',
      'Late night thought',
      'Reminder',
      'Action item',
      'Planning thought',
      'Observation',
      'Follow up',
      'Idea to revisit',
    ];
    const topics = [
      'Personal Life',
      'Health & Fitness',
      'Work Life',
      'Finance',
      'General',
    ];

    final now = DateTime.now();
    return List.generate(100, (index) {
      final idea = ideaPool[index % ideaPool.length];
      final topic = topics[index % topics.length];
      final createdAt = now.subtract(Duration(hours: index * 3));
      final textTemplate = templates[index % templates.length];
      final text = textTemplate.replaceAll('{idea}', idea);
      return Note(
        id: const Uuid().v4(),
        createdAt: createdAt,
        updatedAt: createdAt,
        title: '${titles[index % titles.length]} - $topic',
        text: text,
        transcript: '',
        intent: '',
        bucket: topic,
        topics: ['mock', 'tag'],
        audioPath: null,
        archived: false,
      );
    });
  }

  String _exportNotesContent(List<Note> notes, {required bool isMarkdown}) {
    final grouped = <String, List<Note>>{};
    for (final note in notes) {
      final topic = note.bucket;
      grouped.putIfAbsent(topic, () => []).add(note);
    }
    final buffer = StringBuffer();
    final topics = grouped.keys.toList()..sort();
    for (final topic in topics) {
      buffer.writeln(isMarkdown ? '## $topic' : topic.toUpperCase());
      for (final note in grouped[topic]!) {
        final dateLabel = DateFormat.yMMMd().add_jm().format(note.createdAt);
        if (isMarkdown) {
          buffer.writeln('### $dateLabel');
        } else {
          buffer.writeln('[$dateLabel]');
        }
        buffer.writeln(note.text.isNotEmpty ? note.text : note.transcript);
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validateActiveProvider();
    }
  }

  Future<void> _validateActiveProvider() async {
    await refreshCanRecord();
  }
}

const _stopwords = {
  'the',
  'and',
  'a',
  'an',
  'to',
  'of',
  'in',
  'for',
  'on',
  'with',
  'at',
  'by',
  'from',
  'is',
  'are',
  'was',
  'were',
  'be',
  'been',
  'it',
  'this',
  'that',
  'these',
  'those',
  'as',
  'or',
  'if',
  'but',
  'not',
  'so',
  'we',
  'i',
  'you',
  'they',
  'he',
  'she',
  'my',
  'our',
  'your',
  'their',
};
