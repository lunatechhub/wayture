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

  // ── Alerts ──
  final List<RouteAlert> _activeAlerts = [];
  List<RouteAlert> get activeAlerts =>
      _activeAlerts.where((a) => a.isActive).toList();

  // ── Events ──
  List<KathmanduEvent> get todaysEvents => MockData.kathmanduEvents
      .where((e) => e.isActive)
      .toList();

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
    final timeMultiplier = departureTime != null
        ? predictCongestion(departureTime.hour, departureTime.minute)
        : 1.0;

    _currentRoutes = baseRoutes.map((route) {
      final breakdown = _computeCongestionBreakdown(
        route.trafficLevel,
        timeMultiplier,
        _getEventImpact(from, to),
      );
      final trust = communityTrustScore(baseRoutes.indexOf(route));

      return RouteModel(
        id: route.id,
        name: route.name,
        description: route.description,
        estimatedMinutes:
            (route.estimatedMinutes * timeMultiplier).round(),
        distanceKm: route.distanceKm,
        trafficLevel: _adjustTrafficLevel(route.trafficLevel, timeMultiplier),
        isRecommended: route.isRecommended,
        congestionBreakdown: breakdown,
        communityTrustPercent: trust,
        alertCount: activeAlerts
            .where((a) => a.routeIndex == baseRoutes.indexOf(route))
            .length,
      );
    }).toList();

    _startAlertTimer();
    notifyListeners();
    return _currentRoutes;
  }

  List<RouteModel> _buildRouteOptions(String from, String to) {
    // Use a hash of from+to to produce deterministic but varied routes
    final seed = '$from→$to'.hashCode;
    final r = Random(seed);

    final routeNames = _getRouteNames(from, to);
    final levels = [TrafficLevel.light, TrafficLevel.moderate, TrafficLevel.heavy];

    return List.generate(3, (i) {
      final baseDist = 4.0 + r.nextDouble() * 4;
      final dist = double.parse((baseDist + i * 0.5).toStringAsFixed(1));
      final baseMin = (dist * 3.5 + i * 5).round();

      return RouteModel(
        id: '${i + 1}',
        name: routeNames[i],
        description: '$from → ${routeNames[i].replaceAll('Via ', '')} → $to',
        estimatedMinutes: baseMin,
        distanceKm: dist,
        trafficLevel: levels[i],
        isRecommended: i == 0,
      );
    });
  }

  List<String> _getRouteNames(String from, String to) {
    // Pick via-points from known Kathmandu areas
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

  // ── Congestion Breakdown ──
  CongestionBreakdown _computeCongestionBreakdown(
    TrafficLevel level,
    double timeMultiplier,
    double eventImpact,
  ) {
    double base;
    switch (level) {
      case TrafficLevel.light:
        base = 0.15;
      case TrafficLevel.moderate:
        base = 0.45;
      case TrafficLevel.heavy:
        base = 0.75;
    }

    final factors = <CongestionFactor, double>{};
    for (final factor in CongestionFactor.values) {
      double value;
      switch (factor) {
        case CongestionFactor.speed:
          value = base + (_random.nextDouble() * 0.15);
        case CongestionFactor.incidents:
          value = base * 0.7 + (_random.nextDouble() * 0.2);
        case CongestionFactor.weather:
          value = 0.1 + (_random.nextDouble() * 0.3);
        case CongestionFactor.peakHour:
          value = (timeMultiplier - 1.0).clamp(0.0, 1.0) + base * 0.3;
        case CongestionFactor.hotspot:
          value = base * 0.8 + eventImpact;
      }
      factors[factor] = value.clamp(0.0, 1.0);
    }

    return CongestionBreakdown(factors);
  }

  double _getEventImpact(String from, String to) {
    final events = todaysEvents;
    if (events.isEmpty) return 0.0;

    double impact = 0.0;
    for (final event in events) {
      for (final area in event.affectedAreas) {
        if (from.contains(area) || to.contains(area)) {
          switch (event.impactLevel) {
            case EventImpactLevel.low:
              impact += 0.1;
            case EventImpactLevel.medium:
              impact += 0.2;
            case EventImpactLevel.high:
              impact += 0.3;
          }
        }
      }
    }
    return impact.clamp(0.0, 0.5);
  }

  TrafficLevel _adjustTrafficLevel(TrafficLevel base, double multiplier) {
    if (multiplier <= 0.7) {
      // Night time — reduce
      if (base == TrafficLevel.heavy) return TrafficLevel.moderate;
      if (base == TrafficLevel.moderate) return TrafficLevel.light;
      return base;
    }
    if (multiplier >= 1.3) {
      // Peak — increase
      if (base == TrafficLevel.light) return TrafficLevel.moderate;
      if (base == TrafficLevel.moderate) return TrafficLevel.heavy;
      return base;
    }
    return base;
  }

  // ── Time-Based Prediction ──
  double predictCongestion(int hour, [int minute = 0]) {
    final time = hour + minute / 60.0;

    // Morning peak (7:30–9:30): +40%
    if (time >= 7.5 && time <= 9.5) return 1.4;
    // Evening peak (16:30–19:00): +35%
    if (time >= 16.5 && time <= 19.0) return 1.35;
    // Night (22:00–6:00): -50%
    if (time >= 22.0 || time <= 6.0) return 0.5;

    // Festival/event hours: check for active events
    if (todaysEvents.isNotEmpty) return 1.2;

    return 1.0;
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

    // Auto-expire after 30 seconds
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
    // Avoid duplicates at the top
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
    // Keep last 20
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
  int communityTrustScore(int routeIndex) {
    // Recommended routes (index 0) get higher trust
    final base = routeIndex == 0 ? 85 : (routeIndex == 1 ? 75 : 65);
    return base + _random.nextInt(11); // 60–95 range
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }
}
