import 'package:flutter/material.dart';
import 'dart:async';
// import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sms_sender_background/sms_sender.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'home_screen.dart';
import '../utils/constants.dart';
import '../services/sensor_service.dart';
import '../services/database_service.dart';
import '../services/audio_verification_service.dart';
import '../services/google_places_service.dart';
// Note: AIModelService is used internally by SensorService, so we don't strictly need to import it here,
// but we keep it if your legacy code referenced it.
// import '../services/ai_model_service.dart';

class EmergencyScreen extends StatefulWidget {
  final double gForce;
  const EmergencyScreen({super.key, this.gForce = 5.5});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with WidgetsBindingObserver {
  // --- SERVICES ---
  final DatabaseService _dbService = DatabaseService();
  final SensorService _sensorService = SensorService();
  final AudioVerificationService _audioService = AudioVerificationService();
  final SmsSender _smsSender = SmsSender();
  final GooglePlacesService _placesService = GooglePlacesService();

  // --- STATE VARIABLES ---
  int _countdown = 10;
  Timer? _timer;

  // LOGIC FLAGS
  bool _alertSent =
      false; // Becomes true when the countdown finishes (regardless of outcome)
  bool _isSafe = false; // Becomes true ONLY if AI says "False Alarm"

  String _aiAnalysis = "Analyzing environment...";
  String? _accidentDocId; // To track the Firestore document ID

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Start the Siren/Alarm
    print("🔊 Starting Emergency Alarm...");
    _sensorService.startAlarm();

    // 2. Start Recording Audio (Evidence)
    // The AudioService is now configured to record 16k WAV for the AI
    _audioService.startRecording();

    // 3. Start the Countdown Timer
    startCountdown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _sensorService.stopAlarm(); // Ensure alarm stops when leaving screen
    super.dispose();
  }

