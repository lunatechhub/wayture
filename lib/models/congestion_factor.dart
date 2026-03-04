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

  String get emoji {
    switch (this) {
      case CongestionFactor.speed:
        return '🚗';
      case CongestionFactor.incidents:
        return '⚠️';
      case CongestionFactor.weather:
        return '🌧️';
      case CongestionFactor.peakHour:
        return '⏰';
      case CongestionFactor.hotspot:
        return '🔥';
    }
  }
}

class CongestionBreakdown {
  final Map<CongestionFactor, double> factors;

  const CongestionBreakdown(this.factors);

  double get overall {
    if (factors.isEmpty) return 0;
    return factors.values.reduce((a, b) => a + b) / factors.length;
  }

  Color colorForValue(double value) {
    if (value < 0.4) return const Color(0xFF4CAF50);
    if (value < 0.7) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }
}
