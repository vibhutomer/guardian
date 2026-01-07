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

  // Load saved numbers from phone storage
  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _contacts = prefs.getStringList('emergency_contacts') ?? [];
    });
  }

  // Save a new number
  Future<void> _addContact() async {
    if (_controller.text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _contacts.add(_controller.text);
      await prefs.setStringList('emergency_contacts', _contacts);
      _controller.clear();
      setState(() {});
    }
  }

  // Delete a number
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Input Field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter Phone Number...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _addContact,
                  icon: const Icon(Icons.add_circle, color: AppColors.primaryGreen, size: 40),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // List of Contacts
            Expanded(
              child: _contacts.isEmpty
                  ? const Center(child: Text("No contacts added yet.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(Icons.phone, color: Colors.white),
                            title: Text(_contacts[index], style: const TextStyle(color: Colors.white)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.alertRed),
                              onPressed: () => _removeContact(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}