import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// A single colored route returned by GET /api/simple/find-routes.
///
/// Holds everything the Find Routes screen needs to draw one polyline
/// on flutter_map and show an info card underneath the map.
class SimpleRoute {
  final int index;              // 0 = fastest, 1 = alt 1, 2 = alt 2
  final String label;           // User-friendly name, e.g. "Fastest route"
  final double distanceKm;      // Total length in kilometres
  final double durationMinutes; // Estimated travel time in minutes
  final String congestion;      // "low" | "medium" | "high"
  final Color color;            // Polyline color derived from congestion
  final List<LatLng> points;    // Ordered path — feed straight into Polyline

  SimpleRoute({
    required this.index,
    required this.label,
    required this.distanceKm,
    required this.durationMinutes,
    required this.congestion,
    required this.color,
    required this.points,
  });

  /// Parse one route object from the backend JSON payload.
  factory SimpleRoute.fromJson(Map<String, dynamic> json) {
    // Backend sends points as [[lat, lng], [lat, lng], ...] — convert to LatLng.
    final rawPoints = (json['points'] as List?) ?? [];
    final points = rawPoints
        .map((p) => LatLng(
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ))
        .toList();

    return SimpleRoute(
      index: (json['index'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? 'Route',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['duration_minutes'] as num?)?.toDouble() ?? 0.0,
      congestion: json['congestion'] as String? ?? 'low',
      color: _parseHex(json['color_hex'] as String? ?? '#3498DB'),
      points: points,
    );
  }

  /// Convert "#RRGGBB" from the backend into a Flutter [Color].
  static Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    // Prefix full opacity (FF) since backend sends 6-digit RGB only.
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

/// Full response from /api/simple/find-routes.
/// Holds the resolved origin + destination plus the list of colored routes.
class SimpleRoutesResponse {
  final String originName;
  final LatLng originLatLng;
  final String destinationName;
  final LatLng destinationLatLng;
  final List<SimpleRoute> routes;
  final bool modelLoaded; // Was traffic_model.pkl loaded on the backend?

  SimpleRoutesResponse({
    required this.originName,
    required this.originLatLng,
    required this.destinationName,
    required this.destinationLatLng,
    required this.routes,
    required this.modelLoaded,
  });

  factory SimpleRoutesResponse.fromJson(Map<String, dynamic> json) {
    final origin = json['origin'] as Map<String, dynamic>;
    final dest = json['destination'] as Map<String, dynamic>;
    final rawRoutes = (json['routes'] as List?) ?? [];

    return SimpleRoutesResponse(
      originName: origin['name'] as String? ?? '',
      originLatLng: LatLng(
        (origin['lat'] as num).toDouble(),
        (origin['lng'] as num).toDouble(),
      ),
      destinationName: dest['name'] as String? ?? '',
      destinationLatLng: LatLng(
        (dest['lat'] as num).toDouble(),
        (dest['lng'] as num).toDouble(),
      ),
      routes: rawRoutes
          .map((r) => SimpleRoute.fromJson(r as Map<String, dynamic>))
          .toList(),
      modelLoaded: json['model_loaded'] as bool? ?? false,
    );
  }
}
