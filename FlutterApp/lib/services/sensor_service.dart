import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'ai_model_service.dart'; // CONNECTING BOTH FILES

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  static const _platform = MethodChannel('com.guardian/sensor');

  final _crashController = StreamController<double>.broadcast();
  Stream<double> get crashStream => _crashController.stream;

  final AIModelService _aiModelService = AIModelService();

  void initialize() {
    _platform.setMethodCallHandler(_handleNativeMethodCall);
    print("✅ Sensor Service Initialized & Listening...");
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'crashDetected') {
      try {
        final double gForce = (call.arguments as num).toDouble();
        print("🚨 CRASH SIGNAL RECEIVED: $gForce G");
        _crashController.add(gForce);
      } catch (e) {
        print("❌ Error parsing sensor data: $e");
        _crashController.add(2.5); // Safe fallback
      }
    }
  }

  // --- NATIVE ALARMS ---
  Future<void> startAlarm() async {
    try {
      await _platform.invokeMethod('startAlarm');
    } catch (e) {
      print("Failed to start alarm: $e");
    }
  }

  Future<void> stopAlarm() async {
    try {
      await _platform.invokeMethod('stopAlarm');
    } catch (e) {
      print("Failed to stop alarm: $e");
    }
  }

  // --- CENTRAL INTELLIGENCE (Pollinations + AI Model) ---
  
  // Call this method when you have the recorded audio file ready
  Future<String> verifyIncident({
    required double gForce, 
    required String audioFilePath
  }) async {
    try {
      print("🕵️ Analyzing Incident Data...");

      // 1. Get Audio Analysis from AIModelService
      String detectedSounds = await _aiModelService.processAudio(audioFilePath);
      print("Audio Analysis Result: $detectedSounds");

      // 2. Send both G-Force and Sounds to Pollinations
      return await _askPollinations(gForce, detectedSounds);

    } catch (e) {
      print("Incident Verification Failed: $e");
      return "Error: Could not verify incident.";
    }
  }

  Future<String> _askPollinations(double gForce, String sounds) async {
    try {
      print("☁️ Contacting Pollinations AI...");

      // Combined Logic Prompt
      String prompt =
          "You are an AI Accident Investigator. Analyze this car sensor data:\n"
          "G-Force Impact: $gForce G.\n"
          "Audio Analysis Detected: [$sounds].\n\n"
          "Rules:\n"
          "1. If sounds include 'Glass', 'Crash', 'Screaming', 'Thud', 'Bang' AND G-Force > 4.0 -> RETURN 'CRITICAL ALERT: High probability of accident.'\n"
          "2. If sounds are only 'Speech', 'Music', 'Silence' AND G-Force < 3.0 -> RETURN 'FALSE ALARM: Situation appears normal.'\n"
          "3. Otherwise -> RETURN 'WARNING: Unusual events detected.'\n"
          "Provide a short 1-sentence reason.";

      // Encode URL properly
      final url = Uri.parse(
        'https://text.pollinations.ai/${Uri.encodeComponent(prompt)}',
      );
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        return "AI Service Unavailable (Status: ${response.statusCode})";
      }
    } catch (e) {
      print("Pollinations Network Error: $e");
      return "Network Error: Check Internet Connection";
    }
  }

  void dispose() {
    _crashController.close();
  }
}