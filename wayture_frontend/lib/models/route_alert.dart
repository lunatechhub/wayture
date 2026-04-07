import 'package:flutter/material.dart';

enum AlertSeverity { info, warning, critical }

extension AlertSeverityExtension on AlertSeverity {
  String get label {
    switch (this) {
      case AlertSeverity.info:
        return 'Info';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverity.info:
        return const Color(0xFF2196F3);
      case AlertSeverity.warning:
        return const Color(0xFFFF9800);
      case AlertSeverity.critical:
        return const Color(0xFFF44336);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertSeverity.info:
        return Icons.info_outline;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.critical:
        return Icons.error_outline;
    }
  }
}

class RouteAlert {
  final String id;
  final int routeIndex;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final bool isActive;

  const RouteAlert({
    required this.id,
    required this.routeIndex,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.isActive = true,
  });

  RouteAlert copyWith({bool? isActive}) {
    return RouteAlert(
      id: id,
      routeIndex: routeIndex,
      message: message,
      severity: severity,
      timestamp: timestamp,
      isActive: isActive ?? this.isActive,
    );
  }
}
