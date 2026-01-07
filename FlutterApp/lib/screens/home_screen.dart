import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart'; // Import this
import '../services/sensor_service.dart';
import '../services/auth_service.dart';
import 'emergency_screen.dart';
import 'contacts_screen.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SensorService _sensorService = SensorService();
  final AuthService _authService = AuthService();
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    
    // 1. Ask for ALL Permissions immediately
    _requestPermissions();

    // 2. Start Sensors
    _sensorService.initialize();
    
    // 3. Listen for crashes
    _sensorService.crashStream.listen((gForce) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyScreen(gForce: gForce),
          ),
        );
      }
    });
  }

  // --- NEW PERMISSION LOGIC ---
  Future<void> _requestPermissions() async {
    // Request Location, SMS, and Notification permissions simultaneously
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.sms,
      Permission.notification,
    ].request();

    // Optional: Log results to see if they were granted
    if (statuses[Permission.location]!.isDenied) {
      print("Location permission is required for accurate reporting.");
    }
    if (statuses[Permission.sms]!.isDenied) {
      print("SMS permission is required to text emergency contacts.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user?.photoURL != null)
              CircleAvatar(
                backgroundImage: NetworkImage(user!.photoURL!),
                radius: 30,
              ),
            const SizedBox(height: 20),
            Text(
              "Hello, ${user?.displayName?.split(' ')[0] ?? 'User'}",
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 40),
            
            const Icon(
              Icons.shield_outlined, 
              size: 150, 
              color: AppColors.primaryGreen
            ),
            const SizedBox(height: 30),
            const Text(
              AppStrings.monitoring,
              style: TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              AppStrings.safeMode,
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 40),

            // Manage Contacts Button
            ElevatedButton.icon(
              icon: const Icon(Icons.contact_phone),
              label: const Text("MANAGE CONTACTS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const ContactsScreen())
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}