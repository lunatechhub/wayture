import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';

enum NotificationType { trafficAlert, weatherWarning, communityReport, routeUpdate }

extension NotificationTypeExtension on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.trafficAlert: return 'Traffic Alert';
      case NotificationType.weatherWarning: return 'Weather Warning';
      case NotificationType.communityReport: return 'Community Report';
      case NotificationType.routeUpdate: return 'Route Update';
    }
  }

  String get emoji {
    switch (this) {
      case NotificationType.trafficAlert: return '🚦';
      case NotificationType.weatherWarning: return '🌤️';
      case NotificationType.communityReport: return '👥';
      case NotificationType.routeUpdate: return '🗺️';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.trafficAlert: return Icons.traffic;
      case NotificationType.weatherWarning: return Icons.cloud;
      case NotificationType.communityReport: return Icons.people;
      case NotificationType.routeUpdate: return Icons.route;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.trafficAlert: return AppColors.trafficRed;
      case NotificationType.weatherWarning: return Colors.blueGrey;
      case NotificationType.communityReport: return AppColors.primary;
      case NotificationType.routeUpdate: return AppColors.accent;
    }
  }
}

/// An in-app notification
class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }
}
