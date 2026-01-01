import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'multiday_results.dart';
import 'customize_page.dart';
import 'app_drawer.dart';

class RecommendInfoPage extends StatefulWidget {
  final String uid;
  const RecommendInfoPage({super.key, required this.uid});

  @override
  _RecommendInfoPageState createState() => _RecommendInfoPageState();
}

class _RecommendInfoPageState extends State<RecommendInfoPage> {
  final String apiUrl = dotenv.env['API_URL'] ?? "";
  final String apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? "";

  final _formKey = GlobalKey<FormState>();

  TextEditingController destinationController = TextEditingController();

  // Time Slots
  List<DateTime> scheduledSlots = [];
  bool useSameDetails = false;

  // Shared Data
  String? selectedState;
  String? selectedCity;
  String? userGender;
  Map<String, dynamic> eventRules = {};
  String? selectedEvent;
  String? selectedStyle;
  List<String> availableStyles = [];
  late final String uid;

  bool isLoading = false;
  String loadingStatus = "Loading...";

  final Map<String, List<String>> locations = {
    "Kuala Lumpur": ["Kuala Lumpur"],
    "Putrajaya": ["Putrajaya"],
    "Labuan": ["Labuan"],
    "Selangor": ["Shah Alam", "Petaling Jaya", "Subang Jaya", "Klang", "Kajang", "Ampang Jaya", "Sepang", "Gombak", "Kuala Selangor", "Hulu Langat"],
    "Penang": ["George Town", "Butterworth", "Seberang Jaya", "Bukit Mertajam", "Bayan Lepas", "Batu Ferringhi", "Air Itam"],
    "Johor": ["Johor Bahru", "Batu Pahat", "Muar", "Kluang", "Pasir Gudang", "Kulai", "Segamat", "Iskandar Puteri", "Pontian", "Skudai"],
    "Perak": ["Ipoh", "Taiping", "Teluk Intan", "Batu Gajah", "Kuala Kangsar", "Kampar", "Sitiawan", "Seri Manjung", "Sungai Siput", "Slim River", "Kamunting"],
    "Melaka": ["Melaka"],
    "Negeri Sembilan": ["Seremban", "Port Dickson", "Si Rusa", "Nilai", "Kuala Klawang", "Bahau", "Kuala Pilah", "Batu Kikir"],
    "Pahang": ["Kuantan", "Genting Highlands", "Tanah Rata", "Bentong", "Jerantut", "Bera", "Temerloh", "Raub"],
    "Kedah": ["Alor Setar", "Sungai Petani", "Kulim"],
    "Kelantan": ["Kota Bharu", "Tumpat", "Gua Musang", "Pasir Mas", "Tanah Merah", "Bachok", "Machang", "Jeli", "Pasir Puteh", "Kubang Kerian", "Rantau Panjang"],
    "Perlis": ["Kangar", "Arau", "Padang Besar", "Kaki Bukit"],
    "Terengganu": ["Kuala Terengganu", "Chukai", "Kuala Nerus"],
    "Sabah": ["Kota Kinabalu", "Sandakan", "Lahad Datu", "Keningau", "Tuaran", "Tawau", "Semporna", "Kundasang"],
    "Sarawak": ["Kuching", "Miri", "Sibu", "Bintulu", "Simanggang"],
  };

  @override
  void initState() {
    super.initState();
    uid = widget.uid;
    _loadUserGender();
    _loadEventRules();
  }

  String getSeason(DateTime date) {
    int m = date.month;
    if (m == 12 || m <= 2) return "winter";
    if (m >= 3 && m <= 5) return "spring";
    if (m >= 6 && m <= 8) return "summer";
    return "autumn";
  }

