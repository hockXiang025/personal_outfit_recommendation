import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

import 'main.dart';
import 'clothes_details.dart'; // Create this page for detailed view

class ClothesManagementPage extends StatefulWidget {
  const ClothesManagementPage({super.key});

  @override
  _ClothesManagementPageState createState() => _ClothesManagementPageState();
}

class _ClothesManagementPageState extends State<ClothesManagementPage> {
  final ImagePicker _picker = ImagePicker();
  final uid = FirebaseAuth.instance.currentUser!.uid;

  String searchQuery = "";
  String selectedCategory = "All";
  String selectedSeason = "All";
  String sortOption = "Name A-Z";
  String selectedTimeFilter = "All";

  List<String> categories = ["All", "Top", "Bottom"];
  List<String> sortOptions = ["Name A-Z", "Name Z-A"];
  List<String> timeFilters = ["All", "Last day", "Last week", "Last month", "Last year","Newest", "Oldest"];

  // ---------------- CATEGORY DEFINITIONS ----------------
  static const List<String> TOP_CATEGORIES = [
    "t-shirt", "blouse", "shirt", "long-sleeve top", "tunic"
  ];

  static const List<String> BOTTOM_CATEGORIES = [
    "pants", "trousers", "skirt", "jeans", "palazzo pants"
  ];

  static const List<String> ONE_PIECE = [
    "dress", "gown", "jumpsuit", "maxi dress",
    "baju kurung", "baju kebaya", "baju melayu", "cheongsam",
    "qipao", "tang suit", "saree", "salwar kameez", "kurta",
    "dhoti", "veshti", "pavadai"
  ];


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

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final sizeCtrl = TextEditingController();
    String category = "top"; // default type
    XFile? pickedImage;
    String? error;

    String selectedClothesCategory = TOP_CATEGORIES[0]; // default selection

    showDialog(
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
                      return imgFile != null
                          ? Image.file(File(imgFile.path), height: 120, width: 120)
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

                // Category selection: top/bottom
                DropdownButtonFormField<String>(
                  value: selectedClothesCategory,
                  items: [
                    ...TOP_CATEGORIES,
                    ...BOTTOM_CATEGORIES,
                    ...ONE_PIECE,
                  ].map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.toUpperCase()),
                  )).toList(),
                  onChanged: (v) {
                    setSB(() => selectedClothesCategory = v!); // store selected category
                  },
                  decoration: const InputDecoration(labelText: "Category / Piece Type"),
                ),


          AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: error != null ? const EdgeInsets.all(12) : EdgeInsets.zero,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: error != null
                      ? Row(
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                // validation
                if (nameCtrl.text.trim().isEmpty) {
                  setSB(() => error = "Name is required");
                  return;
                }
                if (sizeCtrl.text.trim().isEmpty) {
                  setSB(() => error = "Size is required");
                  return;
                }
                setSB(() => error = null);

                // Call modified _addClothes
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

  String getPieceType(String selectedCategory) {
    final category = selectedCategory.toLowerCase();
    if (TOP_CATEGORIES.contains(category)) return "top";
    if (BOTTOM_CATEGORIES.contains(category)) return "bottom";
    if (ONE_PIECE.contains(category)) return "one_piece";
    return "top"; // fallback
  }


  // Add, Update, Delete functions (same as before)
  // _addClothes, _updateClothes, _deleteClothes ...
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
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add: $e")),
        );
      }
    }
  }

  Query _buildQuery() {
    Query q = FirebaseFirestore.instance
        .collection("clothes")
        .where("user_id", isEqualTo: uid);

    // Filter by category
    if (selectedCategory != "All") {
      q = q.where("piece_type", isEqualTo: selectedCategory.toLowerCase());
    }

    // TIMESTAMP filter
    final now = DateTime.now();
    DateTime? threshold;

    if (selectedTimeFilter == "Last day") {
      threshold = now.subtract(Duration(days: 1));
    } else if (selectedTimeFilter == "Last week") {
      threshold = now.subtract(Duration(days: 7));
    } else if (selectedTimeFilter == "Last month") {
      threshold = now.subtract(Duration(days: 30));
    }else if (selectedTimeFilter == "Last year") {
      threshold = now.subtract(Duration(days: 365));
    }

    if (threshold != null) {
      q = q.where("created_at", isGreaterThanOrEqualTo: Timestamp.fromDate(threshold));
    }

    // SORTING
    if (selectedTimeFilter == "Newest") {
      q = q.orderBy("created_at", descending: true);
    }
    else if (selectedTimeFilter == "Oldest") {
      q = q.orderBy("created_at", descending: false);
    }
    else {
      // fallback: sort by name
      q = q.orderBy("name", descending: sortOption == "Name Z-A");
    }

    return q;
  }

  void _showFilterDialog() {
    // Temporary variables for dialog selection
    String tempCategory = selectedCategory;
    String tempSeason = selectedSeason;
    String tempSort = sortOption;
    String tempTime = selectedTimeFilter;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSB) => AlertDialog(
          title: const Text("Filters"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Category filter
              Row(
                children: const [
                  Icon(Icons.category),
                  SizedBox(width: 8),
                  Text("Category"),
                ],
              ),
              DropdownButton<String>(
                value: tempCategory,
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setSB(() => tempCategory = v!),
              ),
              const SizedBox(height: 8),

              // Sort option
              Row(
                children: const [
                  Icon(Icons.sort),
                  SizedBox(width: 8),
                  Text("Sort"),
                ],
              ),
              DropdownButton<String>(
                value: tempSort,
                items: sortOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setSB(() => tempSort = v!),
              ),
              const SizedBox(height: 8),

              // Timestamp filter
              Row(
                children: const [
                  Icon(Icons.access_time),
                  SizedBox(width: 8),
                  Text("Created Time"),
                ],
              ),
              DropdownButton<String>(
                value: tempTime,
                items: timeFilters
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setSB(() => tempTime = v!),
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
              onPressed: () {
                // Save selections to main state
                setState(() {
                  selectedCategory = tempCategory;
                  selectedSeason = tempSeason;
                  sortOption = tempSort;
                  selectedTimeFilter = tempTime;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        title: const Text("Clothes Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      backgroundColor: Colors.blue.shade50,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
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
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                final filtered = docs.where((doc) {
                  if (searchQuery.isEmpty) return true;

                  final name = doc['name'].toString().toLowerCase();
                  final query = searchQuery.toLowerCase();

                  return name.contains(query); // <-- contains search
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No clothes found"));
                }
                //if (docs.isEmpty) return const Center(child: Text("No clothes found"));

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
                    final imageUrl = (data['image_url'] as String?) ?? '';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClothesDetailsPage(
                              docId: item.id,
                              clothesData: data,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: imageUrl.isNotEmpty
                                    ? SizedBox.expand(
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover, // fills entire grid cell
                                    placeholder: (context, url) =>
                                    const Center(child: CircularProgressIndicator()),
                                    errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                                  ),
                                )
                                    : Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.checkroom, size: 50, color: Colors.blueAccent),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text("Size: ${data['size'] ?? '-'}"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
