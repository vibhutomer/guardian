import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:csv/csv.dart';

class AIModelService {
  static final AIModelService _instance = AIModelService._internal();
  factory AIModelService() => _instance;
  AIModelService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  // YAMNet Constants
  static const int SAMPLE_RATE = 16000;
  static const int INPUT_SIZE = 15600; // ~0.975 seconds

  // 1. Load Model & Labels
  Future<void> loadModel() async {
    if (_isLoaded) return;
    try {
      print("🧠 Loading YAMNet Model...");
      // Load TFLite
      _interpreter = await Interpreter.fromAsset('assets/yamnet.tflite');

      // Load Labels (CSV)
      final csvString = await rootBundle.loadString(
        'assets/yamnet_class_map.csv',
      );
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(
        csvString,
      );

      // Extract names (Column 2 is display_name) - skip header
      _labels = csvTable.skip(1).map((row) => row[2].toString()).toList();

      _isLoaded = true;
      print("✅ AI Model Loaded with ${_labels.length} classes.");
    } catch (e) {
      print("❌ Error loading AI model: $e");
    }
  }

  // 2. Main Function: Audio File -> List of Sounds (String)
  // Renamed from 'analyzeCrash' to 'processAudio' to reflect its specific job
  Future<String> processAudio(String filePath) async {
    if (!_isLoaded) await loadModel();

    // A. PRE-PROCESSING: Read WAV -> Float32 chunks
    List<List<double>> audioChunks = await _processAudioFile(filePath);

    if (audioChunks.isEmpty) return "Error: Could not process audio file.";

    // B. INFERENCE: Run chunks through YAMNet
    Set<String> detectedSounds = {};
    
    // We expect output shape [1, 521] for each chunk
    var outputBuffer = List.filled(1 * 521, 0.0).reshape([1, 521]);

    print("🧠 Running Inference on ${audioChunks.length} chunks...");

    for (var chunk in audioChunks) {
      // Create Input Buffer [1, 15600]
      var inputBuffer = Float32List.fromList(chunk).reshape([1, INPUT_SIZE]);

      // Run Model
      _interpreter!.run(inputBuffer, outputBuffer);

      // Get Top Prediction for this chunk
      int topIndex = _getTopIndex(outputBuffer[0]);
      String soundName = _labels[topIndex];

      // Filter out irrelevant background noise
      if (soundName != 'Silence' && 
          soundName != 'Inside, small room' && 
          soundName != 'Static') {
        detectedSounds.add(soundName);
      }
    }

    String soundSummary = detectedSounds.join(", ");
    print("🔊 Detected Sounds: $soundSummary");
    
    // Return the raw findings to be used by SensorService
    return soundSummary.isEmpty ? "Unknown/Silence" : soundSummary;
  }

  // --- HELPER: Process WAV File ---
  Future<List<List<double>>> _processAudioFile(String path) async {
    try {
      File file = File(path);
      Uint8List bytes = await file.readAsBytes();

      // Skip WAV Header (44 bytes) to get raw PCM data
      int headerSize = 44;
      if (bytes.length <= headerSize) return [];

      final byteData = ByteData.view(bytes.buffer, headerSize);
      List<double> samples = [];

      int numSamples = byteData.lengthInBytes ~/ 2;

      for (int i = 0; i < numSamples; i++) {
        // Read 16-bit integer (Little Endian)
        int sample = byteData.getInt16(i * 2, Endian.little);
        // Normalize to -1.0 to 1.0
        samples.add(sample / 32768.0);
      }

      // Chunk Logic
      List<List<double>> chunks = [];
      int step = 12000; // Overlap slightly

      for (int i = 0; i < samples.length - INPUT_SIZE; i += step) {
        chunks.add(samples.sublist(i, i + INPUT_SIZE));
      }

      return chunks;
    } catch (e) {
      print("Audio Processing Error: $e");
      return [];
    }
  }

  int _getTopIndex(List<dynamic> scores) {
    double maxScore = -1;
    int maxIndex = -1;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }
}