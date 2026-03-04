import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';

/// Types of incidents users can report
enum IncidentType { accident, trafficJam, roadBlock, protest, construction, weatherIssue }

extension IncidentTypeExtension on IncidentType {
  String get label {
    switch (this) {
      case IncidentType.accident: return 'Accident';
      case IncidentType.trafficJam: return 'Traffic Jam';
      case IncidentType.roadBlock: return 'Road Block';
      case IncidentType.protest: return 'Protest';
      case IncidentType.construction: return 'Construction';
      case IncidentType.weatherIssue: return 'Weather Issue';
    }
  }

  String get emoji {
    switch (this) {
      case IncidentType.accident: return '🚗';
      case IncidentType.trafficJam: return '🚦';
      case IncidentType.roadBlock: return '🚧';
      case IncidentType.protest: return '✊';
      case IncidentType.construction: return '🏗️';
      case IncidentType.weatherIssue: return '🌧️';
    }
  }

  IconData get icon {
    switch (this) {
      case IncidentType.accident: return Icons.car_crash;
      case IncidentType.trafficJam: return Icons.traffic;
      case IncidentType.roadBlock: return Icons.block;
      case IncidentType.protest: return Icons.campaign;
      case IncidentType.construction: return Icons.construction;
      case IncidentType.weatherIssue: return Icons.thunderstorm;
    }
  }

  Color get color {
    switch (this) {
      case IncidentType.accident: return AppColors.trafficRed;
      case IncidentType.trafficJam: return AppColors.trafficYellow;
      case IncidentType.roadBlock: return Colors.orange;
      case IncidentType.protest: return Colors.purple;
      case IncidentType.construction: return Colors.brown;
      case IncidentType.weatherIssue: return Colors.blueGrey;
    }
  }
}

/// A community-reported traffic incident
class ReportModel {
  final String id;
  final IncidentType type;
  final String location;
  final String description;
  final String reporterName;
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  ReportModel({
    required this.id,
    required this.type,
    required this.location,
    required this.description,
    required this.reporterName,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }
}
