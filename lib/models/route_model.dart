import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/congestion_factor.dart';

enum TrafficLevel { light, moderate, heavy }

extension TrafficLevelExtension on TrafficLevel {
  String get label {
    switch (this) {
      case TrafficLevel.light: return 'Light';
      case TrafficLevel.moderate: return 'Moderate';
      case TrafficLevel.heavy: return 'Heavy';
    }
  }

  Color get color {
    switch (this) {
      case TrafficLevel.light: return AppColors.trafficGreen;
      case TrafficLevel.moderate: return AppColors.trafficYellow;
      case TrafficLevel.heavy: return AppColors.trafficRed;
    }
  }

  int get congestionPercent {
    switch (this) {
      case TrafficLevel.light: return 15;
      case TrafficLevel.moderate: return 42;
      case TrafficLevel.heavy: return 68;
    }
  }
}

/// A route option between two points
class RouteModel {
  final String id;
  final String name;
  final String description;
  final int estimatedMinutes;
  final double distanceKm;
  final TrafficLevel trafficLevel;
  final bool isRecommended;
  final CongestionBreakdown? congestionBreakdown;
  final int communityTrustPercent;
  final int alertCount;

  final int? nowEstimatedMinutes;

  RouteModel({
    required this.id,
    required this.name,
    required this.description,
    required this.estimatedMinutes,
    required this.distanceKm,
    required this.trafficLevel,
    this.isRecommended = false,
    this.congestionBreakdown,
    this.communityTrustPercent = 0,
    this.alertCount = 0,
    this.nowEstimatedMinutes,
  });
}
