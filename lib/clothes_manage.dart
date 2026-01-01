import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'clothes_details.dart';
import 'app_drawer.dart';

// ---------------- COLOR ENUMS ----------------
enum UnifiedColorType {
  // Families
  red, blue, green, yellow, orange, purple, pink, black, white, neutral,

  // Attributes
  pastel, bright, dark, neon
}

const Set<String> COLOR_FAMILIES = {
  "red", "blue", "green", "yellow", "orange", "purple", "pink", "black", "white", "neutral",
};


class ClothesManagementPage extends StatefulWidget {
  final String uid;

  const ClothesManagementPage({super.key, required this.uid});

  @override
  _ClothesManagementPageState createState() => _ClothesManagementPageState();
}

class _ClothesManagementPageState extends State<ClothesManagementPage> {
  final String apiUrl = dotenv.env['API_URL'] ?? "";

  final ImagePicker _picker = ImagePicker();
  late final String uid;

  String searchQuery = "";
  // ---------------- FILTER STATES ----------------
  // Piece Type Filter (Top, Bottom, One Piece)
  String filterPieceType = "All";

  // Category Filter
  String filterCategory = "All";

  // Sorting
  String sortOption = "Newest";

  // Date Range Filter
  DateTimeRange? filterDateRange;

  final List<String> pieceTypes = ["All", "top", "bottom", "one_piece"];
  final List<String> sortOptions = ["Newest", "Oldest", "Name A-Z", "Name Z-A"];

  bool isSelectionMode = false;
  Set<String> selectedIds = {};

  // ---------------- CATEGORY DEFINITIONS ----------------
  static const List<String> TOP_CATEGORIES = [
    "t-shirt", "blouse", "shirt", "tunic",
    "tang suit", "kurta", "sweater", "thermal top"
  ];

  static const List<String> BOTTOM_CATEGORIES = [
    "pants", "trousers", "skirt", "jeans", "palazzo pants",
    "dhoti", "veshti", "thermal bottom"
  ];

  static const List<String> ONE_PIECE = [
    "dress", "gown", "jumpsuit", "maxi dress",
    "baju kurung", "baju kebaya", "baju melayu", "cheongsam",
    "qipao", "saree", "salwar kameez", "pavadai"
  ];

  List<String> get allSpecificCategories => ["All", ...TOP_CATEGORIES, ...BOTTOM_CATEGORIES, ...ONE_PIECE];

  UnifiedColorType? selectedColor;
  String? colorFamily;
  List<String> colorAttributes = [];

  @override
  void initState() {
    super.initState();
    uid = widget.uid;
  }

  String colorLabel(UnifiedColorType c) {
    switch (c) {
      case UnifiedColorType.neon:
        return "NEON";
      case UnifiedColorType.pastel:
        return "PASTEL";
      case UnifiedColorType.bright:
        return "BRIGHT";
      case UnifiedColorType.dark:
        return "DARK";
      default:
        return c.name.toUpperCase();
    }
  }

