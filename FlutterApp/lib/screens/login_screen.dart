import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
// import '../screens/hospital_dashboard.dart';
import '../screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void handleLogin() async {
    setState(() => _isLoading = true);

    // 1. Attempt Sign In
    final user = await _authService.signInWithGoogle();

    setState(() => _isLoading = false);

    if (user != null) {
      // 2. SUCCESS: Manually Navigate to Home Screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ), // Make sure to import home_screen.dart
        );
      }
    } else {
      // 3. FAILURE: Show Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login Failed. Try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // FIX: SingleChildScrollView prevents "RenderFlex overflowed" errors
      body: SingleChildScrollView(
        child: Container(
          // FIX: Force the container to fill the screen height so centering works
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield,
                  size: 100,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(height: 20),
                const Text(
                  "GUARDIAN",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Autonomous Emergency Response",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 60),
                _isLoading
                    ? const CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      )
                    : ElevatedButton.icon(
                        onPressed: handleLogin,
                        icon: const Icon(Icons.login),
                        label: const Text("Sign in with Google"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                        ),
                      ),
                const SizedBox(height: 20),

                // Hospital Button
                // TextButton(
                //   onPressed: () {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => const HospitalDashboard(),
                //       ),
                //     );
                //   },
                //   child: const Text(
                //     "Enter as Hospital (Admin)",
                //     style: TextStyle(color: Colors.grey),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