  Future<void> _loadUserGender() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("user_profile");
    if (raw != null) {
      setState(() {
        userGender = jsonDecode(raw)["gender"]?.toString().toLowerCase();
      });
    }
  }

  Future<void> _loadEventRules() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/event-rules'));
      if (response.statusCode == 200) setState(() => eventRules = jsonDecode(response.body));
    } catch (e) { print(e); }
  }

  // --- SLOT MANAGEMENT ---
  Future<void> _addSlot() async {
    DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
        context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 30)));
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (pickedTime == null) return;

    final DateTime combined = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);

    if (!scheduledSlots.contains(combined)) {
      setState(() {
        scheduledSlots.add(combined);
        scheduledSlots.sort();
      });
    }
  }

  void _removeSlot(int index) {
    setState(() {
      scheduledSlots.removeAt(index);
    });
  }

  // --- WEATHER LOGIC Per Slot ---
  Future<Map<String, double>?> _getCoordinates(String city) async {
    try {
      final geoUrl = "http://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$apiKey";
      final geoRes = await http.get(Uri.parse(geoUrl));
      if (geoRes.statusCode == 200) {
        final data = jsonDecode(geoRes.body);
        if (data.isNotEmpty) return {"lat": data[0]["lat"], "lon": data[0]["lon"]};
      }
    } catch (_) {}
    return null;
  }

  dynamic _findClosestWeather(List forecasts, DateTime target) {
    String targetDateStr = DateFormat('yyyy-MM-dd').format(target);

    try {
      return forecasts.firstWhere((f) {
        // Convert Unix timestamp 'dt' to DateTime
        DateTime fDate = DateTime.fromMillisecondsSinceEpoch(f['dt'] * 1000);
        String fDateStr = DateFormat('yyyy-MM-dd').format(fDate);
        return fDateStr == targetDateStr;
      });
    } catch (e) {
      // If no exact match found, return the first one as fallback
      return forecasts.isNotEmpty ? forecasts[0] : null;
    }
  }

  // --- SUBMIT LOGIC  ---
  Future<void> _submitMultiDayBatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (scheduledSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one time slot.")));
      return;
    }

    setState(() { isLoading = true; loadingStatus = "Planning your trip..."; });

    List<Map<String, dynamic>> results = [];
    List<String> usedItemIds = [];

    try {
      // Get Coordinates Once
      Map<String, double>? coords = await _getCoordinates(destinationController.text);
      if (coords == null) throw Exception("Could not find location coordinates");

      // Fetch Forecast Once
      final forecastUrl = "https://pro.openweathermap.org/data/2.5/forecast/climate?lat=${coords['lat']}&lon=${coords['lon']}&appid=$apiKey&units=metric&cnt=30";
      final forecastRes = await http.get(Uri.parse(forecastUrl));
      if (forecastRes.statusCode != 200) throw Exception("Weather API Error");
      final List forecasts = jsonDecode(forecastRes.body)['list'];

      // Loop through all the slots
      for (int i = 0; i < scheduledSlots.length; i++) {
        DateTime slot = scheduledSlots[i];
        setState(() => loadingStatus = "Styling Outfit ${i + 1}/${scheduledSlots.length}...");

        var weatherData = _findClosestWeather(forecasts, slot);
        if (weatherData == null) {
          throw Exception("No weather data found for ${DateFormat('dd MMM').format(slot)}");
        }

        // Get temp based on time of day
        int temp;
        if (weatherData['temp'] is Map) {
          int hour = slot.hour; // Get the time from the slot

          if (hour >= 6 && hour < 12) {
            // Morning (6 AM - 11:59 AM)
            temp = (weatherData['temp']['morn'] as num).toInt();
          } else if (hour >= 12 && hour < 17) {
            // Afternoon (12 PM - 4:59 PM)
            temp = (weatherData['temp']['day'] as num).toInt();
          } else if (hour >= 17 && hour < 21) {
            // Evening (5 PM - 8:59 PM)
            temp = (weatherData['temp']['eve'] as num).toInt();
          } else {
            // Night (9 PM - 5:59 AM)
            temp = (weatherData['temp']['night'] as num).toInt();
          }
        } else {
          // Fallback if structure is unexpected
          temp = 30;
        }

        String weatherMain = weatherData['weather'][0]['main'].toLowerCase();
        String season = getSeason(slot);

        final payload = {
          "user_id": uid,
          "season": season,
          "weather": weatherMain,
          "temp": temp,
          "event": selectedEvent,
          "style_preference": selectedStyle,
          "gender": userGender,
          "exclude_item_ids": usedItemIds
        };

        final res = await http.post(
            Uri.parse('$apiUrl/recommend/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload)
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['top']?['id'] != null) usedItemIds.add(data['top']['id']);
          if (data['bottom']?['id'] != null) usedItemIds.add(data['bottom']['id']);

          results.add({
            "date": slot.toIso8601String(),
            "season": season,
            "weather": weatherMain,
            "temp": temp,
            "event": selectedEvent,
            "result": data
          });
        }
      }

      if (results.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MultiDayResultPageView(dailyResults: results, uid: widget.uid)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --- NAVIGATION FOR CUSTOMIZE ---
  void _goToCustomizePage() {
    if (scheduledSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add time slots first.")));
      return;
    }
    // Navigate to the Page that handles different info for each slot
    Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CustomizePage(
          uid: uid,
          slots: scheduledSlots,
          defaultLocation: destinationController.text,
          defaultEvent: selectedEvent,
          defaultStyle: selectedStyle,
          userGender: userGender,
          eventRules: eventRules,
        ))
    );
  }

  Future<void> _overrideWithNearestLocation() async {
    setState(() {
      // Show a loading indicator on the button while fetching
      isLoading = true;
      loadingStatus = "Locating...";
    });

    try {
      // Check if Location Services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      // Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied, we cannot request permissions.');
      }

      // Get Actual Current Position (Lat/Long)
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      // Convert Lat/Long to Address
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Detected values from GPS
        String detectedState = place.administrativeArea ?? "";
        String detectedCity = place.locality ?? "";

        // Attempt to find a matching State key in map
        String? matchedState;
        try {
          matchedState = locations.keys.firstWhere(
                  (key) => detectedState.contains(key) || key.contains(detectedState)
          );
        } catch (e) {
          matchedState = null;
        }

        if (matchedState != null) {
          // Try to find the City within that State list
          List<String> citiesInState = locations[matchedState]!;
          String? matchedCity;

          try {
            matchedCity = citiesInState.firstWhere(
                    (city) => detectedCity.contains(city) || city.contains(detectedCity)
            );
          } catch (e) {
            // If exact city isn't in the list, maybe default to the first one or leave empty
            matchedCity = null;
          }

          // Update UI
          setState(() {
            selectedState = matchedState;
            selectedCity = matchedCity;

            // fill the text controller for display purposes
            destinationController.text = "${matchedCity ?? detectedCity}, $matchedState, MY";
          });

          if (matchedCity == null) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("You are in $detectedCity, but it's not in our supported list."))
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not match your location to our supported states."))
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error locating: $e"))
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ---------------- HELP DIALOG ----------------
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue),
              SizedBox(width: 10),
              Text("How it Works"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHelpItem(
                  Icons.lightbulb,
                  "Get Recommendations",
                  "Fill in the details (Destination, Event, Style) to generate AI-curated outfits for your trip.",
                ),
                const SizedBox(height: 15),
                _buildHelpItem(
                  Icons.calendar_month,
                  "Save to Schedule",
                  "Once you get a recommendation, you can add it to your Calendar to get reminders on the day.",
                ),
                const SizedBox(height: 15),
                _buildHelpItem(
                  Icons.favorite,
                  "Save to Favourites",
                  "Love an outfit? Save it to your Favourites list to view or schedule it later.",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Got it!", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final List<String> sortedEvents = eventRules.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(uid: widget.uid),
      appBar: AppBar(
        title: const Text("Get Recommendation"),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            tooltip: "Help",
            onPressed: _showHelpDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // SLOT BUILDER CARD
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (scheduledSlots.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("No slots added. Add dates & times below.", style: TextStyle(color: Colors.grey)),
                      ),

                    // List of Slots
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: scheduledSlots.length,
                      itemBuilder: (ctx, index) {
                        final slot = scheduledSlots[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: Text("${index+1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                          title: Text(DateFormat('EEE, dd MMM').format(slot)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(DateFormat('h:mm a').format(slot), style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _removeSlot(index))
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _addSlot,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text("Add Time Slot"),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // TOGGLE TO Ask FOR SAME INFO OR DIFFERENT?
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Use same info for all slots?", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("Turn on to fill up the destination/event for all slots."),
                value: useSameDetails,
                activeColor: Colors.blue,
                onChanged: (val) => setState(() => useSameDetails = val),
              ),
              const SizedBox(height: 10),

              // INFO FORM EXISTED if Same Info is TRUE
              if (useSameDetails) ...[
                // DESTINATION
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text("Destination", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                            OutlinedButton.icon(onPressed: _overrideWithNearestLocation, icon: const Icon(Icons.my_location), label: const Text("Current location")),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: "State", border: OutlineInputBorder()),
                          value: selectedState,
                          items: (locations.keys.toList()..sort()).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() { selectedState = v; selectedCity = null; }),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: "City", border: OutlineInputBorder()),
                          value: selectedCity,
                          items: selectedState == null ? [] : (locations[selectedState]!..sort()).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (String? v) {
                            setState(() { selectedCity = v; destinationController.text = "$v, $selectedState, MY"; });
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // EVENT & STYLE
                if (eventRules.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Event",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    ),
                    value: selectedEvent,
                    isExpanded: true,
                    itemHeight: null,
                    selectedItemBuilder: (BuildContext context) {
                      return sortedEvents.map<Widget>((String item) {
                        return Text(
                          item.replaceAll("_", " ").toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 17,
                              height: 1.0,
                              color: Colors.black87
                          ),
                        );
                      }).toList();
                    },

                    items: sortedEvents.map((e) => DropdownMenuItem(
                      value: e,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          e.replaceAll("_", " ").toUpperCase(),
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    )).toList(),

                    onChanged: (v) => setState(() {
                      selectedEvent = v;
                      selectedStyle = null;
                      availableStyles = List<String>.from(eventRules[v]["allowed_styles"] ?? []);
                    }),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 15),
                  if (selectedEvent != null)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Style", border: OutlineInputBorder()),
                      value: selectedStyle,
                      items: availableStyles.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => selectedStyle = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                ],
              ],

              const SizedBox(height: 30),

              // ACTION BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : (useSameDetails ? _submitMultiDayBatch : _goToCustomizePage),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: useSameDetails ? Colors.blueAccent : Colors.orange.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(loadingStatus, style: const TextStyle(fontSize: 18, color: Colors.white)),
                    ],
                  )
                      : Text(
                    useSameDetails ? "Generate Outfit Plan" : "Customize Each Slot",
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),

              if (!useSameDetails)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text("You will set different destination/events for each slot next.", style: TextStyle(color: Colors.grey)),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}