  // ------------- SHOW ADD CLOTHES DIALOG ---------------
  Future <void> _showAddDialog() {
    final nameCtrl = TextEditingController();
    final sizeCtrl = TextEditingController();
    XFile? pickedImage;
    String? error;


    final List<String> sortedCategories = [
      ...TOP_CATEGORIES,
      ...BOTTOM_CATEGORIES,
      ...ONE_PIECE
    ];
    sortedCategories.sort(); // Alphabetical sorting

    // Sorted Colors
    final List<UnifiedColorType> sortedColors = UnifiedColorType.values.toList();
    sortedColors.sort((a, b) => colorLabel(a).compareTo(colorLabel(b)));

    // Set default value
    String selectedClothesCategory = sortedCategories.contains("t-shirt")
        ? "t-shirt"
        : sortedCategories.first;

    return showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSB) => AlertDialog(
          title: const Text("Add Clothes"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image picker
                GestureDetector(
                  onTap: () async {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text("Camera"),
                              onTap: () async {
                                final img = await _picker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 50,
                                );
                                if (img != null) setSB(() => pickedImage = img);
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo),
                              title: const Text("Gallery"),
                              onTap: () async {
                                final img = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 50,
                                );
                                if (img != null) setSB(() => pickedImage = img);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Builder(
                    builder: (_) {
                      final imgFile = pickedImage;
                      return imgFile != null ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imgFile.path),
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      )
                      : Container(
                        height: 120,
                        width: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.add_a_photo, size: 50),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Name field
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                const SizedBox(height: 8),

                // Size field
                TextField(
                  controller: sizeCtrl,
                  decoration: const InputDecoration(labelText: "Size"),
                ),
                const SizedBox(height: 8),

                // Category selection: top/bottom/one-piece
                DropdownButtonFormField<String>(
                  value: selectedClothesCategory,
                  items: sortedCategories.map((c) => DropdownMenuItem(
                    value: c.toLowerCase(),
                    child: Text(c.toUpperCase()),
                  )).toList(),
                  onChanged: (v) => setSB(() => selectedClothesCategory = v!),
                  decoration: const InputDecoration(labelText: "Clothing Category"),
                ),
                const SizedBox(height: 8),

                // Color picker
                DropdownButtonFormField<UnifiedColorType>(
                  value: selectedColor,
                  decoration: const InputDecoration(
                    labelText: "Color",
                    border: OutlineInputBorder(),
                  ),
                  items: sortedColors.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(colorLabel(c)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setSB(() => selectedColor = v);
                  },
                ),


                // Error message
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: error != null ? const EdgeInsets.all(12) : EdgeInsets.zero,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: error != null ? Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                  : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            }, child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                // Close Keyboard immediately when clicked
                FocusScope.of(context).unfocus();

                // validation
                if (pickedImage == null) {
                  setSB(() => error = "Image is required");
                  return;
                }
                if (nameCtrl.text.trim().isEmpty) {
                  setSB(() => error = "Name is required");
                  return;
                }
                if (sizeCtrl.text.trim().isEmpty) {
                  setSB(() => error = "Size is required");
                  return;
                }
                if (selectedColor == null) {
                  setSB(() => error = "Color is required");
                  return;
                }
                setSB(() => error = null);

                await _addClothes({
                  "name": nameCtrl.text.trim(),
                  "size": sizeCtrl.text.trim(),
                  "category": selectedClothesCategory,
                }, pickedImage);

                Navigator.pop(context);
              },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }

  // ---------------- IMAGE UPLOAD ----------------
  Future<String?> _uploadImage(XFile? image) async {
    if (image == null) return null;
    final ref = FirebaseStorage.instance.ref(
        "clothes_images/${DateTime.now().millisecondsSinceEpoch}.jpg");
    try {
      await ref.putFile(File(image.path));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Image upload failed: $e");
      return null;
    }
  }

  // ---------------- ADD CLOTHES  ----------------
  Future<void> _addClothes(Map<String, dynamic> data, XFile? image) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Uploading clothes...", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    try {
      data["name"] = data["name"]?.toString().toLowerCase();

      // ----------------- Determine piece_type -----------------
      final category = data["category"]?.toString().toLowerCase() ?? "";

      String pieceType;
      if (TOP_CATEGORIES.contains(category)) {
        pieceType = "top";
      } else if (BOTTOM_CATEGORIES.contains(category)) {
        pieceType = "bottom";
      } else if (ONE_PIECE.contains(category)) {
        pieceType = "one_piece";
      } else {
        pieceType = "top";
      }

      data["piece_type"] = pieceType;


      if (selectedColor != null) {
        final value = selectedColor!.name;
        if (COLOR_FAMILIES.contains(value)) {
          colorFamily = value;
        } else {
          colorAttributes = [value];
        }
      }

      // ----------------- Upload image -----------------
      String? imageUrl;
      if (image != null) {
        imageUrl = await _uploadImage(image);
        if (imageUrl == null) throw Exception("Failed to upload image");
      }

