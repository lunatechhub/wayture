import 'package:wayture/models/kathmandu_event.dart';
import 'package:wayture/models/report_model.dart';
import 'package:wayture/models/route_model.dart';
import 'package:wayture/models/notification_model.dart';

/// Centralized mock data for the app demo.
/// Replace with real API calls when backend is ready.
class MockData {
  MockData._();

  // ── Traffic Reports ──
  static List<ReportModel> get reports {
    final now = DateTime.now();
    return [
      ReportModel(
        id: '1',
        type: IncidentType.accident,
        location: 'Koteshwor Chowk',
        description: 'Two vehicles collided near the bridge',
        reporterName: 'Anonymous User',
        timestamp: now.subtract(const Duration(minutes: 5)),
        latitude: 27.6781,
        longitude: 85.3490,
      ),
      ReportModel(
        id: '2',
        type: IncidentType.protest,
        location: 'Maitighar Mandala',
        description: 'Political rally blocking main road',
        reporterName: 'Anonymous User',
        timestamp: now.subtract(const Duration(minutes: 20)),
        latitude: 27.6948,
        longitude: 85.3222,
      ),
      ReportModel(
        id: '3',
        type: IncidentType.roadBlock,
        location: 'Kalanki',
        description: 'Construction work on flyover',
        reporterName: 'Anonymous User',
        timestamp: now.subtract(const Duration(hours: 1)),
        latitude: 27.6933,
        longitude: 85.2814,
      ),
      ReportModel(
        id: '4',
        type: IncidentType.trafficJam,
        location: 'Thapathali',
        description: 'Heavy congestion due to festival',
        reporterName: 'Anonymous User',
        timestamp: now.subtract(const Duration(minutes: 10)),
        latitude: 27.6921,
        longitude: 85.3225,
      ),
      ReportModel(
        id: '5',
        type: IncidentType.weatherIssue,
        location: 'Balaju',
        description: 'Road flooded after heavy rain',
        reporterName: 'Anonymous User',
        timestamp: now.subtract(const Duration(minutes: 30)),
        latitude: 27.7329,
        longitude: 85.3028,
      ),
    ];
  }

  // ── Route Options (Koteshwor to Thamel) ──
  static List<RouteModel> get routes {
    return [
      RouteModel(
        id: '1',
        name: 'Via Lazimpat',
        description: 'Koteshwor → Maharajgunj → Lazimpat → Thamel',
        estimatedMinutes: 20,
        distanceKm: 5.8,
        trafficLevel: TrafficLevel.light,
        isRecommended: true,
      ),
      RouteModel(
        id: '2',
        name: 'Via Bagbazar',
        description: 'Koteshwor → Thapathali → Bagbazar → Thamel',
        estimatedMinutes: 25,
        distanceKm: 5.2,
        trafficLevel: TrafficLevel.moderate,
      ),
      RouteModel(
        id: '3',
        name: 'Via Durbarmarg',
        description: 'Koteshwor → Maitighar → Durbarmarg → Thamel',
        estimatedMinutes: 35,
        distanceKm: 6.1,
        trafficLevel: TrafficLevel.heavy,
      ),
    ];
  }

  // ── Notifications ──
  static List<NotificationModel> get notifications {
    final now = DateTime.now();
    return [
      NotificationModel(
        id: '1',
        type: NotificationType.trafficAlert,
        title: 'Heavy traffic on your route',
        message: 'Congestion detected near Kalanki. Consider alternate route.',
        timestamp: now.subtract(const Duration(minutes: 2)),
        isRead: false,
      ),
      NotificationModel(
        id: '2',
        type: NotificationType.weatherWarning,
        title: 'Rain expected soon',
        message: 'Rain forecast in 30 min. Roads may be slippery.',
        timestamp: now.subtract(const Duration(minutes: 15)),
        isRead: false,
      ),
      NotificationModel(
        id: '3',
        type: NotificationType.communityReport,
        title: 'New incident near you',
        message: 'Accident reported near Thapathali Bridge.',
        timestamp: now.subtract(const Duration(minutes: 25)),
        isRead: true,
      ),
      NotificationModel(
        id: '4',
        type: NotificationType.routeUpdate,
        title: 'Faster route available',
        message: 'A quicker route via Lazimpat saves 10 min.',
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: true,
      ),
    ];
  }

