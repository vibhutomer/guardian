import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sensor_service.dart';
import '../services/auth_service.dart';
import 'emergency_screen.dart';
import 'contacts_screen.dart';
import 'role_selection_screen.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final SensorService _sensorService = SensorService();
  final AuthService _authService = AuthService();
  final User? user = FirebaseAuth.instance.currentUser;
  
  // Animation Controller for the Pulsing Shield
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _sensorService.initialize();

    // Setup Pulse Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _sensorService.crashStream.listen((gForce) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => EmergencyScreen(gForce: gForce)),
        );
      }
    });
  }

  Future<void> _requestPermissions() async {
    // Request all necessary permissions on load
    await [
      Permission.location,
      Permission.sms,
      Permission.notification,
      Permission.microphone,
    ].request();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // REMOVES THE LEFTMOST BACK BUTTON
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // UNIFIED GRADIENT BACKGROUND
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundStart, AppColors.backgroundEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        // SCROLLABLE FIX: SingleChildScrollView allows content to scroll if screen is small
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. User Profile Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      backgroundColor: Colors.grey[800],
                      child: user?.photoURL == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Welcome back,", style: TextStyle(color: Colors.grey, fontSize: 14)),
                        Text(
                          user?.displayName?.split(' ')[0] ?? 'Driver',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ],
                ),
                
                const SizedBox(height: 60),

                // 2. Animated Pulsing Shield
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 140,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),

                // 3. Status Text
                const Text(
                  AppStrings.monitoring,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                
                // Active Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Colors.amber, size: 18),
                      SizedBox(width: 5),
                      Text("Sensors Active", style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),

                const SizedBox(height: 80),

                // 4. Manage Contacts Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactsScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 10,
                      shadowColor: AppColors.primaryGreen.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.contact_phone_outlined),
                        SizedBox(width: 10),
                        Text("Manage Emergency Contacts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
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