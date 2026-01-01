import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import '../utils/constants.dart';
import '../services/sensor_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  int _countdown = 10;
  Timer? _timer;
  bool _alertSent = false;
  String _aiAnalysis = "Waiting for AI...";

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  void startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        sendAlert();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  Future<void> sendAlert() async {
    setState(() {
      _alertSent = true;
    });

    // 1. Get AI Analysis
    String analysis = await SensorService().analyzeCrashWithGemini(5.5); // Mock 5.5G for now

    // 2. Upload to Firestore
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('accidents').add({
      'user_id': user?.uid,
      'user_name': user?.displayName,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'CRITICAL',
      'g_force': 5.5,
      'ai_report': analysis,
      'location': {'lat': 28.5, 'lng': 77.2}, // Mock location (Use Geolocator later)
    });

    setState(() {
      _aiAnalysis = analysis;
    });
  }

  void cancelEmergency() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
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
              _alertSent ? "HELP IS ON THE WAY" : AppStrings.crashDetected,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold, 
                color: AppColors.alertRed
              ),
            ),
            const SizedBox(height: 40),
            
            if (!_alertSent)
              Text(
                "$_countdown",
                style: const TextStyle(
                  fontSize: 100, 
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite
                ),
              ),
            
            if (_alertSent)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "AI REPORT: $_aiAnalysis",
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
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