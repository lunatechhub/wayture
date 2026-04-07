import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/route_model.dart';
import 'package:wayture/widgets/congestion_breakdown_card.dart';

/// Dark-themed route option card for the route planning bottom sheet.
class RouteCard extends StatelessWidget {
  final RouteModel route;
  final VoidCallback? onNavigate;
  final VoidCallback? onSave;
  final bool isFavorite;
  final String? departureLabel;

  const RouteCard({
    super.key,
    required this.route,
    this.onNavigate,
    this.onSave,
    this.isFavorite = false,
    this.departureLabel,
  });

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
          // Route name + recommended badge + save button
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
              if (route.alertCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Color(0xFFFF9800), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '${route.alertCount}',
                        style: const TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (onSave != null)
                GestureDetector(
                  onTap: onSave,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite
                          ? const Color(0xFFFFC107)
                          : Colors.white38,
                      size: 22,
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

          // Community trust score badge
          if (route.communityTrustPercent > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (route.communityTrustPercent > 80
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFFC107))
                    .withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield,
                    size: 12,
                    color: route.communityTrustPercent > 80
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFFC107),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${route.communityTrustPercent}% trusted',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: route.communityTrustPercent > 80
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFFC107),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

          // Time comparison (when departure time is set)
          if (route.nowEstimatedMinutes != null && departureLabel != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.compare_arrows,
                      color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Now: ${route.nowEstimatedMinutes} min',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 12,
                    color: Colors.white24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'At $departureLabel: ${route.estimatedMinutes} min',
                    style: TextStyle(
                      color: route.estimatedMinutes >
                              (route.nowEstimatedMinutes ?? 0)
                          ? const Color(0xFFF44336)
                          : const Color(0xFF4CAF50),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

          // Expandable congestion breakdown
          if (route.congestionBreakdown != null)
            CongestionBreakdownCard(breakdown: route.congestionBreakdown!),
        ],
      ),
    );
  }
}
