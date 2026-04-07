import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wayture/models/congestion_factor.dart';
import 'package:wayture/models/kathmandu_event.dart';
import 'package:wayture/models/route_alert.dart';
import 'package:wayture/models/route_history_item.dart';
import 'package:wayture/models/route_model.dart';
import 'package:wayture/services/api_service.dart';
import 'package:wayture/services/mock_data.dart';

class RouteService extends ChangeNotifier {
  final _random = Random();
  Timer? _alertTimer;

  List<RouteModel> _currentRoutes = [];
  List<RouteModel> get currentRoutes => _currentRoutes;

  // ── Navigation State ──
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;
  int? _navigatingRouteIndex;
  int? get navigatingRouteIndex => _navigatingRouteIndex;
  String? _navigatingRouteName;
  String? get navigatingRouteName => _navigatingRouteName;
  int _navigatingEta = 0;
  int get navigatingEta => _navigatingEta;

  // ── Route display state ──
  bool _showRoutesOnMap = false;
  bool get showRoutesOnMap => _showRoutesOnMap;
  int? _highlightedRouteIndex;
  int? get highlightedRouteIndex => _highlightedRouteIndex;

  // ── Alerts ──
  final List<RouteAlert> _activeAlerts = [];
  List<RouteAlert> get activeAlerts =>
      _activeAlerts.where((a) => a.isActive).toList();

  // ── Events ──
  List<KathmanduEvent> get todaysEvents =>
      MockData.kathmanduEvents.where((e) => e.isActive).toList();

  // ── AI Insights ──
  String? _aiInsight;
  String? get aiInsight => _aiInsight;
  String? _aiRouteSuggestion;
  String? get aiRouteSuggestion => _aiRouteSuggestion;
  bool _isLoadingAi = false;
  bool get isLoadingAi => _isLoadingAi;

  // ── Prediction metadata ──
  String? _weatherWarning;
  String? get weatherWarning => _weatherWarning;
  int _nearbyReportsCount = 0;
  int get nearbyReportsCount => _nearbyReportsCount;
  bool _isRaining = false;
  bool get isRaining => _isRaining;

  // ── Route History ──
  final List<RouteHistoryItem> _routeHistory = [];
  List<RouteHistoryItem> get routeHistory => _routeHistory;
  List<RouteHistoryItem> get favorites =>
      _routeHistory.where((h) => h.isFavorite).toList();

  // ── Kathmandu location coordinates ──
  static const _locationCoords = {
    'Current Location': [27.7090, 85.3038],
    'Koteshwor Chowk': [27.6781, 85.3499],
    'Kalanki Chowk': [27.6933, 85.2814],
    'Thamel': [27.7153, 85.3123],
    'New Baneshwor': [27.6882, 85.3419],
    'Maharajgunj': [27.7369, 85.3300],
    'Lazimpat': [27.7220, 85.3238],
    'Balaju': [27.7343, 85.3042],
    'Chabahil': [27.7178, 85.3457],
    'Maitighar Mandala': [27.6947, 85.3222],
    'Thapathali': [27.6926, 85.3220],
    'Tinkune': [27.6844, 85.3465],
    'Putalisadak': [27.7030, 85.3200],
    'Gaushala': [27.7119, 85.3427],
    'Samakhusi': [27.7280, 85.3150],
    'Bouddha': [27.7215, 85.3620],
    'Swayambhunath': [27.7149, 85.2903],
    'Tribhuvan Airport': [27.6966, 85.3591],
    'Ratnapark': [27.7050, 85.3150],
    'Baneshwor': [27.6882, 85.3419],
    'Kalimati': [27.6975, 85.3020],
  };

  /// Resolve a location name to [lat, lng] coordinates.
  List<double>? _findLocationCoords(String name) {
    return _locationCoords[name];
  }

