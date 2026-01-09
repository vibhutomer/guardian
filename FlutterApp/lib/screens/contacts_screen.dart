import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _contacts = prefs.getStringList('emergency_contacts') ?? [];
    });
  }

  Future<void> _addContact() async {
    if (_controller.text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _contacts.add(_controller.text);
      await prefs.setStringList('emergency_contacts', _contacts);
      _controller.clear();
      setState(() {});
    }
  }

  Future<void> _removeContact(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _contacts.removeAt(index);
    });
    await prefs.setStringList('emergency_contacts', _contacts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Emergency Contacts", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
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
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "Add trusted contacts who will receive your SOS alerts.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // MODERN INPUT FIELD
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.white54),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "Enter Phone Number...",
                              hintStyle: TextStyle(color: Colors.white30),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _addContact,
                          icon: const Icon(Icons.add_circle, color: AppColors.primaryGreen, size: 35),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // LIST HEADER
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "YOUR CONTACTS (${_contacts.length})",
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // CONTACTS LIST
                  _contacts.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: Column(
                            children: [
                              Icon(Icons.contact_phone_outlined, size: 60, color: Colors.white12),
                              SizedBox(height: 10),
                              Text("No contacts added yet", style: TextStyle(color: Colors.white30)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true, // Takes only needed space
                          physics: const NeverScrollableScrollPhysics(), // Disables internal scrolling (uses parent)
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                                ),
                                title: Text(
                                  _contacts[index],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.alertRed),
                                  onPressed: () => _removeContact(index),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}