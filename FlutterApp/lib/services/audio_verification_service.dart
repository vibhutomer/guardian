import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioVerificationService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedFilePath;

  Future<void> startRecording() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) {
      try {
        final Directory tempDir = await getTemporaryDirectory();
        // CHANGED: Use .wav for AI processing
        _recordedFilePath = '${tempDir.path}/crash_event.wav';

        const config = RecordConfig(
          encoder: AudioEncoder.wav, // RAW WAV required for AI
          sampleRate: 16000,         // YAMNet requires exactly 16000Hz
          numChannels: 1,            // YAMNet requires Mono
        );

        await _audioRecorder.start(config, path: _recordedFilePath!);
        print("mic: Recording started (WAV/16k) at $_recordedFilePath");
      } catch (e) {
        print("mic: Error starting recorder: $e");
      }
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
        print("mic: Recording stopped");
        return _recordedFilePath;
      }
    } catch (e) {
      print("mic: Error stopping recorder: $e");
    }
    return null;
  }
}