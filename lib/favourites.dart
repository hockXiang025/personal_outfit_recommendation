import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import 'recommend_result.dart';
import 'calendar.dart';
import 'app_drawer.dart';

class FavouritesPage extends StatefulWidget {
  final String uid;
  const FavouritesPage({super.key, required this.uid});

  @override
  State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage> {
  List<Map<String, dynamic>> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // Load Favourites List
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedStrings = prefs.getStringList('favorite_outfits') ?? [];

    List<Map<String, dynamic>> loaded = [];
    for (String s in savedStrings) {
      loaded.add(jsonDecode(s));
    }

    setState(() {
      _favorites = loaded.reversed.toList(); // Show newest first
    });
  }

  // Remove Favorite
  Future<void> _removeFavorite(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedStrings = prefs.getStringList('favorite_outfits') ?? [];

    int realIndex = savedStrings.length - 1 - index;

    if (realIndex >= 0 && realIndex < savedStrings.length) {
      savedStrings.removeAt(realIndex); // removeAt handles duplicates perfectly
      await prefs.setStringList('favorite_outfits', savedStrings);
    }
  }

  // Add to Calendar
  Future<void> _addToCalendar(Map<String, dynamic> favoriteItem) async {
    // Pick Date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: "Schedule this Outfit",
    );
    if (pickedDate == null) return;

    // Pick Time
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: "Select Time",
    );
    if (pickedTime == null) return;

    // Combine Date & Time
    final DateTime finalDateTime = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime.hour, pickedTime.minute,
    );

    // Prepare Data
    Map<String, dynamic> scheduleItem = Map<String, dynamic>.from(favoriteItem);
    scheduleItem['date'] = finalDateTime.toIso8601String();

    // Save to Schedule Calendar
    final prefs = await SharedPreferences.getInstance();
    List<String> scheduledList = prefs.getStringList('scheduled_outfits') ?? [];
    scheduledList.add(jsonEncode(scheduleItem));
    await prefs.setStringList('scheduled_outfits', scheduledList);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Added to Schedule for ${DateFormat('d MMM, h:mm a').format(finalDateTime)}!")),
      );

      // NAVIGATE TO CALENDAR DIRECTLY
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CalendarPage(uid: widget.uid)),
      );
    }
  }

  void _showOutfitDetails(Map<String, dynamic> outfitData) {
    final result = outfitData['result'];
    final dateStr = DateFormat('EEE, d MMM').format(DateTime.parse(outfitData['date']));

    Navigator.push(context, MaterialPageRoute(builder: (_) => RecommendationResultPage(
      uid: widget.uid,
      pageTitle: "Favourite Outfit",
      pageSubtitle: "Saved on $dateStr",
      pieceType: result['piece_type'] ?? 'fallback',
      top: result['top']?['name'] ?? "",
      bottom: result['bottom']?['name'] ?? "",
      topImageUrl: result['top']?['image_url'] ?? "",
      bottomImageUrl: result['bottom']?['image_url'] ?? "",
      alternativeTops: ((result["alternative_tops"] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList(),
      alternativeBottoms: ((result["alternative_bottoms"] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList(),
      shoppingSuggestions: Map<String, List<Map<String, dynamic>>>.from(
          (result["shoppingSuggestions"] ?? {}).map((k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v)))
      ),
      requestData: {
        "season": outfitData['season'],
        "weather": outfitData['weather'],
        "temperature": outfitData['temp'],
        "event": outfitData['event'],
        "date": dateStr,
      },
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(uid: widget.uid),
      appBar: AppBar(title: const Text("My Favourites"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _favorites.isEmpty
          ? const Center(child: Text("No favorites saved yet."))
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _favorites.length,
        itemBuilder: (ctx, index) {
          final event = _favorites[index];

          String pieceType = (event['result']['piece_type'] ?? '').toString().toLowerCase();
          bool isOnePiece = pieceType == 'one_piece' || pieceType == 'dress';

          String topName = event['result']['top']?['name'] ?? "Top";
          String? bottomName = event['result']['bottom']?['name'];

          String displayName;
          if (isOnePiece || bottomName == null || bottomName.trim().isEmpty) {
            displayName = topName;
          } else {
            displayName = "$topName + $bottomName";
          }

          return Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.endToStart,
            background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (direction) {
              setState(() {
                _favorites.removeAt(index);
              });

              _removeFavorite(index);

              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Removed from favourites"))
              );
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: event['result']['top']?['image_url'] != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(event['result']['top']['image_url'], width: 50, height: 50, fit: BoxFit.cover),
                )
                    : const Icon(Icons.checkroom, size: 40),

                title: Text(event['event']?.toString().toUpperCase() ?? "OUTFIT"),

                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.favorite, size: 14, color: Colors.pink),
                      const SizedBox(width: 4),
                      const Text("Favourite", style: TextStyle(color: Colors.pink, fontSize: 12, fontWeight: FontWeight.bold))
                    ]),
                  ],
                ),

                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month, color: Colors.blueAccent),
                  tooltip: "Add to Schedule",
                  onPressed: () => _addToCalendar(event),
                ),

                onTap: () => _showOutfitDetails(event),
              ),
            ),
          );
        },
      ),
    );
  }
}