import 'package:flutter/material.dart';
import 'package:wayture/models/route_model.dart';

/// Route option card used in the route planning bottom sheet.
class RouteCard extends StatelessWidget {
  final RouteModel route;
  final VoidCallback? onNavigate;

  const RouteCard({super.key, required this.route, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: route.isRecommended
            ? Border.all(color: route.trafficLevel.color, width: 2)
            : null,
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
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF212121),
                  ),
                ),
              ),
              if (route.isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: route.trafficLevel.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Recommended',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: route.trafficLevel.color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            route.description,
            style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              _stat('${route.estimatedMinutes} min'),
              const SizedBox(width: 16),
              _stat('${route.distanceKm} km'),
              const SizedBox(width: 16),
              // Traffic dot + label
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: route.trafficLevel.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${route.trafficLevel.label} Traffic',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: route.trafficLevel.color,
                ),
              ),
              const Spacer(),
              // Navigate button
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: onNavigate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Navigate',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF757575),
      ),
    );
  }
}
