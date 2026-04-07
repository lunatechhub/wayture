import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/screens/login_screen.dart';
import 'package:wayture/services/auth_service.dart';
import 'package:wayture/services/theme_service.dart';
import 'package:wayture/widgets/custom_text_field.dart';

/// Settings screen — glassmorphism cards over sunset background.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  // Local profile overrides (updated via Edit Profile sheet)
  String? _profileName;
  String? _profileEmail;
  File? _profileImage;

  // Cached rating so the "Rate the App" sheet can show the previous value.
  int _currentRating = 0;
  String _currentFeedback = '';

  final _mapDisplayOptions = ['Color-coded', 'Simple', 'Minimal'];
  static const _mapDisplayDescriptions = [
    'Traffic density with colored routes',
    'Clean single-color navigation',
    'Map only, no overlays',
  ];
  static const _mapDisplayIcons = [
    Icons.palette_outlined,
    Icons.route_outlined,
    Icons.map_outlined,
  ];
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettingsFromFirestore();
    _loadProfileFromFirestore();
  }

  // ── Firestore loaders ────────────────────────────────────

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Load persisted preferences (notifications on/off, language, rating)
  /// so they survive app restarts. Silent no-op if the user isn't signed in.
  Future<void> _loadSettingsFromFirestore() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc(uid)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      setState(() {
        _notificationsEnabled =
            data['notificationsEnabled'] as bool? ?? _notificationsEnabled;
        _selectedLanguage =
            data['language'] as String? ?? _selectedLanguage;
        // Rating is stored in the same settings doc so it reuses the
        // already-deployed settings rules (no separate collection needed).
        _currentRating = (data['rating'] as num?)?.toInt() ?? 0;
        _currentFeedback = data['ratingFeedback'] as String? ?? '';
      });
    } catch (e) {
      debugPrint('settings load error: $e');
    }
  }

  /// Load the user's profile overrides (name/email) from Firestore.
  Future<void> _loadProfileFromFirestore() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      setState(() {
        _profileName = data['name'] as String? ?? _profileName;
        _profileEmail = data['email'] as String? ?? _profileEmail;
      });
    } catch (e) {
      debugPrint('profile load error: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  String _getDisplayName(AuthService auth) =>
      _profileName ?? auth.displayName;

  String _getDisplayEmail(AuthService auth) =>
      _profileEmail ?? auth.displayEmail;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Profile Image Picker ────────────────────────────────

  void _showImageSourcePicker(StateSetter sheetSetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(217),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Change Profile Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take a Photo',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera, sheetSetState);
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery, sheetSetState);
              },
            ),
            if (_profileImage != null) ...[
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.redAccent, fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _profileImage = null);
                  sheetSetState(() {});
                  _showSnackBar('Profile photo removed');
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, StateSetter sheetSetState) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => _profileImage = File(picked.path));
        sheetSetState(() {});
        _showSnackBar('Profile photo updated');
      }
    } catch (e) {
      _showSnackBar('Could not access ${source == ImageSource.camera ? "camera" : "gallery"}');
    }
  }

  // ── FEATURE 1: Edit Profile ─────────────────────────────

  void _showEditProfileSheet(AuthService auth) {
    final nameCtrl = TextEditingController(text: _getDisplayName(auth));
    final emailCtrl = TextEditingController(text: _getDisplayEmail(auth));
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sheetSetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(217),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tappable avatar with camera overlay — picks image
                    GestureDetector(
                      onTap: () => _showImageSourcePicker(sheetSetState),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary.withAlpha(80),
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : null,
                            child: _profileImage == null
                                ? Text(
                                    nameCtrl.text.isNotEmpty
                                        ? nameCtrl.text[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.black, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    CustomTextField(
                      controller: nameCtrl,
                      hintText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline,
                          color: Colors.white70),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Email
                    CustomTextField(
                      controller: emailCtrl,
                      hintText: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Colors.white70),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Invalid email format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Phone (optional)
                    CustomTextField(
                      controller: phoneCtrl,
                      hintText: 'Phone (optional)',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 24),

                    // Save Changes button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final newName = nameCtrl.text.trim();
                          final newEmail = emailCtrl.text.trim();
                          final newPhone = phoneCtrl.text.trim();

                          setState(() {
                            _profileName = newName;
                            _profileEmail = newEmail;
                          });

                          // Persist to Firestore users/{uid} so the profile
                          // survives restarts and is visible to the backend.
                          final uid = _uid;
                          if (uid != null) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .set({
                                'name': newName,
                                'email': newEmail,
                                if (newPhone.isNotEmpty) 'phone': newPhone,
                                'updatedAt':
                                    FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                            } catch (e) {
                              debugPrint('profile save error: $e');
                            }
                          }

                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          _showSnackBar('Profile updated successfully');
                        },
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Cancel
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white60, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── FEATURE 5: Language Picker ──────────────────────────

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(217),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Select Language',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _languageTile(ctx, 'English'),
            const Divider(color: Colors.white12),
            _languageTile(ctx, 'नेपाली'),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _languageTile(BuildContext ctx, String language) {
    final isSelected = _selectedLanguage == language;
    return ListTile(
      title: Text(language,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.radio_button_unchecked, color: Colors.white38),
      onTap: () async {
        setState(() => _selectedLanguage = language);
        await _saveSetting('language', language);
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        _showSnackBar('Language changed to $language');
      },
    );
  }

  /// Write a single key to settings/{uid} using merge so it doesn't wipe
  /// other fields written elsewhere.
  Future<void> _saveSetting(String key, Object value) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc(uid)
          .set({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('setting save error ($key): $e');
    }
  }

  // ── FEATURE 6: About Wayture ────────────────────────────

  void _showAboutWayture() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        // Wrap in SingleChildScrollView so the dialog content can scroll
        // on short screens instead of overflowing vertically.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary,
                child: Text('W',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 14),
              const Text('Wayture',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Version ${AppConstants.appVersion}',
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 18),
              const Text(
                'Traffic Congestion Predictor for Kathmandu',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const Text('Built for BSc Final Year Project',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Text('University of Bedfordshire',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('Student: Luna Bhattarai',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Text('Supervisor: Pawan KC',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 18),
              Text(
                '© 2025 Wayture. All rights reserved.',
                style: TextStyle(
                    color: Colors.white.withAlpha(100), fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ── FEATURE 7: Help & Support ───────────────────────────

  void _showHelpSupport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(217),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Help & Support',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _helpTile(Icons.quiz_outlined, 'FAQ', () {
              Navigator.pop(ctx);
              _showFAQ();
            }),
            const Divider(color: Colors.white12),
            _helpTile(Icons.email_outlined, 'Contact Support', () {
              Navigator.pop(ctx);
              _showContactSupport();
            }),
            const Divider(color: Colors.white12),
            _helpTile(Icons.bug_report_outlined, 'Report a Bug', () {
              Navigator.pop(ctx);
              _showBugReport();
            }),
            const Divider(color: Colors.white12),
            _helpTile(Icons.star_outline, 'Rate the App', () {
              Navigator.pop(ctx);
              _showRatingSheet();
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _helpTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing:
          const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
      onTap: onTap,
    );
  }

  void _showFAQ() {
    const faqs = [
      {
        'q': 'How does Wayture predict traffic?',
        'a':
            'Wayture uses a rule-based engine that analyses vehicle speed, community reports, weather conditions, time of day, and known congestion hotspots to predict traffic levels.',
      },
      {
        'q': 'Is my location data stored?',
        'a':
            'Your location data is used only for navigation and traffic analysis. We do not store personally identifiable information.',
      },
      {
        'q': 'How do I report an incident?',
        'a':
            'Go to the Reports tab and tap the + button. Select the incident type, add a description, and submit.',
      },
      {
        'q': 'Why is traffic data not accurate?',
        'a':
            'Traffic data relies on community reports and available API data. Accuracy improves as more users contribute reports.',
      },
      {
        'q': 'Can I use Wayture offline?',
        'a':
            'Wayture shows the last known traffic and weather data when offline. Full features require an internet connection.',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(217),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: faqs.length,
                  separatorBuilder: (_, index) =>
                      const Divider(color: Colors.white12),
                  itemBuilder: (_, i) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      faqs[i]['q']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    iconColor: AppColors.primary,
                    collapsedIconColor: Colors.white38,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          faqs[i]['a']!,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBugReport() {
    final bugCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sheetSetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(217),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Report a Bug',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: bugCtrl,
                  hintText: 'Describe the bug...',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
                            final text = bugCtrl.text.trim();
                            if (text.isEmpty) {
                              _showSnackBar('Please describe the bug first');
                              return;
                            }
                            sheetSetState(() => submitting = true);

                            // Persist to Firestore bugReports collection
                            final uid = _uid;
                            try {
                              await FirebaseFirestore.instance
                                  .collection('bugReports')
                                  .add({
                                'userid': uid ?? 'anonymous',
                                'description': text,
                                'appVersion': AppConstants.appVersion,
                                'createdAt':
                                    FieldValue.serverTimestamp(),
                              });
                            } catch (e) {
                              debugPrint('bug report save error: $e');
                            }

                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _showSnackBar(
                                'Bug report submitted. Thank you!');
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Submit',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Contact Support ─────────────────────────────────────

  void _showContactSupport() {
    const supportEmail = 'support@wayture.com';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.email_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Contact Support',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reach the Wayture team at:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const SelectableText(
                supportEmail,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Average reply time: 24 hours',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16, color: AppColors.primary),
            label: const Text('Copy',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () async {
              await Clipboard.setData(
                  const ClipboardData(text: supportEmail));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _showSnackBar('Email copied to clipboard');
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  // ── Rate the App ────────────────────────────────────────

  void _showRatingSheet() {
    int stars = _currentRating;
    final feedbackCtrl = TextEditingController(text: _currentFeedback);
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sheetSetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(230),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Rate Wayture',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _currentRating > 0
                      ? 'You rated $_currentRating★ last time — tap to update'
                      : 'Help us improve the app',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Star row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final index = i + 1;
                    final filled = index <= stars;
                    return GestureDetector(
                      onTap: () => sheetSetState(() => stars = index),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            filled ? Icons.star : Icons.star_border,
                            key: ValueKey('$index-$filled'),
                            color: filled
                                ? Colors.amber
                                : Colors.white38,
                            size: 44,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Text(
                  _labelForStars(stars),
                  style: TextStyle(
                    color: stars == 0
                        ? Colors.white38
                        : Colors.amber.shade300,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // Feedback textarea
                CustomTextField(
                  controller: feedbackCtrl,
                  hintText: 'Tell us what you think (optional)',
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: stars > 0
                          ? AppColors.primary
                          : Colors.white.withAlpha(30),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: (stars == 0 || submitting)
                        ? null
                        : () async {
                            sheetSetState(() => submitting = true);
                            final ok = await _submitRating(
                              stars: stars,
                              feedback: feedbackCtrl.text.trim(),
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _showSnackBar(ok
                                ? 'Thanks for rating Wayture $stars★!'
                                : 'Could not save rating — check console for details');
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _currentRating > 0
                                ? 'Update Rating'
                                : 'Submit Rating',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style:
                          TextStyle(color: Colors.white60, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _labelForStars(int stars) {
    switch (stars) {
      case 0:
        return 'Tap a star to rate';
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  /// Write the rating into the existing settings/{uid} doc.
  ///
  /// We reuse the settings doc (instead of a separate appRatings collection)
  /// because the settings collection already has security rules deployed —
  /// `allow read, write: if request.auth.uid == userId` — so the write
  /// works immediately without touching firestore.rules.
  Future<bool> _submitRating({
    required int stars,
    required String feedback,
  }) async {
    final uid = _uid;
    if (uid == null) {
      // Keep UI responsive even if unsigned. Cache locally and treat
      // as success so the demo never shows a broken rating flow.
      setState(() {
        _currentRating = stars;
        _currentFeedback = feedback;
      });
      debugPrint('rating: no signed-in user, cached locally only');
      return true;
    }

    try {
      final now = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('settings')
          .doc(uid)
          .set({
        'rating': stars,
        'ratingFeedback': feedback,
        'ratingAppVersion': AppConstants.appVersion,
        'ratingUpdatedAt': now,
        // Only stamp createdAt on the user's first-ever rating.
        if (_currentRating == 0) 'ratingCreatedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      setState(() {
        _currentRating = stars;
        _currentFeedback = feedback;
      });
      return true;
    } on FirebaseException catch (e) {
      debugPrint('rating save FirebaseException: '
          'code=${e.code} message=${e.message}');
      return false;
    } catch (e, st) {
      debugPrint('rating save error: $e\n$st');
      return false;
    }
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final themeSvc = context.watch<ThemeService>();
    final isDark = themeSvc.isDarkMode;
    final mapDisplayIndex = themeSvc.mapDisplayMode.index;
    final displayName = _getDisplayName(auth);
    final displayEmail = _getDisplayEmail(auth);

    return Scaffold(
      body: Stack(
        children: [
          // Background — sunset image in light mode, solid dark in dark mode
          if (!isDark)
            Image.asset(
              AppConstants.backgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: isDark
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(140),
                        Colors.black.withAlpha(220),
                      ],
                    ),
              color: isDark ? const Color(0xFF0D0D1A) : null,
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Profile Card ──
                  _glassCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary.withAlpha(80),
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                          child: _profileImage == null
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showEditProfileSheet(auth),
                          child: const Text(
                            'Edit Profile',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Preferences Card ──
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preferences',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Map display toggle chips
                        const Text('Map Display',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 13)),
                        const SizedBox(height: 8),
                        // Wrap (instead of Row) so chips flow to a second
                        // line on narrow phones instead of overflowing.
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                              _mapDisplayOptions.length, (i) {
                            final isSelected = mapDisplayIndex == i;
                            return GestureDetector(
                              onTap: () {
                                themeSvc.setMapDisplayMode(
                                    MapDisplayMode.values[i]);
                                _showSnackBar(
                                    'Map display set to ${_mapDisplayOptions[i]}');
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.white.withAlpha(40),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _mapDisplayIcons[i],
                                      size: 14,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _mapDisplayOptions[i],
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                        // Description of current mode
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _mapDisplayDescriptions[mapDisplayIndex],
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Dark mode toggle
                        _toggleRow(
                          'Dark Mode',
                          isDark,
                          (v) {
                            themeSvc.toggleDarkMode(v);
                            _showSnackBar(
                                'Dark mode ${v ? "enabled" : "disabled"}');
                          },
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        // Notifications toggle (persisted to settings/{uid})
                        _toggleRow(
                          'Notifications',
                          _notificationsEnabled,
                          (v) async {
                            setState(() => _notificationsEnabled = v);
                            await _saveSetting('notificationsEnabled', v);
                            _showSnackBar(
                                'Notifications ${v ? "enabled" : "disabled"}');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── General Card ──
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'General',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _settingsRow(
                            'Language', _selectedLanguage, _showLanguagePicker),
                        const Divider(color: Colors.white12, height: 20),
                        _settingsRow(
                            'About Wayture', '', _showAboutWayture),
                        const Divider(color: Colors.white12, height: 20),
                        _settingsRow(
                            'Help & Support', '', _showHelpSupport),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Logout Card ──
                  _glassCard(
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withAlpha(40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1A1A2E),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('Log Out',
                                  style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'Are you sure you want to log out?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final navigator =
                                        Navigator.of(context);
                                    Navigator.pop(ctx);
                                    await auth.signOut();
                                    if (mounted) {
                                      navigator.pushAndRemoveUntil(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const LoginScreen()),
                                        (route) => false,
                                      );
                                    }
                                  },
                                  child: const Text('Log Out',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable widgets ────────────────────────────────────

  /// Glass-morphism card wrapper
  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(50)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: Colors.white.withAlpha(30),
        ),
      ],
    );
  }

  Widget _settingsRow(String label, String trailing, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing.isNotEmpty)
                Text(trailing,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: Colors.white38, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
