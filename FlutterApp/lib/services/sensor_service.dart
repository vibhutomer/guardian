import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // Channel must match the one in MainActivity.kt
  static const _platform = MethodChannel('com.guardian/sensor');

  final _crashController = StreamController<bool>.broadcast();
  Stream<bool> get crashStream => _crashController.stream;

  void initialize() {
    // Listen for calls from Kotlin
    _platform.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'crashDetected') {
      _crashController.add(true);
    }
  }

  // AI Crash Analysis (Jaskaran's Part)
  Future<String> analyzeCrashWithGemini(double gForce) async {
    try {
      // Replace with your actual API Key
      final apiKey = 'AIzaSyDJxrGI80KzZd2eOkuMqLcz_0C7m0BdElY';
      //final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

      // 'gemini-pro' is the standard stable model that works everywhere
      final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);

      final prompt =
          '''
      I detected a car crash with a G-Force impact of $gForce Gs. 
      Write a 1-sentence assessment for paramedics about the likely severity.
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "Analysis Unavailable";
    } catch (e) {
      print("Gemini Error: $e"); // Prints to Debug Console
      // Return the REAL error message to the screen (cleaned up)
      return "Error: ${e.toString().replaceAll('GenerativeAIException: ', '')}";
      //return "AI Analysis Failed: Check Internet";
    }
  }

  void dispose() {
    _crashController.close();
  }
}
