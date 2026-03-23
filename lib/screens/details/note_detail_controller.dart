import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../../controllers/app_controller.dart';
import '../../models/note.dart';
import '../../services/audio_sync_service.dart';

class NoteDetailController extends GetxController {
  final Note note;
  NoteDetailController(this.note);

  final AudioPlayer audioPlayer = AudioPlayer();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController textController = TextEditingController();
  final TextEditingController tagController = TextEditingController();

  final RxBool isEditing = false.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoadingAudio = false.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final RxList<String> topics = <String>[].obs;

  /// Whether audio is available (locally or from cloud)
  bool get hasAudio =>
      (note.audioPath != null && note.audioPath!.isNotEmpty) ||
      (note.audioUrl != null && note.audioUrl!.isNotEmpty);

  @override
  void onInit() {
    super.onInit();
    titleController.text = note.title;
    textController.text = note.text.isNotEmpty ? note.text : note.transcript;
    topics.assignAll(note.topics);
    _initAudio();
  }

  Future<void> _initAudio() async {
    if (!hasAudio) return;

    try {
      // Strategy: try local file first, then download from cloud
      final localPath = note.audioPath;
      if (localPath != null && localPath.isNotEmpty && await File(localPath).exists()) {
        // Local file available — use it directly
        await audioPlayer.setFilePath(localPath);
      } else if (note.audioUrl != null && note.audioUrl!.isNotEmpty) {
        // No local file — download from cloud, then play locally
        isLoadingAudio.value = true;
        final audioSync = Get.find<AudioSyncService>();
        final downloadedPath = await audioSync.downloadAudio(
          noteId: note.id,
          audioUrl: note.audioUrl!,
        );
        isLoadingAudio.value = false;

        if (downloadedPath != null) {
          await audioPlayer.setFilePath(downloadedPath);

          // Update the note with the local path so we don't re-download
          final appController = Get.find<AppController>();
          final updated = note.copyWith(audioPath: downloadedPath);
          await appController.updateNote(updated);
        } else {
          // Fallback: try streaming directly from the URL
          await audioPlayer.setUrl(note.audioUrl!);
        }
      } else {
        debugPrint('No audio available for note ${note.id}');
        return;
      }

      audioPlayer.durationStream.listen(
        (d) => duration.value = d ?? Duration.zero,
      );
      audioPlayer.positionStream.listen((p) => position.value = p);
      audioPlayer.playerStateStream.listen(
        (state) => isPlaying.value = state.playing,
      );
    } catch (e) {
      isLoadingAudio.value = false;
      debugPrint('Error loading audio: $e');
    }
  }

  @override
  void onClose() {
    audioPlayer.dispose();
    titleController.dispose();
    textController.dispose();
    tagController.dispose();
    super.onClose();
  }

  Future<void> togglePlayback() async {
    if (isPlaying.value) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play();
    }
  }

  Future<void> saveEdit() async {
    final controller = Get.find<AppController>();
    final updated = note.copyWith(
      title: titleController.text,
      text: textController.text,
      topics: topics,
      updatedAt: DateTime.now(),
    );
    await controller.updateNoteWithBuckets(updated);
    isEditing.value = false;
  }

  void addTag() {
    final raw = tagController.text.trim();
    if (raw.isEmpty || !isEditing.value) return;
    if (topics.contains(raw)) {
      tagController.clear();
      return;
    }
    topics.add(raw);
    tagController.clear();
  }

  void removeTag(String tag) {
    if (!isEditing.value) return;
    topics.remove(tag);
  }

  Future<void> deleteNote() async {
    final controller = Get.find<AppController>();
    return await controller.deleteNote(note.id);
  }
}
