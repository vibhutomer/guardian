// import 'dart:async';
// import 'dart:io';
// import 'package:record/record.dart';
// import 'package:path_provider/path_provider.dart';
//
// class AudioVerificationService {
//   final AudioRecorder _audioRecorder = AudioRecorder();
//   String? _recordedFilePath;
//
//   // 1. Start Recording to a File
//   Future<void> startRecording() async {
//     if (await _audioRecorder.hasPermission()) {
//
//       // Get a temporary path to save the audio
//       final Directory tempDir = await getTemporaryDirectory();
//       _recordedFilePath = '${tempDir.path}/crash_event.m4a'; // M4A is smaller/better for upload
//
//       const config = RecordConfig(
//         encoder: AudioEncoder.aacLc, // Efficient compression
//         sampleRate: 44100,
//         bitRate: 128000,
//       );
//
//       // Start recording to the specific path
//       await _audioRecorder.start(config, path: _recordedFilePath!);
//       print("mic: Recording started at $_recordedFilePath");
//     }
//   }
//
//   // 2. Stop and Return the File Path
//   Future<String?> stopRecording() async {
//     await _audioRecorder.stop();
//     print("mic: Recording stopped");
//     return _recordedFilePath;
//   }
// }
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:csv/csv.dart';
// import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
//
// class AudioVerificationService {
//   Interpreter? _interpreter;
//   List<String> _labels = [];
//
//   // YAMNet specific constants
//   static const int _sampleRate = 16000;
//   static const int _inputSize = 15600;
//
//   // 1. Load the AI Model
//   Future<void> initialize() async {
//     if (_interpreter != null) return;
//     try {
//       _interpreter = await Interpreter.fromAsset('assets/yamnet.tflite');
//       final csvString = await rootBundle.loadString('assets/yamnet_class_map.csv');
//       final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
//       // Load labels (skipping header)
//       _labels = rows.skip(1).map((row) => row[2].toString()).toList();
//       print("✅ YAMNet AI Loaded");
//     } catch (e) {
//       print("❌ Error loading YAMNet: $e");
//     }
//   }
//
//   // 2. Main Function: Identify Sound from Base64
//   Future<String> identifyCrashSoundFromBase64(String base64String) async {
//     await initialize();
//     try {
//       final Directory tempDir = await getTemporaryDirectory();
//       final File tempInput = File('${tempDir.path}/temp_audio.m4a');
//
//       // Clean and write Base64 to file
//       String cleanBase64 = base64String.replaceAll(RegExp(r'\s+'), '');
//       await tempInput.writeAsBytes(base64Decode(cleanBase64));
//
//       // Convert to 16kHz Mono WAV (Required by YAMNet)
//       final String wavPath = '${tempDir.path}/temp_converted.wav';
//       await FFmpegKit.execute('-i "${tempInput.path}" -ac 1 -ar 16000 -y "$wavPath"');
//
//       final File audioFile = File(wavPath);
//       if (!await audioFile.exists()) return "Error: Audio Conversion Failed";
//
//       // Read Bytes and Preprocess
//       final Uint8List wavBytes = await audioFile.readAsBytes();
//       if (wavBytes.length < 44) return "Error: Empty Audio"; // Header check
//
//       List<double> inputAudio = _preprocessAudio(wavBytes.sublist(44));
//
//       // Pad with zeros if audio is too short
//       if (inputAudio.length < _inputSize) {
//         inputAudio.addAll(List.filled(_inputSize - inputAudio.length, 0.0));
//       }
//
//       // Run AI Inference
//       var inputTensor = [inputAudio.sublist(0, _inputSize)];
//       var outputTensor = List.filled(1 * 521, 0.0).reshape([1, 521]);
//
//       _interpreter!.run(inputTensor, outputTensor);
//
//       // Return the most relevant sound name
//       return _getTopCrashLabel(outputTensor[0]);
//
//     } catch (e) {
//       return "Error: Analysis Failed ($e)";
//     }
//   }
//
//   // Helper: Convert Raw Bytes to Floats
//   List<double> _preprocessAudio(Uint8List bytes) {
//     final numSamples = bytes.length ~/ 2;
//     final List<double> floats = List<double>.filled(numSamples, 0.0);
//     for (int i = 0; i < numSamples; i++) {
//       int shortVal = (bytes[i*2+1] << 8) | bytes[i*2];
//       if (shortVal > 32767) shortVal -= 65536;
//       floats[i] = shortVal / 32768.0;
//     }
//     return floats;
//   }
//
//   // Helper: Find the best label
//   String _getTopCrashLabel(List<double> scores) {
//     // Keywords to look for
//     const crashKeywords = ['Car crash', 'Vehicle', 'Glass', 'Screaming', 'Explosion', 'Skid', 'Brakes', 'Siren', 'Bang'];
//
//     String foundLabel = "Normal Background Noise";
//     double highestConfidence = 0.0;
//
//     for (int i = 0; i < scores.length; i++) {
//       if (i >= _labels.length) break;
//
//       // Filter out low confidence sounds
//       if (scores[i] > 0.2) {
//         String currentLabel = _labels[i];
//
//         // Prioritize crash sounds
//         for (var k in crashKeywords) {
//           if (currentLabel.contains(k)) {
//             if (scores[i] > highestConfidence) {
//               highestConfidence = scores[i];
//               foundLabel = currentLabel;
//             }
//           }
//         }
//       }
//     }
//     return foundLabel;
//   }
// }
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/services.dart';
// import 'package:record/record.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:csv/csv.dart';
// import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
//
// class AudioVerificationService {
//   // Recorder
//   final AudioRecorder _audioRecorder = AudioRecorder();
//   String? _recordedFilePath;
//
//   // AI Model
//   Interpreter? _interpreter;
//   List<String> _labels = [];
//   static const int _sampleRate = 16000;
//   static const int _inputSize = 15600;
//
//   // ------------------------------------------
//   // 1. RECORDING METHODS (Restored)
//   // ------------------------------------------
//
//   Future<void> startRecording() async {
//     if (await _audioRecorder.hasPermission()) {
//       final Directory tempDir = await getTemporaryDirectory();
//       _recordedFilePath = '${tempDir.path}/crash_event.m4a';
//
//       const config = RecordConfig(
//         encoder: AudioEncoder.aacLc,
//         sampleRate: 44100,
//         bitRate: 128000,
//       );
//
//       await _audioRecorder.start(config, path: _recordedFilePath!);
//       print("mic: Recording started at $_recordedFilePath");
//     }
//   }
//
//   Future<String?> stopRecording() async {
//     await _audioRecorder.stop();
//     print("mic: Recording stopped");
//     return _recordedFilePath;
//   }
//
//   // ------------------------------------------
//   // 2. AI ANALYSIS METHODS
//   // ------------------------------------------
//
//   Future<void> initialize() async {
//     if (_interpreter != null) return;
//     try {
//       _interpreter = await Interpreter.fromAsset('assets/yamnet.tflite');
//       final csvString = await rootBundle.loadString('assets/yamnet_class_map.csv');
//       final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
//       _labels = rows.skip(1).map((row) => row[2].toString()).toList();
//       print("✅ YAMNet AI Loaded");
//     } catch (e) {
//       print("❌ Error loading YAMNet: $e");
//     }
//   }
//
//   Future<String> identifyCrashSoundFromBase64(String base64String) async {
//     await initialize();
//     try {
//       final Directory tempDir = await getTemporaryDirectory();
//       final File tempInput = File('${tempDir.path}/temp_audio.m4a');
//
//       String cleanBase64 = base64String.replaceAll(RegExp(r'\s+'), '');
//       await tempInput.writeAsBytes(base64Decode(cleanBase64));
//
//       final String wavPath = '${tempDir.path}/temp_converted.wav';
//
//       // Convert M4A -> WAV (16kHz Mono)
//       await FFmpegKit.execute('-i "${tempInput.path}" -ac 1 -ar 16000 -y "$wavPath"');
//
//       final File audioFile = File(wavPath);
//       if (!await audioFile.exists()) return "Error: Audio Conversion Failed";
//
//       final Uint8List wavBytes = await audioFile.readAsBytes();
//       if (wavBytes.length < 44) return "Error: Empty Audio";
//
//       List<double> inputAudio = _preprocessAudio(wavBytes.sublist(44));
//
//       if (inputAudio.length < _inputSize) {
//         inputAudio.addAll(List.filled(_inputSize - inputAudio.length, 0.0));
//       }
//
//       var inputTensor = [inputAudio.sublist(0, _inputSize)];
//       var outputTensor = List.filled(1 * 521, 0.0).reshape([1, 521]);
//
//       _interpreter!.run(inputTensor, outputTensor);
//
//       return _getTopCrashLabel(outputTensor[0]);
//
//     } catch (e) {
//       return "Error: Analysis Failed ($e)";
//     }
//   }
//
//   List<double> _preprocessAudio(Uint8List bytes) {
//     final numSamples = bytes.length ~/ 2;
//     final List<double> floats = List<double>.filled(numSamples, 0.0);
//     for (int i = 0; i < numSamples; i++) {
//       int shortVal = (bytes[i*2+1] << 8) | bytes[i*2];
//       if (shortVal > 32767) shortVal -= 65536;
//       floats[i] = shortVal / 32768.0;
//     }
//     return floats;
//   }
//
//   String _getTopCrashLabel(List<double> scores) {
//     const crashKeywords = ['Car crash', 'Vehicle', 'Glass', 'Screaming', 'Explosion', 'Skid', 'Brakes', 'Siren', 'Bang'];
//     String foundLabel = "Normal Background Noise";
//     double highestConfidence = 0.0;
//
//     for (int i = 0; i < scores.length; i++) {
//       if (i >= _labels.length) break;
//       if (scores[i] > 0.2) {
//         String currentLabel = _labels[i];
//         for (var k in crashKeywords) {
//           if (currentLabel.contains(k)) {
//             if (scores[i] > highestConfidence) {
//               highestConfidence = scores[i];
//               foundLabel = currentLabel;
//             }
//           }
//         }
//       }
//     }
//     return foundLabel;
//   }
// }
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:csv/csv.dart';

