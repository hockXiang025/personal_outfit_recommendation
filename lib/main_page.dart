import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile.dart';
import 'clothes_manage.dart';
import 'recommend_info.dart';

class MainPage extends StatelessWidget {
  final Map<String, dynamic> user;

  const MainPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Outfit Recommendation'),
        backgroundColor: Colors.blue.shade600,
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
      body: CustomerHome(user: user), // ✅ Always use CustomerHome
    );
  }
}

//
// 🧍 Customer UI — (Now includes Manage Clothes)
//
class CustomerHome extends StatelessWidget {
  final Map<String, dynamic> user;
  const CustomerHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Dashboard",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),

        // ---------------- Closet ----------------
        _buildMenuCard(
          icon: Icons.inventory_2,
          text: "Closet",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClothesManagementPage()),
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
              MaterialPageRoute(builder: (_) => const RecommendInfoPage()),
            );
          },
        ),

        // ---------------- Edit Profile ----------------
        _buildMenuCard(
          icon: Icons.account_circle,
          text: "Profile",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
        ),

        // ---------------- Manage Clothes (Moved from Staff UI) ----------------
        // _buildMenuCard(
        //   icon: Icons.shopping_cart,
        //   text: "Closet",
        //   onTap: () {
        //     Navigator.push(
        //       context,
        //       MaterialPageRoute(builder: (_) => const PurchasePage()),
        //     );
        //   },
        // ),
      ],
    );
  }

  // 🔹 Reusable Card Widget
  Widget _buildMenuCard({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
