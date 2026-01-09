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
//
// class EmergencyScreen extends StatefulWidget {
//   final double gForce;
//   const EmergencyScreen({super.key, this.gForce = 5.5});
//
//   @override
//   State<EmergencyScreen> createState() => _EmergencyScreenState();
// }
//
// class _EmergencyScreenState extends State<EmergencyScreen> {
//   // Services
//   final DatabaseService _dbService = DatabaseService();
//   final SensorService _sensorService = SensorService();
//   final AudioVerificationService _audioService = AudioVerificationService();
//   final SmsSender _smsSender = SmsSender();
//   final GooglePlacesService _placesService = GooglePlacesService();
//
//   // State Variables
//   int _countdown = 10;
//   Timer? _timer;
//   bool _alertSent = false;
//   String _aiAnalysis = "Analyzing environment...";
//   String? _accidentDocId; // The ID of the report in the database
//
//   @override
//   void initState() {
//     super.initState();
//     // 1. Start Alarm Sound (Loud!)
//     _sensorService.startAlarm();
//
//     // 2. Start Recording Audio Evidence (10 seconds)
//     _audioService.startRecording();
//
//     // 3. Start the Countdown
//     startCountdown();
//   }
//
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
//
//   // --- SEND ALERT LOGIC ---
//   Future<void> _sendAlert() async {
//     // 1. Stop the Noise
//     _sensorService.stopAlarm();
//
//     // 2. Stop Recording & Get File Path
//     String? localAudioPath = await _audioService.stopRecording();
//
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
//
//     // 2. FIND NEARBY HOSPITALS (The Magic Step 🌟)
//     List<Map<String, dynamic>> hospitals = [];
//     if (lat != 0.0) {
//       hospitals = await _placesService.findNearbyHospitals(lat, lng);
//       // Optional: Send SMS to user contacts saying "Alerting X, Y, Z hospitals..."
//     }
//
//     // 3. Send SMS to Contacts
//     _sendSMS();
//
//     // We try to send SMS to the found hospitals
//     // for (var hospital in hospitals) {
//     //   String phone = hospital['phone'];
//     //   String name = hospital['name'];
//
//     //   // Only try if they have a phone number
//     //   if (phone.isNotEmpty) {
//     //     // Clean the number (remove spaces, brackets) for SMS
//     //     String cleanPhone = phone
//     //         .replaceAll(RegExp(r'\s+'), '')
//     //         .replaceAll('-', '');
//
//     //     // Construct a message for the Hospital
//     //     String hospitalMsg =
//     //         "EMERGENCY ALERT: Crash detected near $name. "
//     //         "Severity: ${widget.gForce.toStringAsFixed(1)}G. "
//     //         "Location: http://maps.google.com/?q=$lat,$lng "
//     //         "Accept: http://guardian-app.com/accept (Simulated Link)";
//
//     //     print("📲 Attempting SMS to Hospital ($name): $cleanPhone");
//
//     //     // Send SMS (Note: Will fail if it's a Landline)
//     //     await _smsSender.sendSms(
//     //       phoneNumber: cleanPhone,
//     //       message: hospitalMsg,
//     //       simSlot: 0,
//     //     );
//     //   }
//     // }
//
//     for (var hospital in hospitals) {
//       String realHospitalPhone = hospital['phone'];
//       String hospitalName = hospital['name'];
//
//       // ⚠️ HACKATHON SAFETY:
//       // Instead of the real hospital number, we send to demo phone.
//       String demoSafeNumber = "+916398567479";
//
//       if (realHospitalPhone.isNotEmpty) {
//
//         String hospitalMsg = "🚨 DEMO ALERT: Crash detected near $hospitalName. "
//             "Severity: ${widget.gForce.toStringAsFixed(1)}G. "
//             "Location: http://maps.google.com/?q=$lat,$lng";
//
//         print("📲 DEMO MODE: Redirecting SMS for $hospitalName to $demoSafeNumber");
//
//         // Send to phone, but the message says it's for "Apollo Hospital"
//         await _smsSender.sendSms(
//           phoneNumber: demoSafeNumber,
//           message: hospitalMsg,
//           simSlot: 0
//         );
//       }
//     }
//
//     setState(() => _alertSent = true);
//
//     // 4. Get AI Text Report
//     String analysis = await _sensorService.analyzeCrashWithGemini(
//       widget.gForce,
//     );
//
//     // Add audio note if recorded
//     if (localAudioPath != null) {
//       analysis += "\n[AUDIO EVIDENCE]: Crash audio recorded and saved.";
//     }
//
//     if (hospitals.isNotEmpty) {
//       analysis += "\n\n🏥 CONTACTED HOSPITALS:\n";
//       for (var h in hospitals) {
//         String p = h['phone'].isEmpty ? "(No Phone)" : h['phone'];
//         analysis += "• ${h['name']} - $p\n";
//       }
//     }
//
//     // 5. Save Everything to Database
//     // Note: We pass 'audioPath', so the DB service converts it to Base64 text.
//     String? reportId = await _dbService.saveAccidentReport(
//       gForce: widget.gForce,
//       aiAnalysis: analysis,
//       status: "CRITICAL",
//       audioPath: localAudioPath,
//       nearbyHospitals: hospitals,
//     );
//
//     if (mounted) {
//       setState(() {
//         _aiAnalysis = analysis;
//         _accidentDocId = reportId; // Important: We listen to this ID below
//       });
//     }
//   }
//
//   // --- SMS HELPER ---
//   Future<void> _sendSMS() async {
//     bool hasPermission = await _smsSender.checkSmsPermission();
//     if (!hasPermission) {
//       hasPermission = await _smsSender.requestSmsPermission();
//     }
//
//     if (hasPermission) {
//       final prefs = await SharedPreferences.getInstance();
//       List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];
//
//       if (contacts.isEmpty) return;
//
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
//
//       String message = "SOS! Crash detected! Help needed. Track me: $mapLink";
//
//       // Send to all contacts
//       for (String number in contacts) {
//         await _smsSender.sendSms(
//           phoneNumber: number,
//           message: message,
//           simSlot: 0,
//         );
//       }
//     }
//   }
//
//   // --- CANCEL LOGIC ---
//   Future<void> cancelEmergency() async {
//     _timer?.cancel();
//     _sensorService.stopAlarm();
//     _audioService.stopRecording(); // Stop mic if user cancelled
//
//     // If alert was already sent, mark as SAFE so hospital knows
//     if (_alertSent && _accidentDocId != null) {
//       await _dbService.markAsSafe(_accidentDocId!);
//     }
//
//     if (mounted) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const HomeScreen()),
//       );
//     }
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel();
//     _sensorService.stopAlarm();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Container(
//             // Flash Red Background if Alert Sent
//             color: _alertSent
//                 ? Colors.black
//                 : AppColors.alertRed.withOpacity(0.2),
//             width: double.infinity,
//             constraints: BoxConstraints(
//               minHeight: MediaQuery.of(context).size.height - 50,
//             ),
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 // Top Icon
//                 Icon(
//                   _alertSent ? Icons.sensors : Icons.warning_amber_rounded,
//                   size: 100,
//                   color: _alertSent ? Colors.grey : AppColors.alertRed,
//                 ),
//                 const SizedBox(height: 20),
//
//                 // Header Text
//                 Text(
//                   _alertSent ? "SOS SENT!\nCONNECTING..." : "CRASH DETECTED",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                     color: _alertSent ? Colors.white : AppColors.alertRed,
//                   ),
//                 ),
//                 const SizedBox(height: 40),
//
//                 // Countdown Timer (Only before alert)
//                 if (!_alertSent)
//                   Text(
//                     "$_countdown",
//                     style: const TextStyle(
//                       fontSize: 100,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//
//                 // --- LIVE STATUS BOX (Changes to Green when Accepted) ---
//                 if (_alertSent && _accidentDocId != null)
//                   StreamBuilder<DocumentSnapshot>(
//                     stream: FirebaseFirestore.instance
//                         .collection('accidents')
//                         .doc(_accidentDocId)
//                         .snapshots(),
//                     builder: (context, snapshot) {
//                       // Default values while loading
//                       bool isAccepted = false;
//
//                       if (snapshot.hasData && snapshot.data!.data() != null) {
//                         var data =
//                             snapshot.data!.data() as Map<String, dynamic>;
//                         // Check if Hospital changed status to ACCEPTED
//                         isAccepted = (data['status'] == "ACCEPTED");
//                       }
//
//                       return Container(
//                         padding: const EdgeInsets.all(20),
//                         decoration: BoxDecoration(
//                           // Change Color: RED/BLACK -> GREEN
//                           color: isAccepted
//                               ? Colors.green[800]
//                               : Colors.black54,
//                           borderRadius: BorderRadius.circular(15),
//                           border: Border.all(
//                             color: isAccepted
//                                 ? Colors.greenAccent
//                                 : AppColors.alertRed,
//                             width: 2,
//                           ),
//                         ),
//                         child: Column(
//                           children: [
//                             // STATUS ICON
//                             Icon(
//                               isAccepted
//                                   ? Icons.medical_services_rounded
//                                   : Icons.wifi_tethering,
//                               size: 50,
//                               color: Colors.white,
//                             ),
//                             const SizedBox(height: 10),
//
//                             // MAIN STATUS TEXT
//                             Text(
//                               isAccepted
//                                   ? "AMBULANCE DISPATCHED!"
//                                   : "WAITING FOR RESPONSE...",
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(
//                                 fontSize: 22,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             const SizedBox(height: 10),
//
//                             // SUBTEXT
//                             Text(
//                               isAccepted
//                                   ? "Help is on the way.\nStay calm."
//                                   : "Alert sent to nearby hospitals.",
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(color: Colors.white70),
//                             ),
//
//                             const SizedBox(height: 15),
//                             const Divider(color: Colors.white24),
//
//                             // AI Report Section
//                             const Text(
//                               "AI ANALYSIS & EVIDENCE",
//                               style: TextStyle(
//                                 color: Colors.grey,
//                                 fontSize: 10,
//                               ),
//                             ),
//                             const SizedBox(height: 5),
//                             Text(
//                               _aiAnalysis,
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//
//                 const SizedBox(height: 60),
//
//                 // Cancel Button
//                 SizedBox(
//                   width: double.infinity,
//                   height: 60,
//                   child: ElevatedButton(
//                     onPressed: cancelEmergency,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.white,
//                       foregroundColor: AppColors.alertRed,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                     ),
//                     child: const Text(
//                       "I AM SAFE (CANCEL)",
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'package:sms_sender_background/sms_sender.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geolocator/geolocator.dart';
// import 'home_screen.dart';
// import '../utils/constants.dart';
// import '../services/sensor_service.dart';
// import '../services/database_service.dart';
// import '../services/audio_verification_service.dart'; 

// class EmergencyScreen extends StatefulWidget {
//   final double gForce;
//   const EmergencyScreen({super.key, this.gForce = 5.5});

//   @override
//   State<EmergencyScreen> createState() => _EmergencyScreenState();
// }

// class _EmergencyScreenState extends State<EmergencyScreen> {
//   final DatabaseService _dbService = DatabaseService();
//   final SensorService _sensorService = SensorService();
//   final AudioVerificationService _audioService = AudioVerificationService(); 
//   final SmsSender _smsSender = SmsSender();

//   int _countdown = 10;
//   Timer? _timer;
//   bool _alertSent = false;
//   String _aiAnalysis = "Analyzing environment...";
//   String? _accidentDocId;

//   @override
//   void initState() {
//     super.initState();
//     // 1. Start Alarm Sound
//     _sensorService.startAlarm();
    
//     // 2. Start Recording Audio (Evidence)
//     _audioService.startRecording();

//     // 3. Start Countdown
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

//   Future<void> _sendAlert() async {
//     _sensorService.stopAlarm();
    
//     // 1. Stop Recording (Get the local file path)
//     String? localAudioPath = await _audioService.stopRecording();
    
//     // 2. Send SMS
//     _sendSMS(); 
    
//     setState(() => _alertSent = true);

//     // 3. Get AI Text Report
//     String analysis = await _sensorService.analyzeCrashWithGemini(widget.gForce);
    
//     // Add audio confirmation tag if true
//     if (localAudioPath != null) {
//       analysis += "\n[AUDIO EVIDENCE]: Crash audio recorded and saved.";
//     }

//     // 4. Save to Database (Passing the path, not URL)
//     String? reportId = await _dbService.saveAccidentReport(
//       gForce: widget.gForce,
//       aiAnalysis: analysis,
//       status: "CRITICAL",
//       audioPath: localAudioPath, // <--- CHANGED: Passing path
//     );

//     if (mounted) {
//       setState(() {
//         _aiAnalysis = analysis;
//         _accidentDocId = reportId;
//       });
//     }
//   }

//   // (Keep _sendSMS and cancelEmergency same as before)
//   Future<void> _sendSMS() async {
//       bool hasPermission = await _smsSender.checkSmsPermission();
//       if (!hasPermission) hasPermission = await _smsSender.requestSmsPermission();

//       if (hasPermission) {
//         final prefs = await SharedPreferences.getInstance();
//         List<String> contacts = prefs.getStringList('emergency_contacts') ?? [];
//         if (contacts.isEmpty) return;

//         String mapLink = "Location Unavailable";
//         try {
//           Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
//           mapLink = "http://googleusercontent.com/maps.google.com/?q=${position.latitude},${position.longitude}";
//         } catch (e) { print(e); }

//         String message = "SOS! Crash detected! Help needed. Track me: $mapLink";

//         for (String number in contacts) {
//           await _smsSender.sendSms(phoneNumber: number, message: message, simSlot: 0);
//         }
//       }
//   }

//   Future<void> cancelEmergency() async {
//     _timer?.cancel();
//     _sensorService.stopAlarm();
//     _audioService.stopRecording(); // Stop if cancelled

//     if (_alertSent && _accidentDocId != null) {
//       await _dbService.markAsSafe(_accidentDocId!);
//     }

//     if (mounted) {
//       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
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
//       backgroundColor: AppColors.background,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Container(
//             color: AppColors.alertRed.withOpacity(0.2),
//             width: double.infinity,
//             constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 50),
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(Icons.warning_amber_rounded, size: 100, color: AppColors.alertRed),
//                 const SizedBox(height: 20),
//                 Text(_alertSent ? "SOS SENT!\nEVIDENCE UPLOADED" : "CRASH DETECTED",
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.alertRed)),
//                 const SizedBox(height: 40),
//                 if (!_alertSent)
//                   Text("$_countdown", style: const TextStyle(fontSize: 100, fontWeight: FontWeight.bold, color: Colors.white)),
//                 if (_alertSent)
//                   Container(
//                     padding: const EdgeInsets.all(15),
//                     decoration: BoxDecoration(
//                         color: Colors.black54, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.alertRed)),
//                     child: Column(
//                       children: [
//                         const Text("REPORT STATUS", style: TextStyle(color: Colors.grey, fontSize: 12)),
//                         const SizedBox(height: 5),
//                         Text(_aiAnalysis, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
//                         const SizedBox(height: 10),
//                         const Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                              Icon(Icons.mic, color: Colors.blue, size: 16),
//                              SizedBox(width: 5),
//                              Text("Audio Evidence Uploaded", style: TextStyle(color: Colors.blue, fontSize: 12)),
//                           ],
//                         )
//                       ],
//                     ),
//                   ),
//                 const SizedBox(height: 60),
//                 SizedBox(
//                   width: double.infinity,
//                   height: 60,
//                   child: ElevatedButton(
//                     onPressed: cancelEmergency,
//                     style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.white, foregroundColor: AppColors.alertRed,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
//                     child: const Text("I AM SAFE (CANCEL)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io'; // Needed for File
import 'dart:convert'; // Needed for base64Encode
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
  String? _accidentDocId;

  @override
  void initState() {
    super.initState();
    // 1. Start Alarm Sound (Loud!)
    _sensorService.startAlarm();

    // 2. Start Recording Audio Evidence (10 seconds)
    _audioService.startRecording();

    // 3. Start the Countdown
    startCountdown();

    // 4. Listen to Sensor Service Stream (Optional: updates UI in real-time)
    _sensorService.crashStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _aiAnalysis = status;
        });
      }
    });
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

    // 2. Stop Recording & Process Audio
    String? localAudioPath = await _audioService.stopRecording();
    String base64Audio = "";

    // Convert Audio to Base64 for the AI Model
    if (localAudioPath != null) {
      final File audioFile = File(localAudioPath);
      if (await audioFile.exists()) {
        List<int> audioBytes = await audioFile.readAsBytes();
        base64Audio = base64Encode(audioBytes);
      }
    }

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

    // 3. FIND NEARBY HOSPITALS
    List<Map<String, dynamic>> hospitals = [];
    if (lat != 0.0) {
      hospitals = await _placesService.findNearbyHospitals(lat, lng);
    }

    // 4. Send SMS to Contacts
    _sendSMS();

    // Send SMS to Hospitals (Demo Mode)
    for (var hospital in hospitals) {
      String realHospitalPhone = hospital['phone'];
      String hospitalName = hospital['name'];

      // ⚠️ DEMO SAFETY: Send to demo number instead of real hospital
      String demoSafeNumber = "+916398567479";

      if (realHospitalPhone.isNotEmpty) {
        String hospitalMsg = "🚨 DEMO ALERT: Crash detected near $hospitalName. "
            "Severity: ${widget.gForce.toStringAsFixed(1)}G. "
            "Location: http://maps.google.com/?q=$lat,$lng";

        print("📲 DEMO MODE: Redirecting SMS for $hospitalName to $demoSafeNumber");

        await _smsSender.sendSms(
            phoneNumber: demoSafeNumber,
            message: hospitalMsg,
            simSlot: 0
        );
      }
    }

    setState(() => _alertSent = true);

    // 5. Get AI Verdict (Fusion Model: YAMNet + Pollinations)
    // NOTE: We pass the base64 string here for the logic layer
    String analysisVerdict = "Analysis Failed";
    try {
      // Ensure your SensorService.analyzeAccident returns Future<String>
      // If it returns void, update SensorService to return the verdict string.
      analysisVerdict = await _sensorService.analyzeAccident(
        widget.gForce,
        base64Audio,
      );
    } catch (e) {
      print("AI Analysis Error: $e");
    }

    // Add Evidence Tags
    String fullReport = analysisVerdict;
    if (localAudioPath != null) {
      fullReport += "\n\n[AUDIO EVIDENCE]: Recorded & Analyzed via YAMNet.";
    }

    if (hospitals.isNotEmpty) {
      fullReport += "\n\n🏥 ALERTED HOSPITALS:\n";
      for (var h in hospitals) {
        String p = h['phone'].isEmpty ? "(No Phone)" : h['phone'];
        fullReport += "• ${h['name']} - $p\n";
      }
    }

    // 6. Save Everything to Database
    String? reportId = await _dbService.saveAccidentReport(
      gForce: widget.gForce,
      aiAnalysis: fullReport,
      status: "CRITICAL",
      audioPath: localAudioPath,
      nearbyHospitals: hospitals,
    );

    if (mounted) {
      setState(() {
        _aiAnalysis = fullReport;
        _accidentDocId = reportId;
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

      for (String number in contacts) {
        await _smsSender.sendSms(
          phoneNumber: number,
          message: message,
          simSlot: 0,
        );
      }
    }
  }

  // --- CANCEL LOGIC ---
  Future<void> cancelEmergency() async {
    _timer?.cancel();
    _sensorService.stopAlarm();
    _audioService.stopRecording();

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
            color: _alertSent
                ? Colors.black
                : AppColors.alertRed.withOpacity(0.2),
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 50,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _alertSent ? Icons.sensors : Icons.warning_amber_rounded,
                  size: 100,
                  color: _alertSent ? Colors.grey : AppColors.alertRed,
                ),
                const SizedBox(height: 20),

                Text(
                  _alertSent ? "SOS SENT!\nCONNECTING..." : "CRASH DETECTED",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _alertSent ? Colors.white : AppColors.alertRed,
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

                // --- LIVE STATUS BOX ---
                if (_alertSent && _accidentDocId != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('accidents')
                        .doc(_accidentDocId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      bool isAccepted = false;

                      if (snapshot.hasData && snapshot.data!.data() != null) {
                        var data =
                        snapshot.data!.data() as Map<String, dynamic>;
                        isAccepted = (data['status'] == "ACCEPTED");
                      }

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isAccepted
                              ? Colors.green[800]
                              : Colors.black54,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isAccepted
                                ? Colors.greenAccent
                                : AppColors.alertRed,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isAccepted
                                  ? Icons.medical_services_rounded
                                  : Icons.wifi_tethering,
                              size: 50,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 10),

                            Text(
                              isAccepted
                                  ? "AMBULANCE DISPATCHED!"
                                  : "WAITING FOR RESPONSE...",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Text(
                              isAccepted
                                  ? "Help is on the way.\nStay calm."
                                  : "Alert sent to nearby hospitals.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),

                            const SizedBox(height: 15),
                            const Divider(color: Colors.white24),

                            const Text(
                              "AI ANALYSIS & EVIDENCE",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _aiAnalysis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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