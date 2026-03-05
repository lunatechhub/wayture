import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wayture/models/congestion_factor.dart';
import 'package:wayture/models/kathmandu_event.dart';
import 'package:wayture/models/route_alert.dart';
import 'package:wayture/models/route_history_item.dart';
import 'package:wayture/models/route_model.dart';
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

  // ── Route History ──
  final List<RouteHistoryItem> _routeHistory = [];
  List<RouteHistoryItem> get routeHistory => _routeHistory;
  List<RouteHistoryItem> get favorites =>
      _routeHistory.where((h) => h.isFavorite).toList();

  // ── Generate Routes ──
  List<RouteModel> generateRoutes(
    String from,
    String to, {
    TimeOfDay? departureTime,
  }) {
    final baseRoutes = _buildRouteOptions(from, to);
    final bool isPeak = departureTime != null
        ? _isPeakHour(departureTime.hour, departureTime.minute)
        : _isPeakHour(TimeOfDay.now().hour, TimeOfDay.now().minute);
    final bool isWeekend = _isWeekend();

    _currentRoutes = List.generate(baseRoutes.length, (i) {
      final route = baseRoutes[i];
      final breakdown = _computeBreakdown(route.trafficLevel, isPeak, isWeekend);

      // Compute time estimates
      final nowMinutes = route.estimatedMinutes;
      int adjustedMinutes = nowMinutes;
      if (departureTime != null) {
        final depPeak = _isPeakHour(departureTime.hour, departureTime.minute);
        if (depPeak) {
          adjustedMinutes = (nowMinutes * 1.25).round();
        } else if (isWeekend) {
          adjustedMinutes = (nowMinutes * 0.9).round();
        }
      }

      final trust = _communityTrustScore(i);

      return RouteModel(
        id: route.id,
        name: route.name,
        description: route.description,
        estimatedMinutes: departureTime != null ? adjustedMinutes : nowMinutes,
        distanceKm: route.distanceKm,
        trafficLevel: route.trafficLevel,
        isRecommended: route.isRecommended,
        congestionBreakdown: breakdown,
        communityTrustPercent: trust,
        alertCount: activeAlerts.where((a) => a.routeIndex == i).length,
        nowEstimatedMinutes: departureTime != null ? nowMinutes : null,
      );
    });

    _showRoutesOnMap = true;
    _startAlertTimer();
    notifyListeners();
    return _currentRoutes;
  }

  List<RouteModel> _buildRouteOptions(String from, String to) {
    final seed = '$from→$to'.hashCode;
    final r = Random(seed);
    final routeNames = _getRouteNames(from, to);
    final levels = [
      TrafficLevel.light,
      TrafficLevel.moderate,
      TrafficLevel.heavy,
    ];

    return List.generate(3, (i) {
      final baseDist = 4.0 + r.nextDouble() * 4;
      final dist = double.parse((baseDist + i * 0.5).toStringAsFixed(1));
      final baseMin = (dist * 3.5 + i * 5).round();

      return RouteModel(
        id: '${i + 1}',
        name: routeNames[i],
        description:
            '$from → ${routeNames[i].replaceAll('Via ', '')} → $to',
        estimatedMinutes: baseMin,
        distanceKm: dist,
        trafficLevel: levels[i],
        isRecommended: i == 0,
      );
    });
  }

  List<String> _getRouteNames(String from, String to) {
    const viaPoints = [
      'Lazimpat', 'Bagbazar', 'Durbarmarg', 'Putalisadak',
      'Maharajgunj', 'Thapathali', 'Chabahil', 'Gaushala',
      'Samakhusi', 'Balaju', 'Jawalakhel', 'Maitighar',
    ];
    final seed = '$from→$to'.hashCode;
    final r = Random(seed);
    final shuffled = List<String>.from(viaPoints)..shuffle(r);
    return shuffled.take(3).map((v) => 'Via $v').toList();
  }

  // ── Congestion Breakdown (Point-Based) ──
  CongestionBreakdown _computeBreakdown(
    TrafficLevel level,
    bool isPeak,
    bool isWeekend,
  ) {
    // Base scores by traffic level
    final Map<CongestionFactor, int> scores;
    final List<FactorInsight> insights;

    switch (level) {
      case TrafficLevel.light:
        scores = {
          CongestionFactor.speed: 0,
          CongestionFactor.incidents: 0,
          CongestionFactor.weather: 0,
          CongestionFactor.peakHour: isPeak ? 15 : 0,
          CongestionFactor.hotspot: 0,
        };
        insights = [
          const FactorInsight(isPositive: true, text: 'No incidents on this route'),
          const FactorInsight(isPositive: true, text: 'Clear weather conditions'),
          if (isPeak)
            const FactorInsight(isPositive: false, text: 'Peak hour traffic')
          else
            const FactorInsight(isPositive: true, text: 'Off-peak — smooth traffic'),
        ];

      case TrafficLevel.moderate:
        scores = {
          CongestionFactor.speed: 10,
          CongestionFactor.incidents: 12,
          CongestionFactor.weather: 0,
          CongestionFactor.peakHour: isPeak ? 15 : 0,
          CongestionFactor.hotspot: 5,
        };
        insights = [
          const FactorInsight(isPositive: false, text: 'Slightly slow traffic detected'),
          const FactorInsight(isPositive: false, text: '1 incident reported nearby'),
          const FactorInsight(isPositive: true, text: 'Clear weather conditions'),
          if (isPeak)
            const FactorInsight(isPositive: false, text: 'Peak hour traffic'),
          const FactorInsight(isPositive: false, text: 'Passes through congestion area'),
        ];

      case TrafficLevel.heavy:
        scores = {
          CongestionFactor.speed: 25,
          CongestionFactor.incidents: 18,
          CongestionFactor.weather: 5,
          CongestionFactor.peakHour: isPeak ? 15 : 0,
          CongestionFactor.hotspot: 5,
        };
        insights = [
          const FactorInsight(isPositive: false, text: 'Very slow traffic on this route'),
          const FactorInsight(isPositive: false, text: '2 incidents: accident + protest'),
          const FactorInsight(isPositive: false, text: 'Light rain affecting roads'),
          if (isPeak)
            const FactorInsight(isPositive: false, text: 'Peak hour traffic'),
          const FactorInsight(isPositive: false, text: 'Passes through Maitighar area'),
        ];
    }

    // Weekend reduction: -10% on all scores
    if (isWeekend) {
      final adjusted = scores.map((k, v) => MapEntry(k, (v * 0.9).round()));
      return CongestionBreakdown(scores: adjusted, insights: insights);
    }

    return CongestionBreakdown(scores: scores, insights: insights);
  }

  bool _isPeakHour(int hour, [int minute = 0]) {
    final time = hour + minute / 60.0;
    // Morning peak: 7-10 AM
    if (time >= 7.0 && time < 10.0) return true;
    // Evening peak: 4-7 PM
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

  // ── Community Trust Score ──
  int _communityTrustScore(int routeIndex) {
    final base = routeIndex == 0 ? 85 : (routeIndex == 1 ? 75 : 65);
    return base + _random.nextInt(11);
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }
}
