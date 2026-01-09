// import 'package:flutter/services.dart';
// import 'dart:async';
// import 'package:http/http.dart' as http;
//
// class SensorService {
//   static final SensorService _instance = SensorService._internal();
//   factory SensorService() => _instance;
//   SensorService._internal();
//
//   static const _platform = MethodChannel('com.guardian/sensor');
//
//   // CHANGED: Now broadcasting a double (the specific G-Force value)
//   final _crashController = StreamController<double>.broadcast();
//   Stream<double> get crashStream => _crashController.stream;
//
//   void initialize() {
//     _platform.setMethodCallHandler(_handleNativeMethodCall);
//     print("✅ Sensor Service Initialized & Listening...");
//   }
//
//   Future<void> _handleNativeMethodCall(MethodCall call) async {
//     if (call.method == 'crashDetected') {
//       try {
//         // SAFETY CHECK: Extract the number sent from Kotlin
//         // We cast to 'num' first to handle both int and double safely
//         final double gForce = (call.arguments as num).toDouble();
//
//         print("🚨 CRASH SIGNAL RECEIVED FROM NATIVE: $gForce G");
//         _crashController.add(gForce);
//
//       } catch (e) {
//         print("❌ Error parsing sensor data: $e");
//         // Fallback value if data is corrupted, so the app doesn't crash
//         _crashController.add(2.5);
//       }
//     }
//   }
//
//   // Call Kotlin to play sound
//   Future<void> startAlarm() async {
//     try {
//       await _platform.invokeMethod('startAlarm');
//     } catch (e) {
//       print("Failed to start alarm: $e");
//     }
//   }
//
//   // Call Kotlin to stop sound
//   Future<void> stopAlarm() async {
//     try {
//       await _platform.invokeMethod('stopAlarm');
//     } catch (e) {
//       print("Failed to stop alarm: $e");
//     }
//   }
//
//   // --- POLLINATIONS.AI (FREE, NO KEY, NO LIMITS) ---
//   Future<String> analyzeCrashWithGemini(double gForce) async {
//     try {
//       print("Contacting Pollinations AI...");
//
//       final prompt = "You are an automated emergency dispatcher. "
//           "A car crash happened with $gForce G-force. "
//           "If G-force is over 4.0, respond exactly: 'CRITICAL: Calling nearest hospital and dispatching ambulance.' "
//           "If G-force is under 4.0, respond exactly: 'WARNING: Alerting emergency contacts and logging location.' "
//           "Do not write anything else.";
//
//       final url = Uri.parse('https://text.pollinations.ai/${Uri.encodeComponent(prompt)}');
//       final response = await http.get(url);
//
//       if (response.statusCode == 200) {
//         final text = response.body;
//         return text.isNotEmpty ? text : "Analysis Empty";
//       } else {
//         print("Pollinations Error: ${response.statusCode}");
//         return "Error: Server Busy";
//       }
//     } catch (e) {
//       print("Network Error: $e");
//       return "Connection Failed";
//     }
//   }
//
//   void dispose() {
//     _crashController.close();
//   }
// }
// import 'dart:async';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'audio_verification_service.dart';
//
// class SensorService {
//   static final SensorService _instance = SensorService._internal();
//   factory SensorService() => _instance;
//   SensorService._internal();
//
//   final AudioVerificationService _audioService = AudioVerificationService();
//
//   // Stream to update UI with status
//   final _crashController = StreamController<String>.broadcast();
//   Stream<String> get crashStatusStream => _crashController.stream;
//
//   // --- FUSION ANALYSIS FUNCTION ---
//   Future<void> analyzeAccident(double gForce, String base64Audio) async {
//     try {
//       _crashController.add("Analyzing Audio...");
//
//       // 1. Get Audio Label from YAMNet (Offline)
//       String soundDetected = await _audioService.identifyCrashSoundFromBase64(base64Audio);
//       print("🔊 Audio Heard: $soundDetected");
//
//       _crashController.add("Consulting AI Judge...");
//
//       // 2. Ask Pollinations AI to decide
//       final prompt =
//           "System: Vehicle Incident Analyzer.\n"
//           "Input Data:\n"
//           "- G-Force: ${gForce.toStringAsFixed(1)} G\n"
//           "- Acoustic Event: '$soundDetected'\n\n"
//           "Task: Determine if a serious car accident occurred.\n"
//           "Rules:\n"
//           "1. IF G-Force > 3.5 AND Sound is (Crash, Impact, Glass, Scream, Explosion) -> Output: 'CRITICAL ACCIDENT'\n"
//           "2. IF G-Force > 3.5 but Sound is Normal -> Output: 'WARNING: Hard Braking'\n"
//           "3. IF Sound is Crash but G-Force is Low (< 2.0) -> Output: 'FALSE ALARM: Audio Only'\n"
//           "4. Else -> Output: 'NO ACCIDENT'\n\n"
//           "Response Format: Only the Output phrase.";
//
//       final url = Uri.parse('https://text.pollinations.ai/${Uri.encodeComponent(prompt)}');
//       final response = await http.get(url);
//
//       if (response.statusCode == 200) {
//         final verdict = response.body.trim();
//         print("🤖 AI Verdict: $verdict");
//         _crashController.add(verdict);
//       } else {
//         _crashController.add("Error: AI Server Down");
//       }
//
//     } catch (e) {
//       print("Error: $e");
//       _crashController.add("System Error");
//     }
//   }
//
//   void dispose() {
//     _crashController.close();
//   }
// }
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'audio_verification_service.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // 1. NATIVE COMMUNICATION (Restored)
  static const _platform = MethodChannel('com.guardian/sensor');
  final _crashController = StreamController<double>.broadcast();
  Stream<double> get crashStream => _crashController.stream;

  // Status Stream for UI
  final _statusController = StreamController<String>.broadcast();
  Stream<String> get crashStatusStream => _statusController.stream;

  final AudioVerificationService _audioService = AudioVerificationService();

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
        _crashController.add(2.5);
      }
    }
  }

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

  // 2. FUSION ANALYSIS (The New Logic)
  // CHANGED: Returns Future<String> so EmergencyScreen can wait for it
  Future<String> analyzeAccident(double gForce, String base64Audio) async {
    try {
      _statusController.add("Analyzing Audio...");

      // Step A: Audio Analysis (YAMNet)
      String soundDetected = await _audioService.identifyCrashSoundFromBase64(base64Audio);
      print("🔊 Audio Heard: $soundDetected");

      _statusController.add("Consulting AI Judge...");

      // Step B: Pollinations Logic
      final prompt =
          "System: Vehicle Incident Analyzer.\n"
          "Input Data:\n"
          "- G-Force: ${gForce.toStringAsFixed(1)} G\n"
          "- Acoustic Event: '$soundDetected'\n\n"
          "Task: Determine if a serious car accident occurred.\n"
          "Rules:\n"
          "1. IF G-Force > 3.5 AND Sound is (Crash, Impact, Glass, Scream, Explosion) -> Output: 'CRITICAL ACCIDENT'\n"
          "2. IF G-Force > 3.5 but Sound is Normal -> Output: 'WARNING: Hard Braking'\n"
          "3. IF Sound is Crash but G-Force is Low (< 2.0) -> Output: 'FALSE ALARM: Audio Only'\n"
          "4. Else -> Output: 'NO ACCIDENT'\n\n"
          "Response Format: Only the Output phrase.";


      final url = Uri.parse('https://text.pollinations.ai/${Uri.encodeComponent(prompt)}');
      final response = await http.get(url);

      String verdict = "Analysis Failed";
      if (response.statusCode == 200) {
        verdict = response.body.trim();
        print("🤖 AI Verdict: $verdict");
        _statusController.add(verdict);
      } else {
        _statusController.add("Error: AI Server Down");
      }

      return verdict;

    } catch (e) {
      print("Error: $e");
      _statusController.add("System Error");
      return "System Error: $e";
    }
  }

  void dispose() {
    _crashController.close();
    _statusController.close();
  }
}