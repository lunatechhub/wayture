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

  // ── Traffic Polyline Data (lat/lng pairs for demo) ──
  // Green: Lazimpat → Thamel (light traffic)
  static const List<List<double>> greenRoute = [
    [27.7221, 85.3216],
    [27.7200, 85.3180],
    [27.7170, 85.3150],
    [27.7152, 85.3123],
  ];

  // Yellow: Koteshwor → Tinkune (moderate traffic)
  static const List<List<double>> yellowRoute = [
    [27.6781, 85.3490],
    [27.6800, 85.3475],
    [27.6830, 85.3460],
    [27.6852, 85.3442],
  ];

  // Red: Kalanki → Kalimati (heavy traffic)
  static const List<List<double>> redRoute = [
    [27.6933, 85.2814],
    [27.6940, 85.2880],
    [27.6950, 85.2950],
    [27.6956, 85.3012],
  ];
}
