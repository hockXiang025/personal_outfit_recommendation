import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'recommend_manage.dart';

class RecommendInfoPage extends StatefulWidget {
  const RecommendInfoPage({super.key});

  @override
  _RecommendInfoPageState createState() => _RecommendInfoPageState();
}

class _RecommendInfoPageState extends State<RecommendInfoPage> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController destinationController = TextEditingController();
  TextEditingController eventController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  String? generatedSeason;
  String? generatedWeather;
  int? generatedTemperature;

  String? userGender; // "male" or "female"

  Map<String, dynamic> eventRules = {};

  String? selectedEvent;
  String? selectedStyle;

  List<String> availableStyles = [];
  final uid = FirebaseAuth.instance.currentUser!.uid;

  // Auto refresh trigger
  bool autoRefresh = true;
  bool isLoading = false;

  // ------------------ SEASON ------------------
  String getSeason(DateTime date) {
    int m = date.month;
    if (m == 12 || m <= 2) return "winter";
    if (m >= 3 && m <= 5) return "spring";
    if (m >= 6 && m <= 8) return "summer";
    return "autumn";
  }

  @override
  void initState() {
    super.initState();
    _loadUserGender();
    _loadEventRules();
  }

  Future<void> _loadUserGender() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("user_profile");

    if (raw != null) {
      final profile = jsonDecode(raw);
      setState(() {
        userGender = profile["gender"]?.toString().toLowerCase();
      });
    }
  }

  // ------------------ LOCATION ------------------
  Future<void> _getCurrentLocation() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Fetching location..."),
          ],
        ),
      ),
    );

    try {
      // --------------------------------
      // 1. Check if GPS is enabled
      // --------------------------------
      bool gpsOn = await Geolocator.isLocationServiceEnabled();
      if (!gpsOn) {
        Navigator.pop(context); // stop loading

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Enable GPS"),
            content: const Text("GPS is off. Please enable it to continue."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              TextButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  Navigator.pop(context);
                },
                child: const Text("Open Settings"),
              ),
            ],
          ),
        );

        gpsOn = await Geolocator.isLocationServiceEnabled();
        if (!gpsOn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("GPS is still off.")),
          );
          return; // ❗ STOP fetching
        }

        // Re-show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Fetching location..."),
              ],
            ),
          ),
        );
      }

      // --------------------------------
      // 2. Check permissions
      // --------------------------------
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Navigator.pop(context); // stop loading

        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied.")),
          );
          return; // ❗ STOP fetching
        }

        // Re-show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Fetching location..."),
              ],
            ),
          ),
        );
      }

      // --------------------------------
      // 3. Get last known location
      // --------------------------------
      Position? lastKnown = await Geolocator.getLastKnownPosition();

      // --------------------------------
      // 4. Get current location with manual timeout
      // --------------------------------
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        position = lastKnown; // fallback
      }

      if (position == null) {
        Navigator.pop(context); // stop loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to obtain location. Try again later or direct key the destination")),
        );
        return; // ❗ STOP fetching
      }

      // --------------------------------
      // 5. Convert to city name
      // --------------------------------
      final city = await getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Navigator.pop(context); // stop loading

      setState(() {
        destinationController.text = city;
      });

      if (autoRefresh) _refreshGeneratedValues();

    } catch (e) {
      Navigator.pop(context); // always close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location error: $e")),
      );
    }
  }

  Future<String> getCityFromCoordinates(double lat, double lon) async {
    const apiKey = "16606af8acd79966f23c98c460b119e2";
    final url =
        "http://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lon&limit=1&appid=$apiKey";


    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isNotEmpty && data[0]['name'] != null) {
        return data[0]['name'];
      }
    }
    return "";
  }

  // ------------------ WEATHER ------------------
  Future<void> _getWeather() async {
    if (destinationController.text.isEmpty || selectedDate == null || selectedTime == null) return;

    const apiKey = "16606af8acd79966f23c98c460b119e2";
    final city = destinationController.text.trim();

    // Step 1: Get coordinates from city name
    final geoUrl = "http://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$apiKey";
    final geoRes = await http.get(Uri.parse(geoUrl));

    if (geoRes.statusCode != 200) return;
    final geoData = jsonDecode(geoRes.body);
    if (geoData.isEmpty) return;

    final lat = geoData[0]["lat"];
    final lon = geoData[0]["lon"];

    // Step 2: Fetch 5-day / 3-hour forecast
    final forecastUrl =
        //"https://pro.openweathermap.org/data/2.5/forecast/climate?lat=$lat&lon=$lon&cnt=30&appid=$apiKey&units=metric";
        "https://pro.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric";
        //"https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon={lon}$lon&appid=$apiKey";
    final forecastRes = await http.get(Uri.parse(forecastUrl));

    if (forecastRes.statusCode != 200) return;
    final forecastData = jsonDecode(forecastRes.body);
    final List forecasts = forecastData['list'];

    if (forecasts.isEmpty) return;

    // Step 3: Convert selected date & time to DateTime
    final selectedDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    // Step 4: Find the forecast closest to selected date & time
    Map<String, dynamic>? closestForecast;
    int minDiff = 1 << 31; // large initial value

    for (var f in forecasts) {
      DateTime forecastTime = DateTime.parse(f['dt_txt']);
      int diff = (forecastTime.difference(selectedDateTime).inMinutes).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestForecast = f;
      }
    }

    if (closestForecast != null) {
      setState(() {
        generatedWeather = closestForecast!['weather'][0]['main'].toLowerCase();
        generatedTemperature = (closestForecast!['main']['temp'] as num).toInt();
      });
    }
  }

  // ------------------ AUTO UPDATE ------------------
  Future<void> _refreshGeneratedValues() async {
    if (selectedDate != null) {
      generatedSeason = getSeason(selectedDate!);
    }

    await _getWeather();
    setState(() {});
  }

  // ------------------ PICK DATE ------------------
  void _pickDate() async {
    DateTime now = DateTime.now();
    DateTime lastAllowed = now.add(Duration(days: 30));

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now,
      lastDate: lastAllowed,
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      if (autoRefresh) {
        await _getWeather();
      }
    }
  }

  // ------------------ PICK TIME ------------------
  void _pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
      if (autoRefresh) _refreshGeneratedValues();
    }
  }

  Future<void> _loadEventRules() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/event-rules'));
      if (response.statusCode == 200) {
        setState(() {
          eventRules = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Failed to load event rules: $e");
    }
  }

  // ------------------ RECOMMENDATION ------------------
  Future<void> _getRecommendation() async {
    if (eventRules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Events are still loading, please wait.")),
      );
      return;
    }

    if (!_formKey.currentState!.validate() ||
        selectedDate == null ||
        selectedTime == null ||
        destinationController.text.isEmpty) {
      return;
    }

    setState(() => isLoading = true);

    final dateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    // Prepare payload to send to backend
    Map<String, dynamic> payload = {
      "user_id": uid,
      "season": generatedSeason ?? "",
      "weather": generatedWeather ?? "",
      "event": selectedEvent,
      "style_preference": selectedStyle,
      "gender": userGender ?? "",
    };

    try {
      // Call backend
      final response = await http.post(
        Uri.parse('$apiUrl/recommend/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check backend response
        if (data == null || data.isEmpty) {
          // Backend empty, try warming up and rebuilding cache
          await _warmupAndRebuild();
          return _getRecommendation(); // Retry
        }

        // Extract top & bottom info
        final topName = data['top']?['name'] ?? "";
        final bottomName = data['bottom']?['name'] ?? "";
        final topImageUrl = data['top']?['image_url'] ?? "";
        final bottomImageUrl = data['bottom']?['image_url'] ?? "";
        final alternativeTops = ((data["alternative_tops"] ?? []) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final alternativeBottoms = ((data["alternative_bottoms"] ?? []) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final shoppingSuggestions = ((data["shoppingSuggestions"] ?? []) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        // Navigate to recommendation result page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecommendationResultPage(
              top: topName,
              bottom: bottomName,
              topImageUrl: topImageUrl,
              bottomImageUrl: bottomImageUrl,
              alternativeTops: alternativeTops,
              alternativeBottoms: alternativeBottoms,
              shoppingSuggestions: shoppingSuggestions,
              requestData: {
                "season": generatedSeason ?? "",
                "weather": generatedWeather ?? "",
                "temperature": generatedTemperature ?? "",
                "event": selectedEvent ?? "",
              },
            ),
          ),
        );
      } else if (response.statusCode == 500) {
        // Backend not ready, warmup + rebuild
        await _warmupAndRebuild();
        return _getRecommendation(); // Retry
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
              Text('Backend error ${response.statusCode}: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false); // 🔹 STOP loading
    }
  }

  /// Call this if backend returns empty or 500
  Future<void> _warmupAndRebuild() async {
    try {
      await http.post(Uri.parse('$apiUrl/warmup/'));
      await http.post(Uri.parse('$apiUrl/rebuild_cache/'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backend warmed up and cache rebuilt.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to warmup/rebuild cache: $e')),
      );
    }
  }

  // ------------------ MODERN CLEAN UI ------------------
  @override
  Widget build(BuildContext context) {
    final List<String> sortedEvents = eventRules.keys.toList()..sort((a, b) => a.compareTo(b));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        title: const Text("Recommendation Info",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ---------------- GENERATED INFO Card ----------------
              Card(
                elevation: 3,
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Auto-Generated Values",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),

                      const SizedBox(height: 14),

                      Text("Season: ${generatedSeason ?? '…'}",
                          style: const TextStyle(fontSize: 16)),

                      const SizedBox(height: 8),
                      Text("Weather: ${generatedWeather ?? '…'}",
                          style: const TextStyle(fontSize: 16)),

                      const SizedBox(height: 8),
                      Text(
                          "Temperature: ${generatedTemperature != null ? '${generatedTemperature}°C' : '…'}",
                          style: const TextStyle(fontSize: 16)),

                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _refreshGeneratedValues,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("Refresh Now"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ---------------- DATE & TIME Card ----------------
              Card(
                elevation: 3,
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                            selectedDate == null
                                ? "Select Date"
                                : "Date: ${selectedDate!.toLocal().toString().split(' ')[0]}",
                            style: const TextStyle(fontSize: 16)),
                        onTap: _pickDate,
                      ),

                      const Divider(),

                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: Text(
                            selectedTime == null
                                ? "Select Time"
                                : "Time: ${selectedTime!.format(context)}",
                            style: const TextStyle(fontSize: 16)),
                        onTap: _pickTime,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ---------------- Destination + Location Button ----------------
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: destinationController,
                          decoration: const InputDecoration(
                            labelText: "Destination",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            if (autoRefresh) _refreshGeneratedValues();
                          },
                          validator: (v) =>
                          v!.isEmpty ? 'Enter a destination' : null,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Location button inside the card
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Icon(Icons.my_location, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ---------------- Event ----------------
              if (eventRules.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Select Event",
                      border: OutlineInputBorder(),
                    ),
                    value: selectedEvent,
                    items: sortedEvents.map((event) {
                      return DropdownMenuItem(
                        value: event,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.6,
                          child: Text(
                            event.replaceAll("_", " ").toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedEvent = value;
                        selectedStyle = null;

                        // Load allowed styles
                        final rule = eventRules[value]!;
                        availableStyles = List<String>.from(rule["allowed_styles"] ?? []);

                      });
                    },
                    validator: (v) => v == null ? "Select an event" : null,
                ),

              const SizedBox(height: 18),

              if (selectedEvent != null)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Style Preference",
                    border: OutlineInputBorder(),
                  ),
                  value: selectedStyle,
                  items: availableStyles.map((style) {
                    return DropdownMenuItem(
                      value: style,
                      child: Text(style.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStyle = value;
                    });
                  },
                  validator: (v) => v == null ? "Select a style" : null,
                ),

              const SizedBox(height: 30),

              // ---------------- Submit Button ----------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _getRecommendation, // disable when loading
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text("Loading...",
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ],
                  )
                      : const Text(
                    "Get Outfit Recommendation",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
