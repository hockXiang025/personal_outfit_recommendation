import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'multiday_results.dart';
import 'app_drawer.dart';

class CustomizePage extends StatefulWidget {
  final String uid;
  final List<DateTime> slots;

  final String? defaultLocation;
  final String? defaultEvent;
  final String? defaultStyle;
  final String? userGender;
  final Map<String, dynamic> eventRules;

  const CustomizePage({
    super.key,
    required this.uid,
    required this.slots,
    this.defaultLocation,
    this.defaultEvent,
    this.defaultStyle,
    this.userGender,
    required this.eventRules,
  });

  @override
  _CustomizePageState createState() => _CustomizePageState();
}

class _CustomizePageState extends State<CustomizePage> {
  final String apiUrl = dotenv.env['API_URL'] ?? "";
  final String openWeatherApiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? "";

  final _formKey = GlobalKey<FormState>();
  // Controller for the current slot being edited
  int _currentIndex = 0;

  // Store form data for ALL slots independently
  List<Map<String, dynamic>> formData = [];

  // Destination controllers
  TextEditingController destinationController = TextEditingController();

  // Weather Data for current view
  String? generatedSeason;
  String? generatedWeather;
  int? generatedTemperature;

  // Shared Data
  String? userGender;
  List<String> availableStyles = [];

  bool isLoading = false;
  String loadingStatus = "Loading...";

  // Locations Map
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
    _loadUserGender();

    String? initialCity;
    String? initialState;

    if (widget.defaultLocation != null && widget.defaultLocation!.contains(",")) {
      var parts = widget.defaultLocation!.split(",");
      if (parts.length >= 2) {
        initialCity = parts[0].trim();
        initialState = parts[1].trim();
      }
    }

    // Initialize FormData for every slot
    for (var _ in widget.slots) {
      formData.add({
        "state": initialState,
        "city": initialCity,
        "event": widget.defaultEvent,
        "style": widget.defaultStyle,
        // Calculate available styles immediately if default event exists
        "available_styles": widget.defaultEvent != null
            ? List<String>.from(widget.eventRules[widget.defaultEvent]["allowed_styles"] ?? [])
            : <String>[],
      });
    }

