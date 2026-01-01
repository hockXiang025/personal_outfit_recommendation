import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'login.dart';
import 'register.dart';
import 'main_page.dart';
import 'notification_service.dart';
import 'recommend_result.dart';

//const String apiUrl = "https://clip-backend-693720663766.asia-southeast1.run.app";
//const String openWeatherApiKey = "1f339f586ed9ab8314766c9988b30986";

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  tz.initializeTimeZones();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.init();

  // Hide Status Bar and Navigation Bar (Full Screen)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Lock Orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    // LISTEN FOR NOTIFICATION CLICKS
    NotificationService.onNotifications.stream.listen(onNotificationClicked);
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await NotificationService.requestPermissions();
  }

  // HANDLE NAVIGATION WHEN NOTIFICATION CLICKED
  void onNotificationClicked(String? payload) async {
    if (payload != null && payload.isNotEmpty) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;

        // If no user is logged in, not to open the details page
        if (currentUser == null) {
          print("No user logged in. Cannot navigate.");
          return;
        }

        final Map<String, dynamic> data = jsonDecode(payload);
        await _removeReminderFromStorage(data);

        final result = data['result'];
        final dateStr = DateFormat('EEE, d MMM').format(DateTime.parse(data['date']));

        // Use the global key to push the page
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => RecommendationResultPage(
            uid: currentUser.uid,
            pageTitle: "Outfit for Today",
            pageSubtitle: dateStr,
            pieceType: result['piece_type'] ?? 'fallback',
            top: result['top']?['name'] ?? "",
            bottom: result['bottom']?['name'] ?? "",
            topImageUrl: result['top']?['image_url'] ?? "",
            bottomImageUrl: result['bottom']?['image_url'] ?? "",
            alternativeTops: ((result["alternative_tops"] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList(),
            alternativeBottoms: ((result["alternative_bottoms"] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList(),
            shoppingSuggestions: Map<String, List<Map<String, dynamic>>>.from((result["shoppingSuggestions"] ?? {}).map((k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v)))),
            requestData: {
              "season": data['season'],
              "weather": data['weather'],
              "temperature": data['temp'],
              "event": data['event'],
              "date": dateStr,
            },
          )),
        );
      } catch (e) {
        print("Error parsing notification payload: $e");
      }
    }
  }

  // Remove reminder
  Future<void> _removeReminderFromStorage(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedStrings = prefs.getStringList('scheduled_outfits') ?? [];
    List<String> updatedStrings = [];

    for (String s in savedStrings) {
      Map<String, dynamic> event = jsonDecode(s);

      // Check if it is the matching event or not
      bool sameDate = event['date'] == item['date'];
      bool sameTop = event['result']['top']?['name'] == item['result']['top']?['name'];

      if (sameDate && sameTop) {
        // Remove the notification
        event.remove('notification_time');
      }
      updatedStrings.add(jsonEncode(event));
    }

    await prefs.setStringList('scheduled_outfits', updatedStrings);
  }

  Future<Widget> _loadHome() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    // go to login screen if haven't logged in yet
    if (user == null) {
      return const LoginPage();
    }

    final uid = user.uid;

    // Try load cached profile
    final cached = prefs.getString("user_profile");

    if (cached != null) {
      // Use cached profile
      final userData = jsonDecode(cached);
      return MainPage(uid: uid);
    }

    // fallback to login if no cache exist
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
      },
    );
  }
}

