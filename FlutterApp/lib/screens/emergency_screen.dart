import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sms_sender_background/sms_sender.dart'; // <--- NEW PLUGIN
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../utils/constants.dart';
import '../services/sensor_service.dart';
import '../services/database_service.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyScreen extends StatefulWidget {
  final double gForce;
  const EmergencyScreen({super.key, this.gForce = 5.5});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final DatabaseService _dbService = DatabaseService();
  final SensorService _sensorService = SensorService();

  // NEW: Instance of the plugin
  final SmsSender _smsSender = SmsSender();

  int _countdown = 10;
  Timer? _timer;
  bool _alertSent = false;
  String _aiAnalysis = "Analyzing crash intensity...";
  String? _accidentDocId;

  @override
  void initState() {
    super.initState();
    _sensorService.startAlarm();
    startCountdown();
  }

  void startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        _sendAlert();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  // --- NEW SMS LOGIC ---
  Future<void> _sendSMS() async {
    bool hasPermission = await _smsSender.checkSmsPermission();
    if (!hasPermission) {
      hasPermission = await _smsSender.requestSmsPermission();
    }

    if (hasPermission) {
      final prefs = await SharedPreferences.getInstance();
      List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];

      if (contacts.isEmpty) return;

      // 1. GET REAL LOCATION FOR SMS
      String mapLink = "Location Unavailable";
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        // Create a real Google Maps Link
        mapLink =
            "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      } catch (e) {
        print("Could not fetch location for SMS: $e");
      }

      // 2. Create Message with Real Link
      String message = "SOS! Crash detected! Help needed. Track me: $mapLink";

      for (String number in contacts) {
        await _smsSender.sendSms(
          phoneNumber: number,
          message: message,
          simSlot: 0,
        );
      }
    }
  }

  Future<void> _sendAlert() async {
    _sensorService.stopAlarm();
    _sendSMS(); // <--- Calls the new logic
    setState(() => _alertSent = true);

    String analysis = await _sensorService.analyzeCrashWithGemini(
      widget.gForce,
    );

    String? reportId = await _dbService.saveAccidentReport(
      gForce: widget.gForce,
      aiAnalysis: analysis,
      status: "CRITICAL",
    );

    if (mounted) {
      setState(() {
        _aiAnalysis = analysis;
        _accidentDocId = reportId;
      });
    }
  }

  Future<void> cancelEmergency() async {
    _timer?.cancel();
    _sensorService.stopAlarm();

    if (_alertSent && _accidentDocId != null) {
      await _dbService.markAsSafe(_accidentDocId!);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sensorService.stopAlarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            color: AppColors.alertRed.withOpacity(0.2),
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 50,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 100,
                  color: AppColors.alertRed,
                ),
                const SizedBox(height: 20),
                Text(
                  _alertSent
                      ? "SOS SENT!\nHELP IS ON THE WAY"
                      : "CRASH DETECTED",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.alertRed,
                  ),
                ),
                const SizedBox(height: 40),

                if (!_alertSent)
                  Text(
                    "$_countdown",
                    style: const TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                if (_alertSent)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.alertRed),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "GEMINI AI ANALYSIS",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _aiAnalysis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 60),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: cancelEmergency,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.alertRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "I AM SAFE (CANCEL)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
