import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
// import '../utils/constants.dart';

class HospitalDashboard extends StatefulWidget {
  final String hospitalName; // E.g., "Apollo (Sector 62)"
  const HospitalDashboard({super.key, required this.hospitalName});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- HELPER: Get the main name for filtering ---
  // If ID is "Apollo (Sector 62)", this returns "Apollo"
  String get searchName => widget.hospitalName.split(' (').first.trim();

  Future<void> _playAudio(String base64String) async {
    if (base64String == "NO_AUDIO" || base64String.isEmpty) return;
    try {
      final bytes = base64Decode(base64String);
      await _audioPlayer.play(BytesSource(bytes));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔊 Playing Audio Evidence...")),
      );
    } catch (e) {
      print("Audio Error: $e");
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse("http://googleusercontent.com/maps.google.com/?q=$lat,$lng");
    if (!await launchUrl(googleMapsUrl)) {
      throw Exception('Could not launch maps');
    }
  }

  // --- ACCEPT EMERGENCY (Uses FULL Unique ID) ---
  Future<void> _acceptEmergency(String docId) async {
    final docRef = FirebaseFirestore.instance.collection('accidents').doc(docId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);

        if (!snapshot.exists) throw Exception("Report does not exist!");

        String currentStatus = snapshot.get('status');

        if (currentStatus == 'ACCEPTED') {
          String takenBy = snapshot.get('hospital_name');
          throw Exception("Too late! Accepted by $takenBy");
        }

        transaction.update(docRef, {
          "status": "ACCEPTED",
          "hospital_name": widget.hospitalName, // Save "Apollo (Sector 62)"
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ You (${widget.hospitalName}) accepted the emergency!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("⚠️ Request Expired"),
            content: Text(e.toString().replaceAll("Exception: ", "")),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.hospitalName, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red[800],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('accidents')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("✅ No Active Emergencies"));
          }

          // --- SMART FILTERING LOGIC ---
          var myDocs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            
            // 1. Is it meant for me? (Check if Google Maps name contains "Apollo")
            List nearby = data['nearby_hospitals'] ?? [];
            bool isForMe = nearby.any((h) => 
              h['name'].toString().toLowerCase().contains(searchName.toLowerCase())
            );

            // 2. Did I accept it? (Check exact match "Apollo (Sector 62)")
            bool didIAccept = data['hospital_name'] == widget.hospitalName;

            bool isActive = ['PENDING', 'CRITICAL', 'ACCEPTED'].contains(data['status']);

            return (isForMe || didIAccept) && isActive;
          }).toList();

          if (myDocs.isEmpty) {
            return Center(
              child: Text(
                "✅ No Active Alerts for '$searchName'",
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: myDocs.length,
            itemBuilder: (context, index) {
              var data = myDocs[index].data() as Map<String, dynamic>;
              String docId = myDocs[index].id;
              
              double gForce = data['g_force'] ?? 0.0;
              String analysis = data['ai_analysis'] ?? "No Analysis";
              Map loc = data['location'] is Map ? data['location'] : {'lat': 0.0, 'lng': 0.0};
              String audioBase64 = data['audio_base64'] ?? "NO_AUDIO";
              bool isTaken = data['status'] == 'ACCEPTED';
              bool isTakenByMe = data['hospital_name'] == widget.hospitalName;

              return Card(
                color: isTaken ? (isTakenByMe ? Colors.green[50] : Colors.grey[300]) : Colors.white,
                margin: const EdgeInsets.all(10),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 30),
                          const SizedBox(width: 10),
                          Text(
                            "CRASH DETECTED (${gForce.toStringAsFixed(1)} G)",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text("🤖 AI Report: $analysis", style: TextStyle(color: Colors.grey[800])),
                      const SizedBox(height: 10),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _playAudio(audioBase64),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text("Listen"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openMap(loc['lat'], loc['lng']),
                            icon: const Icon(Icons.map),
                            label: const Text("Map"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Hospital List (Admin View)
                      if (data['nearby_hospitals'] != null) ...[
                        const Divider(),
                        const Text("Nearby Hospitals Alerted:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                         ...(data['nearby_hospitals'] as List).map((h) {
                           // Highlight MY hospital in the list
                           bool isMe = h['name'].toString().toLowerCase().contains(searchName.toLowerCase());
                           return Text(
                             "• ${h['name']}", 
                             style: TextStyle(
                               fontSize: 12, 
                               fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                               color: isMe ? Colors.black : Colors.grey
                             )
                           );
                         }).toList(),
                         const SizedBox(height: 10),
                      ],

                      // ACTION BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: isTaken
                            ? ElevatedButton(
                                onPressed: null,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                                child: Text(isTakenByMe ? "✅ ACCEPTED BY YOU" : "⚠️ TAKEN BY OTHER"),
                              )
                            : ElevatedButton(
                                onPressed: () => _acceptEmergency(docId),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                                child: const Text("ACCEPT EMERGENCY"),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:audioplayers/audioplayers.dart'; // Play the evidence
// import 'package:url_launcher/url_launcher.dart'; // Open Google Maps
// // import '../utils/constants.dart';

// class HospitalDashboard extends StatefulWidget {
//   const HospitalDashboard({super.key});

//   @override
//   State<HospitalDashboard> createState() => _HospitalDashboardState();
// }

// class _HospitalDashboardState extends State<HospitalDashboard> {
//   final AudioPlayer _audioPlayer = AudioPlayer();

//   // --- PLAY AUDIO EVIDENCE (Base64 -> Sound) ---
//   Future<void> _playAudio(String base64String) async {
//     if (base64String == "NO_AUDIO" || base64String.isEmpty) return;

//     try {
//       // 1. Convert Text back to Bytes
//       final bytes = base64Decode(base64String);
      
//       // 2. Play the Bytes
//       await _audioPlayer.play(BytesSource(bytes));
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("🔊 Playing Audio Evidence...")),
//       );
//     } catch (e) {
//       print("Audio Error: $e");
//     }
//   }

//   // --- OPEN MAPS ---
//   Future<void> _openMap(double lat, double lng) async {
//     final Uri googleMapsUrl = Uri.parse("http://googleusercontent.com/maps.google.com/?q=$lat,$lng");
//     if (!await launchUrl(googleMapsUrl)) {
//       throw Exception('Could not launch maps');
//     }
//   }

//   // --- ACCEPT EMERGENCY ---
//   Future<void> _acceptEmergency(String docId) async {
//     await FirebaseFirestore.instance.collection('accidents').doc(docId).update({
//       "status": "ACCEPTED",
//       "hospital_name": "City General Hospital", // In a real app, this would be the logged-in hospital's name
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(
//         title: const Text("🚑 Hospital Dispatch", style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.red[800],
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('accidents')
//             .where('status', whereIn: ['PENDING', 'CRITICAL']) // Filter
//             .orderBy('timestamp', descending: true)            // Sort
//             .snapshots(),
//         builder: (context, snapshot) {
          
//           // 1. CHECK FOR INDEX ERROR
//           if (snapshot.hasError) {
//             print("❌ FIRESTORE ERROR: ${snapshot.error}");
//             return Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Text(
//                   "Missing Index Error!\n\nCheck your VS Code Debug Console for a link to create it.",
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(color: Colors.red),
//                 ),
//               ),
//             );
//           }

//           // 2. Loading State
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           // 3. Empty State
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(
//               child: Text("✅ No Active Emergencies", style: TextStyle(fontSize: 18)),
//             );
//           }

//           var docs = snapshot.data!.docs;

//           return ListView.builder(
//             itemCount: docs.length,
//             itemBuilder: (context, index) {
//               var data = docs[index].data() as Map<String, dynamic>;
//               String docId = docs[index].id;
              
//               double gForce = data['g_force'] ?? 0.0;
//               String analysis = data['ai_analysis'] ?? "No Analysis";
//               // Handle location safely (sometimes it might be null or missing keys)
//               Map loc = data['location'] is Map ? data['location'] : {'lat': 0.0, 'lng': 0.0};
//               String audioBase64 = data['audio_base64'] ?? "NO_AUDIO"; 

//               return Card(
//                 margin: const EdgeInsets.all(10),
//                 elevation: 5,
//                 color: Colors.white,
//                 child: Padding(
//                   padding: const EdgeInsets.all(15),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // --- HEADER ---
//                       Row(
//                         children: [
//                           const Icon(Icons.warning, color: Colors.red, size: 30),
//                           const SizedBox(width: 10),
//                           Text(
//                             "CRASH DETECTED (${gForce.toStringAsFixed(1)} G)",
//                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
//                           ),
//                         ],
//                       ),
//                       const Divider(),
                      
//                       // --- AI REPORT ---
//                       Text("🤖 AI Report: $analysis", style: TextStyle(color: Colors.grey[800])),
//                       const SizedBox(height: 10),

//                       // --- ACTION BUTTONS (Listen / Map) ---
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                         children: [
//                           ElevatedButton.icon(
//                             onPressed: () => _playAudio(audioBase64),
//                             icon: const Icon(Icons.play_arrow),
//                             label: const Text("Listen"),
//                             style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
//                           ),
//                           ElevatedButton.icon(
//                             onPressed: () => _openMap(loc['lat'], loc['lng']),
//                             icon: const Icon(Icons.map),
//                             label: const Text("Map"),
//                             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 10),

//                       // --- NEARBY HOSPITALS LIST (NEW) ---
//                       if (data['nearby_hospitals'] != null) ...[
//                         const Divider(),
//                         const Text("🏥 Nearby Hospitals Notified:", style: TextStyle(fontWeight: FontWeight.bold)),
//                         const SizedBox(height: 5),
//                         ...(data['nearby_hospitals'] as List).map((h) {
//                           return ListTile(
//                             dense: true,
//                             contentPadding: EdgeInsets.zero,
//                             leading: const Icon(Icons.local_hospital, color: Colors.red),
//                             title: Text(h['name'] ?? "Unknown Hospital"),
//                             subtitle: Text(h['phone']?.toString().isNotEmpty == true ? h['phone'] : "No Phone"),
//                             trailing: h['name'] == data['hospital_name']
//                                 ? const Icon(Icons.check_circle, color: Colors.green)
//                                 : const Text("Request Sent", style: TextStyle(color: Colors.orange, fontSize: 10)),
//                           );
//                         }).toList(),
//                         const SizedBox(height: 10),
//                       ],

//                       // --- ACCEPT BUTTON ---
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: () => _acceptEmergency(docId),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.red[800],
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                           child: const Text("ACCEPT EMERGENCY", style: TextStyle(fontSize: 16)),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }