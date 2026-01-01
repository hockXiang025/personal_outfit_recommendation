import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

import 'favourites.dart';

class RecommendationResultPage extends StatefulWidget {
  final String uid;
  final String pieceType;
  final String top;
  final String bottom;
  final String? topImageUrl;
  final String? bottomImageUrl;

  final List<Map<String, dynamic>>? alternativeTops;
  final List<Map<String, dynamic>>? alternativeBottoms;

  final Map<String, List<Map<String, dynamic>>> shoppingSuggestions;
  final Map<String, dynamic> requestData;

  final String? pageTitle;
  final String? pageSubtitle;

  final bool showFavButton;

  const RecommendationResultPage({
    super.key,
    required this.uid,
    required this.pieceType,
    required this.top,
    required this.bottom,
    this.topImageUrl,
    this.bottomImageUrl,
    this.alternativeTops,
    this.alternativeBottoms,
    required this.shoppingSuggestions,
    required this.requestData,
    required this.pageTitle,
    required this.pageSubtitle,
    this.showFavButton = false,
  });

  @override
  State<RecommendationResultPage> createState() =>
      _RecommendationResultPageState();
}

class _RecommendationResultPageState extends State<RecommendationResultPage> {
  String? selectedTopName;
  String? selectedTopUrl;
  String? selectedBottomName;
  String? selectedBottomUrl;

  @override
  void initState() {
    super.initState();

    selectedTopName = widget.top.trim().isEmpty ? null : widget.top.trim();
    selectedBottomName =
    widget.bottom.trim().isEmpty ? null : widget.bottom.trim();

    selectedTopUrl =
    widget.topImageUrl?.trim().isEmpty ?? true ? null : widget.topImageUrl;
    selectedBottomUrl =
    widget.bottomImageUrl?.trim().isEmpty ?? true ? null : widget.bottomImageUrl;
  }

  // ---------------- SAVE ----------------
  Future<void> _saveToFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedFavs = prefs.getStringList('favorite_outfits') ?? [];

    Map<String, dynamic> newOutfit = {
      "date": DateTime.now().toIso8601String(), // Or use widget.scheduledDate
      "event": widget.requestData['event'] ?? "Event",
      "season": widget.requestData['season'],
      "weather": widget.requestData['weather'],
      "temp": widget.requestData['temp'] ?? widget.requestData['temperature'],
      "result": {
        "piece_type": widget.pieceType,
        "top": {"name": selectedTopName ?? widget.top, "image_url": selectedTopUrl ?? widget.topImageUrl},
        "bottom": {"name": selectedBottomName ?? widget.bottom, "image_url": selectedBottomUrl ?? widget.bottomImageUrl},
        "alternative_tops": widget.alternativeTops,
        "alternative_bottoms": widget.alternativeBottoms,
        "shoppingSuggestions": widget.shoppingSuggestions,
      }
    };

