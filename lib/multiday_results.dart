import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'recommend_result.dart';
import 'calendar.dart';
import 'favourites.dart';

class MultiDayResultPageView extends StatefulWidget {
  final List<Map<String, dynamic>> dailyResults;
  final String uid;

  const MultiDayResultPageView({super.key, required this.dailyResults, required this.uid});

  @override
  State<MultiDayResultPageView> createState() => _MultiDayResultPageViewState();
}

class _MultiDayResultPageViewState extends State<MultiDayResultPageView> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  Future<void> _saveSelectedOutfits({required bool isFavorite, required Set<int> selectedIndices}) async {
    final prefs = await SharedPreferences.getInstance();

    // Choose the correct storage key
    final String key = isFavorite ? 'favorite_outfits' : 'scheduled_outfits';
    List<String> currentList = prefs.getStringList(key) ?? [];
    int addedCount = 0;

    for (int i in selectedIndices) {
      if (i < 0 || i >= widget.dailyResults.length) continue;

      var dayData = widget.dailyResults[i];
      final result = dayData['result'];

      // Basic Validation
      final String? topName = result['top']?['name'];
      final String? bottomName = result['bottom']?['name'];
      if ((topName == null || topName.isEmpty) && (bottomName == null || bottomName.isEmpty)) {
        continue;
      }

      currentList.add(jsonEncode(dayData));
      addedCount++;
    }

    if (addedCount > 0) {
      await prefs.setStringList(key, currentList);
    }

    if (mounted) {
      // Check if count is 0 (invalid)
      if (addedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No valid outfits selected to save."),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        String type = isFavorite ? "Favourites" : "Schedule";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Saved $addedCount outfits to $type!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        // Navigation
        if (isFavorite) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => FavouritesPage(uid: widget.uid)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarPage(uid: widget.uid)));
        }
      }
    }
  }

  // ---------------- SELECTION DIALOG ----------------
  void _showSelectionDialog(bool isFavorite) {
    // Select only the CURRENT day
    Set<int> selected = {_currentIndex};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isFavorite ? "Save to Favourites" : "Add to Schedule"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- QUICK ACTION BUTTONS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => setStateDialog(() => selected = {_currentIndex}),
                          child: const Text("Current"),
                        ),
                        TextButton(
                          onPressed: () => setStateDialog(() {
                            selected = List.generate(widget.dailyResults.length, (i) => i).toSet();
                          }),
                          child: const Text("Select All"),
                        ),
                        TextButton(
                          onPressed: () => setStateDialog(() => selected.clear()),
                          child: const Text("Clear"),
                        ),
                      ],
                    ),
                    const Divider(),

                    // --- LIST OF DAYS ---
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: widget.dailyResults.length,
                        itemBuilder: (context, index) {
                          final item = widget.dailyResults[index];
                          final dateStr = DateFormat('EEE, d MMM').format(DateTime.parse(item['date']));
                          final timeStr = DateFormat('h:mm a').format(DateTime.parse(item['date']));
                          final event = item['event'] ?? "Outfit";

                          return CheckboxListTile(
                            dense: true,
                            title: Text("$dateStr ($timeStr)"),
                            subtitle: Text(event),
                            value: selected.contains(index),
                            activeColor: isFavorite ? Colors.pink : Colors.blue,
                            onChanged: (bool? value) {
                              setStateDialog(() {
                                if (value == true) {
                                  selected.add(index);
                                } else {
                                  selected.remove(index);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFavorite ? Colors.pink : Colors.blue,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (selected.isNotEmpty) {
                      _saveSelectedOutfits(isFavorite: isFavorite, selectedIndices: selected);
                    }
                  },
                  child: Text(isFavorite ? "Save Favourites" : "Save Schedule", style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ---------------- SWIPEABLE VIEW ----------------
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.dailyResults.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final dayData = widget.dailyResults[index];
                    final dateStr = DateFormat('EEE, d MMM • h:mm a').format(DateTime.parse(dayData['date']));

                    // Reuse existing RecommendationResultPage logic
                    return RecommendationResultPage(
                      uid: widget.uid,
                      pageTitle: "Day ${index + 1} of ${widget.dailyResults.length}",
                      pageSubtitle: dateStr,

                      pieceType: dayData['result']['piece_type'] ?? 'fallback',
                      top: dayData['result']['top']?['name'] ?? "",
                      bottom: dayData['result']['bottom']?['name'] ?? "",
                      topImageUrl: dayData['result']['top']?['image_url'] ?? "",
                      bottomImageUrl: dayData['result']['bottom']?['image_url'] ?? "",

                      alternativeTops: ((dayData['result']["alternative_tops"] ?? []) as List)
                          .map((e) => Map<String, dynamic>.from(e)).toList(),
                      alternativeBottoms: ((dayData['result']["alternative_bottoms"] ?? []) as List)
                          .map((e) => Map<String, dynamic>.from(e)).toList(),

                      shoppingSuggestions: Map<String, List<Map<String, dynamic>>>.from(
                        (dayData['result']["shoppingSuggestions"] ?? {}).map(
                              (k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v)),
                        ),
                      ),

                      requestData: {
                        "season": dayData['season'],
                        "weather": dayData['weather'],
                        "temperature": dayData['temp'],
                        "event": dayData['event'],
                        "date": dateStr,
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton.icon(
                        onPressed: () => _showSelectionDialog(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.favorite, color: Colors.white, size: 20),
                        label: const Text("Save as Favourite", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton.icon(
                        onPressed: () => _showSelectionDialog(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                        label: const Text("Save to Schedule", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // ---------------- Bottom Navigation Bar ----------------
      bottomNavigationBar: Container(
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.dailyResults.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentIndex == index ? 12 : 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentIndex == index ? Colors.blueAccent : Colors.grey.shade400,
              ),
            );
          }),
        ),
      ),
    );
  }
}