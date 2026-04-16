import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wayture/models/notification_model.dart';
import 'package:wayture/models/report_model.dart';

/// Single file that handles ALL backend communication.
/// Base URL points to FastAPI server (port 8000).
/// Every method returns data on success or null on failure,
/// allowing callers to fall back to mock data.
class ApiService {
  // 10.0.2.2 for Android emulator, localhost for web/desktop
  static String get _baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static const _timeout = Duration(seconds: 10);

  // Firebase auth token — kept for backward compatibility (manual override).
  static String? _authToken;
  static void setAuthToken(String token) => _authToken = token;

  /// Builds the request headers for every authenticated backend call.
  /// Always tries to fetch a fresh Firebase ID token from FirebaseAuth so
  /// the backend's `Depends(get_current_uid)` succeeds.
  static Future<Map<String, String>> _buildHeaders() async {
    String? token;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        token = await user.getIdToken();
      }
    } catch (e) {
      debugPrint('getIdToken error: $e');
    }
    // Fallback to a manually-set token (legacy callers / tests).
    token ??= _authToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

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

  // ── Congestion Prediction (main endpoint) ──

  static Future<Map<String, dynamic>?> predictCongestion({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
    double? userSpeed,
  }) async {
    try {
      final body = <String, dynamic>{
        'user_lat': userLat,
        'user_lng': userLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
        // ignore: use_null_aware_elements
        if (userSpeed != null) 'user_speed': userSpeed,
      };
      final response = await http
          .post(
            Uri.parse('$_baseUrl/prediction/predict-congestion'),
            headers: await _buildHeaders(),
            body: json.encode(body),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('predictCongestion error: $e');
    }
    return null;
  }

  // ── Traffic Status (for map point) ──

  static Future<Map<String, dynamic>?> getTrafficStatus({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/prediction/traffic-status/$lat/$lng'),
            headers: await _buildHeaders(),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('getTrafficStatus error: $e');
    }
    return null;
  }

  // ── Geocoding (Nominatim via backend) ──

  static Future<List<Map<String, dynamic>>?> geocodePlace(String query) async {
    try {
      final response = await http
          .get(Uri.parse(
              '$_baseUrl/geocode?q=${Uri.encodeComponent(query)}&limit=5'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('geocodePlace error: $e');
    }
    return null;
  }

  // ── Routes (OSRM via backend) ──

  static Future<Map<String, dynamic>?> getRoutes({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    // Uses the predict-congestion endpoint which includes routes
    return predictCongestion(
      userLat: startLat,
      userLng: startLng,
      destLat: endLat,
      destLng: endLng,
    );
  }

  // ── Weather (Open-Meteo via backend, embedded in prediction) ──

  static Future<Map<String, dynamic>?> getWeather({
    double lat = 27.7172,
    double lng = 85.3240,
  }) async {
    // Weather is included in traffic-status response
    final status = await getTrafficStatus(lat: lat, lng: lng);
    if (status != null) {
      return {
        'weather_factor': status['weather_factor'],
        'is_raining': status['weather_factor'] != 'clear',
      };
    }
    return null;
  }

  // ── Reports ──

  static Future<List<ReportModel>?> getReports({
    double latitude = 27.7172,
    double longitude = 85.3240,
    double radiusKm = 5.0,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/reports/nearby?latitude=$latitude&longitude=$longitude&radius_km=$radiusKm',
            ),
            headers: await _buildHeaders(),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        return list.map((r) => _parseReport(r)).toList();
      }
    } catch (e) {
      debugPrint('getReports error: $e');
    }
    return null;
  }

  static Future<bool> submitReport({
    required String type,
    String description = '',
    double latitude = 27.7172,
    double longitude = 85.3240,
    String location = '',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/reports/'),
            headers: await _buildHeaders(),
            body: json.encode({
              'latitude': latitude,
              'longitude': longitude,
              'report_type': type,
              'description': description,
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Notifications ──

  static Future<List<NotificationModel>?> getNotifications() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/notifications/unread'),
            headers: await _buildHeaders(),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        return list.map((n) => _parseNotification(n)).toList();
      }
    } catch (e) {
      debugPrint('getNotifications error: $e');
    }
    return null;
  }

  static Future<bool> markNotificationRead(String id) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/notifications/mark-read'),
            headers: await _buildHeaders(),
            body: json.encode({
              'notification_ids': [id]
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> markAllNotificationsRead() async {
    // Fetch unread first, then mark all
    final notifications = await getNotifications();
    if (notifications == null || notifications.isEmpty) return true;
    final ids = notifications.map((n) => n.id).toList();
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/notifications/mark-read'),
            headers: await _buildHeaders(),
            body: json.encode({'notification_ids': ids}),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Traffic Data (new endpoints) ──

  /// Fetch all traffic data from Firestore via backend.
  static Future<List<Map<String, dynamic>>?> getAllTraffic({int limit = 500}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/traffic?limit=$limit'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('getAllTraffic error: $e');
    }
    return null;
  }

  /// Fetch traffic data for a specific location.
  static Future<List<Map<String, dynamic>>?> getTrafficByLocation(String location) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/traffic/${Uri.encodeComponent(location)}'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('getTrafficByLocation error: $e');
    }
    return null;
  }

  /// Upload a single traffic observation.
  static Future<bool> uploadTraffic(Map<String, dynamic> data) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/traffic'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('uploadTraffic error: $e');
    }
    return false;
  }

  /// Send a real-time traffic update.
  static Future<bool> sendRealtimeUpdate(Map<String, dynamic> data) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/realtime-update'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('sendRealtimeUpdate error: $e');
    }
    return false;
  }

  /// Get Google Maps route with traffic info.
  static Future<Map<String, dynamic>?> getGoogleRoute({
    required String origin,
    required String destination,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(
            '$_baseUrl/route?origin=${Uri.encodeComponent(origin)}'
            '&destination=${Uri.encodeComponent(destination)}',
          ))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('getGoogleRoute error: $e');
    }
    return null;
  }

  /// Get ML traffic prediction for a location.
  static Future<Map<String, dynamic>?> getTrafficPrediction({
    required String location,
    double latitude = 27.7172,
    double longitude = 85.3240,
    int? hour,
    String? dayOfWeek,
  }) async {
    try {
      final params = <String, String>{
        'location': location,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      };
      if (hour != null) params['hour'] = hour.toString();
      if (dayOfWeek != null) params['day_of_week'] = dayOfWeek;

      final uri = Uri.parse('$_baseUrl/predict').replace(queryParameters: params);
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('getTrafficPrediction error: $e');
    }
    return null;
  }

  /// Get real-time traffic snapshots for all locations.
  static Future<List<Map<String, dynamic>>?> getRealtimeTraffic() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/realtime'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('getRealtimeTraffic error: $e');
    }
    return null;
  }

  // ── Ratings ──

  /// Submit or update the current user's app rating via backend.
  static Future<bool> submitRating({
    required int stars,
    String feedback = '',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ratings/submit'),
            headers: await _buildHeaders(),
            body: json.encode({
              'stars': stars,
              'feedback': feedback,
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('submitRating error: $e');
    }
    return false;
  }

  /// Fetch the current user's own rating.
  static Future<Map<String, dynamic>?> getMyRating() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ratings/my-rating'),
            headers: await _buildHeaders(),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = response.body;
        if (body == 'null' || body.isEmpty) return null;
        return json.decode(body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('getMyRating error: $e');
    }
    return null;
  }

  /// Fetch all ratings from all users.
  static Future<List<Map<String, dynamic>>?> getAllRatings() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/ratings/all'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('getAllRatings error: $e');
    }
    return null;
  }

  /// Fetch aggregated rating summary (average, distribution, count).
  static Future<Map<String, dynamic>?> getRatingSummary() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/ratings/summary'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('getRatingSummary error: $e');
    }
    return null;
  }

  // ── Events (local — no backend endpoint yet) ──

  static Future<List<Map<String, dynamic>>?> getEvents() async {
    return null; // Falls back to mock data
  }

  // ── Settings ──

  static Future<Map<String, dynamic>?> getSettings() async {
    return null; // Falls back to local prefs
  }

  static Future<bool> updateSettings(Map<String, dynamic> settings) async {
    return false; // Local prefs for now
  }

  // ── Legacy compatibility methods ──

  static Future<List<Map<String, dynamic>>?> findRoutes({
    required String from,
    required String to,
    int? departureHour,
    int? departureMinute,
  }) async {
    // Geocode both places, then get routes
    final fromResults = await geocodePlace(from);
    final toResults = await geocodePlace(to);
    if (fromResults == null ||
        fromResults.isEmpty ||
        toResults == null ||
        toResults.isEmpty) {
      return null;
    }

    final result = await predictCongestion(
      userLat: fromResults[0]['latitude'],
      userLng: fromResults[0]['longitude'],
      destLat: toResults[0]['latitude'],
      destLng: toResults[0]['longitude'],
    );
    if (result == null) return null;

    final routes = <Map<String, dynamic>>[];
    if (result['main_route'] != null) {
      routes.add(result['main_route']);
    }
    for (final alt in (result['alternate_routes'] as List? ?? [])) {
      routes.add(alt);
    }
    return routes.isEmpty ? null : routes;
  }

  // ── Parsers ──

  static ReportModel _parseReport(Map<String, dynamic> r) {
    return ReportModel(
      id: r['id'] ?? '',
      type: _parseIncidentType(r['report_type'] ?? r['type']),
      location: r['description'] ?? '',
      description: r['description'] ?? '',
      reporterName: r['reporter_name'] ?? 'Anonymous',
      timestamp: DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now(),
      latitude: (r['latitude'] as num?)?.toDouble() ?? 27.7172,
      longitude: (r['longitude'] as num?)?.toDouble() ?? 85.3240,
      upvotes: (r['upvotes'] as num?)?.toInt() ?? 0,
    );
  }

  static IncidentType _parseIncidentType(String? type) {
    switch (type) {
      case 'accident':
        return IncidentType.accident;
      case 'traffic_jam':
      case 'trafficJam':
        return IncidentType.trafficJam;
      case 'road_closure':
      case 'roadBlock':
        return IncidentType.roadBlock;
      case 'protest':
        return IncidentType.protest;
      case 'construction':
        return IncidentType.construction;
      case 'flooding':
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
      message: n['body'] ?? n['message'] ?? '',
      timestamp: DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now(),
      isRead: n['read'] ?? false,
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