      // ----------------- Send to backend -----------------
      final backendUrl = "$apiUrl/upload_item/";
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": data["name"],
          "size": data["size"],
          "image_url": imageUrl ?? "",
          "category": category,
          "piece_type": pieceType,
          "user_id": uid,
          "color_family": colorFamily,
          "color_attributes": colorAttributes,
        }),
      );

      Navigator.pop(context); // close loading

      if (response.statusCode != 200) {
        throw Exception("Backend error: ${response.body}");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Clothes added successfully")),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add: $e")),
        );
      }
    }
  }

  // --------------SHOW FILTER DIALOG ----------------
  Future <void> _showFilterDialog() {
    String tempPieceType = filterPieceType;
    String tempCategory = filterCategory;
    String tempSort = sortOption;
    DateTimeRange? tempDateRange = filterDateRange;

    final List<String> sortedSpecificCats = [
      ...TOP_CATEGORIES,
      ...BOTTOM_CATEGORIES,
      ...ONE_PIECE
    ];
    sortedSpecificCats.sort();

    // Create final list with "All" at the top
    final List<String> filterDropdownItems = ["All", ...sortedSpecificCats];

    return showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSB) => AlertDialog(
          title: const Text("Filter & Sort"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PIECE TYPE FILTER
                const Text("Piece Type", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: tempPieceType,
                  items: pieceTypes.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.replaceAll("_", " ").toUpperCase()),
                  )).toList(),
                  onChanged: (v) {
                    setSB(() {
                      tempPieceType = v!;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // CATEGORY FILTER
                const Text("Clothing Category", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: tempCategory,
                  items: filterDropdownItems.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.toUpperCase()),
                  )).toList(),
                  onChanged: (v) => setSB(() => tempCategory = v!),
                ),
                const SizedBox(height: 12),

                // SORT OPTION
                const Text("Sort By", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: tempSort,
                  items: sortOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setSB(() => tempSort = v!),
                ),
                const SizedBox(height: 12),

                // DATE RANGE PICKER
                const Text("Date Created", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(
                      tempDateRange == null
                          ? "Select Date Range"
                          : "${DateFormat('MMM d, y').format(tempDateRange!.start)} - ${DateFormat('MMM d, y').format(
                          tempDateRange!.end)}"
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: tempDateRange,
                    );
                    if (picked != null) {
                      setSB(() => tempDateRange = picked);
                    }
                  },
                ),
                if (tempDateRange != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setSB(() => tempDateRange = null),
                      child: const Text("Clear Date"),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();

                setState(() {
                  filterPieceType = tempPieceType;
                  filterCategory = tempCategory;
                  sortOption = tempSort;
                  filterDateRange = tempDateRange;
                });
                Navigator.pop(context);
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (selectedIds.contains(docId)) {
        selectedIds.remove(docId);
        if (selectedIds.isEmpty) {
          isSelectionMode = false; // Exit mode if nothing selected
        }
      } else {
        selectedIds.add(docId);
      }
    });
  }

  // --- DELETE FUNCTION ---
  Future<void> _deleteSelectedClothes() async {
    FocusScope.of(context).unfocus();

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Clothes"),
        content: Text("Are you sure you want to delete ${selectedIds.length} items?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Run Backend Deletes first
        List<Future<Map<String, dynamic>>> apiFutures = selectedIds.map((id) async {
          try {
            final url = Uri.parse('$apiUrl/items/$id');
            final response = await http.delete(url);
            return {'id': id, 'success': response.statusCode == 200};
          } catch (e) {
            print("API Delete failed for $id: $e");
            // If error, return false so delete from Firestore manually
            return {'id': id, 'success': false};
          }
        }).toList();

        // Wait for all API calls to finish
        final results = await Future.wait(apiFutures);

        // Build Firestore Batch ONLY for items that failed on Backend
        final firestoreBatch = FirebaseFirestore.instance.batch();
        bool needsCommit = false;

        for (var result in results) {
          // delete from Firestore if failed on Backend
          if (result['success'] == false) {
            final docRef = FirebaseFirestore.instance.collection('clothes').doc(result['id']);
            firestoreBatch.delete(docRef);
            needsCommit = true;
          }
        }

        if (needsCommit) {
          await firestoreBatch.commit();
        }

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Refresh UI
        setState(() {
          selectedIds.clear();
          isSelectionMode = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Selected items deleted")),
          );
        }
      } catch (e) {
        // Close loading dialog if error
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error deleting: $e"))
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap anywhere to close keyboard
      onTap: () => FocusScope.of(context).unfocus(),

      child: Scaffold(
        onDrawerChanged: (isOpened) {
          if (isOpened) {
            FocusScope.of(context).unfocus();
          }
        },
      drawer: isSelectionMode ? null : AppDrawer(uid: widget.uid),

      appBar: AppBar(
        backgroundColor: isSelectionMode ? Colors.grey.shade200 : Colors.blue.shade600,
        foregroundColor: isSelectionMode ? Colors.black : Colors.white,

        leading: isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            isSelectionMode = false;
            selectedIds.clear();
          }),
        )
            : null,

        title: isSelectionMode
            ? Text("${selectedIds.length} Selected")
            : const Text("Clothes Management"),

        actions: [
          if (isSelectionMode)
          // Show DELETE icon in selection mode
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                FocusScope.of(context).unfocus();
                await _deleteSelectedClothes();
                FocusScope.of(context).unfocus();
              },
            )
          else
          // Show FILTER icon in normal mode
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () async {
                FocusScope.of(context).unfocus();
                await _showFilterDialog();
                FocusScope.of(context).unfocus();
              },
            ),
        ],
      ),

      backgroundColor: Colors.blue.shade50,

      // Hide the button when selection mode
      floatingActionButton: isSelectionMode ? null : FloatingActionButton(
        onPressed: () async {
          FocusScope.of(context).unfocus();
          await _showAddDialog();
          FocusScope.of(context).unfocus();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search clothes...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // FETCH for Specific User
              stream: FirebaseFirestore.instance
                  .collection("clothes")
                  .where("user_id", isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Please upload your clothes"));

                var docs = snapshot.data!.docs;

                // Filter
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Search Text
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  if (searchQuery.isNotEmpty && !name.contains(searchQuery.toLowerCase())) return false;

                  // Piece Type
                  if (filterPieceType != "All") {
                    if (data['piece_type'] != filterPieceType) return false;
                  }

                  // Specific Category
                  if (filterCategory != "All") {
                    // Ensure case-insensitive match
                    if ((data['category'] ?? '').toString().toLowerCase() != filterCategory.toLowerCase()) return false;
                  }

                  // Date Range
                  if (filterDateRange != null) {
                    final Timestamp? ts = data['created_at'];
                    if (ts == null) return false;
                    final date = ts.toDate();
                    // Check if date is within range
                    if (date.isBefore(filterDateRange!.start) || date.isAfter(filterDateRange!.end.add(const Duration(days: 1)))) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                // Sort
                filtered.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;

                  if (sortOption == "Name A-Z") {
                    return (dataA['name'] ?? '').toString().compareTo(dataB['name'] ?? '');
                  } else if (sortOption == "Name Z-A") {
                    return (dataB['name'] ?? '').toString().compareTo(dataA['name'] ?? '');
                  } else if (sortOption == "Oldest") {
                    final tA = (dataA['created_at'] as Timestamp?)?.toDate() ?? DateTime(0);
                    final tB = (dataB['created_at'] as Timestamp?)?.toDate() ?? DateTime(0);
                    return tA.compareTo(tB);
                  } else {
                    // Newest (Default)
                    final tA = (dataA['created_at'] as Timestamp?)?.toDate() ?? DateTime(0);
                    final tB = (dataB['created_at'] as Timestamp?)?.toDate() ?? DateTime(0);
                    return tB.compareTo(tA);
                  }
                });

                if (filtered.isEmpty) return const Center(child: Text("No clothes match your filters"));

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final data = item.data() as Map<String, dynamic>;
                    final imageUrl = data['image_url'] ?? '';
                    final bool isSelected = selectedIds.contains(item.id);

                    return GestureDetector(
                      onLongPress: () {
                        FocusScope.of(context).unfocus();

                        if (!isSelectionMode) {
                          setState(() {
                            isSelectionMode = true;
                            selectedIds.add(item.id);
                          });
                        }
                      },
                      onTap: () async {
                        if (isSelectionMode) {
                          _toggleSelection(item.id);
                        } else {
                          FocusScope.of(context).unfocus();
                          await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ClothesDetailsPage(docId: item.id, clothesData: data)));
                          FocusScope.of(context).unfocus();
                        }
                      },
                      child: Stack(
                        children: [
                          Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isSelected ? const BorderSide(color: Colors.blueAccent, width: 3) : BorderSide.none,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: imageUrl.isNotEmpty
                                          ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (_, __) => const Center(child: CircularProgressIndicator()), errorWidget: (_, __, ___) => const Icon(Icons.error))
                                          : Container(color: Colors.grey[300], child: const Center(child: Icon(Icons.checkroom, size: 50))),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text("Size: ${data['size'] ?? '-'}", maxLines: 1),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelectionMode)
                            Positioned(top: 8, right: 8, child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.blue : Colors.grey, size: 28)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }
}
