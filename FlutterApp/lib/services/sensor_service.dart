import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  static const _platform = MethodChannel('com.guardian/sensor');

  // CHANGED: Now broadcasting a double (the specific G-Force value)
  final _crashController = StreamController<double>.broadcast();
  Stream<double> get crashStream => _crashController.stream;

  void initialize() {
    _platform.setMethodCallHandler(_handleNativeMethodCall);
    print("✅ Sensor Service Initialized & Listening...");
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'crashDetected') {
      try {
        // SAFETY CHECK: Extract the number sent from Kotlin
        // We cast to 'num' first to handle both int and double safely
        final double gForce = (call.arguments as num).toDouble();
        
        print("🚨 CRASH SIGNAL RECEIVED FROM NATIVE: $gForce G");
        _crashController.add(gForce);
        
      } catch (e) {
        print("❌ Error parsing sensor data: $e");
        // Fallback value if data is corrupted, so the app doesn't crash
        _crashController.add(2.5); 
      }
    }
  }

  // --- POLLINATIONS.AI (FREE, NO KEY, NO LIMITS) ---
  Future<String> analyzeCrashWithGemini(double gForce) async {
    try {
      print("Contacting Pollinations AI...");

      final prompt = "You are an automated emergency dispatcher. "
          "A car crash happened with $gForce G-force. "
          "If G-force is over 4.0, respond exactly: 'CRITICAL: Calling nearest hospital and dispatching ambulance.' "
          "If G-force is under 4.0, respond exactly: 'WARNING: Alerting emergency contacts and logging location.' "
          "Do not write anything else.";

      final url = Uri.parse('https://text.pollinations.ai/${Uri.encodeComponent(prompt)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final text = response.body;
        return text.isNotEmpty ? text : "Analysis Empty";
      } else {
        print("Pollinations Error: ${response.statusCode}");
        return "Error: Server Busy";
      }
    } catch (e) {
      print("Network Error: $e");
      return "Connection Failed";
    }
  }

  void dispose() {
    _crashController.close();
  }
}