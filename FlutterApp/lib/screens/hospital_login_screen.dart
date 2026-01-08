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
  final TextEditingController _branchController = TextEditingController(); // <--- NEW

  void _enterDashboard() {
    String name = _nameController.text.trim();
    String branch = _branchController.text.trim();

    if (name.isNotEmpty && branch.isNotEmpty) {
      // Combine them to create a Unique ID
      String uniqueHospitalId = "$name ($branch)";

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // Pass the unique ID to the dashboard
          builder: (context) => HospitalDashboard(hospitalName: uniqueHospitalId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both Name and Branch")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Hospital Login"), backgroundColor: Colors.red[900]),
      body: SingleChildScrollView( // Made scrollable to avoid keyboard issues
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.local_hospital, size: 80, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                "Hospital Admin Portal",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              // FIELD 1: NAME
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Hospital Name",
                  hintText: "e.g. Apollo Hospital",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.business, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),

              // FIELD 2: BRANCH (Makes it Unique)
              TextField(
                controller: _branchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Branch / Area",
                  hintText: "e.g. Sector 62",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                ),
              ),
              
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _enterDashboard,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text("ENTER DASHBOARD", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}