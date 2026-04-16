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
import 'package:wayture/screens/profile_screen.dart';
import 'package:wayture/services/auth_service.dart';
import 'package:wayture/services/theme_service.dart';
import 'package:wayture/services/api_service.dart';
import 'package:wayture/services/firestore_service.dart';
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

  // Saved routes count
  int _savedRoutesCount = 0;

  // Aggregated rating summary (fetched from Firestore/backend)
  double _averageRating = 0.0;
  int _totalRatings = 0;
  bool _ratingsLoaded = false;

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
    _loadRatingSummary();
    _loadSavedRoutesCount();
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
          .collection('Settings')
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
          .collection('Users')
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

  /// Load aggregated rating data from Firestore so the settings screen can
  /// show the app's average rating and the user's own rating.
  Future<void> _loadRatingSummary() async {
    try {
      // Fetch from Firestore directly (real-time capable)
      final summary = await FirestoreService.instance.getRatingSummary();
      if (!mounted) return;
      setState(() {
        _averageRating = (summary['average_stars'] as num?)?.toDouble() ?? 0.0;
        _totalRatings = (summary['total_ratings'] as num?)?.toInt() ?? 0;
        _ratingsLoaded = true;
      });

      // Also try fetching the user's own rating from appRatings collection
      final uid = _uid;
      if (uid != null) {
        final myRating = await FirestoreService.instance.getUserRating(uid);
        if (myRating != null && mounted) {
          setState(() {
            _currentRating = (myRating['stars'] as num?)?.toInt() ?? _currentRating;
            _currentFeedback = myRating['feedback'] as String? ?? _currentFeedback;
          });
        }
      }
    } catch (e) {
      debugPrint('loadRatingSummary error: $e');
    }
  }

  /// Load saved routes count from Firestore.
  Future<void> _loadSavedRoutesCount() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final count =
          await FirestoreService.instance.getSavedRoutesCount(uid);
      if (!mounted) return;
      setState(() => _savedRoutesCount = count);
    } catch (e) {
      debugPrint('savedRoutesCount error: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  String _getDisplayName(AuthService auth) =>
      _profileName ?? auth.displayName;

  String _getDisplayEmail(AuthService auth) =>
      _profileEmail ?? auth.displayEmail;

  void _showSnackBar(String message) {
    if (!mounted) return;
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
                  if (mounted) setState(() => _profileImage = null);
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
      if (picked != null && mounted) {
        setState(() => _profileImage = File(picked.path));
        sheetSetState(() {});
        _showSnackBar('Profile photo updated');
      }
    } catch (e) {
      _showSnackBar('Could not access ${source == ImageSource.camera ? "camera" : "gallery"}');
    }
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
        if (mounted) setState(() => _selectedLanguage = language);
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
          .collection('Settings')
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

  static const List<String> _changelogItems = [
    'Real-time traffic congestion prediction',
    'Community incident reporting with upvotes',
    'OSRM route planning with alternates',
    'AI-powered insights via Groq LLaMA',
    'Live weather integration via Open-Meteo',
    'Dark / Light theme support',
  ];

  static const String _privacyPolicyText =
      'Wayture collects location data solely for traffic prediction and '
      'navigation. We do not sell or share your personal data with third '
      'parties. Location data is processed in real-time and is not stored '
      'beyond your active session. Community reports are anonymized before '
      'storage.\n\nFor questions contact: wayture.support@gmail.com';

  static const String _termsOfServiceText =
      'By using Wayture you agree to use the app for lawful purposes only. '
      'Traffic predictions are estimates and should not replace your own '
      'judgment while driving. The app is provided as-is for academic and '
      'personal use.\n\nWayture © 2025 Luna Bhattarai';

  void _showAboutWayture() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section A: Header ──
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFF00897B),
                    child: Text(
                      'W',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Wayture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Version ${AppConstants.appVersion}',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Traffic Congestion Predictor for Kathmandu',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Section B: Powered By ──
                const Text(
                  'POWERED BY',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _PoweredByChip(
                        icon: Icons.map_outlined, label: 'OpenStreetMap'),
                    _PoweredByChip(
                        icon: Icons.alt_route, label: 'OSRM Routing'),
                    _PoweredByChip(
                        icon: Icons.cloud_outlined, label: 'Open-Meteo'),
                    _PoweredByChip(
                        icon: Icons.storage_outlined, label: 'Firebase'),
                    _PoweredByChip(
                        icon: Icons.psychology_outlined, label: 'Groq AI'),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Section C: Built For ──
                const Text(
                  'BUILT FOR',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: const [
                      _InfoRow(
                          icon: Icons.school_outlined,
                          text: 'BSc Final Year Project'),
                      SizedBox(height: 10),
                      _InfoRow(
                          icon: Icons.location_city,
                          text: 'University of Bedfordshire'),
                      SizedBox(height: 10),
                      _InfoRow(
                          icon: Icons.person_outlined,
                          text: 'Student: Luna Bhattarai'),
                      SizedBox(height: 10),
                      _InfoRow(
                          icon: Icons.supervisor_account,
                          text: 'Supervisor: Pawan KC'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Section D: Links ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showPrivacyPolicy();
                        },
                        icon: const Icon(Icons.privacy_tip_outlined,
                            size: 18),
                        label: const Text('Privacy Policy',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showTermsOfService();
                        },
                        icon: const Icon(Icons.article_outlined, size: 18),
                        label: const Text('Terms of Service',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Section E: What's New ──
                Text(
                  "WHAT'S NEW IN V${AppConstants.appVersion}",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _changelogItems.length; i++) ...[
                        _ChangelogRow(text: _changelogItems[i]),
                        if (i < _changelogItems.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Section F: Share & Footer ──
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Sharing coming soon!'),
                          ),
                        );
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text(
                      'Share Wayture',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '© 2025 Wayture · Luna Bhattarai · University of Bedfordshire',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white),
        ),
        content: const SingleChildScrollView(
          child: Text(
            _privacyPolicyText,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFF00897B))),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Terms of Service',
          style: TextStyle(color: Colors.white),
        ),
        content: const SingleChildScrollView(
          child: Text(
            _termsOfServiceText,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: Color(0xFF00897B))),
          ),
        ],
      ),
    );
  }

  void _showWhatsNew() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              "What's New in v${AppConstants.appVersion}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < _changelogItems.length; i++) ...[
                    _ChangelogRow(text: _changelogItems[i]),
                    if (i < _changelogItems.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
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

  void _showBugReport() async {
    final bugCtrl = TextEditingController();
    bool submitting = false;

    try {
    await showModalBottomSheet(
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
    } finally {
      bugCtrl.dispose();
    }
  }

  // ── Contact Support ─────────────────────────────────────

  void _showContactSupport() {
    const supportEmail = 'support@wayture.com';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email_outlined, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Contact Support',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: supportEmail));
                  if (!mounted) return;
                  Navigator.pop(context);
                  _showSnackBar('Email copied to clipboard');
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Email'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ── Rate the App ────────────────────────────────────────

  void _showRatingSheet() async {
    int stars = _currentRating;
    final feedbackCtrl = TextEditingController(text: _currentFeedback);
    bool submitting = false;

    try {
    await showModalBottomSheet(
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
                            final error = await _submitRating(
                              stars: stars,
                              feedback: feedbackCtrl.text.trim(),
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _showSnackBar(error ??
                                'Thanks for rating Wayture $stars★!');
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
    } finally {
      feedbackCtrl.dispose();
    }
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

  /// Persist the rating to Firestore + backend.
  /// Returns null on success, or an error message on failure.
  Future<String?> _submitRating({
    required int stars,
    required String feedback,
  }) async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _currentRating = stars;
          _currentFeedback = feedback;
        });
      }
      return null; // cached locally, not an error
    }

    try {
      final now = FieldValue.serverTimestamp();

      // 1. Write to appRatings/{uid} (main ratings collection)
      await FirebaseFirestore.instance
          .collection('appRatings')
          .doc(uid)
          .set({
        'uid': uid,
        'stars': stars,
        'feedback': feedback,
        'app_version': AppConstants.appVersion,
        'updated_at': now,
        if (_currentRating == 0) 'created_at': now,
      }, SetOptions(merge: true));

      // 2. Write to settings/{uid} (backup for settings screen)
      await FirebaseFirestore.instance
          .collection('Settings')
          .doc(uid)
          .set({
        'rating': stars,
        'ratingFeedback': feedback,
        'updatedAt': now,
      }, SetOptions(merge: true));

      // 3. Backend API (best-effort, don't block on failure)
      ApiService.submitRating(stars: stars, feedback: feedback).catchError((e) {
        debugPrint('rating backend submit error: $e');
        return false;
      });

      if (!mounted) return null;
      setState(() {
        _currentRating = stars;
        _currentFeedback = feedback;
      });

      _loadRatingSummary();
      return null; // success
    } on FirebaseException catch (e) {
      debugPrint('rating FirebaseException: code=${e.code} message=${e.message}');
      return 'Firestore error: ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('rating error: $e');
      return 'Error: $e';
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
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.bookmark,
                                      color: AppColors.primary, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_savedRoutesCount saved route${_savedRoutesCount == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen()),
                          ),
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
                            if (mounted) setState(() => _notificationsEnabled = v);
                            await _saveSetting('notificationsEnabled', v);
                            _showSnackBar(
                                'Notifications ${v ? "enabled" : "disabled"}');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Rating Card (visible on settings main screen) ──
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'App Rating',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_ratingsLoaded && _totalRatings > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_totalRatings review${_totalRatings == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: Colors.amber.shade300,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Average rating row
                        if (_ratingsLoaded && _totalRatings > 0) ...[
                          Row(
                            children: [
                              Text(
                                _averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Star row for average
                              Row(
                                children: List.generate(5, (i) {
                                  final starVal = i + 1;
                                  if (starVal <= _averageRating.floor()) {
                                    return const Icon(Icons.star,
                                        color: Colors.amber, size: 20);
                                  } else if (starVal - _averageRating < 1) {
                                    return const Icon(Icons.star_half,
                                        color: Colors.amber, size: 20);
                                  } else {
                                    return const Icon(Icons.star_border,
                                        color: Colors.white24, size: 20);
                                  }
                                }),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'avg',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],

                        // User's own rating
                        Row(
                          children: [
                            const Text('Your rating: ',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 13)),
                            if (_currentRating > 0)
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < _currentRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: i < _currentRating
                                        ? Colors.amber
                                        : Colors.white24,
                                    size: 18,
                                  ),
                                ),
                              )
                            else
                              const Text('Not rated yet',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 13)),
                            const Spacer(),
                            GestureDetector(
                              onTap: _showRatingSheet,
                              child: Text(
                                _currentRating > 0
                                    ? 'Update'
                                    : 'Rate Now',
                                style: const TextStyle(
                                    color: AppColors.primary, fontSize: 13),
                              ),
                            ),
                          ],
                        ),

                        if (_currentRating > 0 &&
                            _currentFeedback.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '"$_currentFeedback"',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
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
                        _iconSettingsRow(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy Policy',
                          onTap: _showPrivacyPolicy,
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        _iconSettingsRow(
                          icon: Icons.new_releases_outlined,
                          label: "What's New",
                          onTap: _showWhatsNew,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'v${AppConstants.appVersion}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
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
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                              content: const Row(children: [
                                Icon(Icons.logout_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 10),
                                Text('Log out of Wayture?',
                                    style: TextStyle(color: Colors.white)),
                              ]),
                              backgroundColor: const Color(0xFF1A1A2E),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 4),
                              action: SnackBarAction(
                                label: 'LOG OUT',
                                textColor: Colors.redAccent,
                                onPressed: () async {
                                  final rootNav = Navigator.of(
                                      context, rootNavigator: true);
                                  await auth.signOut();
                                  rootNav.pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const LoginScreen()),
                                    (route) => false,
                                  );
                                },
                              ),
                            ));
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

  Widget _iconSettingsRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (trailing != null) ...[
            trailing,
            const SizedBox(width: 4),
          ],
          const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
        ],
      ),
    );
  }
}

class _PoweredByChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PoweredByChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 14, color: Colors.white70),
      label: Text(label),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
      backgroundColor: Colors.white.withAlpha(20),
      side: const BorderSide(color: Colors.white24),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00897B), size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ChangelogRow extends StatelessWidget {
  final String text;

  const _ChangelogRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(
            Icons.fiber_manual_record,
            size: 8,
            color: Color(0xFF00897B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