    savedFavs.add(jsonEncode(newOutfit));
    await prefs.setStringList('favorite_outfits', savedFavs);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Added to Favourites!"))
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => FavouritesPage(uid: widget.uid)));
    }
  }

  Future<void> showPlatformSelector(
      List<Map<String, dynamic>> platforms,
      ) async {
    if (platforms.isEmpty) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Buy from"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: platforms.map((p) {
              final String platform = p["platform"] ?? "Platform";
              final String? url = p["url"];

              return ListTile(
                leading: const Icon(Icons.shopping_bag),
                title: Text(platform),
                onTap: (url != null && url.isNotEmpty)
                    ? () {
                  Navigator.pop(context);
                  _openPlatform(url);
                }
                    : null,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ---------------- URL LAUNCH ----------------
  Future<void> _openPlatform(String url) async {
    if (url.isEmpty) return;

    Uri uri = Uri.parse(url);

    try {
      bool launched =
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);

        if (!launched) {
          // --- WebView Fallback ---
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text("Web Preview")),
                body: WebViewWidget(
                  controller: WebViewController()
                    ..setJavaScriptMode(JavaScriptMode.unrestricted)
                    ..loadRequest(Uri.parse(url)),
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("Web Preview")),
            body: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(Uri.parse(url)),
            ),
          ),
        ),
      );
    }
  }

  // --------------- CHOOSE ALTERNATIVES -----------------
  Future<void> chooseAlternative({
    required bool isTop,
    required List<Map<String, dynamic>> alternatives,
  }) async {

    // Identify Original
    final String originalName = isTop ? widget.top : widget.bottom;
    final String? originalImage = isTop ? widget.topImageUrl : widget.bottomImageUrl;

    final String? currentName = isTop ? selectedTopName : selectedBottomName;

    List<Map<String, dynamic>> fullList = List.from(alternatives);

    // Only add Original if currently not using it
    if (currentName != originalName) {
      fullList.insert(0, {
        "name": originalName,
        "image_url": originalImage,
        "is_original": true,
      });
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Alternatives"),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: fullList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.7
              ),
              itemBuilder: (context, index) {
                final item = fullList[index];

                // Handle different key naming conventions
                final String? imgUrl = item['image_url'] ?? item['imageUrl'];
                final String name = item['name'] ?? "Unknown";
                final bool isOriginal = item['is_original'] ?? false;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isTop) {
                        selectedTopName = name;
                        selectedTopUrl = imgUrl;
                      } else {
                        selectedBottomName = name;
                        selectedBottomUrl = imgUrl;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            // Highlight the "Original" option specifically
                              border: isOriginal
                                  ? Border.all(color: Colors.blueAccent, width: 3)
                                  : Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8)),
                          child: imgUrl != null && imgUrl.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.network(imgUrl, fit: BoxFit.cover),
                          )
                              : const Center(child: Text("No Img", style: TextStyle(fontSize: 10))),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOriginal ? "Original" : name,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: isOriginal ? FontWeight.bold : FontWeight.normal,
                            color: isOriginal ? Colors.blue : Colors.black
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ---------------- IMAGE BUILDER ----------------
  Widget buildImage(String? url) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: url == null
          ? const Center(child: Text("No Suitable Outfit"))
          : Image.network(url, fit: BoxFit.cover),
    );
  }

  // ---------------- BUY BUTTON ----------------
  Widget buyButton(String key) {
    final platforms = widget.shoppingSuggestions[key] ?? [];

    if (platforms.isEmpty) return const SizedBox.shrink();

    return ElevatedButton.icon(
      icon: const Icon(Icons.shopping_cart),
      label: const Text("Buy"),
      onPressed: () => showPlatformSelector(platforms),
    );
  }

  // ---------------- PREVIEW ----------------
  Widget outfitPreview() {
    final hasTop = selectedTopName != null;
    final hasBottom = selectedBottomName != null;

    // -------- ONE-PIECE --------
    if (widget.pieceType == "one_piece") {
      if (hasTop) {
        // If Have suitable recommendation,
        // Show Image + Name + "More" Button
        return Center(
          child: _clothColumn(
            title: "One-Piece",
            name: selectedTopName,
            image: selectedTopUrl,
            keyName: "one_piece",
            hasRecommendation: true,
          ),
        );
      } else {
        // If Have NO suitable recommendation,
        // Show No Image + "Buy" Button
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildImage(null),
            const SizedBox(height: 12),
            const Text(
              "No suitable one-piece found.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (widget.shoppingSuggestions.containsKey("one_piece"))
              buyButton("one_piece"),
          ],
        );
      }
    }

    // -------- TOP + BOTTOM (side-by-side) --------
    if (widget.pieceType == "top_bottom") {
      final bool hasTop = selectedTopName != null;
      final bool hasBottom = selectedBottomName != null;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------- TOP COLUMN --------
          // Handles both "Found" (More) and "Missing" (Buy) internally
          Expanded(
            child: _clothColumn(
              title: "Top",
              name: selectedTopName,
              image: selectedTopUrl,
              keyName: "top",
              hasRecommendation: hasTop,
            ),
          ),

          // Divider
          Container(
              width: 1,
              height: 200,
              color: Colors.grey[300],
              margin: const EdgeInsets.symmetric(horizontal: 8)
          ),

          // -------- BOTTOM COLUMN --------
          // Handles both "Found" (More) and "Missing" (Buy) internally
          Expanded(
            child: _clothColumn(
              title: "Bottom",
              name: selectedBottomName,
              image: selectedBottomUrl,
              keyName: "bottom",
              hasRecommendation: hasBottom,
            ),
          ),
        ],
      );
    }
    return const Center(child: Text("No outfit data available"));
  }

  Widget _clothColumn({
    required String title,
    required String? name,
    required String? image,
    required String keyName,
    required bool hasRecommendation,
  }) {
    return Column(
      children: [
        Text(title.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 8),

        buildImage(image),

        const SizedBox(height: 10),
        Text(
          name ?? "No suitable item",
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 12),

        // SHOW "MORE" BUTTON If have recommendation
        if (hasRecommendation)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: OutlinedButton.icon(
              onPressed: () => chooseAlternative(
                isTop: keyName == "top" || keyName == "one_piece",
                alternatives: keyName == "top" || keyName == "one_piece"
                    ? widget.alternativeTops ?? []
                    : widget.alternativeBottoms ?? [],
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("More"),
            ),
          ),

        // SHOW "BUY" BUTTON If no recommendation
        if (!hasRecommendation)
          buyButton(keyName)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.requestData['weather'] ?? "--";
    final temp = widget.requestData['temp'] ?? widget.requestData['temperature'] ?? "--";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
          title: widget.pageTitle != null
             ? Column(
              children:[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.pageTitle!,
                      style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
          )
      : const Text("Your Outfit Recommendation"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.pageSubtitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  widget.pageSubtitle!,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87
                  ),
                ),
              ),
            // WEATHER CARD
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      const Text("Weather", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(weather.toString()),
                    ]),
                    Column(children: [
                      const Text("Temperature", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("$temp°C"),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            outfitPreview(),
            const Spacer(),
            if (widget.showFavButton)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveToFavorites, // save to favourites button
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.favorite),
                  label: const Text("Save as Favourite", style: TextStyle(fontSize: 18)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