  // --- COUNTDOWN LOGIC ---
  void startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 0) {
        timer.cancel();
        // Time is up! Trigger the analysis and potential alert.
        _sendAlert();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  // ==============================================================================
  // 🛑 CORE LOGIC: THE AI GATEKEEPER
  // ==============================================================================
  Future<void> _sendAlert() async {
    // 1. STOP HARDWARE IMMEDIATELY
    // We don't want the alarm blasting while we listen to the recording or talk to AI.
    await _sensorService.stopAlarm();
    String? localAudioPath = await _audioService.stopRecording();

    print("🎤 Audio recorded for analysis at: $localAudioPath");

    // Update UI to show we are processing
    if (mounted) {
      setState(() {
        _aiAnalysis = "Contacting AI for Verification...";
      });
    }

    // --------------------------------------------------------------------------
    // 2. ASK THE AI (The Gatekeeper)
    // --------------------------------------------------------------------------
    String analysisResult = "Analysis Failed";

    // We use a try-catch block for robustness
    try {
      if (localAudioPath != null) {
        // This calls SensorService -> AIModelService (WAV Analysis) -> Pollinations API
        analysisResult = await _sensorService.verifyIncident(
          gForce: widget.gForce,
          audioFilePath: localAudioPath,
        );
      } else {
        // If the microphone failed, we must assume the worst case for safety.
        analysisResult =
            "CRITICAL: Audio hardware failed. Unable to verify. Proceeding with alert.";
      }
    } catch (e) {
      print("Error during AI Verification: $e");
      analysisResult = "CRITICAL: AI Service Error. Proceeding with alert.";
    }

    // --------------------------------------------------------------------------
    // 3. EVALUATE THE VERDICT
    // --------------------------------------------------------------------------

    // STRICT RULE: We only send alerts if the AI explicitly says "CRITICAL".
    // If it says "FALSE ALARM", "WARNING", or "NORMAL", we STOP.
    bool isCritical = analysisResult.toUpperCase().contains("CRITICAL");

    // --- CASE A: FALSE ALARM (SAFE) ---
    if (!isCritical) {
      print("✋ AI VERDICT: NOT CRITICAL. ALERTS CANCELLED.");

      // 1. Log to Database (as IGNORED/SAFE) so we have a record
      await _dbService.saveAccidentReport(
        gForce: widget.gForce,
        aiAnalysis: analysisResult,
        status: "IGNORED",
        audioPath: localAudioPath,
        nearbyHospitals: [],
      );

      // 2. Update UI to Green/Safe Mode
      if (mounted) {
        setState(() {
          _isSafe = true; // Turns screen Green
          _alertSent = true; // Stops countdown UI
          _aiAnalysis = "Analysis: $analysisResult\n\n✅ ALERTS CANCELLED";
        });

        // 3. Show a SnackBar to inform the user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("False Alarm Detected by AI. No SMS was sent."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }

      // 🛑 EXIT FUNCTION: DO NOT PROCEED TO SEND SMS
      return;
    }

    // --- CASE B: REAL CRASH (CRITICAL) ---
    print("🚨 AI VERIFIED CRITICAL. INITIATING EMERGENCY PROTOCOLS.");

    // 1. Get Current GPS Location
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

    // 2. Find Nearby Hospitals
    List<Map<String, dynamic>> hospitals = [];
    if (lat != 0.0) {
      hospitals = await _placesService.findNearbyHospitals(lat, lng);
    }

    // 3. SEND SMS TO EMERGENCY CONTACTS
    // This function handles permissions and looping through contacts
    await _sendSMS();

    // 4. BLAST SOS TO HOSPITALS (DEMO MODE)
    // In a real app, this would use an API. Here we simulate it via SMS to a demo number.
    // Pass the lat/lng variables you calculated earlier in _sendAlert
    await _alertHospitalsDemo(hospitals, lat, lng);

    // 5. SAVE CRITICAL REPORT TO DATABASE
    String finalLog = analysisResult;
    // Append hospital details to the log
    if (hospitals.isNotEmpty) {
      finalLog += "\n\n🏥 CONTACTED HOSPITALS:\n";
      for (var h in hospitals) {
        String p = h['phone'].isEmpty ? "(No Phone)" : h['phone'];
        finalLog += "• ${h['name']} - $p\n";
      }
    }

    String? reportId = await _dbService.saveAccidentReport(
      gForce: widget.gForce,
      aiAnalysis: finalLog,
      status: "CRITICAL",
      audioPath: localAudioPath,
      nearbyHospitals: hospitals,
    );

    // 6. Update UI to Red/Sent State
    if (mounted) {
      setState(() {
        _isSafe = false; // Remains Red
        _alertSent = true;
        _aiAnalysis = finalLog;
        _accidentDocId = reportId;
      });
    }
  }

  // --- HELPER: SMS SENDING LOGIC ---
  Future<void> _sendSMS() async {
    print("📲 Initiating SMS Sequence...");

    // 1. Check Permissions
    bool hasPermission = await _smsSender.checkSmsPermission();
    if (!hasPermission) {
      print("Requesting SMS Permission...");
      hasPermission = await _smsSender.requestSmsPermission();
    }

    if (hasPermission) {
      final prefs = await SharedPreferences.getInstance();
      List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];

      if (contacts.isEmpty) {
        print("⚠️ No emergency contacts found in SharedPreferences.");
        return;
      }

      // 2. Generate Google Maps Link
      String mapLink = "Location Unavailable";
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        mapLink =
            "http://googleusercontent.com/maps.google.com/?q=${position.latitude},${position.longitude}";
      } catch (e) {
        print("GPS Error for SMS: $e");
      }

      String message = "SOS! Crash detected! Help needed. Track me: $mapLink";

      // 3. Loop through contacts and send
      for (String number in contacts) {
        try {
          // Attempt Slot 0
          await _smsSender.sendSms(
            phoneNumber: number,
            message: message,
            simSlot: 0,
          );
          print("✅ SMS sent to $number (Slot 0)");
        } catch (e) {
          print("❌ Slot 0 failed for $number: $e. Trying Slot 1...");
          try {
            // Retry with Slot 1
            await _smsSender.sendSms(
              phoneNumber: number,
              message: message,
              simSlot: 1,
            );
            print("✅ SMS sent to $number (Slot 1)");
          } catch (e2) {
            print("❌ SMS completely failed for $number: $e2");
          }
        }
      }
    } else {
      print("❌ SMS Permission denied. Cannot send alerts.");
    }
  }

  // --- HELPER: HOSPITAL ALERT DEMO ---
  // --- HELPER: HOSPITAL ALERT DEMO ---
  // FIXED: Added lat/lng parameters to generate real map links
  Future<void> _alertHospitalsDemo(
    List<Map<String, dynamic>> hospitals,
    double lat,
    double lng,
  ) async {
    for (var hospital in hospitals) {
      String hospitalName = hospital['name'];

      // ⚠️ HACKATHON DEMO NUMBER
      String demoSafeNumber = "+919258346766";

      // FIXED: Use the actual coordinates passed to this function
      String mapsLink =
          "http://googleusercontent.com/maps.google.com/?q=$lat,$lng";

      String hospitalMsg =
          "🚨 DEMO ALERT: Crash detected near $hospitalName. "
          "Severity: ${widget.gForce.toStringAsFixed(1)}G. "
          "Location: $mapsLink";

      try {
        await _smsSender.sendSms(
          phoneNumber: demoSafeNumber,
          message: hospitalMsg,
          simSlot: 0,
        );
        print("🏥 Alert sent to Hospital (Demo): $hospitalName");
      } catch (e) {
        print("Failed to alert hospital (Demo): $e");
      }
    }
  }

  // --- CANCEL / RETURN HOME LOGIC ---
  Future<void> cancelEmergency() async {
    print("Actions Cancelled by User.");
    _timer?.cancel();
    _sensorService.stopAlarm();
    await _audioService.stopRecording();

    // If we already sent a CRITICAL alert, we need to tell the DB we are safe now
    if (_alertSent && !_isSafe && _accidentDocId != null) {
      print("Marking incident as SAFE in Database...");
      await _dbService.markAsSafe(_accidentDocId!);
    }

    if (mounted) {
      // Navigate back to Home and remove this screen from stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  // ==============================================================================
  // UI BUILD METHOD
  // ==============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark Theme Base
      body: Stack(
        children: [
          // ----------------------------------------------------------------------
          // 1. DYNAMIC BACKGROUND (Flash Red vs Green)
          // ----------------------------------------------------------------------
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: _isSafe
                    ? [
                        AppColors.primaryGreen.withOpacity(0.6),
                        Colors.black,
                      ] // GREEN (Safe Mode)
                    : _alertSent
                    ? [
                        Colors.black,
                        Colors.black,
                      ] // SOLID BLACK (Sent/Analyzing)
                    : [
                        AppColors.alertRed.withOpacity(0.6),
                        Colors.black,
                      ], // RED (Countdown)
                center: Alignment.center,
                radius: 1.0,
              ),
            ),
          ),

          // ----------------------------------------------------------------------
          // 2. SCROLLABLE CONTENT AREA
          // ----------------------------------------------------------------------
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25.0,
                      vertical: 40.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),

                        // A. STATUS ICON
                        // Changes based on Safe vs Critical state
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            _isSafe
                                ? Icons
                                      .verified_user_rounded // Shield for Safe
                                : (_alertSent
                                      ? Icons.check_circle_outline
                                      : Icons.warning_amber_rounded),
                            key: ValueKey<bool>(_isSafe),
                            size: 80,
                            color: _isSafe
                                ? AppColors.primaryGreen
                                : (_alertSent
                                      ? AppColors.primaryGreen
                                      : AppColors.alertRed),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // B. MAIN TITLE TEXT
                        Text(
                          _isSafe
                              ? "FALSE ALARM"
                              : (_alertSent ? "SOS SENT" : "CRASH DETECTED"),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                blurRadius: 10.0,
                                color: Colors.black45,
                                offset: Offset(2.0, 2.0),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // C. SUBTITLE / INSTRUCTION
                        Text(
                          _isSafe
                              ? "AI has determined this was not a crash."
                              : (_alertSent
                                    ? "Help is on the way."
                                    : "Sending alerts in..."),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // D. COUNTDOWN CIRCLE (Only visible before processing)
                        if (!_alertSent)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: CircularProgressIndicator(
                                  value: _countdown / 10, // 10-second scale
                                  strokeWidth: 12,
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

                        // E. ANALYSIS & INFO BOX (Visible after countdown)
                        if (_alertSent)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                0.1,
                              ), // Glassmorphism
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isSafe
                                    ? AppColors.primaryGreen.withOpacity(0.5)
                                    : Colors.white24,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "AI SITUATION REPORT",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _aiAnalysis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),

                                // Show Live Hospital Status (Only if Critical)
                                if (!_isSafe && _accidentDocId != null) ...[
                                  const Divider(
                                    color: Colors.white12,
                                    height: 30,
                                  ),

                                  // Real-time Firestore Listener
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
                                        // Check if a dashboard admin has clicked "ACCEPT"
                                        isAccepted =
                                            (data['status'] == "ACCEPTED");
                                      }

                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isAccepted
                                              ? AppColors.primaryGreen
                                                    .withOpacity(0.2)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isAccepted
                                                  ? Icons
                                                        .medical_services_rounded
                                                  : Icons.wifi_tethering,
                                              color: isAccepted
                                                  ? AppColors.primaryGreen
                                                  : Colors.amber,
                                              size: 20,
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
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),

                        const SizedBox(height: 40),

                        // F. ACTION BUTTON
                        // Swaps between "I AM SAFE" (Cancel) and "RETURN TO HOME" (Safe)
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: cancelEmergency,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSafe
                                  ? AppColors.primaryGreen
                                  : Colors.white,
                              foregroundColor: _isSafe
                                  ? Colors.white
                                  : Colors.black,
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isSafe ? Icons.home_rounded : Icons.cancel,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _isSafe
                                      ? "RETURN TO HOME"
                                      : "I AM SAFE (CANCEL)",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
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

// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Required for StreamBuilder
// import 'package:sms_sender_background/sms_sender.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geolocator/geolocator.dart';
// import 'home_screen.dart';
// import '../utils/constants.dart';
// import '../services/sensor_service.dart';
// import '../services/database_service.dart';
// import '../services/audio_verification_service.dart';
// import '../services/google_places_service.dart';
// import '../services/ai_model_service.dart';

// class EmergencyScreen extends StatefulWidget {
//   final double gForce;
//   const EmergencyScreen({super.key, this.gForce = 5.5});

//   @override
//   State<EmergencyScreen> createState() => _EmergencyScreenState();
// }

// class _EmergencyScreenState extends State<EmergencyScreen> {
//   // Services
//   final DatabaseService _dbService = DatabaseService();
//   final SensorService _sensorService = SensorService();
//   final AudioVerificationService _audioService = AudioVerificationService();
//   final SmsSender _smsSender = SmsSender();
//   final GooglePlacesService _placesService = GooglePlacesService();

//   // State Variables
//   int _countdown = 10;
//   Timer? _timer;
//   bool _alertSent = false;
//   String _aiAnalysis = "Analyzing environment...";
//   String? _accidentDocId; // The ID of the report in the database

//   @override
//   void initState() {
//     super.initState();
//     // 1. Start Alarm Sound (Loud!)
//     _sensorService.startAlarm();

