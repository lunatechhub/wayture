import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';

/// Small floating traffic legend card for the map screen.
class TrafficLegend extends StatelessWidget {
  const TrafficLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(140),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Traffic',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _legendRow(AppColors.trafficGreen, 'Clear'),
              const SizedBox(height: 4),
              _legendRow(AppColors.trafficYellow, 'Moderate'),
              const SizedBox(height: 4),
              _legendRow(AppColors.trafficRed, 'Heavy'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20, height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
