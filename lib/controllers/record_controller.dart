import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'app_controller.dart';

class RecordController extends GetxController {
  final AudioRecorder _recorder = AudioRecorder();
  final RxBool isRecording = false.obs;
  final RxInt elapsedSeconds = 0.obs;
  final RxDouble visualLevel = 0.2.obs;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  DateTime? _lastVoiceAt;

  Future<void> toggleRecording() async {
    if (isRecording.value) {
      await stopRecording();
    } else {
      await startRecording();
    }
  }

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      final controller = Get.find<AppController>();
      controller.errorMessage.value = 'Microphone permission is required.';
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final fileName = 'vtt_${const Uuid().v4()}.m4a';
    final path = '${tempDir.path}/$fileName';

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 256000,
      sampleRate: 48000,
    );
    await _recorder.start(config, path: path);
    isRecording.value = true;
    elapsedSeconds.value = 0;
    _lastVoiceAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds.value += 1;
    });
    _listenForSilence();
  }

  Future<void> stopRecording() async {
    final path = await _recorder.stop();
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    isRecording.value = false;
    elapsedSeconds.value = 0;

    if (path == null) return;
    final controller = Get.find<AppController>();
    await controller.addNoteFromAudio(File(path));
  }

  void _listenForSilence() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 300))
        .listen((amplitude) {
      final controller = Get.find<AppController>();
      final config = controller.config.value;
      if (!config.autoStopSilence) return;

      final now = DateTime.now();
      final threshold = -45.0;
      if (amplitude.max > threshold) {
        _lastVoiceAt = now;
        visualLevel.value = _normalizeAmplitude(amplitude.max);
        return;
      }
      visualLevel.value = _normalizeAmplitude(amplitude.max);
      if (_lastVoiceAt == null) {
        _lastVoiceAt = now;
        return;
      }
      final silentFor = now.difference(_lastVoiceAt!).inSeconds;
      if (silentFor >= config.silenceSeconds && isRecording.value) {
        stopRecording();
      }
    });
  }

  double _normalizeAmplitude(double db) {
    final clamped = db.clamp(-60.0, 0.0);
    return ((clamped + 60) / 60);
  }

  @override
  void onClose() {
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    super.onClose();
  }
}
