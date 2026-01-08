import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioVerificationService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedFilePath;

  // 1. Start Recording to a File
  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      
      // Get a temporary path to save the audio
      final Directory tempDir = await getTemporaryDirectory();
      _recordedFilePath = '${tempDir.path}/crash_event.m4a'; // M4A is smaller/better for upload

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // Efficient compression
        sampleRate: 44100,
        bitRate: 128000,
      );

      // Start recording to the specific path
      await _audioRecorder.start(config, path: _recordedFilePath!);
      print("mic: Recording started at $_recordedFilePath");
    }
  }

  // 2. Stop and Return the File Path
  Future<String?> stopRecording() async {
    await _audioRecorder.stop();
    print("mic: Recording stopped");
    return _recordedFilePath;
  }
}