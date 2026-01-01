import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'app_drawer.dart';

class ProfilePage extends StatefulWidget {
  final String uid;
  const ProfilePage({super.key, required this.uid});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final String uid;
  bool _loading = true;
  bool _saving = false;

  SharedPreferences? _prefs;
  Stream<DocumentSnapshot>? _profileStream;

  // Controllers
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  String? _gender; // "Male", "Female"

  // Size recommendations
  String recommendedTop = '-';
  String recommendedBottom = '-';

  @override
  void initState() {
    super.initState();
    uid = widget.uid;
    _initCacheAndUser();
  }

  Future<void> _initCacheAndUser() async {
    _prefs = await SharedPreferences.getInstance();

    // Load cached values instantly
    _loadFromCache();

    // Listening to Firestore auto updates
    _subscribeToFirestore();
  }

  void _loadFromCache() {
    setState(() {
      _usernameCtrl.text = _prefs?.getString('profile_username') ?? '';
      _weightCtrl.text = _prefs?.getString('profile_weight') ?? '';
      _heightCtrl.text = _prefs?.getString('profile_height') ?? '';
      _ageCtrl.text = _prefs?.getString('profile_age') ?? '';
      _gender = _prefs?.getString('profile_gender');
    });

    _calcAndSetRecommendation();
  }

  void _subscribeToFirestore() {
    _profileStream = _firestore.collection('profile').doc(uid).snapshots();

    _profileStream!.listen((doc) {
      if (_loading) setState(() => _loading = false);
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;

      setState(() {
        _usernameCtrl.text = data['username'] ?? '';
        _weightCtrl.text = data['weight']?.toString() ?? '';
        _heightCtrl.text = data['height']?.toString() ?? '';
        _ageCtrl.text = data['age']?.toString() ?? '';
        _gender = data['gender'];
      });

      _calcAndSetRecommendation();
    }, onError: (e) {
      if (_loading) setState(() => _loading = false);
    });
  }

  Future<void> _saveToCache({
    required String username,
    required String weight,
    required String height,
    required String age,
    String? gender,
  }) async {
    await _prefs?.setString('profile_username', username);
    await _prefs?.setString('profile_weight', weight);
    await _prefs?.setString('profile_height', height);
    await _prefs?.setString('profile_age', age);
    if (gender != null) await _prefs?.setString('profile_gender', gender);

    final Map<String, dynamic> userProfileMap = {
      "username": username,
      "weight": weight,
      "height": height,
      "age": age,
      "gender": gender,
      "uid": uid
    };

    await _prefs?.setString("user_profile", jsonEncode(userProfileMap));
  }

  _calcAndSetRecommendation() {
    final w = double.tryParse(_weightCtrl.text);
    final h = double.tryParse(_heightCtrl.text);
    final a = int.tryParse(_ageCtrl.text);

    if (w == null || h == null) {
      setState(() {
        recommendedTop = '-';
        recommendedBottom = '-';
      });
      return;
    }

    final sizes = calculateSizes(heightCm: h, weightKg: w, age: a);
    setState(() {
      recommendedTop = sizes['top']!;
      recommendedBottom = sizes['bottom']!;
    });
  }

  // calculate suitable size based on height, weight and age
  Map<String, String> calculateSizes({
    required double heightCm,
    required double weightKg,
    int? age,
  }) {
    // Height category
    String heightCategory;
    if (heightCm < 160) {
      heightCategory = 'short';
    } else if (heightCm < 175) {
      heightCategory = 'medium';
    } else {
      heightCategory = 'tall';
    }

    // Weight category
    String weightCategory;
    if (weightKg < 55) {
      weightCategory = 'light';
    } else if (weightKg < 75) {
      weightCategory = 'normal';
    } else if (weightKg < 95) {
      weightCategory = 'heavy';
    } else {
      weightCategory = 'xheavy';
    }

    // Top size mapping
    String top;
    switch (weightCategory) {
      case 'light':
        top = 'S';
        break;
      case 'normal':
        top = 'M';
        break;
      case 'heavy':
        top = 'L';
        break;
      default:
        top = 'XL';
    }

    // Bottom size mapping
    String bottom;
    if (heightCategory == 'short') {
      if (weightCategory == 'light') bottom = 'S';
      else if (weightCategory == 'normal') bottom = 'S-M';
      else if (weightCategory == 'heavy') bottom = 'M-L';
      else bottom = 'L-XL';
    } else if (heightCategory == 'medium') {
      if (weightCategory == 'light') bottom = 'S';
      else if (weightCategory == 'normal') bottom = 'M';
      else if (weightCategory == 'heavy') bottom = 'L';
      else bottom = 'XL';
    } else { // tall
      if (weightCategory == 'light') bottom = 'M';
      else if (weightCategory == 'normal') bottom = 'M-L';
      else if (weightCategory == 'heavy') bottom = 'L-XL';
      else bottom = 'XL';
    }

    // Age adjustments
    if (age != null) {
      if (age < 18) {
        if (top == 'M') top = 'S';
        else if (top == 'L') top = 'M';
        if (bottom.contains('M')) bottom = bottom.replaceAll('M', 'S');
        else if (bottom.contains('L')) bottom = bottom.replaceAll('L', 'M');
      } else if (age >= 60) {
        top += '+';
        bottom += '+';
      }
    }

    return {'top': top, 'bottom': bottom};
  }

