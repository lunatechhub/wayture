import 'package:flutter/material.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/core/app_routes.dart';
import 'package:wayture/screens/permission_request_screen.dart';

/// Splash / Welcome screen — full background image with "Get Started" button.
/// On first launch, navigates to the permission screen.
/// On subsequent launches, goes straight to login.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<void> _onGetStarted(BuildContext context) async {
    final seen = await hasSeenPermissions();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(
      context,
      seen ? AppRoutes.login : AppRoutes.permissions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Image.asset(
            AppConstants.backgroundImage,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(77),
                  Colors.black.withAlpha(204),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  const Text(
                    'Welcome to\nWayture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Explore analytics\nwith confidence',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _onGetStarted(context),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
