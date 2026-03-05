import 'package:flutter/material.dart';

enum CongestionFactor { speed, incidents, weather, peakHour, hotspot }

extension CongestionFactorExtension on CongestionFactor {
  String get label {
    switch (this) {
      case CongestionFactor.speed:
        return 'Speed';
      case CongestionFactor.incidents:
        return 'Incidents';
      case CongestionFactor.weather:
        return 'Weather';
      case CongestionFactor.peakHour:
        return 'Peak Hour';
      case CongestionFactor.hotspot:
        return 'Hotspot';
    }
  }

  IconData get icon {
    switch (this) {
      case CongestionFactor.speed:
        return Icons.speed;
      case CongestionFactor.incidents:
        return Icons.warning_amber_rounded;
      case CongestionFactor.weather:
        return Icons.cloud;
      case CongestionFactor.peakHour:
        return Icons.access_time_filled;
      case CongestionFactor.hotspot:
        return Icons.local_fire_department;
    }
  }

  int get maxScore {
    switch (this) {
      case CongestionFactor.speed:
        return 40;
      case CongestionFactor.incidents:
        return 30;
      case CongestionFactor.weather:
        return 20;
      case CongestionFactor.peakHour:
        return 15;
      case CongestionFactor.hotspot:
        return 12;
    }
  }
}

class FactorInsight {
  final bool isPositive;
  final String text;

  const FactorInsight({required this.isPositive, required this.text});
}

class CongestionBreakdown {
  final Map<CongestionFactor, int> scores;
  final List<FactorInsight> insights;

  const CongestionBreakdown({
    required this.scores,
    this.insights = const [],
  });

  int get totalScore => scores.values.fold(0, (a, b) => a + b);

  String get classification {
    if (totalScore < 25) return 'Low';
    if (totalScore < 50) return 'Moderate';
    return 'Heavy';
  }

  Color get classificationColor {
    if (totalScore < 25) return const Color(0xFF4CAF50);
    if (totalScore < 50) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }

  Color colorForFactor(CongestionFactor factor) {
    final score = scores[factor] ?? 0;
    final max = factor.maxScore;
    if (max == 0) return const Color(0xFF4CAF50);
    final ratio = score / max;
    if (ratio < 0.25) return const Color(0xFF4CAF50);
    if (ratio < 0.65) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }
}
