import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/sensor_service.dart';
import '../services/auth_service.dart';
import 'emergency_screen.dart';
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
    _sensorService.initialize();
    
    // CHANGED: Listen for 'gForce' (double), not 'event' (bool)
    _sensorService.crashStream.listen((gForce) {
      if (mounted) {
        // We go to EmergencyScreen and PASS the real gForce value!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyScreen(gForce: gForce),
          ),
        );
      }
    });
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
            // User Greeting
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
            
            // The Big Green Shield
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

            const SizedBox(height: 30),

            // TEST BUTTON (Keep this for now to verify DB connection)
             ElevatedButton(
              onPressed: () async {
                print("Attempting to talk to Firebase...");
                // Note: You can remove this button later once sensors are verified
              },
              child: const Text("GUARDIAN ACTIVE"),
            ),
          ],
        ),
      ),
    );
  }
}