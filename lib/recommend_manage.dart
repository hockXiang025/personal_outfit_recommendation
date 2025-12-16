import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class RecommendationResultPage extends StatefulWidget {
  final String top;
  final String bottom;
  final String? topImageUrl;
  final String? bottomImageUrl;

  final List<Map<String, dynamic>>? alternativeTops;
  final List<Map<String, dynamic>>? alternativeBottoms;

  final List<Map<String, dynamic>> shoppingSuggestions;

  final Map<String, dynamic> requestData;

  const RecommendationResultPage({
    super.key,
    required this.top,
    required this.bottom,
    this.topImageUrl,
    this.bottomImageUrl,
    this.alternativeTops,
    this.alternativeBottoms,
    required this.requestData,
    required this.shoppingSuggestions,
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
    selectedTopName = widget.top;
    selectedTopUrl = widget.topImageUrl;
    selectedBottomName = widget.bottom;
    selectedBottomUrl = widget.bottomImageUrl;
  }

  // ---------------- SAVE RECOMMENDATION ----------------
  Future<void> saveRecommendation() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList('saved_outfits') ?? [];

    Map<String, dynamic> data = {
      "top": selectedTopName,
      "bottom": selectedBottomName,
      "topImageUrl": selectedTopUrl,
      "bottomImageUrl": selectedBottomUrl,
      "details": widget.requestData,
      "time": DateTime.now().toIso8601String(),
    };

    saved.add(jsonEncode(data));
    await prefs.setStringList('saved_outfits', saved);
  }

  // ---------------- SAFE URL LAUNCH ----------------
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
    if (alternatives.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No alternatives available.")));
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isTop ? "Choose an alternative top" : "Choose an alternative bottom"),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: alternatives.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10),
              itemBuilder: (context, index) {
                final item = alternatives[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isTop) {
                        selectedTopName = item['name'];
                        selectedTopUrl = item['imageUrl'];
                      } else {
                        selectedBottomName = item['name'];
                        selectedBottomUrl = item['imageUrl'];
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.black54),
                        borderRadius: BorderRadius.circular(8)),
                    child: item['imageUrl'] != null
                        ? Image.network(item['imageUrl'], fit: BoxFit.cover)
                        : const Center(child: Text("No Image")),
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
  Widget buildImage(String? url, String label) {
    const double width = 120;
    const double height = 120;

    if (url == null || url.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black26),
        ),
        child: Center(
          child: Text(
            "No $label image",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ),
      );
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black26),
        ),
        child: Center(
          child: Text(
            "$label image error",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget outfitPreview() {
    final hasTop = selectedTopName != null && selectedTopName!.isNotEmpty;
    final hasBottom = selectedBottomName != null && selectedBottomName!.isNotEmpty;

    final noSuitableOutfit = !hasTop && !hasBottom && widget.shoppingSuggestions.isNotEmpty;

    // ----------------- ONE-PIECE -----------------
    if (hasTop && !hasBottom) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildImage(selectedTopUrl, "one-piece"),
          const SizedBox(height: 8),
          Text(selectedTopName ?? "No Name", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if ((widget.alternativeTops ?? []).isNotEmpty)
            ElevatedButton(
              onPressed: () => chooseAlternative(
                isTop: true,
                alternatives: widget.alternativeTops ?? [],
              ),
              child: const Text("More"),
            )
          else if (noSuitableOutfit)
            ElevatedButton.icon(
              onPressed: () => _openPlatform(widget.shoppingSuggestions.first["url"]),
              icon: const Icon(Icons.shopping_cart),
              label: const Text("Buy"),
            ),
        ],
      );
    }

    // ----------------- TOP + BOTTOM -----------------
    if (hasTop || hasBottom) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              const Text("Top", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              buildImage(selectedTopUrl, "top"),
              const SizedBox(height: 8),
              Text(selectedTopName ?? "No suitable top"),
              const SizedBox(height: 8),
              if ((widget.alternativeTops ?? []).isNotEmpty)
                ElevatedButton(
                  onPressed: () => chooseAlternative(
                    isTop: true,
                    alternatives: widget.alternativeTops ?? [],
                  ),
                  child: const Text("More"),
                )
              else if (!hasTop && widget.shoppingSuggestions.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _openPlatform(widget.shoppingSuggestions.first["url"]),
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text("Buy"),
                ),
            ],
          ),
          Column(
            children: [
              const Text("Bottom", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              buildImage(selectedBottomUrl, "bottom"),
              const SizedBox(height: 8),
              Text(selectedBottomName ?? "No suitable bottom"),
              const SizedBox(height: 8),
              if ((widget.alternativeBottoms ?? []).isNotEmpty)
                ElevatedButton(
                  onPressed: () => chooseAlternative(
                    isTop: false,
                    alternatives: widget.alternativeBottoms ?? [],
                  ),
                  child: const Text("More"),
                )
              else if (!hasBottom && widget.shoppingSuggestions.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _openPlatform(widget.shoppingSuggestions.first["url"]),
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text("Buy"),
                ),
            ],
          ),
        ],
      );
    }

    // ----------------- NOTHING SUITABLE -----------------
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildImage(null, "one-piece"), // default placeholder
        const SizedBox(height: 8),
        const Text("No suitable outfit found.", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (widget.shoppingSuggestions.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () => _openPlatform(widget.shoppingSuggestions.first["url"]),
            icon: const Icon(Icons.shopping_cart),
            label: const Text("Buy"),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.requestData['weather'] ?? "--";
    final temp = widget.requestData['temperature'] ?? "--";

    return Scaffold(
      appBar: AppBar(title: const Text("Your Outfit Recommendation")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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

            // MAIN OUTFIT PREVIEW
            outfitPreview(),

            const Spacer(),

            // SAVE BUTTON
            ElevatedButton.icon(
              onPressed: () async {
                await saveRecommendation();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Saved to your history!")));
              },
              icon: const Icon(Icons.bookmark_add),
              label: const Text("Save Recommendation"),
            ),
          ],
        ),
      ),
    );
  }
}
