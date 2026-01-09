import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
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

    // Attempt Sign In
    final user = await _authService.signInWithGoogle();

    setState(() => _isLoading = false);

    if (user != null) {
      // SUCCESS: Navigate to Home
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      // FAILURE: Show Snack bar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login Failed. Please try again."),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        // SCROLLABLE FIX: LayoutBuilder ensures full height constraint
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // LOGO SECTION
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withOpacity(0.2),
                              blurRadius: 50,
                              spreadRadius: 10,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 100,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      const Text(
                        "GUARDIAN",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      const Text(
                        "Autonomous Emergency Response",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 60),

                      // GLASSMORPHISM LOGIN CARD
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05), // Translucent
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Sign In",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            _isLoading
                                ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                                : SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton.icon(
                                      onPressed: handleLogin,
                                      icon: const Icon(Icons.login),
                                      label: const Text(
                                        "Continue with Google",
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}