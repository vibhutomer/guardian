import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class HospitalDashboard extends StatefulWidget {
  final String hospitalName;
  final String hospitalAddress;

  const HospitalDashboard({
    super.key,
    required this.hospitalName,
    required this.hospitalAddress,
  });

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Helper: Use just the name for filtering notifications
  String get searchName => widget.hospitalName.trim();

  // Helper: Combine Name + Address for the "Accepted By" status
  String get fullName => "${widget.hospitalName} (${widget.hospitalAddress})";

  Future<void> _playAudio(String base64String) async {
    if (base64String == "NO_AUDIO" || base64String.isEmpty) return;
    try {
      final bytes = base64Decode(base64String);
      await _audioPlayer.play(BytesSource(bytes));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔊 Playing Audio Evidence..."),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      print("Audio Error: $e");
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    // Use the official Google Maps Universal Link
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    try {
      if (!await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not launch maps');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not open map: $e"),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  Future<void> _acceptEmergency(String docId) async {
    final docRef = FirebaseFirestore.instance
        .collection('accidents')
        .doc(docId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);

        if (!snapshot.exists) throw Exception("Report does not exist!");

        String currentStatus = snapshot.get('status');

        if (currentStatus == 'ACCEPTED') {
          throw Exception("Already accepted!");
        }

        transaction.update(docRef, {
          "status": "ACCEPTED",
          // Save the Full Name (Name + Address) so User sees exact location
          "hospital_name": fullName,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // DISPLAY NAME AND ADDRESS IN APP BAR
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.hospitalName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.hospitalAddress,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundStart, AppColors.backgroundEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('accidents')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.alertRed),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "✅ System Clear: No Alerts",
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            // FILTERING LOGIC
            var myDocs = snapshot.data!.docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;

              // 1. Is it meant for me? (Check if nearby_hospitals contains my Name)
              List nearby = data['nearby_hospitals'] ?? [];
              bool isForMe = nearby.any(
                (h) => h['name'].toString().toLowerCase().contains(
                  searchName.toLowerCase(),
                ),
              );

              // 2. Did I accept it? (Check if DB field matches my FULL name)
              bool didIAccept = data['hospital_name'] == fullName;

              bool isActive = [
                'PENDING',
                'CRITICAL',
                'ACCEPTED',
              ].contains(data['status']);

              return (isForMe || didIAccept) && isActive;
            }).toList();

            if (myDocs.isEmpty) {
              return Center(
                child: Text(
                  "No Active Alerts for '$searchName'",
                  style: const TextStyle(color: Colors.white30),
                ),
              );
            }

            // LISTVIEW IS NATURALLY SCROLLABLE
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(15, 100, 15, 20),
              itemCount: myDocs.length,
              itemBuilder: (context, index) {
                var data = myDocs[index].data() as Map<String, dynamic>;
                String docId = myDocs[index].id;

                double gForce = data['g_force'] ?? 0.0;
                String analysis = data['ai_analysis'] ?? "No Analysis";
                Map loc = data['location'] is Map
                    ? data['location']
                    : {'lat': 0.0, 'lng': 0.0};
                String audioBase64 = data['audio_base64'] ?? "NO_AUDIO";
                bool isTaken = data['status'] == 'ACCEPTED';

                // Check against FULL NAME for ownership
                bool isTakenByMe = data['hospital_name'] == fullName;

                Color borderColor = isTakenByMe
                    ? AppColors.primaryGreen
                    : AppColors.alertRed;

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: borderColor.withOpacity(0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: borderColor,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isTakenByMe ? "CASE ACCEPTED" : "CRITICAL ALERT",
                              style: TextStyle(
                                color: borderColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${gForce.toStringAsFixed(1)} G",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 10),

                      // CONTENT
                      Text(
                        analysis.length > 100
                            ? "${analysis.substring(0, 100)}..."
                            : analysis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ACTION BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openMap(loc['lat'], loc['lng']),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text("Locate"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent.withOpacity(
                                  0.2,
                                ),
                                foregroundColor: Colors.blueAccent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _playAudio(audioBase64),
                              icon: const Icon(Icons.volume_up_rounded),
                              label: const Text("Listen"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // MAIN ACCEPT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isTaken
                              ? null
                              : () => _acceptEmergency(docId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTakenByMe
                                ? AppColors.primaryGreen
                                : AppColors.alertRed,
                            disabledBackgroundColor: Colors.grey.withOpacity(
                              0.2,
                            ),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isTaken
                                ? (isTakenByMe
                                      ? "✅ UNIT DISPATCHED"
                                      : "⚠️ TAKEN BY OTHER")
                                : "ACCEPT EMERGENCY & DISPATCH",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
