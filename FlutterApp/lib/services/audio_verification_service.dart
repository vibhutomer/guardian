import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // Import this

class AudioVerificationService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedFilePath;

  // 1. Start Recording (SILENT CHECK ONLY)
  Future<void> startRecording() async {
    // FIX: Check status directly using permission_handler
    // This returns the status WITHOUT triggering a popup dialog
    var status = await Permission.microphone.status;

    if (status.isGranted) {
      try {
        // Get a temporary path to save the audio
        final Directory tempDir = await getTemporaryDirectory();
        _recordedFilePath = '${tempDir.path}/crash_event.m4a';

        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        );

        // Start recording
        // We assume permission is granted because of the check above.
        await _audioRecorder.start(config, path: _recordedFilePath!);
        print("mic: Recording started at $_recordedFilePath");
      } catch (e) {
        print("mic: Error starting recorder: $e");
      }
    } else {
      // If permission is NOT granted, we just skip recording.
      // We do NOT ask for it here (to avoid blocking the UI).
      print("mic: Permission not granted previously. Skipping audio evidence.");
    }
  }

  // 2. Stop and Return the File Path
  Future<String?> stopRecording() async {
    try {
      // Check if it's actually recording before stopping
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
