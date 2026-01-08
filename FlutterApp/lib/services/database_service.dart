import 'dart:io';
import 'dart:convert'; // Used for Base64 conversion
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // REMOVED: FirebaseStorage _storage
  // REPLACED WITH: Base64 Converter
  
  Future<String?> saveAccidentReport({
    required double gForce,
    required String aiAnalysis,
    required String status,
    String? audioPath, // We accept the local path now
    List<Map<String, dynamic>>? nearbyHospitals,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      print("Error: No user logged in.");
      return null;
    }

    try {
      // 1. Convert Audio File to Text (Base64)
      String? audioBase64;
      if (audioPath != null) {
        File audioFile = File(audioPath);
        if (await audioFile.exists()) {
          List<int> audioBytes = await audioFile.readAsBytes();
          audioBase64 = base64Encode(audioBytes); // The Magic Line
        }
      }

      // 2. Get Location
      Map<String, double> locationData = await _getCurrentLocation();

      // 3. Create Data Packet
      final docRef = _db.collection('accidents').doc();

      final crashData = {
        "accident_id": docRef.id,
        "user_id": user.uid,
        "user_name": user.displayName ?? "Unknown Driver",
        "phone_number": user.phoneNumber ?? "Not Provided",
        "timestamp": FieldValue.serverTimestamp(),
        "g_force": gForce,
        "ai_analysis": aiAnalysis,
        "status": status,
        "is_false_alarm": false,
        "location": locationData,
        
        // SAVE AUDIO AS TEXT FIELD
        // The hospital dashboard can convert this back to sound later.
        "audio_base64": audioBase64 ?? "NO_AUDIO", 
        "nearby_hospitals": nearbyHospitals ?? [],
      };

      await docRef.set(crashData);
      print("✅ Report Saved. Audio size: ${audioBase64?.length ?? 0} chars");
      
      return docRef.id; 
      
    } catch (e) {
      print("❌ Failed to save report: $e");
      return null;
    }
  }

  Future<void> markAsSafe(String accidentId) async {
    try {
      await _db.collection('accidents').doc(accidentId).update({
        "status": "SAFE",
        "is_false_alarm": true,
      });
    } catch (e) {
      print("Failed to update status: $e");
    }
  }

  Future<Map<String, double>> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return {"lat": 0.0, "lng": 0.0};

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return {"lat": 0.0, "lng": 0.0};
    }
    
    if (permission == LocationPermission.deniedForever) return {"lat": 0.0, "lng": 0.0};

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation, 
    );

    return {
      "lat": position.latitude,
      "lng": position.longitude
    };
  }
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:geolocator/geolocator.dart';

// class DatabaseService {
//   final FirebaseFirestore _db = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   Future<String?> saveAccidentReport({
//     required double gForce,
//     required String aiAnalysis,
//     required String status,
//   }) async {
//     final user = _auth.currentUser;

//     if (user == null) {
//       print("Error: No user logged in.");
//       return null;
//     }

//     try {
//       // 1. GET REAL HIGH-ACCURACY LOCATION
//       Map<String, double> locationData = await _getCurrentLocation();

//       final docRef = _db.collection('accidents').doc();

//       final crashData = {
//         "accident_id": docRef.id,
//         "user_id": user.uid,
//         "user_name": user.displayName ?? "Unknown Driver",
//         "phone_number": user.phoneNumber ?? "Not Provided",
//         "timestamp": FieldValue.serverTimestamp(),
//         "g_force": gForce,
//         "ai_analysis": aiAnalysis,
//         "status": status,
//         "is_false_alarm": false,
//         "location": locationData, 
//       };

//       await docRef.set(crashData);
//       print("✅ Report Saved with Location: ${locationData.toString()}");
      
//       return docRef.id; 
      
//     } catch (e) {
//       print("❌ Failed to save report: $e");
//       return null;
//     }
//   }

//   Future<void> markAsSafe(String accidentId) async {
//     try {
//       await _db.collection('accidents').doc(accidentId).update({
//         "status": "SAFE",
//         "is_false_alarm": true,
//       });
//     } catch (e) {
//       print("Failed to update status: $e");
//     }
//   }

//   // --- UPDATED LOCATION HELPER ---
//   Future<Map<String, double>> _getCurrentLocation() async {
//     bool serviceEnabled;
//     LocationPermission permission;

//     serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       return {"lat": 0.0, "lng": 0.0};
//     }

//     permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         return {"lat": 0.0, "lng": 0.0};
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       return {"lat": 0.0, "lng": 0.0};
//     }

//     // CHANGED: Force High Accuracy to avoid cached/default emulator locations
//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.bestForNavigation, 
//     );

//     return {
//       "lat": position.latitude,
//       "lng": position.longitude
//     };
//   }
// }