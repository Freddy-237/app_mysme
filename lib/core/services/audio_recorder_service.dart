import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages microphone recording using [audio_waveforms].
///
/// Exposes a [RecorderController] so the UI can display a live waveform
/// via [AudioWaveforms] during recording.
class AudioRecorderService {
  AudioRecorderService() {
    controller
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
  }

  final RecorderController controller = RecorderController();

  bool get isRecording => controller.isRecording;

  /// Returns true when microphone permission is granted (requests if needed).
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Starts recording to a timestamped temp file.
  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    debugPrint('[AudioRecorderService] startRecording path=$path');
    await controller.record(path: path);
  }

  /// Stops the active recording and returns the file path, or null on failure.
  Future<String?> stopRecording() async {
    final path = await controller.stop();
    debugPrint('[AudioRecorderService] stopRecording path=$path');
    return path;
  }

  void dispose() => controller.dispose();
}