  // ── Generate Routes (calls real backend) ──
  Future<List<RouteModel>> generateRoutes(
    String from,
    String to, {
    TimeOfDay? departureTime,
  }) async {
    _currentRoutes = [];
    _aiInsight = null;
    _aiRouteSuggestion = null;
    _weatherWarning = null;
    _isLoadingAi = true;
    notifyListeners();

    final fromCoords = _findLocationCoords(from);
    final toCoords = _findLocationCoords(to);

    if (fromCoords == null || toCoords == null) {
      // Fallback to mock routes if coordinates not found
      _currentRoutes = _buildMockRoutes(from, to, departureTime);
      _showRoutesOnMap = true;
      _isLoadingAi = false;
      _startAlertTimer();
      notifyListeners();
      return _currentRoutes;
    }

    // Call the real backend prediction API
    final prediction = await ApiService.predictCongestion(
      userLat: fromCoords[0],
      userLng: fromCoords[1],
      destLat: toCoords[0],
      destLng: toCoords[1],
    );

    if (prediction == null) {
      // Backend unreachable — fall back to mock
      _currentRoutes = _buildMockRoutes(from, to, departureTime);
      _showRoutesOnMap = true;
      _isLoadingAi = false;
      _startAlertTimer();
      notifyListeners();
      return _currentRoutes;
    }

    // Parse real routes from prediction response
    _currentRoutes = _parseApiRoutes(prediction, from, to, departureTime);

    // Extract metadata
    _aiInsight = prediction['ai_insight'] as String?;
    _aiRouteSuggestion = prediction['ai_route_suggestion'] as String?;
    _weatherWarning = prediction['weather_warning'] as String?;
    _nearbyReportsCount = (prediction['nearby_reports_count'] as num?)?.toInt() ?? 0;
    _isRaining = prediction['is_raining'] as bool? ?? false;

    _showRoutesOnMap = true;
    _isLoadingAi = false;
    _startAlertTimer();
    notifyListeners();
    return _currentRoutes;
  }

  /// Parse the backend prediction response into RouteModel list.
  List<RouteModel> _parseApiRoutes(
    Map<String, dynamic> prediction,
    String from,
    String to,
    TimeOfDay? departureTime,
  ) {
    final routes = <RouteModel>[];
    final bool isPeak = departureTime != null
        ? _isPeakHour(departureTime.hour, departureTime.minute)
        : _isPeakHour(TimeOfDay.now().hour, TimeOfDay.now().minute);
    final bool isWeekend = _isWeekend();

    // Main route
    final mainRoute = prediction['main_route'] as Map<String, dynamic>?;
    if (mainRoute != null) {
      final level = _parseCongestionLevel(
          prediction['congestion_level'] as String? ?? 'green');
      final points = _parsePoints(mainRoute['points']);
      final durationMin = (mainRoute['duration_minutes'] as num).round();
      final distKm = (mainRoute['distance_km'] as num).toDouble();

      routes.add(RouteModel(
        id: '0',
        name: _routeNameFromSteps(mainRoute['steps'], 'Main Route'),
        description: '$from → $to',
        estimatedMinutes: durationMin,
        distanceKm: distKm,
        trafficLevel: level,
        isRecommended: level != TrafficLevel.heavy,
        congestionBreakdown: _buildBreakdownFromApi(level, isPeak, isWeekend),
        communityTrustPercent: 80 + _random.nextInt(11),
        polylinePoints: points,
      ));
    }

    // Alternate routes
    final alternates = prediction['alternate_routes'] as List? ?? [];
    for (int i = 0; i < alternates.length; i++) {
      final alt = alternates[i] as Map<String, dynamic>;
      final altLevel = _parseCongestionLevel(
          alt['congestion_level'] as String? ?? 'green');
      final points = _parsePoints(alt['points']);
      final durationMin = (alt['duration_minutes'] as num).round();
      final distKm = (alt['distance_km'] as num).toDouble();

      // If the main route is heavy and this alternate is better, recommend it
      final mainLevel = routes.isNotEmpty ? routes[0].trafficLevel : TrafficLevel.heavy;
      final isRecommended = mainLevel == TrafficLevel.heavy &&
          altLevel != TrafficLevel.heavy;

      routes.add(RouteModel(
        id: '${i + 1}',
        name: _routeNameFromSteps(alt['steps'], 'Alt Route ${i + 1}'),
        description: '$from → $to (alternate)',
        estimatedMinutes: durationMin,
        distanceKm: distKm,
        trafficLevel: altLevel,
        isRecommended: isRecommended,
        congestionBreakdown: _buildBreakdownFromApi(altLevel, isPeak, isWeekend),
        communityTrustPercent: 70 + _random.nextInt(16),
        polylinePoints: points,
      ));
    }

    // If main route is congested and alternates are better, reorder
    // so the best route is shown first as recommended
    if (routes.length > 1) {
      routes.sort((a, b) {
        // Prioritize lower congestion, then shorter duration
        final levelCompare = a.trafficLevel.index.compareTo(b.trafficLevel.index);
        if (levelCompare != 0) return levelCompare;
        return a.estimatedMinutes.compareTo(b.estimatedMinutes);
      });
      // Mark the first (best) route as recommended
      if (routes.isNotEmpty) {
        final best = routes[0];
        routes[0] = RouteModel(
          id: best.id,
          name: best.name,
          description: best.description,
          estimatedMinutes: best.estimatedMinutes,
          distanceKm: best.distanceKm,
          trafficLevel: best.trafficLevel,
          isRecommended: true,
          congestionBreakdown: best.congestionBreakdown,
          communityTrustPercent: best.communityTrustPercent,
          polylinePoints: best.polylinePoints,
        );
      }
    }

    return routes;
  }

