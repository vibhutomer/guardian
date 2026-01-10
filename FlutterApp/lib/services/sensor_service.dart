import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'ai_model_service.dart'; 

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
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'crashDetected') {
      try {
        final double gForce = (call.arguments as num).toDouble();
        _crashController.add(gForce);
      } catch (e) {
        _crashController.add(2.5); 
      }
    }
  }

  Future<void> startAlarm() async { await _platform.invokeMethod('startAlarm'); }
  Future<void> stopAlarm() async { await _platform.invokeMethod('stopAlarm'); }

  // --- THE BRIDGE METHOD ---
  Future<String> verifyIncident({
    required double gForce, 
    required String audioFilePath
  }) async {
    try {
      print("🕵️ SensorService: Calling AI Model...");

      // 1. Convert Audio to Text (e.g., "Glass, Crash")
      String detectedSounds = await _aiModelService.processAudio(audioFilePath);
      print("🔊 Detected Sounds: $detectedSounds");

      // 2. Ask Pollinations for Verdict
      return await _askPollinations(gForce, detectedSounds);

    } catch (e) {
      print("Incident Verification Failed: $e");
      // SAFETY FIX: If anything fails here, assume it's CRITICAL
      return "CRITICAL: Internal Error ($e). Proceeding with alert.";
    }
  }

  // --- POLLINATIONS AI (FAIL-SAFE VERSION) ---
  Future<String> _askPollinations(double gForce, String sounds) async {
    try {

      // ---------------------------------------------------------
      // 1. HACKATHON DEMO TRIGGERS (MAGIC NUMBERS)
      // ---------------------------------------------------------
      
      // SCENARIO A: FORCE FALSE ALARM
      // If you simulate 2.2 G-Force, we FORCE the AI to say False Alarm
      if (gForce == 2.2) {
        print("🧪 DEMO MODE: Forcing FALSE ALARM");
        return "FALSE ALARM: Demo Mode triggered. Situation normal.";
      }

      // SCENARIO B: FORCE REAL CRASH
      // If you simulate 8.8 G-Force, we FORCE the AI to say Critical
      if (gForce == 8.8) {
        print("🧪 DEMO MODE: Forcing CRITICAL CRASH");
        return "CRITICAL: Demo Mode triggered. High impact crash detected.";
      }

      // Shortened prompt to reduce 502 errors
      String prompt =
          "Analyze car crash data: G-Force $gForce. Sounds: $sounds. "
          "Reply CRITICAL if sounds contain crash/glass/thud OR G-Force > 4.0. "
          "Reply FALSE ALARM if silence/talk/music AND G-Force < 3.0. "
          "Else reply WARNING. Keep it short.";
          

      final url = Uri.parse(
        'https://text.pollinations.ai/${Uri.encodeComponent(prompt)}',
      );
      
      // Increased timeout to 10 seconds
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // 🚨 CRITICAL FIX: If server is down (502), return CRITICAL so we send SMS!
        print("Pollinations Error: ${response.statusCode}");
        return "CRITICAL: AI Server Down (Status ${response.statusCode}). Defaulting to Alert.";
      }
    } catch (e) {
      // 🚨 CRITICAL FIX: If no internet, return CRITICAL so we send SMS!
      print("Pollinations Network Error: $e");
      return "CRITICAL: Network Error. Defaulting to Alert.";
    }
  }

  void dispose() {
    _crashController.close();
  }
}