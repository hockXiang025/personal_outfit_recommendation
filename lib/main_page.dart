import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'clothes_manage.dart';
import 'recommend_info.dart';
import 'calendar.dart';
import 'user_profile.dart';

class MainPage extends StatelessWidget {
  final String uid;

  const MainPage({
    super.key,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfit Recommendation'),
        backgroundColor: Colors.blue,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove("user_profile");
              await FirebaseAuth.instance.signOut();

              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      backgroundColor: Colors.blue.shade50,
      body: CustomerHome(uid: uid),
    );
  }
}

// User's Dashboard UI
class CustomerHome extends StatefulWidget {
  final String uid;

  const CustomerHome({
    super.key,
    required this.uid,
  });

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String username = "User";

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = prefs.getString("user_profile");

    if (profile != null) {
      final data = Map<String, dynamic>.from(
        jsonDecode(profile),
      );

      setState(() {
        username = data["username"] ?? "User";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          "$username's Dashboard",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),

        // ---------------- Closet ----------------
        _buildMenuCard(
          icon: Icons.checkroom,
          text: "Closet",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClothesManagementPage(uid: widget.uid),
              ),
            );
          },
        ),

        // ---------------- Recommendation ----------------
        _buildMenuCard(
          icon: Icons.lightbulb,
          text: "Recommendation",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecommendInfoPage(uid: widget.uid),
              ),
            );
          },
        ),

        // ---------------- Schedule ----------------
        _buildMenuCard(
          icon: Icons.calendar_month,
          text: "Schedule",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CalendarPage(uid: widget.uid)),
            );
          },
        ),

        // ---------------- Profile ----------------
        _buildMenuCard(
          icon: Icons.account_circle,
          text: "Profile",
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(uid: widget.uid),
              ),
            );
            _loadUsername();
          },
        ),
      ],
    );
  }

  // Reusable Card Widget
  Widget _buildMenuCard({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(icon, size: 40, color: Colors.blue),
                  const SizedBox(width: 20),
                  Text(text, style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}