  /// Extract a human-readable route name from OSRM steps.
  String _routeNameFromSteps(dynamic steps, String fallback) {
    if (steps == null || steps is! List || steps.isEmpty) return fallback;
    // Find the most prominent road name from steps
    final names = <String>[];
    for (final step in steps) {
      final name = step['name'] as String? ?? '';
      if (name.isNotEmpty && !names.contains(name)) {
        names.add(name);
      }
    }
    if (names.isEmpty) return fallback;
    // Pick up to 2 major road names
    final display = names.take(2).join(' → ');
    return 'Via $display';
  }

  /// Parse points from API response [[lat, lng], ...].
  List<List<double>> _parsePoints(dynamic pointsData) {
    if (pointsData == null || pointsData is! List) return [];
    return pointsData.map<List<double>>((p) {
      if (p is List && p.length >= 2) {
        return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
      }
      return [0.0, 0.0];
    }).toList();
  }

  TrafficLevel _parseCongestionLevel(String level) {
    switch (level) {
      case 'red':
        return TrafficLevel.heavy;
      case 'yellow':
        return TrafficLevel.moderate;
      case 'green':
      default:
        return TrafficLevel.light;
    }
  }

  CongestionBreakdown _buildBreakdownFromApi(
    TrafficLevel level,
    bool isPeak,
    bool isWeekend,
  ) {
    final Map<CongestionFactor, int> scores;
    final List<FactorInsight> insights;

    switch (level) {
      case TrafficLevel.light:
        scores = {
          CongestionFactor.speed: 0,
          CongestionFactor.incidents: 0,
          CongestionFactor.weather: _isRaining ? 10 : 0,
          CongestionFactor.peakHour: isPeak ? 15 : 0,
          CongestionFactor.hotspot: 0,
        };
        insights = [
          const FactorInsight(isPositive: true, text: 'Traffic flowing smoothly'),
          if (_isRaining)
            const FactorInsight(isPositive: false, text: 'Rain may slow traffic')
          else
            const FactorInsight(isPositive: true, text: 'Clear weather conditions'),
          if (isPeak)
            const FactorInsight(isPositive: false, text: 'Peak hour — may get busier'),
          if (_nearbyReportsCount > 0)
            FactorInsight(isPositive: false, text: '$_nearbyReportsCount report(s) nearby'),
        ];
      case TrafficLevel.moderate:
        scores = {
          CongestionFactor.speed: 10,
          CongestionFactor.incidents: _nearbyReportsCount > 0 ? 12 : 5,
          CongestionFactor.weather: _isRaining ? 15 : 0,
          CongestionFactor.peakHour: isPeak ? 15 : 0,
          CongestionFactor.hotspot: 5,
        };
        insights = [
          const FactorInsight(isPositive: false, text: 'Moderate congestion detected'),
          if (_nearbyReportsCount > 0)
            FactorInsight(isPositive: false, text: '$_nearbyReportsCount incident(s) reported'),
          if (_isRaining)
            const FactorInsight(isPositive: false, text: 'Rain affecting road conditions'),
          if (isPeak)
            const FactorInsight(isPositive: false, text: 'Peak hour traffic'),
          const FactorInsight(isPositive: true, text: 'Alternative routes available'),
        ];
      case TrafficLevel.heavy:
        scores = {
          CongestionFactor.speed: 25,
          CongestionFactor.incidents: _nearbyReportsCount > 0 ? 20 : 10,
          CongestionFactor.weather: _isRaining ? 15 : 5,
          CongestionFactor.peakHour: isPeak ? 15 : 0,
          CongestionFactor.hotspot: 8,
        };
        insights = [
          const FactorInsight(isPositive: false, text: 'Heavy congestion — consider alternatives'),
          if (_nearbyReportsCount > 0)
            FactorInsight(isPositive: false, text: '$_nearbyReportsCount incident(s) in this area'),
          if (_isRaining)
            const FactorInsight(isPositive: false, text: 'Rain worsening conditions'),
          if (isPeak)
            const FactorInsight(isPositive: false, text: 'Peak hour — expect delays'),
          const FactorInsight(isPositive: true, text: 'Use suggested alternate route'),
        ];
    }

    if (isWeekend) {
      final adjusted = scores.map((k, v) => MapEntry(k, (v * 0.9).round()));
      return CongestionBreakdown(scores: adjusted, insights: insights);
    }
    return CongestionBreakdown(scores: scores, insights: insights);
  }

