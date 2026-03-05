import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wayture/models/notification_model.dart';
import 'package:wayture/models/report_model.dart';

/// Single file that handles ALL backend communication.
/// Every method returns data on success or null on failure,
/// allowing callers to fall back to mock data.
class ApiService {
  // Use 10.0.2.2 for Android emulator, localhost for others
  static String get _baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static const _timeout = Duration(seconds: 5);

  // ── Health Check ──

  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Weather ──

  static Future<Map<String, dynamic>?> getWeather() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/weather'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Reports ──

  static Future<List<ReportModel>?> getReports() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/reports'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['reports'] as List;
        return list.map((r) => _parseReport(r)).toList();
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> submitReport({
    required String type,
    required String location,
    required String description,
    double latitude = 27.7172,
    double longitude = 85.3240,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/reports'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'type': type,
              'location': location,
              'description': description,
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ── Notifications ──

  static Future<List<NotificationModel>?> getNotifications() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/notifications'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['notifications'] as List;
        return list.map((n) => _parseNotification(n)).toList();
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> markAllNotificationsRead() async {
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/notifications/read-all'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> markNotificationRead(String id) async {
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/notifications/$id/read'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Routes ──

  static Future<List<Map<String, dynamic>>?> findRoutes({
    required String from,
    required String to,
    int? departureHour,
    int? departureMinute,
  }) async {
    try {
      final body = <String, dynamic>{
        'from': from,
        'to': to,
      };
      if (departureHour != null) {
        body['departureHour'] = departureHour;
        body['departureMinute'] = departureMinute ?? 0;
      }
      final response = await http
          .post(
            Uri.parse('$_baseUrl/routes'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['routes']);
      }
    } catch (_) {}
    return null;
  }

  // ── Events ──

  static Future<List<Map<String, dynamic>>?> getEvents() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/events'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['events']);
      }
    } catch (_) {}
    return null;
  }

  // ── Settings ──

  static Future<Map<String, dynamic>?> getSettings() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/settings'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/settings'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(settings),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Parsers ──

  static ReportModel _parseReport(Map<String, dynamic> r) {
    return ReportModel(
      id: r['id'] ?? '',
      type: _parseIncidentType(r['type']),
      location: r['location'] ?? '',
      description: r['description'] ?? '',
      reporterName: r['reporterName'] ?? 'Anonymous',
      timestamp: DateTime.tryParse(r['timestamp'] ?? '') ?? DateTime.now(),
      latitude: (r['latitude'] as num?)?.toDouble() ?? 27.7172,
      longitude: (r['longitude'] as num?)?.toDouble() ?? 85.3240,
    );
  }

  static IncidentType _parseIncidentType(String? type) {
    switch (type) {
      case 'accident':
        return IncidentType.accident;
      case 'trafficJam':
        return IncidentType.trafficJam;
      case 'roadBlock':
        return IncidentType.roadBlock;
      case 'protest':
        return IncidentType.protest;
      case 'construction':
        return IncidentType.construction;
      case 'weatherIssue':
        return IncidentType.weatherIssue;
      default:
        return IncidentType.accident;
    }
  }

  static NotificationModel _parseNotification(Map<String, dynamic> n) {
    return NotificationModel(
      id: n['id'] ?? '',
      type: _parseNotificationType(n['type']),
      title: n['title'] ?? '',
      message: n['message'] ?? '',
      timestamp: DateTime.tryParse(n['timestamp'] ?? '') ?? DateTime.now(),
      isRead: n['isRead'] ?? false,
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'trafficAlert':
        return NotificationType.trafficAlert;
      case 'weatherWarning':
        return NotificationType.weatherWarning;
      case 'communityReport':
        return NotificationType.communityReport;
      case 'routeUpdate':
        return NotificationType.routeUpdate;
      default:
        return NotificationType.trafficAlert;
    }
  }
}
