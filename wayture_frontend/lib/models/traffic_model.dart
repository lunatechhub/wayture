/// Traffic data model — mirrors the backend TrafficDataResponse schema.
///
/// Used for both API responses and Firestore real-time stream documents.
class TrafficData {
  final String id;
  final String locationName;
  final double latitude;
  final double longitude;
  final String congestionLevel; // "low", "medium", "high", "severe"
  final int vehicleCount;
  final double averageSpeedKmh;
  final int hour;
  final String dayOfWeek;
  final String? date;
  final String source;
  final DateTime? timestamp;

  TrafficData({
    required this.id,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    this.congestionLevel = 'low',
    this.vehicleCount = 0,
    this.averageSpeedKmh = 30.0,
    this.hour = 0,
    this.dayOfWeek = '',
    this.date,
    this.source = 'manual',
    this.timestamp,
  });

  /// Parse from backend JSON (GET /traffic)
  factory TrafficData.fromJson(Map<String, dynamic> json) {
    return TrafficData(
      id: json['id'] ?? '',
      locationName: json['location_name'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      congestionLevel: json['congestion_level'] ?? 'low',
      vehicleCount: (json['vehicle_count'] as num?)?.toInt() ?? 0,
      averageSpeedKmh: (json['average_speed_kmh'] as num?)?.toDouble() ?? 30.0,
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      dayOfWeek: json['day_of_week'] ?? '',
      date: json['date'],
      source: json['source'] ?? 'manual',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }

  /// Parse from Firestore document snapshot
  factory TrafficData.fromFirestore(String docId, Map<String, dynamic> data) {
    return TrafficData(
      id: docId,
      locationName: data['location_name'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      congestionLevel: data['congestion_level'] ?? 'low',
      vehicleCount: (data['vehicle_count'] as num?)?.toInt() ?? 0,
      averageSpeedKmh: (data['average_speed_kmh'] as num?)?.toDouble() ?? 30.0,
      hour: (data['hour'] as num?)?.toInt() ?? 0,
      dayOfWeek: data['day_of_week'] ?? '',
      date: data['date'],
      source: data['source'] ?? 'manual',
      timestamp: data['timestamp']?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'location_name': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'congestion_level': congestionLevel,
        'vehicle_count': vehicleCount,
        'average_speed_kmh': averageSpeedKmh,
        'hour': hour,
        'day_of_week': dayOfWeek,
        'date': date,
        'source': source,
      };
}


/// ML prediction result from GET /traffic/predict
class TrafficPrediction {
  final String location;
  final String predictedCongestion;
  final double predictedSpeed;
  final double confidence;
  final int hour;
  final String dayOfWeek;
  final List<String> factors;

  TrafficPrediction({
    required this.location,
    required this.predictedCongestion,
    required this.predictedSpeed,
    required this.confidence,
    required this.hour,
    required this.dayOfWeek,
    this.factors = const [],
  });

  factory TrafficPrediction.fromJson(Map<String, dynamic> json) {
    return TrafficPrediction(
      location: json['location'] ?? '',
      predictedCongestion: json['predicted_congestion'] ?? 'green',
      predictedSpeed: (json['predicted_speed'] as num?)?.toDouble() ?? 30.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      dayOfWeek: json['day_of_week'] ?? '',
      factors: List<String>.from(json['factors'] ?? []),
    );
  }
}


/// A route returned from the Google Maps Directions endpoint
class GoogleRoute {
  final String summary;
  final double distanceKm;
  final double durationMinutes;
  final double? durationInTrafficMinutes;
  final String polyline;
  final List<String> warnings;

  GoogleRoute({
    required this.summary,
    required this.distanceKm,
    required this.durationMinutes,
    this.durationInTrafficMinutes,
    this.polyline = '',
    this.warnings = const [],
  });

  factory GoogleRoute.fromJson(Map<String, dynamic> json) {
    return GoogleRoute(
      summary: json['summary'] ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['duration_minutes'] as num?)?.toDouble() ?? 0.0,
      durationInTrafficMinutes:
          (json['duration_in_traffic_minutes'] as num?)?.toDouble(),
      polyline: json['polyline'] ?? '',
      warnings: List<String>.from(json['warnings'] ?? []),
    );
  }
}