  // ── Mock route fallback (when backend is offline) ──
  List<RouteModel> _buildMockRoutes(
    String from,
    String to,
    TimeOfDay? departureTime,
  ) {
    final seed = '$from→$to'.hashCode;
    final r = Random(seed);
    final isPeak = departureTime != null
        ? _isPeakHour(departureTime.hour, departureTime.minute)
        : _isPeakHour(TimeOfDay.now().hour, TimeOfDay.now().minute);
    final isWeekend = _isWeekend();

    final viaPoints = [
      'Lazimpat', 'Bagbazar', 'Durbarmarg', 'Putalisadak',
      'Maharajgunj', 'Thapathali', 'Chabahil', 'Gaushala',
      'Samakhusi', 'Balaju', 'Maitighar', 'Kalimati',
    ];
    final shuffled = List<String>.from(viaPoints)..shuffle(r);
    final names = shuffled.take(3).map((v) => 'Via $v').toList();

    final levels = [TrafficLevel.light, TrafficLevel.moderate, TrafficLevel.heavy];

    return List.generate(3, (i) {
      final baseDist = 4.0 + r.nextDouble() * 4;
      final dist = double.parse((baseDist + i * 0.5).toStringAsFixed(1));
      int baseMin = (dist * 3.5 + i * 5).round();
      if (isPeak) baseMin = (baseMin * 1.25).round();
      if (isWeekend) baseMin = (baseMin * 0.9).round();

      final breakdown = _buildBreakdownFromApi(levels[i], isPeak, isWeekend);

      // Use mock polylines for offline mode
      final polylines = i < MockData.routePolylines.length
          ? MockData.routePolylines[i]
          : <List<double>>[];

      return RouteModel(
        id: '${i + 1}',
        name: names[i],
        description: '$from → ${names[i].replaceAll('Via ', '')} → $to',
        estimatedMinutes: baseMin,
        distanceKm: dist,
        trafficLevel: levels[i],
        isRecommended: i == 0,
        congestionBreakdown: breakdown,
        communityTrustPercent: 85 - i * 10 + r.nextInt(11),
        polylinePoints: polylines,
      );
    });
  }

