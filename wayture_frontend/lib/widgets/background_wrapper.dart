import 'package:flutter/material.dart';
import 'package:wayture/config/constants.dart';

/// Reusable full-screen background image wrapper with gradient overlay.
/// Used on all screens except the map screen.
class BackgroundWrapper extends StatelessWidget {
  final Widget child;

  /// Controls how dark the gradient overlay is.
  /// Use higher values for screens with lots of text.
  final double topOpacity;
  final double bottomOpacity;

  const BackgroundWrapper({
    super.key,
    required this.child,
    this.topOpacity = 0.2,
    this.bottomOpacity = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen background image
          Image.asset(
            AppConstants.backgroundImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          // Dark gradient overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha((topOpacity * 255).round()),
                  Colors.black.withAlpha((bottomOpacity * 255).round()),
                ],
              ),
            ),
          ),
          // Screen content
          child,
        ],
      ),
    );
  }
}