//     // 2. Start Recording Audio Evidence (10 seconds)
//     _audioService.startRecording();

//     // 3. Start the Countdown
//     startCountdown();
//   }

//   void startCountdown() {
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_countdown == 0) {
//         timer.cancel();
//         _sendAlert();
//       } else {
//         setState(() {
//           _countdown--;
//         });
//       }
//     });
//   }

//   // --- SEND ALERT LOGIC ---
//   // Future<void> _sendAlert() async {
//   //   // 1. Stop the Noise
//   //   _sensorService.stopAlarm();

//   //   // 2. Stop Recording & Get File Path
//   //   String? localAudioPath = await _audioService.stopRecording();
//   //   print("🎤 Audio recorded at: $localAudioPath"); // Debug print

//   //   double lat = 0.0, lng = 0.0;
//   //   try {
//   //     Position position = await Geolocator.getCurrentPosition(
//   //       desiredAccuracy: LocationAccuracy.high,
//   //     );
//   //     lat = position.latitude;
//   //     lng = position.longitude;
//   //   } catch (e) {
//   //     print("GPS Error: $e");
//   //   }

//   //   // 2. FIND NEARBY HOSPITALS (The Magic Step 🌟)
//   //   List<Map<String, dynamic>> hospitals = [];
//   //   if (lat != 0.0) {
//   //     hospitals = await _placesService.findNearbyHospitals(lat, lng);
//   //     // Optional: Send SMS to user contacts saying "Alerting X, Y, Z hospitals..."
//   //   }

//   //   // 3. Send SMS to Contacts
//   //   _sendSMS();

//   //   // 4. BLAST SOS TO HOSPITALS (DEMO MODE 🚧)
//   //   for (var hospital in hospitals) {
//   //     //String realHospitalPhone = hospital['phone'];
//   //     String hospitalName = hospital['name'];

//   //     // ⚠️ HACKATHON SAFETY: Send to YOUR demo phone
//   //     String demoSafeNumber = "+919258346766";

//   //     // We simulate the check: "If the hospital HAS a phone number, we alert them"
//   //     // if (realHospitalPhone.isNotEmpty) {
//   //     if (hospitals.isNotEmpty) {
//   //       // FIX: Create a REAL Google Maps Link using the lat/lng variables
//   //       String mapsLink =
//   //           "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

//   //       String hospitalMsg =
//   //           "🚨 DEMO ALERT: Crash detected near $hospitalName. "
//   //           "Severity: ${widget.gForce.toStringAsFixed(1)}G. "
//   //           "Location: $mapsLink"; // <--- Clickable Link!

//   //       print(
//   //         "📲 DEMO MODE: Redirecting SMS for $hospitalName to $demoSafeNumber",
//   //       );

//   //       try {
//   //         // Send to YOUR phone
//   //         await _smsSender.sendSms(
//   //           phoneNumber: demoSafeNumber,
//   //           message: hospitalMsg,
//   //           simSlot: 0,
//   //         );
//   //       } catch (e) {
//   //         print("Slot 0 failed, trying Slot 1...");
//   //         try {
//   //           // Retry with Slot 1
//   //           await _smsSender.sendSms(
//   //             phoneNumber: demoSafeNumber,
//   //             message: hospitalMsg,
//   //             simSlot: 1,
//   //           );
//   //         } catch (e2) {
//   //           print("❌ Both SIM slots failed: $e2");
//   //         }
//   //       }
//   //     }
//   //   }

//   //   setState(() => _alertSent = true);

//   //   // 4. Get AI Text Report
//   //   String analysis = "Analyzing...";

//   //   final AIModelService aiService = AIModelService();
//   //   await aiService.loadModel();

//   //   // Add audio note if recorded
//   //   if (localAudioPath != null) {
//   //     // FIX: Use SensorService to verify (it handles AIModelService internally now)
//   //     analysis = await _sensorService.verifyIncident(
//   //       gForce: widget.gForce,
//   //       audioFilePath: localAudioPath,
//   //     );
//   //   } else {
//   //     analysis =
//   //         "Audio failed. G-Force: ${widget.gForce}G. Please verify status.";
//   //   }

//   //   if (hospitals.isNotEmpty) {
//   //     analysis += "\n\n🏥 CONTACTED HOSPITALS:\n";
//   //     for (var h in hospitals) {
//   //       String p = h['phone'].isEmpty ? "(No Phone)" : h['phone'];
//   //       analysis += "• ${h['name']} - $p\n";
//   //     }
//   //   }

//   //   // 5. Save Everything to Database
//   //   // Note: We pass 'audioPath', so the DB service converts it to Base64 text.
//   //   String? reportId = await _dbService.saveAccidentReport(
//   //     gForce: widget.gForce,
//   //     aiAnalysis: analysis,
//   //     status: "CRITICAL",
//   //     audioPath: localAudioPath,
//   //     nearbyHospitals: hospitals,
//   //   );

//   //   if (mounted) {
//   //     setState(() {
//   //       _aiAnalysis = analysis;
//   //       _accidentDocId = reportId; // Important: We listen to this ID below
//   //     });
//   //   }
//   // }

//   // --- SEND ALERT LOGIC (GATEKEEPER PATTERN) ---
//   Future<void> _sendAlert() async {
//     // 1. STOP EVERYTHING FIRST
//     _sensorService.stopAlarm();
//     String? localAudioPath = await _audioService.stopRecording();
//     print("🎤 Audio recorded at: $localAudioPath");
    
//     // Show user we are thinking...
//     setState(() {
//       _aiAnalysis = "Verifying Incident with AI...";
//     });

//     // -----------------------------------------------------------
//     // 2. GATEKEEPER: ASK AI BEFORE SENDING ANYTHING
//     // -----------------------------------------------------------
//     String analysisResult = "Analysis Failed";
    
//     // If we have audio, ask the AI
//     if (localAudioPath != null) {
//       analysisResult = await _sensorService.verifyIncident(
//         gForce: widget.gForce,
//         audioFilePath: localAudioPath,
//       );
//     } else {
//       // If mic failed, we cannot be sure, so we assume CRITICAL to be safe
//       analysisResult = "WARNING: Audio hardware failed. Proceeding with alert.";
//     }

//     // UPDATE UI WITH VERDICT
//     setState(() {
//       _aiAnalysis = analysisResult;
//     });

//     // -----------------------------------------------------------
//     // 3. DECISION TIME
//     // -----------------------------------------------------------
    
//     // CHECK: Did the AI explicitly say "FALSE ALARM"?
//     // We use toUpperCase() to make sure case differences don't break it.
//     if (analysisResult.toUpperCase().contains("FALSE ALARM")) {
      
//       print("🛑 AI BLOCKED THE ALERT: False Alarm Detected.");
      
//       // A. Save "False Alarm" to Database for logs
//       await _dbService.saveAccidentReport(
//         gForce: widget.gForce,
//         aiAnalysis: analysisResult,
//         status: "SAFE", // Mark as Safe/False Alarm
//         audioPath: localAudioPath,
//         nearbyHospitals: [], // No hospitals needed
//       );

//       // B. Auto-Exit or Show Safe State
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//            const SnackBar(
//              content: Text("AI detected a False Alarm. Alert Cancelled."),
//              backgroundColor: Colors.green,
//              duration: Duration(seconds: 4),
//            ),
//         );
//         // Optional: Go back to home automatically after 2 seconds
//         Future.delayed(const Duration(seconds: 2), () {
//            if (mounted) cancelEmergency(); 
//         });
//       }
      
//       // 🛑 CRITICAL RETURN: THIS STOPS THE SMS FROM SENDING
//       return; 
//     }

//     // -----------------------------------------------------------
//     // 4. IF WE ARE HERE -> IT IS REAL! PROCEED TO ALERT
//     // -----------------------------------------------------------
//     print("🚨 AI VERIFIED CRITICAL/WARNING. SENDING ALERTS NOW.");

//     double lat = 0.0, lng = 0.0;
//     try {
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       lat = position.latitude;
//       lng = position.longitude;
//     } catch (e) {
//       print("GPS Error: $e");
//     }

//     // 5. FIND HOSPITALS
//     List<Map<String, dynamic>> hospitals = [];
//     if (lat != 0.0) {
//       hospitals = await _placesService.findNearbyHospitals(lat, lng);
//     }

//     // 6. SEND SMS TO CONTACTS
//     await _sendSMS();

//     // 7. ALERT HOSPITALS (DEMO)
//     for (var hospital in hospitals) {
//       String hospitalName = hospital['name'];
//       String demoSafeNumber = "+919258346766"; 

//       if (hospitals.isNotEmpty) {
//         String mapsLink = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
//         String hospitalMsg =
//             "🚨 DEMO ALERT: Crash detected near $hospitalName. "
//             "Severity: ${widget.gForce.toStringAsFixed(1)}G. "
//             "Location: $mapsLink";

//         try {
//           await _smsSender.sendSms(
//             phoneNumber: demoSafeNumber,
//             message: hospitalMsg,
//             simSlot: 0,
//           );
//         } catch (e) {
//              // Try slot 1...
//         }
//       }
//     }

//     // Update UI to show SENT state
//     setState(() => _alertSent = true);

//     // 8. FINAL DB SAVE (CRITICAL STATUS)
//     // Append hospital info to the AI analysis text for the DB record
//     String finalLog = analysisResult;
//     if (hospitals.isNotEmpty) {
//       finalLog += "\n\n🏥 CONTACTED HOSPITALS:\n";
//       for (var h in hospitals) {
//         String p = h['phone'].isEmpty ? "(No Phone)" : h['phone'];
//         finalLog += "• ${h['name']} - $p\n";
//       }
//     }

//     String? reportId = await _dbService.saveAccidentReport(
//       gForce: widget.gForce,
//       aiAnalysis: finalLog,
//       status: "CRITICAL",
//       audioPath: localAudioPath,
//       nearbyHospitals: hospitals,
//     );

//     if (mounted) {
//       setState(() {
//         _accidentDocId = reportId;
//       });
//     }
//   }

//   // --- SMS HELPER ---
//   Future<void> _sendSMS() async {
//     bool hasPermission = await _smsSender.checkSmsPermission();
//     if (!hasPermission) {
//       hasPermission = await _smsSender.requestSmsPermission();
//     }

//     if (hasPermission) {
//       final prefs = await SharedPreferences.getInstance();
//       List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];

//       if (contacts.isEmpty) return;

//       // Get Real GPS Location
//       String mapLink = "Location Unavailable";
//       try {
//         Position position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//         );
//         mapLink =
//             "http://googleusercontent.com/maps.google.com/?q=${position.latitude},${position.longitude}";
//       } catch (e) {
//         print("GPS Error: $e");
//       }

//       String message = "SOS! Crash detected! Help needed. Track me: $mapLink";

//       // Send to all contacts
//       for (String number in contacts) {
//         try {
//           // Try Slot 0 first
//           await _smsSender.sendSms(
//             phoneNumber: number,
//             message: message,
//             simSlot: 0,
//           );
//         } catch (e) {
//           print("Slot 0 failed, trying Slot 1...");
//           try {
//             // Retry with Slot 1
//             await _smsSender.sendSms(
//               phoneNumber: number,
//               message: message,
//               simSlot: 1,
//             );
//           } catch (e2) {
//             print("❌ Both SIM slots failed: $e2");
//           }
//         }
//       }
//     }
//   }

//   // --- CANCEL LOGIC ---
//   Future<void> cancelEmergency() async {
//     _timer?.cancel();
//     _sensorService.stopAlarm();
//     _audioService.stopRecording(); // Stop mic if user cancelled

//     // If alert was already sent, mark as SAFE so hospital knows
//     if (_alertSent && _accidentDocId != null) {
//       await _dbService.markAsSafe(_accidentDocId!);
//     }

//     if (mounted) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const HomeScreen()),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _sensorService.stopAlarm();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black, // Dark background base
//       body: Stack(
//         children: [
//           // 1. FLASHING BACKGROUND
//           AnimatedContainer(
//             duration: const Duration(milliseconds: 500),
//             width: double.infinity,
//             height: double.infinity,
//             decoration: BoxDecoration(
//               gradient: RadialGradient(
//                 colors: _alertSent
//                     ? [Colors.black, Colors.black] // Stop flashing if sent
//                     : [AppColors.alertRed.withOpacity(0.6), Colors.black],
//                 center: Alignment.center,
//                 radius: 1.0,
//               ),
//             ),
//           ),

//           // 2. SCROLLABLE & CENTERED CONTENT
//           // LayoutBuilder allows us to check screen height
//           LayoutBuilder(
//             builder: (context, constraints) {
//               return SingleChildScrollView(
//                 // ConstrainedBox ensures the content takes up at least the full screen height
//                 // This allows 'MainAxisAlignment.center' to work even inside a ScrollView
//                 child: ConstrainedBox(
//                   constraints: BoxConstraints(minHeight: constraints.maxHeight),
//                   child: Padding(
//                     padding: const EdgeInsets.all(25.0),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const SizedBox(height: 40),

//                         // 2. WARNING ICON
//                         Icon(
//                           _alertSent
//                               ? Icons.check_circle_outline
//                               : Icons.warning_amber_rounded,
//                           size: 80,
//                           color: _alertSent
//                               ? AppColors.primaryGreen
//                               : AppColors.alertRed,
//                         ),
//                         const SizedBox(height: 20),

//                         // 3. TITLE
//                         Text(
//                           _alertSent ? "SOS SENT" : "CRASH DETECTED",
//                           textAlign: TextAlign.center,
//                           style: const TextStyle(
//                             fontSize: 32,
//                             fontWeight: FontWeight.w900,
//                             color: Colors.white,
//                             letterSpacing: 2,
//                           ),
//                         ),

//                         const SizedBox(height: 40),

//                         // 4. CIRCULAR COUNTDOWN (Only before alert)
//                         if (!_alertSent)
//                           Stack(
//                             alignment: Alignment.center,
//                             children: [
//                               SizedBox(
//                                 width: 150,
//                                 height: 150,
//                                 child: CircularProgressIndicator(
//                                   value: _countdown / 10, // 10 second countdown
//                                   strokeWidth: 10,
//                                   backgroundColor: Colors.white12,
//                                   valueColor:
//                                       const AlwaysStoppedAnimation<Color>(
//                                         AppColors.alertRed,
//                                       ),
//                                 ),
//                               ),
//                               Text(
//                                 "$_countdown",
//                                 style: const TextStyle(
//                                   fontSize: 60,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                             ],
//                           ),

//                         // 5. STATUS HUD (Glassmorphism Box)
//                         if (_alertSent)
//                           Container(
//                             margin: const EdgeInsets.symmetric(vertical: 20),
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(color: Colors.white24),
//                             ),
//                             child: Column(
//                               children: [
//                                 Text(
//                                   _aiAnalysis, // AI ANALYSIS TEXT
//                                   textAlign: TextAlign.center,
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 15,
//                                     height: 1.5,
//                                   ),
//                                 ),
//                                 const Divider(
//                                   color: Colors.white12,
//                                   height: 30,
//                                 ),
//                                 // Only show hospital status if document ID exists
//                                 if (_accidentDocId != null)
//                                   StreamBuilder<DocumentSnapshot>(
//                                     stream: FirebaseFirestore.instance
//                                         .collection('accidents')
//                                         .doc(_accidentDocId)
//                                         .snapshots(),
//                                     builder: (context, snapshot) {
//                                       bool isAccepted = false;
//                                       if (snapshot.hasData &&
//                                           snapshot.data!.data() != null) {
//                                         var data =
//                                             snapshot.data!.data()
//                                                 as Map<String, dynamic>;
//                                         isAccepted =
//                                             (data['status'] == "ACCEPTED");
//                                       }
//                                       return Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.center,
//                                         children: [
//                                           Icon(
//                                             isAccepted
//                                                 ? Icons.medical_services_rounded
//                                                 : Icons.wifi,
//                                             color: isAccepted
//                                                 ? AppColors.primaryGreen
//                                                 : Colors.amber,
//                                           ),
//                                           const SizedBox(width: 10),
//                                           Text(
//                                             isAccepted
//                                                 ? "AMBULANCE DISPATCHED"
//                                                 : "CONTACTING HOSPITALS...",
//                                             style: TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               color: isAccepted
//                                                   ? AppColors.primaryGreen
//                                                   : Colors.amber,
//                                             ),
//                                           ),
//                                         ],
//                                       );
//                                     },
//                                   ),
//                               ],
//                             ),
//                           ),

//                         const SizedBox(height: 50),

//                         // 6. SLIDER / BIG BUTTON
//                         SizedBox(
//                           width: double.infinity,
//                           height: 55,
//                           child: ElevatedButton(
//                             onPressed: cancelEmergency,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.white,
//                               foregroundColor: Colors.black, // Text color
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(30),
//                               ),
//                             ),
//                             child: const Text(
//                               "I AM SAFE (CANCEL)",
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
