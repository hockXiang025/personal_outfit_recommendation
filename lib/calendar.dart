import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'recommend_result.dart';
import 'favourites.dart';
import 'notification_service.dart';
import 'app_drawer.dart';


class CalendarPage extends StatefulWidget {
  final String uid;
  const CalendarPage({super.key, required this.uid});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with WidgetsBindingObserver {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSchedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  //--- App Resume ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the user taps a notification and comes back to the app,
    if (state == AppLifecycleState.resumed) {
      _loadSchedule();
    }
  }

  Future<bool> _checkSmartPermissions() async {
    // Check basic notification permission
    await NotificationService.requestPermissions();

    // Check Exact Alarm for Android 12 or higher
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        var status = await Permission.scheduleExactAlarm.status;
        if (status.isDenied) {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Permission Needed"),
                content: const Text("To send reminders at exact times, please allow 'Alarms & Reminders' in settings."),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      openAppSettings();
                    },
                    child: const Text("Open Settings"),
                  ),
                ],
              ),
            );
          }
          return false;
        }
      }
    }
    return true; // Safe to proceed for Android 11 and below
  }

  // Generate a Unique ID for the Notification
  int _getNotificationId(Map<String, dynamic> outfit) {
    // Create a unique hash based on date and top name
    String uniqueString = "${outfit['date']}_${outfit['result']['top']?['name']}";
    return uniqueString.hashCode;
  }

  String _getNotificationBody(Map<String, dynamic> result) {
    String topName = result['top']?['name'] ?? "Top";
    String bottomName = result['bottom']?['name'] ?? "Bottom";
    String pieceType = result['piece_type'] ?? "";

    // Only show the top name if one-piece
    if (pieceType.toLowerCase() == 'one-piece' || pieceType.toLowerCase() == 'dress') {
      return "$topName";
    } else {
      return "$topName + $bottomName";
    }
  }

  // Handle reminder
  void _handleReminderClick(Map<String, dynamic> outfit) {
    if (outfit['notification_time'] != null) {
      // Ask to remove if reminder exist
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Manage Reminder"),
          content: Text("Reminder set for ${outfit['notification_time']}.\nDo you want to remove it?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close")
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _cancelReminder(outfit);
              },
              child: const Text("Remove Reminder", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      // Create new only no reminder
      _scheduleSingleOutfit(outfit);
    }
  }

  Future<void> _cancelReminder(Map<String, dynamic> outfit, {bool showMsg = true}) async {
    int notifId = _getNotificationId(outfit);

    // Cancel reminder
    await NotificationService.cancelNotification(notifId);

    // Update UI & Storage
    setState(() {
      outfit.remove('notification_time');
    });
    await _saveAllEvents();

    if (showMsg && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reminder removed.")),
      );
    }
  }

  // Load data from SharedPreferences
  Future<void> _loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedStrings = prefs.getStringList('scheduled_outfits') ?? [];

    Map<String, List<Map<String, dynamic>>> loadedEvents = {};

    for (String s in savedStrings) {
      Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(s));

      // Check if notification time has passed
      if (data['notification_time'] != null) {
        if (_isTimeInPast(data['date'], data['notification_time'])) {
          data.remove('notification_time'); // Auto-reset icon
        }
      }

      final String dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(data['date']));
      if (loadedEvents[dateKey] == null) {
        loadedEvents[dateKey] = [];
      }
      loadedEvents[dateKey]!.add(data);
    }

    setState(() {
      _events = loadedEvents;
    });

    _saveAllEvents();
  }

  // Check the notification time is passed or not
  bool _isTimeInPast(String dateStr, String timeStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      DateTime now = DateTime.now();

      DateTime parsedTime;
      try {
        parsedTime = DateFormat("h:mm a").parse(timeStr);
      } catch (e) {
        parsedTime = DateFormat("HH:mm").parse(timeStr);
      }

      DateTime scheduledDateTime = DateTime(
          date.year, date.month, date.day,
          parsedTime.hour, parsedTime.minute
      );

      return now.isAfter(scheduledDateTime);
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveAllEvents() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> allEncoded = [];
    _events.forEach((key, list) {
      for (var item in list) {
        allEncoded.add(jsonEncode(item));
      }
    });
    await prefs.setStringList('scheduled_outfits', allEncoded);
  }

  // Set reminder
  Future<void> _scheduleSingleOutfit(Map<String, dynamic> outfit) async {
    // Check Permissions
    bool canProceed = await _checkSmartPermissions();
    if (!canProceed) return;

    // Pick Time
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      helpText: "Set Reminder for this Outfit",
    );
    if (pickedTime == null) return;

    // Prepare Data
    DateTime date = DateTime.parse(outfit['date']);
    String bodyText = _getNotificationBody(outfit['result']);
    int notifId = _getNotificationId(outfit);

    // Schedule It
    await NotificationService.scheduleOutfitNotification(
      id: notifId,
      date: date,
      time: pickedTime,
      topName: bodyText,
      bottomName: "",
      fullOutfitData: outfit,
    );

    // Save & Update UI
    setState(() {
      outfit['notification_time'] = pickedTime.format(context);
    });
    await _saveAllEvents();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reminder set for ${pickedTime.format(context)}!")),
      );
    }
  }

  // Get events for a specific day
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final String dateKey = DateFormat('yyyy-MM-dd').format(day);
    return _events[dateKey] ?? [];
  }

  // Show outfit details
  void _showOutfitDetails(Map<String, dynamic> outfitData) {
    final result = outfitData['result'];
    final dateStr = DateFormat('EEE, d MMM • h:mm a').format(DateTime.parse(outfitData['date']));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecommendationResultPage(
          uid: widget.uid,
          pageTitle: "Scheduled Outfit",
          pageSubtitle: dateStr,
          showFavButton: true,
          pieceType: result['piece_type'] ?? 'fallback',
          top: result['top']?['name'] ?? "",
          bottom: result['bottom']?['name'] ?? "",
          topImageUrl: result['top']?['image_url'] ?? "",
          bottomImageUrl: result['bottom']?['image_url'] ?? "",
          alternativeTops: ((result["alternative_tops"] ?? []) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
          alternativeBottoms: ((result["alternative_bottoms"] ?? []) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
          shoppingSuggestions: Map<String, List<Map<String, dynamic>>>.from(
            (result["shoppingSuggestions"] ?? {}).map(
                  (k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v)),
            ),
          ),
          requestData: {
            "season": outfitData['season'],
            "weather": outfitData['weather'],
            "temperature": outfitData['temp'],
            "event": outfitData['event'],
            "date": dateStr,
          },
        ),
      ),
    );
  }

  Future<void> _deleteOutfit(Map<String, dynamic> itemToDelete) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedStrings = prefs.getStringList('scheduled_outfits') ?? [];

    int indexToRemove = -1;
    for (int i = 0; i < savedStrings.length; i++) {
      final Map<String, dynamic> decoded = jsonDecode(savedStrings[i]);

      // Compare unique fields to identify the item
      bool sameDate = decoded['date'] == itemToDelete['date'];
      bool sameTop = decoded['result']['top']?['name'] == itemToDelete['result']['top']?['name'];
      bool sameBottom = decoded['result']['bottom']?['name'] == itemToDelete['result']['bottom']?['name'];

      if (sameDate && sameTop && sameBottom) {
        indexToRemove = i;
        break; // Stop after finding the first match
      }
    }

    // Remove when found
    if (indexToRemove != -1) {
      savedStrings.removeAt(indexToRemove);
      await prefs.setStringList('scheduled_outfits', savedStrings);
      await _loadSchedule(); // Refresh UI

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Outfit removed from schedule")),
        );
      }
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(uid: widget.uid),
      appBar: AppBar(title: const Text("Outfit Schedule"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: "My Favourites",
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FavouritesPage(uid: widget.uid))
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,

            // Marker Logic
            eventLoader: _getEventsForDay,

            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            // Style the markers (dots)
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text("Select a date to view outfits"))
                : ListView(
              children: _getEventsForDay(_selectedDay!).asMap().entries.map((entry) {
                int index = entry.key;
                var event = entry.value;

                String? notifTime = event['notification_time'];
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
                    // Create a unique key for the widget
                    key: UniqueKey(),
                    direction: DismissDirection.endToStart, // Swipe right to left
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      setState(() {
                        _events[DateFormat('yyyy-MM-dd').format(_selectedDay!)]!.removeAt(index);
                      });
                      _deleteOutfit(event);
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: event['result']['top']?['image_url'] != null
                            ? Image.network(event['result']['top']['image_url'], width: 50, fit: BoxFit.cover)
                            : const Icon(Icons.checkroom),
                        title: Text(event['event']?.toString().toUpperCase() ?? "Outfit"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName),

                            // Display time
                            if (notifTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.alarm, size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                        "Reminder: $notifTime",
                                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            notifTime != null ? Icons.notifications_active : Icons.notifications_none,
                            color: notifTime != null ? Colors.blue : Colors.grey,
                          ),
                          onPressed: () => _handleReminderClick(event),
                          tooltip: "Manage Reminder",
                        ),
                        onTap: () => _showOutfitDetails(event),
                      ),
                    ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}