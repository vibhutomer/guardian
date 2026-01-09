import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'hospital_dashboard.dart';

class HospitalLoginScreen extends StatefulWidget {
  const HospitalLoginScreen({super.key});

  @override
  State<HospitalLoginScreen> createState() => _HospitalLoginScreenState();
}

class _HospitalLoginScreenState extends State<HospitalLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  void _login() {
    if (_nameController.text.isNotEmpty && _addressController.text.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HospitalDashboard(
            hospitalName: _nameController.text,
            hospitalAddress: _addressController.text,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both Name and Address")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
        // SCROLLABLE FIX: LayoutBuilder ensures background fills screen
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ICON
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.alertRed.withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(color: AppColors.alertRed.withOpacity(0.1), blurRadius: 20)
                          ]
                        ),
                        child: const Icon(Icons.local_hospital, size: 60, color: AppColors.alertRed),
                      ),
                      const SizedBox(height: 30),
                      
                      const Text(
                        "Hospital Portal",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Enter details to access dashboard",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 40),

                      // 1. NAME INPUT
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.business, color: Colors.white54),
                            hintText: "Hospital Name (e.g. Apollo)",
                            hintStyle: TextStyle(color: Colors.white30),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. ADDRESS INPUT
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _addressController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.location_on, color: Colors.white54),
                            hintText: "Address (e.g. Sector 62)",
                            hintStyle: TextStyle(color: Colors.white30),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.alertRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 10,
                            shadowColor: AppColors.alertRed.withOpacity(0.4),
                          ),
                          child: const Text("ACCESS DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold)),
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