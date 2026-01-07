import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // CHANGED: Returns Future<String?> so we know the ID of the report
  Future<String?> saveAccidentReport({
    required double gForce,
    required String aiAnalysis,
    required String status,
  }) async {
    final user = _auth.currentUser;

    // It's okay to save anonymous reports if user is null, but for now we return null
    if (user == null) {
      print("Error: No user logged in.");
      return null;
    }

    try {
      final docRef = _db.collection('accidents').doc(); // Generate ID

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
        "location": {"lat": 28.5, "lng": 77.2}, // Still mock, we can fix this later
      };

      await docRef.set(crashData);
      print("✅ CRASH REPORT SAVED: ${docRef.id}");
      
      return docRef.id; // Return the ID to the UI
      
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
      print("✅ Status updated to SAFE for ID: $accidentId");
    } catch (e) {
      print("❌ Failed to update status: $e");
    }
  }
}