  bool _isPeakHour(int hour, [int minute = 0]) {
    final time = hour + minute / 60.0;
    if (time >= 7.0 && time < 10.0) return true;
    if (time >= 16.0 && time < 19.0) return true;
    return false;
  }

  bool _isWeekend() {
    final day = DateTime.now().weekday;
    return day == DateTime.saturday || day == DateTime.sunday;
  }

  // ── Navigation ──
  void startNavigation(int index, String name) {
    _isNavigating = true;
    _navigatingRouteIndex = index;
    _navigatingRouteName = name;
    _navigatingEta = index < _currentRoutes.length
        ? _currentRoutes[index].estimatedMinutes
        : 20;
    _highlightedRouteIndex = index;
    notifyListeners();
  }

  void switchRoute(int newIndex, String newName) {
    _navigatingRouteIndex = newIndex;
    _navigatingRouteName = newName;
    _navigatingEta = newIndex < _currentRoutes.length
        ? _currentRoutes[newIndex].estimatedMinutes
        : 20;
    _highlightedRouteIndex = newIndex;
    notifyListeners();
  }

  void stopNavigation() {
    _isNavigating = false;
    _navigatingRouteIndex = null;
    _navigatingRouteName = null;
    _showRoutesOnMap = false;
    _highlightedRouteIndex = null;
    _aiInsight = null;
    _aiRouteSuggestion = null;
    _weatherWarning = null;
    notifyListeners();
  }

  void highlightRoute(int index) {
    _highlightedRouteIndex = index;
    notifyListeners();
  }

  void clearRouteDisplay() {
    _showRoutesOnMap = false;
    _highlightedRouteIndex = null;
    notifyListeners();
  }

  // ── Alerts ──
  void _startAlertTimer() {
    _alertTimer?.cancel();
    _alertTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _generateMockAlert();
    });
  }

  void _generateMockAlert() {
    if (_currentRoutes.isEmpty) return;

    final messages = [
      'Slowdown detected ahead — expect 5 min delay',
      'Minor accident reported — traffic clearing',
      'Road work ahead — use alternate lane',
      'Heavy rain reducing visibility',
      'Congestion easing — faster than expected',
      'Police checkpoint ahead — brief delay',
      'Festival procession crossing — temporary block',
    ];

    final severities = [
      AlertSeverity.info,
      AlertSeverity.warning,
      AlertSeverity.critical,
    ];

    final alert = RouteAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      routeIndex: _random.nextInt(_currentRoutes.length),
      message: messages[_random.nextInt(messages.length)],
      severity: severities[_random.nextInt(severities.length)],
      timestamp: DateTime.now(),
    );

    _activeAlerts.add(alert);
    notifyListeners();

    Timer(const Duration(seconds: 30), () {
      final idx = _activeAlerts.indexWhere((a) => a.id == alert.id);
      if (idx != -1) {
        _activeAlerts[idx] = _activeAlerts[idx].copyWith(isActive: false);
        notifyListeners();
      }
    });
  }

  void dismissAlert(String alertId) {
    final idx = _activeAlerts.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      _activeAlerts[idx] = _activeAlerts[idx].copyWith(isActive: false);
      notifyListeners();
    }
  }

  // ── Route History ──
  void addToHistory(String from, String to, String routeName) {
    _routeHistory.removeWhere(
        (h) => h.from == from && h.to == to && h.routeName == routeName);
    _routeHistory.insert(
      0,
      RouteHistoryItem(
        from: from,
        to: to,
        routeName: routeName,
        timestamp: DateTime.now(),
      ),
    );
    if (_routeHistory.length > 20) {
      _routeHistory.removeRange(20, _routeHistory.length);
    }
    notifyListeners();
  }

  void toggleFavorite(int index) {
    if (index < _routeHistory.length) {
      _routeHistory[index].isFavorite = !_routeHistory[index].isFavorite;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }
}