  // ── Kathmandu Events (for home screen carousel) ──
  static List<KathmanduEvent> get kathmanduEvents {
    final now = DateTime.now();
    return [
      KathmanduEvent(
        name: 'Bandh Alert',
        description: 'Political strike reported in western Kathmandu',
        affectedAreas: ['Kalanki', 'Kalimati', 'Balaju'],
        date: now,
        impactLevel: EventImpactLevel.high,
        isActive: true,
      ),
      KathmanduEvent(
        name: 'Festival Traffic',
        description: 'Increased traffic expected around Basantapur',
        affectedAreas: ['Basantapur', 'Thamel', 'Asan'],
        date: now,
        impactLevel: EventImpactLevel.medium,
        isActive: true,
      ),
      KathmanduEvent(
        name: 'Construction',
        description: 'Kalanki flyover construction — lane restrictions',
        affectedAreas: ['Kalanki'],
        date: now,
        impactLevel: EventImpactLevel.low,
        isActive: true,
      ),
    ];
  }

  // ── Peak Hour Ranges ──
  static const peakHourRanges = {
    'morningStart': 7.0,
    'morningEnd': 10.0,
    'eveningStart': 16.0,
    'eveningEnd': 19.0,
  };

  // ── Route Polyline Coordinates (Koteshwor → Thamel) ──

  // Route 1: Via Lazimpat (Green - Recommended)
  static const List<List<double>> route1Points = [
    [27.6781, 85.3499], // Koteshwor
    [27.6882, 85.3419], // New Baneshwor
    [27.7030, 85.3350], // Baneshwor
    [27.7119, 85.3427], // Gaushala
    [27.7220, 85.3238], // Lazimpat
    [27.7153, 85.3123], // Thamel
  ];

  // Route 2: Via Bagbazar (Yellow - Moderate)
  static const List<List<double>> route2Points = [
    [27.6781, 85.3499], // Koteshwor
    [27.6882, 85.3419], // New Baneshwor
    [27.6947, 85.3222], // Maitighar
    [27.7030, 85.3200], // Putalisadak/Bagbazar
    [27.7100, 85.3150], // Asan area
    [27.7153, 85.3123], // Thamel
  ];

  // Route 3: Via Durbarmarg (Red - Heavy)
  static const List<List<double>> route3Points = [
    [27.6781, 85.3499], // Koteshwor
    [27.6844, 85.3465], // Tinkune
    [27.6926, 85.3220], // Thapathali
    [27.6947, 85.3222], // Maitighar
    [27.7030, 85.3180], // Durbarmarg
    [27.7153, 85.3123], // Thamel
  ];

  // All route polylines grouped
  static const List<List<List<double>>> routePolylines = [
    route1Points,
    route2Points,
    route3Points,
  ];

  // ── Route-specific incident markers ──
  static const List<Map<String, dynamic>> routeIncidents = [
    {
      'lat': 27.6948,
      'lng': 85.3222,
      'type': 'protest',
      'label': 'Protest at Maitighar',
    },
    {
      'lat': 27.6921,
      'lng': 85.3225,
      'type': 'accident',
      'label': 'Accident at Thapathali',
    },
  ];

  // Legacy polyline data (for default map overlay)
  static const List<List<double>> greenRoute = [
    [27.7221, 85.3216],
    [27.7200, 85.3180],
    [27.7170, 85.3150],
    [27.7152, 85.3123],
  ];

  static const List<List<double>> yellowRoute = [
    [27.6781, 85.3490],
    [27.6800, 85.3475],
    [27.6830, 85.3460],
    [27.6852, 85.3442],
  ];

  static const List<List<double>> redRoute = [
    [27.6933, 85.2814],
    [27.6940, 85.2880],
    [27.6950, 85.2950],
    [27.6956, 85.3012],
  ];
}
