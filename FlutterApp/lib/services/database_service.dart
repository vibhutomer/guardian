import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Function to save crash report
  Future<void> saveAccidentReport({
    required double gForce,
    required String aiAnalysis,
    required String status, // e.g., "PENDING" or "FALSE_ALARM"
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      print("Error: No user logged in, cannot save report.");
      return;
    }

    try {
      // 1. Create a reference to the 'accidents' collection
      final docRef = _db.collection('accidents').doc(); // Auto-generate ID

      // 2. Prepare the data (JSON format)
      final crashData = {
        "accident_id": docRef.id,
        "user_id": user.uid,
        "user_name": user.displayName ?? "Unknown Driver",
        "phone_number": user.phoneNumber ?? "Not Provided",
        "timestamp": FieldValue.serverTimestamp(), // Exact server time
        "g_force": gForce,
        "ai_analysis": aiAnalysis,
        "status": status,
        "is_false_alarm": false,
        // TODO: Add Location (Latitude/Longitude) here later
        "location": {"lat": 0.0, "lng": 0.0}, 
      };

      // 3. Upload to Firebase
      await docRef.set(crashData);
      print("✅ CRASH REPORT SAVED TO FIRESTORE!");
      
    } catch (e) {
      print("❌ Failed to save report: $e");
    }
  }

  // Function to update status (e.g., if user says "I am Safe")
  Future<void> markAsSafe(String accidentId) async {
    try {
      await _db.collection('accidents').doc(accidentId).update({
        "status": "SAFE",
        "is_false_alarm": true,
      });
      print("✅ Status updated to SAFE");
    } catch (e) {
      print("❌ Failed to update status: $e");
    }
  }
}