  Future<void> _saveProfile() async {
    final username = _usernameCtrl.text.trim();
    final weightVal = double.tryParse(_weightCtrl.text.trim());
    final heightVal = double.tryParse(_heightCtrl.text.trim());
    final ageVal = int.tryParse(_ageCtrl.text.trim());

    if (username.isEmpty || weightVal == null || heightVal == null || ageVal == null || _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _firestore.collection('profile').doc(uid).set({
        'username': username,
        'weight': weightVal,
        'height': heightVal,
        'age': ageVal,
        'gender': _gender,
      }, SetOptions(merge: true));

      // save to local cache
      await _saveToCache(
        username: username,
        weight: weightVal.toString(),
        height: heightVal.toString(),
        age: ageVal.toString(),
        gender: _gender,
      );

      _calcAndSetRecommendation();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _changePasswordFlow() async {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordCtrl,
                decoration: const InputDecoration(labelText: 'Current password'),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: newPasswordCtrl,
                decoration: const InputDecoration(labelText: 'New password (8+ chars)'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 8) ? 'Minimum 8 chars' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(context).pop(true);
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final currentPassword = currentPasswordCtrl.text.trim();
    final newPassword = newPasswordCtrl.text.trim();

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No logged-in user')));
      return;
    }

    // Reauthenticate
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Re-authentication failed: ${e.message}')),
      );
      return;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Re-authentication error: $e')),
      );
      return;
    }

    // Update password
    try {
      await user.updatePassword(newPassword);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password update failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating password: $e')),
      );
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    VoidCallback? onChangedCallback,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) {
        if (onChangedCallback != null) onChangedCallback();
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.blue.shade600;

    if (_loading &&
        _usernameCtrl.text.isEmpty &&
        _weightCtrl.text.isEmpty &&
        _heightCtrl.text.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    return Scaffold(
      drawer: AppDrawer(uid: widget.uid),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.blue.shade50,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (_usernameCtrl.text.isNotEmpty ? _usernameCtrl.text[0].toUpperCase() : '?'),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _usernameCtrl.text.isNotEmpty ? _usernameCtrl.text : 'No username',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(_auth.currentUser?.email ?? '-', style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.lock_open),
                                  label: const Text('Change Password'),
                                  onPressed: _changePasswordFlow,
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Editable fields card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Align(alignment: Alignment.centerLeft, child: Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent))),
                      const SizedBox(height: 12),
                      _buildField(
                        label: 'Username',
                        controller: _usernameCtrl,
                        icon: Icons.person,
                        onChangedCallback: () => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        label: 'Weight (kg)',
                        controller: _weightCtrl,
                        icon: Icons.monitor_weight,
                        keyboardType: TextInputType.number,
                        onChangedCallback: _calcAndSetRecommendation,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        label: 'Height (cm)',
                        controller: _heightCtrl,
                        icon: Icons.height,
                        keyboardType: TextInputType.number,
                        onChangedCallback: _calcAndSetRecommendation,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Age field
                          Expanded(
                            flex: 1,
                            child: _buildField(
                              label: 'Age',
                              controller: _ageCtrl,
                              icon: Icons.cake,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Gender selection
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Gender',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(() => _gender = "Male"),
                                      child: Column(
                                        children: [
                                          Icon(Icons.male, color: _gender == "Male" ? Colors.blue : Colors.grey, size: 32),
                                          const SizedBox(height: 2),
                                          const Text('Male', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _gender = "Female"),
                                      child: Column(
                                        children: [
                                          Icon(Icons.female, color: _gender == "Female" ? Colors.pink : Colors.grey, size: 32),
                                          const SizedBox(height: 2),
                                          const Text('Female', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)
                                  )),
                              child: _saving
                                  ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2
                                  ))
                                  : const Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Recommendation card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Align(alignment: Alignment.centerLeft, child: Text('Recommended Sizes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Top', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(recommendedTop, style: const TextStyle(fontSize: 20)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bottom', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(recommendedBottom, style: const TextStyle(fontSize: 20)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sizes are recommendations based on age, height and weight ranges. Adjust according to fit preference.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