    // Load the first slot into view
    _loadSlotData(_currentIndex);
  }

  // --- SLOT NAVIGATION LOGIC ---
  void _loadSlotData(int index) {
    setState(() {
      _currentIndex = index;
      var data = formData[index];

      // Update UI Controllers to match the saved data for the specific slot
      destinationController.text = (data['city'] != null && data['state'] != null)
          ? "${data['city']}, ${data['state']}, MY"
          : "";

      availableStyles = data['available_styles'] ?? [];

      // Clear weather display until fetched
      generatedWeather = null;
      generatedTemperature = null;
      generatedSeason = null;
    });

    // Automatically check weather for that slot if city is already selected
    if (formData[index]['city'] != null) {
      _fetchWeatherForCurrentSlot();
    }
  }

  void _saveCurrentSlotData(String key, dynamic value) {
    setState(() {
      formData[_currentIndex][key] = value;

      // If event changes, update available styles
      if (key == 'event') {
        var styles = List<String>.from(widget.eventRules[value]["allowed_styles"] ?? []);
        formData[_currentIndex]['available_styles'] = styles;
        availableStyles = styles;

        // Reset style if the old one isn't valid for the new event
        if (!styles.contains(formData[_currentIndex]['style'])) {
          formData[_currentIndex]['style'] = null;
        }
      }
    });
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

  // --- WEATHER LOGIC for Current Slot ---
  Future<void> _fetchWeatherForCurrentSlot() async {
    String? city = formData[_currentIndex]['city'];
    if (city == null || city.isEmpty) return;

    DateTime slotTime = widget.slots[_currentIndex];
    setState(() { isLoading = true; loadingStatus = "Checking forecast..."; });

    try {
      final geoUrl = "http://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$openWeatherApiKey";
      final geoRes = await http.get(Uri.parse(geoUrl));
      if (geoRes.statusCode != 200) throw Exception("City not found");
      final geoData = jsonDecode(geoRes.body);
      if (geoData.isEmpty) throw Exception("City not found");
      final lat = geoData[0]["lat"];
      final lon = geoData[0]["lon"];

      final forecastUrl = "https://pro.openweathermap.org/data/2.5/forecast/climate?lat=$lat&lon=$lon&appid=$openWeatherApiKey&units=metric&cnt=30";

      final forecastRes = await http.get(Uri.parse(forecastUrl));
      if (forecastRes.statusCode != 200) throw Exception("Weather API Error: ${forecastRes.statusCode}");

      final List forecasts = jsonDecode(forecastRes.body)['list'];
      var closest = _findClosest(forecasts, slotTime);

      if (closest != null) {
        setState(() {
          generatedWeather = closest['weather'][0]['main'].toLowerCase();

          if (closest['temp'] is Map) {
            int hour = slotTime.hour;
            if (hour >= 6 && hour < 12) {
              generatedTemperature = (closest['temp']['morn'] as num).toInt();
            } else if (hour >= 12 && hour < 17) {
              generatedTemperature = (closest['temp']['day'] as num).toInt();
            } else if (hour >= 17 && hour < 21) {
              generatedTemperature = (closest['temp']['eve'] as num).toInt();
            } else {
              generatedTemperature = (closest['temp']['night'] as num).toInt();
            }
          } else {
            generatedTemperature = 30;
          }
          generatedSeason = getSeason(slotTime);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Weather Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  //--- Match Logic ---
  dynamic _findClosest(List forecasts, DateTime target) {
    String targetDateStr = DateFormat('yyyy-MM-dd').format(target);
    try {
      return forecasts.firstWhere((f) {
        DateTime fDate = DateTime.fromMillisecondsSinceEpoch(f['dt'] * 1000);
        String fDateStr = DateFormat('yyyy-MM-dd').format(fDate);
        return fDateStr == targetDateStr;
      });
    } catch (e) {
      return forecasts.isNotEmpty ? forecasts[0] : null;
    }
  }

  Future<void> _overrideWithNearestLocation() async {
    setState(() {
      isLoading = true;
      loadingStatus = "Locating...";
    });

    try {
      // Check Service Status
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
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
        throw Exception('Location permissions are permanently denied.');
      }

      // Get Coordinates
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      // Get Address (City/State)
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String detectedState = place.administrativeArea ?? "";
        String detectedCity = place.locality ?? "";

        // Match with 'locations' map
        String? matchedState;
        try {
          matchedState = locations.keys.firstWhere(
                  (key) => detectedState.contains(key) || key.contains(detectedState)
          );
        } catch (e) {
          matchedState = null;
        }

        if (matchedState != null) {
          // Find matching City in that State
          List<String> citiesInState = locations[matchedState]!;
          String? matchedCity;

          try {
            matchedCity = citiesInState.firstWhere(
                    (city) => detectedCity.contains(city) || city.contains(detectedCity)
            );
          } catch (e) {
            matchedCity = null;
          }

          // Update Form Data for the CURRENT SLOT
          if (matchedCity != null) {
            _saveCurrentSlotData('state', matchedState);
            _saveCurrentSlotData('city', matchedCity);

            // Update the visual text controller
            destinationController.text = "$matchedCity, $matchedState, MY";

            // Trigger weather fetch immediately
            _fetchWeatherForCurrentSlot();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Detected $detectedCity, but it's not in our list."))
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
          SnackBar(content: Text("Error: $e"))
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // --- SUBMIT AND GENERATE RECOMMENDATION LOGIC ---
  Future<void> _submitAllSlots() async {
    // Check if ANY slot is incomplete
    for (int i = 0; i < formData.length; i++) {
      if (formData[i]['city'] == null || formData[i]['event'] == null || formData[i]['style'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Please complete details for Slot ${i + 1}"))
        );
        // Automatically jump to the incomplete slot
        _loadSlotData(i);
        return;
      }
    }

    setState(() { isLoading = true; loadingStatus = "Generating Itinerary..."; });

    List<Map<String, dynamic>> results = [];
    List<String> usedItemIds = [];

    try {
      // Loop through every slot and generate
      for (int i = 0; i < widget.slots.length; i++) {
        DateTime slotTime = widget.slots[i];
        var data = formData[i];

        setState(() => loadingStatus = "Styling Slot ${i + 1}/${widget.slots.length}...");

        // Fetch weather internally for the loop
        Map<String, dynamic> weatherInfo = await _fetchWeatherInternal(data['city'], slotTime);

        final payload = {
          "user_id": widget.uid,
          "season": getSeason(slotTime),
          "weather": weatherInfo['weather'],
          "temp": weatherInfo['temp'],
          "event": data['event'],
          "style_preference": data['style'],
          "gender": userGender,
          "exclude_item_ids": usedItemIds
        };

        final res = await http.post(Uri.parse('$apiUrl/recommend/'), headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));

        if (res.statusCode == 200) {
          final resData = jsonDecode(res.body);
          if (resData['top']?['id'] != null) usedItemIds.add(resData['top']['id']);
          if (resData['bottom']?['id'] != null) usedItemIds.add(resData['bottom']['id']);

          results.add({
            "date": slotTime.toIso8601String(),
            "season": getSeason(slotTime),
            "weather": weatherInfo['weather'],
            "temp": weatherInfo['temp'],
            "event": data['event'],
            "result": resData
          });
        }
      }

      if (results.isNotEmpty) {
        // Navigate to the Results Page
        Navigator.push(context, MaterialPageRoute(builder: (_) => MultiDayResultPageView(dailyResults: results, uid: widget.uid)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Internal helper for the loop to get weather data without updating UI state
  Future<Map<String, dynamic>> _fetchWeatherInternal(String city, DateTime target) async {
    try {
      final geoUrl = "http://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$openWeatherApiKey";
      final geoRes = await http.get(Uri.parse(geoUrl));
      final coords = jsonDecode(geoRes.body)[0];

      final fUrl = "https://pro.openweathermap.org/data/2.5/forecast/climate?lat=${coords['lat']}&lon=${coords['lon']}&appid=$openWeatherApiKey&units=metric&cnt=30";

      final fRes = await http.get(Uri.parse(fUrl));
      final list = jsonDecode(fRes.body)['list'];

      var closest = _findClosest(list, target);

      if (closest != null) {
        int temp;

        if (closest['temp'] is Map) {
          int hour = target.hour;
          if (hour >= 6 && hour < 12) {
            temp = (closest['temp']['morn'] as num).toInt();
          } else if (hour >= 12 && hour < 17) {
            temp = (closest['temp']['day'] as num).toInt();
          } else if (hour >= 17 && hour < 21) {
            temp = (closest['temp']['eve'] as num).toInt();
          } else {
            temp = (closest['temp']['night'] as num).toInt();
          }
        } else {
          temp = 30;
        }
        return {
          "weather": closest['weather'][0]['main'].toLowerCase(),
          "temp": temp
        };
      }
      return {"weather": "cloudy", "temp": 30};
    } catch (e) {
      return {"weather": "cloudy", "temp": 30};
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final List<String> sortedEvents = widget.eventRules.keys.toList()..sort();

    // Data for Current Slot View
    var currentData = formData[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(uid: widget.uid),
      appBar: AppBar(
        // Title to show which slot be edited
        title: Text("Customize Slot ${_currentIndex + 1}/${widget.slots.length}"),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [

              // HORIZONTAL SLOT SELECTOR
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.slots.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                  itemBuilder: (ctx, index) {
                    bool isActive = index == _currentIndex;
                    return GestureDetector(
                      onTap: () => _loadSlotData(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                            color: isActive ? Colors.blueAccent : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: isActive ? Colors.blue : Colors.grey.shade300)
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          DateFormat('d MMM, h:mm a').format(widget.slots[index]),
                          style: TextStyle(
                              color: isActive ? Colors.white : Colors.black87,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Weather display dynamically
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Forecast for ${DateFormat('h:mm a').format(widget.slots[_currentIndex])}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("Season: ${generatedSeason ?? '-'}"),
                            Text("Weather: ${generatedWeather ?? '-'}"),
                          ]),
                          Text("${generatedTemperature ?? '-'}°C", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // DESTINATION current slot
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
                        value: currentData['state'],
                        items: (locations.keys.toList()..sort()).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) {
                          _saveCurrentSlotData('state', v);
                          _saveCurrentSlotData('city', null); // Reset city
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "City", border: OutlineInputBorder()),
                        value: currentData['city'],
                        items: currentData['state'] == null ? [] : (locations[currentData['state']]!..sort()).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (String? v) {
                          _saveCurrentSlotData('city', v);
                          destinationController.text = "$v, ${currentData['state']}, MY";
                          _fetchWeatherForCurrentSlot();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // EVENT & STYLE for current slot
              if (widget.eventRules.isEmpty)
                const Center(child: CircularProgressIndicator())
              else ...[
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Event",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  ),
                  value: currentData['event'],
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

                  onChanged: (v) => _saveCurrentSlotData('event', v),
                ),
                const SizedBox(height: 15),
                if (currentData['event'] != null)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Style", border: OutlineInputBorder()),
                    value: currentData['style'],
                    items: availableStyles.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                    onChanged: (v) => _saveCurrentSlotData('style', v),
                  ),
              ],
              const SizedBox(height: 30),

              // NAVIGATION && SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () {
                    // If not last slot, go next. else, submit.
                    if (_currentIndex < widget.slots.length - 1) {
                      _loadSlotData(_currentIndex + 1);
                    } else {
                      _submitAllSlots();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_currentIndex == widget.slots.length - 1) ? Colors.green : Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(color: Colors.white), const SizedBox(width: 10), Text(loadingStatus, style: const TextStyle(color: Colors.white))])
                      : Text(
                      (_currentIndex == widget.slots.length - 1) ? "Generate All Outfits" : "Next Slot",
                      style: const TextStyle(fontSize: 18, color: Colors.white)
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