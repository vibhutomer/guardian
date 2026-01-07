import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart';
import '../utils/constants.dart';
import '../services/sensor_service.dart';
import '../services/database_service.dart'; // Import the service

class EmergencyScreen extends StatefulWidget {
  final double gForce;
  const EmergencyScreen({super.key, this.gForce = 5.5});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  // Services
  final DatabaseService _dbService = DatabaseService();
  final SensorService _sensorService = SensorService();

  // State Variables
  int _countdown = 10;
  Timer? _timer;
  bool _alertSent = false;
  String _aiAnalysis = "Analyzing crash intensity...";
  String? _accidentDocId; // We store the ID here after saving

  @override
  void initState() {
    super.initState();
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

  // --- NEW DATABASE LOGIC ---
  Future<void> _sendAlert() async {
    setState(() => _alertSent = true);

    // 1. Get AI Analysis
    String analysis = await _sensorService.analyzeCrashWithGemini(widget.gForce);

    // 2. Save to Database using the Service
    // We await the ID so we can save it in case we need to cancel later
    String? reportId = await _dbService.saveAccidentReport(
      gForce: widget.gForce,
      aiAnalysis: analysis,
      status: "CRITICAL",
    );

    if (mounted) {
      setState(() {
        _aiAnalysis = analysis;
        _accidentDocId = reportId; // Store the ID!
      });
    }
  }

  // --- CANCEL LOGIC ---
  Future<void> cancelEmergency() async {
    _timer?.cancel();

    // If we already sent the alert, we need to mark it as SAFE in the DB
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.alertRed.withOpacity(0.2),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded, 
              size: 100, 
              color: AppColors.alertRed
            ),
            const SizedBox(height: 20),
            Text(
              _alertSent ? "SOS SENT!\nHELP IS ON THE WAY" : "CRASH DETECTED",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold, 
                color: AppColors.alertRed
              ),
            ),
            const SizedBox(height: 40),
            
            // Countdown Timer
            if (!_alertSent)
              Text(
                "$_countdown",
                style: const TextStyle(
                  fontSize: 100, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white
                ),
              ),
            
            // AI Analysis Box
            if (_alertSent)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.alertRed)
                ),
                child: Column(
                  children: [
                    const Text("GEMINI AI ANALYSIS", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 5),
                    Text(
                      _aiAnalysis,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 60),
            
            // "I AM SAFE" Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: cancelEmergency,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.alertRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  "I AM SAFE (CANCEL)", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}