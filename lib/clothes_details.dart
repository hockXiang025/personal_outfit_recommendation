import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ---------------- SHARED CONSTANTS ----------------
enum UnifiedColorType {
  red, blue, green, yellow, orange, purple, pink, black, white, neutral,
  pastel, bright, dark, neon
}

const Set<String> COLOR_FAMILIES = {
  "red", "blue", "green", "yellow", "orange", "purple", "pink", "black", "white", "neutral",
};

const List<String> TOP_CATEGORIES = ["t-shirt", "blouse", "shirt", "tunic", "tang suit", "kurta"];
const List<String> BOTTOM_CATEGORIES = ["pants", "trousers", "skirt", "jeans", "palazzo pants", "dhoti", "veshti"];
const List<String> ONE_PIECE = ["dress", "gown", "jumpsuit", "maxi dress", "baju kurung", "baju kebaya", "baju melayu",
  "cheongsam", "qipao", "saree", "salwar kameez", "pavadai"];

List<String> get allSpecificCategories => [...TOP_CATEGORIES, ...BOTTOM_CATEGORIES, ...ONE_PIECE];

class ClothesDetailsPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> clothesData;

  const ClothesDetailsPage({
    super.key,
    required this.docId,
    required this.clothesData
  });

  @override
  State<ClothesDetailsPage> createState() => _ClothesDetailsPageState();
}

class _ClothesDetailsPageState extends State<ClothesDetailsPage> {
  final String apiUrl = dotenv.env['API_URL'] ?? "";

