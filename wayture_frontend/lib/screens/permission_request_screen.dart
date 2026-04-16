import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/core/app_routes.dart';

/// Key stored in SharedPreferences so this screen only shows once.
const String _kPermissionsShown = 'permissions_shown';

/// Check whether the onboarding permission screen has been seen before.
Future<bool> hasSeenPermissions() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kPermissionsShown) ?? false;
}

/// Permission screen — dark glassmorphism style matching the login screen.
/// Shown only once on first app launch, before the login screen.
class PermissionRequestScreen extends StatefulWidget {
  const PermissionRequestScreen({super.key});

  @override
  State<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _isRequesting = false;
  bool _whyExpanded = false;

  static const _items = [
    _PermItem(
      icon: Icons.location_on_rounded,
      emoji: '📍',
      title: 'Location Access',
      desc: 'To show live traffic and suggest the best routes near you',
    ),
    _PermItem(
      icon: Icons.notifications_active_rounded,
      emoji: '🔔',
      title: 'Notifications',
      desc: 'To alert you about congestion before you reach it',
    ),
    _PermItem(
      icon: Icons.map_rounded,
      emoji: '🗺️',
      title: 'Background Location',
      desc: 'To monitor your route even when the app is minimised',
    ),
  ];

  Future<void> _markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPermissionsShown, true);
  }

  Future<void> _allowAndContinue() async {
    if (_isRequesting) return;
    if (mounted) setState(() => _isRequesting = true);

    bool anyGranted = false;
    try {
      final loc = await Permission.locationWhenInUse.request();
      if (loc.isGranted) anyGranted = true;

      final notif = await Permission.notification.request();
      if (notif.isGranted) anyGranted = true;

      if (loc.isGranted) {
        final bg = await Permission.locationAlways.request();
        if (bg.isGranted) anyGranted = true;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isRequesting = false);

    await _markShown();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (anyGranted) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Permissions Enabled — You will now receive live Kathmandu traffic alerts',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ]),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
    } else {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Location access is needed for the best experience. You can enable it later from settings.',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ]),
          backgroundColor: const Color(0xFFFB8C00),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
    }

    _goToLogin();
  }

  Future<void> _skip() async {
    await _markShown();
    if (!mounted) return;
    _goToLogin();
  }

  void _goToLogin() {
    // If the user is already signed in (came from signup), go to home.
    final destination = FirebaseAuth.instance.currentUser != null
        ? AppRoutes.home
        : AppRoutes.login;
    Navigator.of(context).pushReplacementNamed(destination);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 640;
    final isWide = size.width > 600;
    final hPad = isWide ? size.width * 0.15 : 24.0;
    final maxW = isWide ? 480.0 : double.infinity;

    return Scaffold(
      body: Stack(
        children: [
          // Background image — same as login
          Image.asset(
            AppConstants.backgroundImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          // Gradient overlay — same as login
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(51),
                  Colors.black.withAlpha(204),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: isSmall ? 16 : 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Column(
                    children: [
                      SizedBox(height: isSmall ? 8 : 20),

                      // Animated map pin icon
                      const _AnimatedMapPin(),

                      SizedBox(height: isSmall ? 16 : 28),

                      // Title
                      Text(
                        'Stay Ahead of\nTraffic',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 26 : 32,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      const Text(
                        'Allow Wayture to access your location and send you real-time traffic alerts for Kathmandu Valley',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),

                      SizedBox(height: isSmall ? 20 : 28),

                      // Glassmorphism card with permission rows
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < _items.length; i++) ...[
                              _buildPermRow(_items[i]),
                              if (i < _items.length - 1)
                                Divider(
                                  color: Colors.white.withAlpha(30),
                                  height: 20,
                                ),
                            ],

                            // "Why we need this" expandable
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                if (mounted) {
                                  setState(
                                      () => _whyExpanded = !_whyExpanded);
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Why we need this',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: _whyExpanded ? 0.5 : 0,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              child: _whyExpanded
                                  ? const Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(4, 10, 4, 4),
                                      child: Text(
                                        'Wayture uses your location to show real-time traffic around you and calculate the fastest routes across Kathmandu. '
                                        'Notifications let us warn you before you hit congestion. Background location keeps monitoring your route when you switch apps. '
                                        'Your data is never shared with third parties.',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    )
                                  : const SizedBox(width: double.infinity),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isSmall ? 20 : 28),

                      // Allow button — matches login button style
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isRequesting ? null : _allowAndContinue,
                          child: _isRequesting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            Colors.black),
                                  ),
                                )
                              : const Text(
                                  'Allow and Continue',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Skip link
                      TextButton(
                        onPressed: _isRequesting ? null : _skip,
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      SizedBox(height: isSmall ? 8 : 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermRow(_PermItem item) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(item.emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.desc,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Data model ──────────────────────────────────────────────────────────────

class _PermItem {
  final IconData icon;
  final String emoji;
  final String title;
  final String desc;
  const _PermItem({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.desc,
  });
}

// ── Animated map pin header ─────────────────────────────────────────────────

class _AnimatedMapPin extends StatefulWidget {
  const _AnimatedMapPin();

  @override
  State<_AnimatedMapPin> createState() => _AnimatedMapPinState();
}

class _AnimatedMapPinState extends State<_AnimatedMapPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final bounce = math.sin(_c.value * math.pi) * 8;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, -bounce),
              child: child,
            ),
            const SizedBox(height: 4),
            // Shadow that scales with bounce
            Container(
              width: 24 - bounce,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((20 + bounce * 2).toInt()),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        );
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(40), width: 2),
        ),
        child: const Icon(
          Icons.navigation_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}
