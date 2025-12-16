import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'login.dart';
import 'register.dart';
import 'main_page.dart';
import 'clothes_manage.dart';
import 'recommend_info.dart';
import 'recommend_manage.dart';

const String apiUrl = "https://clip-backend-693720663766.asia-southeast1.run.app";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _loadHome() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    // Not logged in → go to login screen
    if (user == null) {
      return const LoginPage();
    }

    // Try load cached profile
    final cached = prefs.getString("user_profile");

    if (cached != null) {
      // Use cached profile
      final userData = jsonDecode(cached);
      return MainPage(user: userData);
    }

    // No cache → fallback to login
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Outfit Recommendation',
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: _loadHome(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data!;
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/clothesManagement': (context) => const ClothesManagementPage(),
        '/info': (context) => const RecommendInfoPage(),
      },
    );
  }
}