  late Map<String, dynamic> currentData;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    currentData = widget.clothesData;
  }

  String _formatColor(Map<String, dynamic> data) {
    // Check if 'color' field exists and is a Map
    if (data['color'] == null || data['color'] is! Map) {
      return "UNKNOWN";
    }

    final colorMap = data['color'] as Map<String, dynamic>;

    // Extract Family
    String family = (colorMap['family'] ?? "").toString().toUpperCase();

    // Extract Attributes
    List<dynamic> attrs = colorMap['attributes'] ?? [];

    if (attrs.isNotEmpty) {
      return attrs.first.toString().toUpperCase();
    }

    return family.isEmpty ? "UNKNOWN" : family;
  }

  // Dropdown Display
  String colorLabel(UnifiedColorType c) {
    switch (c) {
      case UnifiedColorType.neon: return "NEON";
      case UnifiedColorType.pastel: return "PASTEL";
      case UnifiedColorType.bright: return "BRIGHT";
      case UnifiedColorType.dark: return "DARK";
      default: return c.name.toUpperCase();
    }
  }

  // ---------------- UPDATE FUNCTION ----------------
  Future<void> _showEditDialog() async {
    final nameCtrl = TextEditingController(text: currentData['name']);
    final sizeCtrl = TextEditingController(text: currentData['size']);

    String selectedCategory = currentData['category'] ?? TOP_CATEGORIES[0];

    // Attempt to find current color enum
    UnifiedColorType? selectedColor;
    String currentColorStr = "";

    if (currentData['color'] != null && currentData['color'] is Map) {
      final colorMap = currentData['color'] as Map<String, dynamic>;
      final List attrs = colorMap['attributes'] ?? [];
      final String family = colorMap['family'] ?? "";

      // Prioritize color attribute, else fallback to color family
      if (attrs.isNotEmpty) {
        currentColorStr = attrs.first.toString();
      } else {
        currentColorStr = family;
      }
    }

    // Match string to Enum
    try {
      selectedColor = UnifiedColorType.values.firstWhere(
              (e) => e.name.toLowerCase() == currentColorStr.toLowerCase()
      );
    } catch (_) {
      selectedColor = UnifiedColorType.neutral;
    }

    XFile? newImageFile;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setSB) => AlertDialog(
          title: const Text("Edit Clothes"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Picker
                GestureDetector(
                  onTap: () async {
                    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                    if (img != null) setSB(() => newImageFile = img);
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: newImageFile != null
                            ? Image.file(File(newImageFile!.path), height: 120, width: 120, fit: BoxFit.cover)
                            : CachedNetworkImage(
                          imageUrl: currentData['image_url'] ?? "",
                          height: 120, width: 120, fit: BoxFit.cover,
                          placeholder: (_,__) => Container(color: Colors.grey[200]),
                          errorWidget: (_,__,___) => const Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                      Container(
                        height: 120, width: 120,
                        alignment: Alignment.center,
                        color: Colors.black26,
                        child: const Icon(Icons.edit, color: Colors.white),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
                const SizedBox(height: 10),

                TextField(controller: sizeCtrl, decoration: const InputDecoration(labelText: "Size")),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: allSpecificCategories.contains(selectedCategory) ? selectedCategory : allSpecificCategories[0],
                  isExpanded: true,
                  items: allSpecificCategories.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                  onChanged: (v) => setSB(() => selectedCategory = v!),
                  decoration: const InputDecoration(labelText: "Category"),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<UnifiedColorType>(
                  value: selectedColor,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: "Color"),
                  items: UnifiedColorType.values.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(colorLabel(c))
                  )).toList(),
                  onChanged: (v) => setSB(() => selectedColor = v),
                ),
                // THE ERROR CONTAINER
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

                final newName = nameCtrl.text.trim();
                final newSize = sizeCtrl.text.trim();

                // VALIDATION
                if (newName.isEmpty) {
                  setSB(() => error = "Name cannot be empty");
                  return;
                }
                if (newSize.isEmpty) {
                  setSB(() => error = "Size cannot be empty");
                  return;
                }

                // Clear error if validation passes
                setSB(() => error = null);

                await _performUpdate(
                    name: newName,
                    size: newSize,
                    category: selectedCategory,
                    color: selectedColor!,
                    newImage: newImageFile
                );
                Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performUpdate({
    required String name,
    required String size,
    required String category,
    required UnifiedColorType color,
    XFile? newImage
  }) async {
    // Show Loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updating...")));

    try {
      // Upload new image to Firebase Storage if picked
      String finalImageUrl = currentData['image_url'];
      if (newImage != null) {
        final ref = FirebaseStorage.instance.ref("clothes_images/${DateTime.now().millisecondsSinceEpoch}.jpg");
        await ref.putFile(File(newImage.path));
        finalImageUrl = await ref.getDownloadURL();
      }

      // Determine Piece Type
      String pieceType = "top";
      if (BOTTOM_CATEGORIES.contains(category)) pieceType = "bottom";
      else if (ONE_PIECE.contains(category)) pieceType = "one_piece";

      // Determine Color Logic
      String? colorFamily;
      List<String> colorAttributes = [];

      if (COLOR_FAMILIES.contains(color.name)) {
        colorFamily = color.name;
      } else {
        colorAttributes = [color.name];
      }

      // Send Update to Backend
      final url = Uri.parse('$apiUrl/items/${widget.docId}');

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": currentData['user_id'],
          "name": name,
          "size": size,
          "category": category,
          "piece_type": pieceType,
          "image_url": finalImageUrl,
          "color_family": colorFamily,
          "color_attributes": colorAttributes,
        }),
      );

      if (response.statusCode == 200) {
        // Update Local UI only after success
        final newData = {
          ...currentData,
          "name": name,
          "size": size,
          "category": category,
          "piece_type": pieceType,
          "image_url": finalImageUrl,
          "color": {
            "family": colorFamily ?? "neutral",
            "attributes": colorAttributes,
          }
        };

        setState(() {
          currentData = newData;
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update successful!")));
      } else {
        throw Exception("Backend error: ${response.body}");
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update: $e")));
    }
  }

  // ---------------- DELETE FUNCTION ----------------
  Future<void> _deleteClothes() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Are you sure you want to delete this item permanently?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        bool backendDeleteSuccess = false;

        // Delete from Backend
        try {
          final url = Uri.parse('$apiUrl/items/${widget.docId}');
          final response = await http.delete(url);

          if (response.statusCode == 200) {
            backendDeleteSuccess = true;
          }
        } catch (apiError) {
          print("Warning: Backend delete failed: $apiError");
        }

        // Delete from Firestore
        if (!backendDeleteSuccess) {
          await FirebaseFirestore.instance.collection('clothes').doc(widget.docId).delete();
        }

        // Close Loading Dialog
        if (mounted) Navigator.pop(context);

        // Close Details Page
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item deleted")));
        }
      } catch (e) {
        // Close loading if error
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
        }
      }
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = currentData['image_url'] ?? "";
    final name = currentData['name'] ?? "Unknown";
    final size = currentData['size'] ?? "-";
    final category = currentData['category'] ?? "-";
    final pieceType = currentData['piece_type'] ?? "-";

    String colorDisplay = _formatColor(currentData);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Details"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Close keyboard specifically when back is clicked
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit",
            onPressed: _showEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Delete",
            onPressed: _deleteClothes,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------------- IMAGE SECTION ----------------
            Container(
              height: 350,
              width: double.infinity,
              color: Colors.grey[200],
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_,__) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_,__,___) => const Icon(Icons.broken_image, size: 60, color: Colors.grey),
              )
                  : const Icon(Icons.checkroom, size: 100, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // ---------------- INFO CARD ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Name
                      Text(
                        name.toUpperCase(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Category Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                        ),
                      ),

                      const Divider(height: 30),

                      // Details Grid
                      _buildDetailRow(Icons.straighten, "Size", size),
                      _buildDetailRow(Icons.category, "Type", pieceType.replaceAll("_", " ").toUpperCase()),
                      _buildDetailRow(Icons.palette, "Color", colorDisplay),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}