class AudioVerificationService {
  // Recorder
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedFilePath;

  // AI Model
  Interpreter? _interpreter;
  List<String> _labels = [];

  // YAMNet requires 16kHz
  static const int _sampleRate = 16000;
  static const int _inputSize = 15600;

  // ------------------------------------------
  // 1. RECORDING METHODS (Direct to WAV)
  // ------------------------------------------

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final Directory tempDir = await getTemporaryDirectory();
      // CHANGED: Save directly as .wav
      _recordedFilePath = '${tempDir.path}/crash_event.wav';

      // CHANGED: Configure for raw WAV (PCM 16-bit)
      const config = RecordConfig(
        encoder: AudioEncoder.wav, // Record directly to WAV
        sampleRate: _sampleRate,   // 16000 Hz
        numChannels: 1,            // Mono
      );

      await _audioRecorder.start(config, path: _recordedFilePath!);
      print("mic: Recording started at $_recordedFilePath");
    }
  }

  Future<String?> stopRecording() async {
    await _audioRecorder.stop();
    print("mic: Recording stopped");
    return _recordedFilePath;
  }

  // ------------------------------------------
  // 2. AI ANALYSIS METHODS
  // ------------------------------------------

  Future<void> initialize() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/yamnet.tflite');
      final csvString = await rootBundle.loadString('assets/yamnet_class_map.csv');
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      // Skip header and map to 3rd column (index 2)
      _labels = rows.skip(1).map((row) => row[2].toString()).toList();
      print("✅ YAMNet AI Loaded");
    } catch (e) {
      print("❌ Error loading YAMNet: $e");
    }
  }

  Future<String> identifyCrashSoundFromBase64(String base64String) async {
    await initialize();
    try {
      // 1. Decode the Base64 String back to Bytes
      String cleanBase64 = base64String.replaceAll(RegExp(r'\s+'), '');
      Uint8List audioBytes = base64Decode(cleanBase64);

      // 2. Preprocess (No conversion needed, it's already WAV!)
      if (audioBytes.length < 44) return "Error: Empty Audio";

      // Skip 44-byte WAV header and normalize
      List<double> inputAudio = _preprocessAudio(audioBytes.sublist(44));

      // Pad with zeros if recording was too short (< 0.975s)
      if (inputAudio.length < _inputSize) {
        inputAudio.addAll(List.filled(_inputSize - inputAudio.length, 0.0));
      }

      // 3. Run Inference
      var inputTensor = [inputAudio.sublist(0, _inputSize)];
      var outputTensor = List.filled(1 * 521, 0.0).reshape([1, 521]);

      _interpreter!.run(inputTensor, outputTensor);

      return _getTopCrashLabel(outputTensor[0]);

    } catch (e) {
      return "Error: Analysis Failed ($e)";
    }
  }

  List<double> _preprocessAudio(Uint8List bytes) {
    // Convert 16-bit PCM Bytes to Normalized Floats [-1.0, 1.0]
    final numSamples = bytes.length ~/ 2;
    final List<double> floats = List<double>.filled(numSamples, 0.0);
    for (int i = 0; i < numSamples; i++) {
      int byte1 = bytes[i * 2];
      int byte2 = bytes[i * 2 + 1];
      // Little Endian
      int shortVal = (byte2 << 8) | byte1;
      // Handle signed integer
      if (shortVal > 32767) shortVal -= 65536;
      floats[i] = shortVal / 32768.0;
    }
    return floats;
  }

  String _getTopCrashLabel(List<double> scores) {
    const crashKeywords = ['Car crash', 'Vehicle', 'Glass', 'Screaming', 'Explosion', 'Skid', 'Brakes', 'Siren', 'Bang'];
    String foundLabel = "Normal Background Noise";
    double highestConfidence = 0.0;

    for (int i = 0; i < scores.length; i++) {
      if (i >= _labels.length) break;
      if (scores[i] > 0.2) {
        String currentLabel = _labels[i];
        for (var k in crashKeywords) {
          if (currentLabel.contains(k)) {
            if (scores[i] > highestConfidence) {
              highestConfidence = scores[i];
              foundLabel = currentLabel;
            }
          }
        }
      }
    }
    return foundLabel;
  }
}