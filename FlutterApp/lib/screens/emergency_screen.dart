import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for StreamBuilder
import 'package:sms_sender_background/sms_sender.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'home_screen.dart';
import '../utils/constants.dart';
import '../services/sensor_service.dart';
import '../services/database_service.dart';
import '../services/audio_verification_service.dart';
import '../services/google_places_service.dart';

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
  final AudioVerificationService _audioService = AudioVerificationService();
  final SmsSender _smsSender = SmsSender();
  final GooglePlacesService _placesService = GooglePlacesService();

  // State Variables
  int _countdown = 10;
  Timer? _timer;
  bool _alertSent = false;
  String _aiAnalysis = "Analyzing environment...";
  String? _accidentDocId; // The ID of the report in the database

  @override
  void initState() {
    super.initState();
    // 1. Start Alarm Sound (Loud!)
    _sensorService.startAlarm();

    // 2. Start Recording Audio Evidence (10 seconds)
    _audioService.startRecording();

    // 3. Start the Countdown
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

  // --- SEND ALERT LOGIC ---
  Future<void> _sendAlert() async {
    // 1. Stop the Noise
    _sensorService.stopAlarm();

    // 2. Stop Recording & Get File Path
    String? localAudioPath = await _audioService.stopRecording();
    print("🎤 Audio recorded at: $localAudioPath"); // Debug print

    double lat = 0.0, lng = 0.0;
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lat = position.latitude;
      lng = position.longitude;
    } catch (e) {
      print("GPS Error: $e");
    }

    // 2. FIND NEARBY HOSPITALS (The Magic Step 🌟)
    List<Map<String, dynamic>> hospitals = [];
    if (lat != 0.0) {
      hospitals = await _placesService.findNearbyHospitals(lat, lng);
      // Optional: Send SMS to user contacts saying "Alerting X, Y, Z hospitals..."
    }

    // 3. Send SMS to Contacts
    _sendSMS();

    // 4. BLAST SOS TO HOSPITALS (DEMO MODE 🚧)
    for (var hospital in hospitals) {
      String realHospitalPhone = hospital['phone'];
      String hospitalName = hospital['name'];

      // ⚠️ HACKATHON SAFETY: Send to YOUR demo phone
      String demoSafeNumber = "+919258346766";

      // We simulate the check: "If the hospital HAS a phone number, we alert them"
      // if (realHospitalPhone.isNotEmpty) {
      if (hospitals.isNotEmpty) {
        // FIX: Create a REAL Google Maps Link using the lat/lng variables
        String mapsLink =
            "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

        String hospitalMsg =
            "🚨 DEMO ALERT: Crash detected near $hospitalName. "
            "Severity: ${widget.gForce.toStringAsFixed(1)}G. "
            "Location: $mapsLink"; // <--- Clickable Link!

        print(
          "📲 DEMO MODE: Redirecting SMS for $hospitalName to $demoSafeNumber",
        );

        try {
          // Send to YOUR phone
          await _smsSender.sendSms(
            phoneNumber: demoSafeNumber,
            message: hospitalMsg,
            simSlot: 0,
          );
        } catch (e) {
          print("Slot 0 failed, trying Slot 1...");
          try {
            // Retry with Slot 1
            await _smsSender.sendSms(
              phoneNumber: demoSafeNumber,
              message: hospitalMsg,
              simSlot: 1,
            );
          } catch (e2) {
            print("❌ Both SIM slots failed: $e2");
          }
        }
      }
    }

    setState(() => _alertSent = true);

    // 4. Get AI Text Report
    String analysis = await _sensorService.analyzeCrashWithGemini(
      widget.gForce,
    );

    // Add audio note if recorded
    if (localAudioPath != null) {
      analysis += "\n[AUDIO EVIDENCE]: Crash audio recorded and saved.";
    }

    if (hospitals.isNotEmpty) {
      analysis += "\n\n🏥 CONTACTED HOSPITALS:\n";
      for (var h in hospitals) {
        String p = h['phone'].isEmpty ? "(No Phone)" : h['phone'];
        analysis += "• ${h['name']} - $p\n";
      }
    }

    // 5. Save Everything to Database
    // Note: We pass 'audioPath', so the DB service converts it to Base64 text.
    String? reportId = await _dbService.saveAccidentReport(
      gForce: widget.gForce,
      aiAnalysis: analysis,
      status: "CRITICAL",
      audioPath: localAudioPath,
      nearbyHospitals: hospitals,
    );

    if (mounted) {
      setState(() {
        _aiAnalysis = analysis;
        _accidentDocId = reportId; // Important: We listen to this ID below
      });
    }
  }

  // --- SMS HELPER ---
  Future<void> _sendSMS() async {
    bool hasPermission = await _smsSender.checkSmsPermission();
    if (!hasPermission) {
      hasPermission = await _smsSender.requestSmsPermission();
    }

    if (hasPermission) {
      final prefs = await SharedPreferences.getInstance();
      List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];

      if (contacts.isEmpty) return;

      // Get Real GPS Location
      String mapLink = "Location Unavailable";
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        mapLink =
            "http://googleusercontent.com/maps.google.com/?q=${position.latitude},${position.longitude}";
      } catch (e) {
        print("GPS Error: $e");
      }

      String message = "SOS! Crash detected! Help needed. Track me: $mapLink";

      // Send to all contacts
      for (String number in contacts) {
        try {
          // Try Slot 0 first
          await _smsSender.sendSms(
            phoneNumber: number,
            message: message,
            simSlot: 0,
          );
        } catch (e) {
          print("Slot 0 failed, trying Slot 1...");
          try {
            // Retry with Slot 1
            await _smsSender.sendSms(
              phoneNumber: number,
              message: message,
              simSlot: 1,
            );
          } catch (e2) {
            print("❌ Both SIM slots failed: $e2");
          }
        }
      }
    }
  }

  // --- CANCEL LOGIC ---
  Future<void> cancelEmergency() async {
    _timer?.cancel();
    _sensorService.stopAlarm();
    _audioService.stopRecording(); // Stop mic if user cancelled

    // If alert was already sent, mark as SAFE so hospital knows
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
      backgroundColor: Colors.black, // Dark background base
      body: Stack(
        children: [
          // 1. FLASHING BACKGROUND
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: _alertSent
                    ? [Colors.black, Colors.black] // Stop flashing if sent
                    : [AppColors.alertRed.withOpacity(0.6), Colors.black],
                center: Alignment.center,
                radius: 1.0,
              ),
            ),
          ),

          // 2. SCROLLABLE & CENTERED CONTENT
          // LayoutBuilder allows us to check screen height
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // ConstrainedBox ensures the content takes up at least the full screen height
                // This allows 'MainAxisAlignment.center' to work even inside a ScrollView
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // 2. WARNING ICON
                        Icon(
                          _alertSent
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_rounded,
                          size: 80,
                          color: _alertSent
                              ? AppColors.primaryGreen
                              : AppColors.alertRed,
                        ),
                        const SizedBox(height: 20),

                        // 3. TITLE
                        Text(
                          _alertSent ? "SOS SENT" : "CRASH DETECTED",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // 4. CIRCULAR COUNTDOWN (Only before alert)
                        if (!_alertSent)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 150,
                                height: 150,
                                child: CircularProgressIndicator(
                                  value: _countdown / 10, // 10 second countdown
                                  strokeWidth: 10,
                                  backgroundColor: Colors.white12,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.alertRed,
                                      ),
                                ),
                              ),
                              Text(
                                "$_countdown",
                                style: const TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),

                        // 5. STATUS HUD (Glassmorphism Box)
                        if (_alertSent)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _aiAnalysis, // AI ANALYSIS TEXT
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                                const Divider(
                                  color: Colors.white12,
                                  height: 30,
                                ),
                                // Only show hospital status if document ID exists
                                if (_accidentDocId != null)
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('accidents')
                                        .doc(_accidentDocId)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      bool isAccepted = false;
                                      if (snapshot.hasData &&
                                          snapshot.data!.data() != null) {
                                        var data =
                                            snapshot.data!.data()
                                                as Map<String, dynamic>;
                                        isAccepted =
                                            (data['status'] == "ACCEPTED");
                                      }
                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isAccepted
                                                ? Icons.medical_services_rounded
                                                : Icons.wifi,
                                            color: isAccepted
                                                ? AppColors.primaryGreen
                                                : Colors.amber,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            isAccepted
                                                ? "AMBULANCE DISPATCHED"
                                                : "CONTACTING HOSPITALS...",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isAccepted
                                                  ? AppColors.primaryGreen
                                                  : Colors.amber,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 50),

                        // 6. SLIDER / BIG BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: cancelEmergency,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black, // Text color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "I AM SAFE (CANCEL)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
