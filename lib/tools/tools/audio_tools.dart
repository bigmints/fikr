/// Audio domain tools — playback and file management.
library;

import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../services/audio_sync_service.dart';
import '../tool_interface.dart';

// ───────────────────────────────────────────────────────────────────────────
//  audio.play
// ───────────────────────────────────────────────────────────────────────────

class AudioPlayTool extends FikrTool {
  @override
  String get name => 'audio.play';

  @override
  String get description =>
      'Play the audio recording for a note. '
      'Tries local file first, then cloud download, then streams.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'noteId': {
        'type': 'string',
        'description': 'ID of the note whose audio to play.',
      },
    },
    'required': ['noteId'],
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
      final noteId = params['noteId'] as String;
      final note = ctrl.notes.firstWhereOrNull((n) => n.id == noteId);
      if (note == null) return ToolResult.fail('Note not found: $noteId');
      if (note.audioPath == null && note.audioUrl == null) {
        return ToolResult.fail('No audio available for this note.');
      }
      await ctrl.playAudio(note);
      return ToolResult.ok({'playing': noteId});
    } catch (e) {
      return ToolResult.fail('Playback failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  audio.upload
// ───────────────────────────────────────────────────────────────────────────

class AudioUploadTool extends FikrTool {
  @override
  String get name => 'audio.upload';

  @override
  String get description =>
      'Upload a note\'s audio file to Firebase Storage.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'noteId': {'type': 'string'},
      'localPath': {'type': 'string'},
    },
    'required': ['noteId', 'localPath'],
  };

  @override
  ToolTier get requiredTier => ToolTier.plus;

  @override
  ToolLocation get location => ToolLocation.cloud;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final audioSync = Get.find<AudioSyncService>();
      final url = await audioSync.uploadAudio(
        noteId: params['noteId'] as String,
        localPath: params['localPath'] as String,
      );
      if (url == null) return ToolResult.fail('Upload returned no URL.');
      return ToolResult.ok({'audioUrl': url});
    } catch (e) {
      return ToolResult.fail('Audio upload failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  audio.download
// ───────────────────────────────────────────────────────────────────────────

class AudioDownloadTool extends FikrTool {
  @override
  String get name => 'audio.download';

  @override
  String get description =>
      'Download a note\'s audio from Firebase Storage to local.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'object',
    'properties': {
      'noteId': {'type': 'string'},
      'audioUrl': {'type': 'string'},
    },
    'required': ['noteId', 'audioUrl'],
  };

  @override
  ToolTier get requiredTier => ToolTier.plus;

  @override
  ToolLocation get location => ToolLocation.cloud;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> params,
    ToolContext context,
  ) async {
    try {
      final audioSync = Get.find<AudioSyncService>();
      final localPath = await audioSync.downloadAudio(
        noteId: params['noteId'] as String,
        audioUrl: params['audioUrl'] as String,
      );
      if (localPath == null) return ToolResult.fail('Download failed.');
      return ToolResult.ok({'localPath': localPath});
    } catch (e) {
      return ToolResult.fail('Audio download failed: $e');
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
//  Convenience
// ───────────────────────────────────────────────────────────────────────────

List<FikrTool> allAudioTools() => [
      AudioPlayTool(),
      AudioUploadTool(),
      AudioDownloadTool(),
    ];
