import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';

class NavigationOverlay extends StatefulWidget {
  final String routeName;
  final int etaMinutes;
  final List<String> alternativeRouteNames;
  final void Function(int newIndex, String newName)? onSwitchRoute;
  final VoidCallback? onEndNavigation;

  const NavigationOverlay({
    super.key,
    required this.routeName,
    required this.etaMinutes,
    this.alternativeRouteNames = const [],
    this.onSwitchRoute,
    this.onEndNavigation,
  });

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _alertTimer;
  bool _showAlert = false;
  bool _alertDismissed = false;

  // Pick a random alternative route for the reroute suggestion
  String get _suggestedRoute {
    if (widget.alternativeRouteNames.isEmpty) return 'Via Lazimpat';
    return widget.alternativeRouteNames.first;
  }

  int get _suggestedSaving {
    return 5 + (widget.etaMinutes ~/ 5);
  }

  @override
  void initState() {
    super.initState();
    // Progress bar fills over 30 seconds
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..forward();

    // Show reroute alert after 8 seconds
    _alertTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_alertDismissed) {
        setState(() => _showAlert = true);
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _alertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Top banner
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E).withAlpha(240),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Route name + ETA
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.navigation,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Navigating ${widget.routeName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ETA: ${widget.etaMinutes} min',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress bar
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (_, _) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progressController.value,
                              backgroundColor: Colors.white.withAlpha(20),
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primary),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Journey progress',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 10),
                              ),
                              Text(
                                '${(_progressController.value * 100).round()}%',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Reroute alert (slides up from bottom)
          if (_showAlert && !_alertDismissed)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 100, end: 0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (_, offset, child) => Transform.translate(
                  offset: Offset(0, offset),
                  child: Opacity(
                    opacity: (1 - offset / 100).clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF9800).withAlpha(100),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: Color(0xFFFF9800), size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'New incident ahead!',
                            style: TextStyle(
                              color: Color(0xFFFF9800),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accident reported ahead on your route.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Faster alternative available: $_suggestedRoute — saves $_suggestedSaving min',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                if (mounted) setState(() => _alertDismissed = true);
                                // Find the alternative route index
                                widget.onSwitchRoute?.call(
                                    0, _suggestedRoute);
                              },
                              child: const Text(
                                'Switch Route',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Colors.white24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                if (mounted) setState(() => _alertDismissed = true);
                              },
                              child: const Text(
                                'Stay on Route',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // End Navigation button
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A3E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                onPressed: widget.onEndNavigation,
                icon: const Icon(Icons.close, size: 18),
                label: const Text(
                  'End Navigation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
