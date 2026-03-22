import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../../controllers/app_controller.dart';
import '../../models/note.dart';

class NoteDetailController extends GetxController {
  final Note note;
  NoteDetailController(this.note);

  final AudioPlayer audioPlayer = AudioPlayer();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController textController = TextEditingController();
  final TextEditingController tagController = TextEditingController();

  final RxBool isEditing = false.obs;
  final RxBool isPlaying = false.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final RxList<String> topics = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    titleController.text = note.title;
    textController.text = note.text.isNotEmpty ? note.text : note.transcript;
    topics.assignAll(note.topics);
    _initAudio();
  }

  Future<void> _initAudio() async {
    if (note.audioPath != null) {
      try {
        await audioPlayer.setFilePath(note.audioPath!);
        audioPlayer.durationStream.listen(
          (d) => duration.value = d ?? Duration.zero,
        );
        audioPlayer.positionStream.listen((p) => position.value = p);
        audioPlayer.playerStateStream.listen(
          (state) => isPlaying.value = state.playing,
        );
      } catch (e) {
        debugPrint('Error loading audio: $e');
      }
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
