import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ClothesDetailsPage extends StatefulWidget {
  final String docId; // Firestore document ID
  final Map<String, dynamic> clothesData;

  const ClothesDetailsPage({super.key, required this.docId, required this.clothesData});

  @override
  _ClothesDetailsPageState createState() => _ClothesDetailsPageState();
}

class _ClothesDetailsPageState extends State<ClothesDetailsPage> {
  final ImagePicker _picker = ImagePicker();

  late TextEditingController nameCtrl;
  late TextEditingController sizeCtrl;
  late String category;
  late String season;
  XFile? pickedImage;
  String? error;

  List<String> categories = ["Top", "Bottom", "Shoes", "Accessories"];
  List<String> seasons = ["Spring", "Summer", "Autumn", "Winter"];

  @override
  void initState() {
    super.initState();
    final data = widget.clothesData;
    nameCtrl = TextEditingController(text: data["name"] ?? "");
    sizeCtrl = TextEditingController(text: data["size"] ?? "");
    category = (data["category"] as String?) ?? categories.first;
    season = (data["season"] as String?) ?? seasons.first;
  }

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

  Future<void> _updateClothes() async {
    if (nameCtrl.text.trim().isEmpty) {
      setState(() => error = "Name is required");
      return;
    }
    if (sizeCtrl.text.trim().isEmpty) {
      setState(() => error = "Size is required");
      return;
    }
    setState(() => error = null);

    try {
      Map<String, dynamic> data = {
        "name": nameCtrl.text.trim(),
        "size": sizeCtrl.text.trim(),
        "category": category,
        "season": season,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      if (pickedImage != null) {
        String? url = await _uploadImage(pickedImage);
        if (url != null) data["image_url"] = url;
      }
      await FirebaseFirestore.instance.collection("clothes").doc(widget.docId).update(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clothes updated")));
      }
    } catch (e) {
      debugPrint("Update error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update: $e")));
    }
  }

  Future<void> _deleteClothes() async {
    try {
      await FirebaseFirestore.instance.collection("clothes").doc(widget.docId).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Delete error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = pickedImage != null ? pickedImage!.path : (widget.clothesData['image_url'] as String? ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Clothes Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Delete Clothes"),
                  content: const Text("Are you sure you want to delete this item?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    ElevatedButton(
                        onPressed: () {
                          _deleteClothes();
                          Navigator.pop(context);
                        },
                        child: const Text("Delete")),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image picker
            GestureDetector(
              onTap: () async {
                final img = await _picker.pickImage(source: ImageSource.gallery);
                if (img != null) setState(() => pickedImage = img);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? (pickedImage != null
                    ? Image.file(File(pickedImage!.path), width: double.infinity, height: 250, fit: BoxFit.contain)
                    : Image.network(imageUrl, width: double.infinity, height: 250, fit: BoxFit.contain))
                    : Container(
                  width: double.infinity,
                  height: 250,
                  color: Colors.grey[300],
                  child: const Icon(Icons.checkroom, size: 60, color: Colors.blueAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Name
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            const SizedBox(height: 16),
            // Size
            TextField(controller: sizeCtrl, decoration: const InputDecoration(labelText: "Size")),
            const SizedBox(height: 16),
            // Category
            DropdownButtonFormField<String>(
              value: category,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => category = v!),
              decoration: const InputDecoration(labelText: "Category"),
            ),
            const SizedBox(height: 16),
            // Season
            DropdownButtonFormField<String>(
              value: season,
              items: seasons.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => season = v!),
              decoration: const InputDecoration(labelText: "Season"),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _updateClothes,
                child: const Text("Save Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
