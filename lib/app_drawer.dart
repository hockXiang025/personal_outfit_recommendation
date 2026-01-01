import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

import 'clothes_manage.dart';
import 'recommend_info.dart';
import 'calendar.dart';
import 'favourites.dart';
import 'user_profile.dart';
import 'main_page.dart';

class AppDrawer extends StatefulWidget {
  final String uid;

  const AppDrawer({super.key, required this.uid});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _username = "User";
  String _email = "";

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Load User info from Cache
  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();

    // Get Username from Cache
    final String? profileString = prefs.getString("user_profile");
    if (profileString != null) {
      final data = jsonDecode(profileString);
      if (mounted) {
        setState(() {
          _username = data["username"] ?? "User";
        });
      }
    }

    // Get Email from Firebase Auth directly
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      setState(() {
        _email = user.email ?? "";
      });
    }
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context); // Close the drawer first
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  // --- Logout logic ---
  Future<void> _logout(BuildContext context) async {
    // Clear Cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("user_profile");

    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();

    // Navigate to Login page
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
     child: SingleChildScrollView(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            // Display Loaded Username
            accountName: Text(
              _username,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            // Display Email
            accountEmail: Text(_email.isNotEmpty ? _email : "ID: ${widget.uid.substring(0, 5)}..."),

            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : "U",
                style: const TextStyle(fontSize: 40, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            decoration: BoxDecoration(color: Colors.blue.shade600),
          ),

          // --- MENU ITEMS ---
          // Dashboard Navigation
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Dashboard"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => MainPage(uid: widget.uid)),
                  (route) => false,
              );
            },
          ),
          // Closet Navigation
          ListTile(
            leading: const Icon(Icons.checkroom),
            title: const Text("Closet"),
            onTap: () => _navigateTo(context, ClothesManagementPage(uid: widget.uid)),
          ),
          // Recommendation Navigation
          ListTile(
            leading: const Icon(Icons.lightbulb),
            title: const Text("Recommendation"),
            onTap: () => _navigateTo(context, RecommendInfoPage(uid: widget.uid)),
          ),
          // Schedule Navigation
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text("Schedule"),
            onTap: () => _navigateTo(context, CalendarPage(uid: widget.uid)),
          ),
          // Favourites Navigation
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text("Favourites"),
            onTap: () => _navigateTo(context, FavouritesPage(uid: widget.uid)),
          ),
          // Profile Navigation
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text("Profile"),
            onTap: () => _navigateTo(context, ProfilePage(uid: widget.uid)),
          ),

          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => _logout(context),
          ),
        ],
      ),
     ),
    );
  }
}