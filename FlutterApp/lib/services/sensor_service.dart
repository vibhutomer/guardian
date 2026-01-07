import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  static const _platform = MethodChannel('com.guardian/sensor');
  final _crashController = StreamController<bool>.broadcast();
  Stream<bool> get crashStream => _crashController.stream;

  void initialize() {
    _platform.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'crashDetected') {
      _crashController.add(true);
    }
  }

  // --- POLLINATIONS.AI (FREE, NO KEY, NO LIMITS) ---
  Future<String> analyzeCrashWithGemini(double gForce) async {
    // We use Pollinations.ai which requires NO API KEY.
    // It is perfect for Hackathons.

    try {
      print("Contacting Pollinations AI (Free)...");

      final prompt = "You are an automated emergency dispatcher. "
          "A car crash happened with $gForce G-force. "
          "If G-force is over 4.0, respond exactly: 'CRITICAL: Calling nearest hospital and dispatching ambulance.' "
          "If G-force is under 4.0, respond exactly: 'WARNING: Alerting emergency contacts and logging location.' "
          "Do not write anything else.";

      // Pollinations uses a simple GET request with the prompt in the URL.
      // We encode the prompt to make it URL-safe.
      final url = Uri.parse('https://text.pollinations.ai/${Uri.encodeComponent(prompt)}');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Pollinations returns raw text, no complex JSON!
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