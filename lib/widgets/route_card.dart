import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/route_model.dart';

/// Dark-themed route option card for the route planning bottom sheet.
class RouteCard extends StatelessWidget {
  final RouteModel route;
  final VoidCallback? onNavigate;

  const RouteCard({super.key, required this.route, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final trafficColor = route.trafficLevel.color;
    final congestion = route.trafficLevel.congestionPercent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: route.isRecommended
              ? AppColors.primary
              : const Color(0xFF3A3A4E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route name + recommended badge
          Row(
            children: [
              Expanded(
                child: Text(
                  route.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (route.isRecommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Recommended',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Duration and distance
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '${route.estimatedMinutes} min',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.straighten, color: Colors.white54, size: 16),
              const SizedBox(width: 4),
              Text(
                '${route.distanceKm} km',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Traffic progress bar + navigate button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: congestion / 100),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (_, value, child) => LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white.withAlpha(25),
                          valueColor:
                              AlwaysStoppedAnimation(trafficColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${route.trafficLevel.label} Traffic · $congestion%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: trafficColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onNavigate,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text(
                  'Navigate →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
