import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/kathmandu_event.dart';
import 'package:wayture/models/report_model.dart';
import 'package:wayture/models/route_model.dart';
import 'package:wayture/models/traffic_model.dart';
import 'package:wayture/services/api_service.dart';
import 'package:wayture/services/firestore_service.dart';
import 'package:wayture/services/location_service.dart';
import 'package:wayture/services/mock_data.dart';
import 'package:wayture/services/connection_manager.dart';
import 'package:wayture/services/route_service.dart';
import 'package:wayture/services/theme_service.dart';
import 'package:wayture/widgets/custom_text_field.dart';
import 'package:wayture/widgets/event_carousel.dart';
import 'package:wayture/widgets/navigation_overlay.dart';
import 'package:wayture/widgets/route_planning_sheet.dart';
import 'package:wayture/widgets/traffic_legend.dart';
import 'package:wayture/widgets/weather_widget.dart';

/// Home / Map screen — the core screen of the app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  // ── Live traffic data from Firestore ──
  List<TrafficData> _liveTraffic = [];
  List<Map<String, dynamic>> _liveReports = [];
  StreamSubscription? _trafficSub;
  StreamSubscription? _reportsSub;

  // ── User location ──
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionSub;
  bool _locationDenied = false;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToLiveTraffic();
    _listenToLiveReports();
    _fetchTrafficFromApi();
    _initLocation();
  }

  @override
  void dispose() {
    _trafficSub?.cancel();
    _reportsSub?.cancel();
    _positionSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Location bootstrap ──
  Future<void> _initLocation() async {
    final fix = await LocationService.getCurrentPosition(withAddress: false);
    if (!mounted) return;

    if (!fix.isSuccess) {
      setState(() {
        _locationLoading = false;
        _locationDenied = fix.result == LocationResult.permissionDenied ||
            fix.result == LocationResult.permissionDeniedForever;
      });
      return;
    }

    final pos = fix.position!;
    final latLng = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _userLocation = latLng;
      _locationLoading = false;
      _locationDenied = false;
    });
    _mapController.move(latLng, 15);
    _startLocationStream();
  }

  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub = LocationService.positionStream(distanceFilterMeters: 10)
        .listen((pos) {
      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
    }, onError: (e) {
      debugPrint('Position stream error: $e');
    });
  }

  Future<void> _locateMe() async {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16);
      return;
    }
    setState(() => _locationLoading = true);
    await _initLocation();
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _locationLoading = true;
      _locationDenied = false;
    });
    await _initLocation();
  }

  void _listenToLiveTraffic() {
    _trafficSub = FirestoreService.instance.realtimeTrafficStream().listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _liveTraffic = data;
        });
      },
      onError: (e) {
        debugPrint('Live traffic stream error: $e');
      },
    );
  }

  void _listenToLiveReports() {
    _reportsSub = FirestoreService.instance.communityReportsStream().listen(
      (data) {
        if (!mounted) return;
        setState(() => _liveReports = data);
      },
      onError: (e) => debugPrint('Live reports stream error: $e'),
    );
  }

  /// Fetch traffic from backend API as supplement when Firestore is empty.
  Future<void> _fetchTrafficFromApi() async {
    try {
      final data = await ApiService.getRealtimeTraffic();
      if (data != null && data.isNotEmpty && _liveTraffic.isEmpty && mounted) {
        setState(() {
          _liveTraffic = data.map((d) => TrafficData.fromJson(d)).toList();
        });
      }
    } catch (e) {
      debugPrint('API traffic fetch error: $e');
    }
  }

  // ── Kathmandu hotspot locations — always visible on map ──
  static const _kathmanduHotspots = [
    {'name': 'Koteshwor',   'lat': 27.6788, 'lng': 85.3456},
    {'name': 'Kalanki',     'lat': 27.6940, 'lng': 85.2816},
    {'name': 'Chabahil',    'lat': 27.7167, 'lng': 85.3456},
    {'name': 'Balaju',      'lat': 27.7343, 'lng': 85.3042},
    {'name': 'Tinkune',     'lat': 27.6864, 'lng': 85.3456},
    {'name': 'Ratnapark',   'lat': 27.7041, 'lng': 85.3145},
    {'name': 'Baneshwor',   'lat': 27.6939, 'lng': 85.3330},
    {'name': 'Maharajgunj', 'lat': 27.7369, 'lng': 85.3306},
    {'name': 'Gongabu',     'lat': 27.7369, 'lng': 85.3128},
    {'name': 'Thapathali',  'lat': 27.6926, 'lng': 85.3220},
    {'name': 'Kalimati',    'lat': 27.6975, 'lng': 85.3020},
    {'name': 'Gaushala',    'lat': 27.7119, 'lng': 85.3427},
  ];

  /// Markers that ALWAYS show on the map for Kathmandu hotspots.
  /// If live data exists for a location, it uses real congestion color.
  /// Otherwise it shows a neutral teal marker.
  List<Marker> get _hotspotMarkers {
    return _kathmanduHotspots.map((spot) {
      final name = spot['name'] as String;
      final lat = spot['lat'] as double;
      final lng = spot['lng'] as double;

      // Check if we have live data for this location
      final liveMatch = _liveTraffic.where((tp) =>
          tp.locationName.toLowerCase() == name.toLowerCase()).firstOrNull;

      final color = liveMatch != null
          ? _congestionColor(liveMatch.congestionLevel)
          : const Color(0xFF00897B); // teal default
      final level = liveMatch?.congestionLevel ?? 'monitoring';
      final vehicles = liveMatch?.vehicleCount ?? 0;
      final speed = liveMatch?.averageSpeedKmh ?? 0;

      return Marker(
        point: LatLng(lat, lng),
        width: 56,
        height: 56,
        child: GestureDetector(
          onTap: () {
            if (liveMatch != null) {
              _showTrafficInfo(liveMatch);
            } else {
              _showHotspotInfo(name, level, vehicles, speed);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(50),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(60),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    liveMatch != null ? Icons.traffic : Icons.location_on,
                    color: color,
                    size: 18,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E).withAlpha(200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showHotspotInfo(String name, String level, int vehicles, double speed) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _trafficInfoRow('Status', level.toUpperCase(),
                const Color(0xFF00897B)),
            if (vehicles > 0)
              _trafficInfoRow('Vehicles', '$vehicles', Colors.white70),
            if (speed > 0)
              _trafficInfoRow('Avg Speed', '${speed.toStringAsFixed(0)} km/h',
                  Colors.white70),
            _trafficInfoRow('Source', 'Kathmandu Hotspot', Colors.white54),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Incident markers from LIVE Firestore community reports ──
  List<Marker> get _liveIncidentMarkers {
    return _liveReports.map((report) {
      final lat = (report['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (report['longitude'] as num?)?.toDouble() ?? 0.0;
      if (lat == 0.0 && lng == 0.0) return null;
      final type = report['report_type'] ?? report['type'] ?? 'accident';
      final desc = report['description'] ?? '';
      final docId = report['id'] as String? ?? '';
      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showLiveReportInfo(type, desc, lat, lng, docId),
          child: Icon(
            _iconForReportType(type),
            color: _colorForReportType(type),
            size: 30,
          ),
        ),
      );
    }).whereType<Marker>().toList();
  }

  Color _congestionColor(String level) {
    switch (level) {
      case 'severe':
        return Colors.red.shade700;
      case 'high':
        return Colors.deepOrange;
      case 'medium':
        return Colors.amber.shade700;
      default:
        return Colors.green;
    }
  }

  IconData _iconForReportType(String type) {
    switch (type) {
      case 'accident':
        return Icons.car_crash;
      case 'traffic_jam':
        return Icons.traffic;
      case 'road_closure':
        return Icons.block;
      case 'construction':
        return Icons.construction;
      case 'flooding':
        return Icons.thunderstorm;
      default:
        return Icons.warning_amber;
    }
  }

  Color _colorForReportType(String type) {
    switch (type) {
      case 'accident':
        return Colors.red;
      case 'traffic_jam':
        return Colors.orange;
      case 'road_closure':
        return Colors.deepOrange;
      case 'construction':
        return Colors.brown;
      case 'flooding':
        return Colors.blueGrey;
      default:
        return Colors.purple;
    }
  }

  void _showTrafficInfo(TrafficData tp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tp.locationName,
              style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _trafficInfoRow('Congestion', tp.congestionLevel.toUpperCase(),
                _congestionColor(tp.congestionLevel)),
            _trafficInfoRow('Vehicles', '${tp.vehicleCount}', Colors.white70),
            _trafficInfoRow('Avg Speed',
                '${tp.averageSpeedKmh.toStringAsFixed(0)} km/h', Colors.white70),
            _trafficInfoRow('Source', tp.source, Colors.white54),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _trafficInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  void _showLiveReportInfo(
      String type, String desc, double lat, double lng, String docId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(_iconForReportType(type),
                    color: _colorForReportType(type), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
            const SizedBox(height: 16),
            // Delete button — only if the report belongs to the current user
            if (docId.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await FirebaseFirestore.instance
                          .collection('CommunityReports')
                          .doc(docId)
                          .delete();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report deleted'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                  label: const Text('Delete Report',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Fallback mock polylines (only used when no live data) ──
  List<Polyline> get _fallbackTrafficPolylines => [
        Polyline(
          points:
              MockData.greenRoute.map((p) => LatLng(p[0], p[1])).toList(),
          color: AppColors.trafficGreen,
          strokeWidth: 5,
        ),
        Polyline(
          points:
              MockData.yellowRoute.map((p) => LatLng(p[0], p[1])).toList(),
          color: AppColors.trafficYellow,
          strokeWidth: 5,
        ),
        Polyline(
          points:
              MockData.redRoute.map((p) => LatLng(p[0], p[1])).toList(),
          color: AppColors.trafficRed,
          strokeWidth: 5,
        ),
      ];

  // ── Route-specific polylines (shown after Find Routes) ──
  List<Polyline> _buildRoutePolylines(RouteService routeService) {
    if (!routeService.showRoutesOnMap || routeService.currentRoutes.isEmpty) {
      return [];
    }

    final highlighted = routeService.highlightedRouteIndex;
    final routes = routeService.currentRoutes;

    return List.generate(routes.length, (i) {
      final route = routes[i];
      final isHighlighted = highlighted == i;

      // Use real polyline points from OSRM, fall back to mock
      List<LatLng> points;
      if (route.polylinePoints.isNotEmpty) {
        points = route.polylinePoints
            .map((p) => LatLng(p[0], p[1]))
            .toList();
      } else if (i < MockData.routePolylines.length) {
        points = MockData.routePolylines[i]
            .map((p) => LatLng(p[0], p[1]))
            .toList();
      } else {
        return Polyline(points: [], color: Colors.transparent, strokeWidth: 0);
      }

      return Polyline(
        points: points,
        color: route.trafficLevel.color.withAlpha(isHighlighted ? 230 : 80),
        strokeWidth: isHighlighted ? 6.0 : 3.0,
      );
    });
  }

  List<Marker> _buildRouteIncidentMarkers() {
    return MockData.routeIncidents.map((incident) {
      final isProtest = incident['type'] == 'protest';
      return Marker(
        point: LatLng(
          incident['lat'] as double,
          incident['lng'] as double,
        ),
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: (isProtest ? Colors.red : Colors.orange).withAlpha(40),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isProtest ? Icons.groups : Icons.car_crash,
            color: isProtest ? Colors.red : Colors.orange,
            size: 22,
          ),
        ),
      );
    }).toList();
  }

  void _openRoutePlanning({String? from, String? to}) {
    _showRoutePlanningSheet(prefillFrom: from, prefillTo: to);
  }

  void _openReportSheet() {
    _showAddReportSheet();
  }

  List<Polyline> get _simplePolylines => [
        Polyline(
          points:
              MockData.greenRoute.map((p) => LatLng(p[0], p[1])).toList(),
          color: AppColors.primary,
          strokeWidth: 3,
        ),
        Polyline(
          points:
              MockData.yellowRoute.map((p) => LatLng(p[0], p[1])).toList(),
          color: AppColors.primary.withAlpha(140),
          strokeWidth: 3,
        ),
        Polyline(
          points:
              MockData.redRoute.map((p) => LatLng(p[0], p[1])).toList(),
          color: AppColors.primary.withAlpha(90),
          strokeWidth: 3,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final themeSvc = context.watch<ThemeService>();
    final routeService = context.watch<RouteService>();
    final connMgr = context.watch<ConnectionManager>();
    final isDark = themeSvc.isDarkMode;
    final mapMode = themeSvc.mapDisplayMode;
    final isNavigating = routeService.isNavigating;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          // OpenStreetMap
          _buildOSMap(isDark, mapMode, routeService),

          // Search bar at top (hidden during navigation)
          if (!isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _openRoutePlanning(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: Colors.white70),
                          SizedBox(width: 12),
                          Text(
                            'Where are you going?',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 15),
                          ),
                          Spacer(),
                          Icon(Icons.directions,
                              color: Color(0xFF00897B)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Location permission banner — Pathao-style "Allow" prompt
          if (!isNavigating && _locationDenied)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: _requestLocationPermission,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E).withAlpha(240),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withAlpha(80)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(40),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_off_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location access needed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Allow location to see traffic near you',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Allow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Location loading indicator
          if (!isNavigating && _locationLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E).withAlpha(230),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Finding your location...',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // Event banner (below search bar, hidden during navigation)
          if (!isNavigating && !_locationDenied && !_locationLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 16,
              right: 16,
              child: EventCarousel(
                events: MockData.kathmanduEvents,
                onEventTap: (event) => _showEventDetails(event),
              ),
            ),

          // Quick route chips (below event banner, hidden during navigation)
          if (!isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 180,
              left: 16,
              right: 16,
              child: _buildQuickRouteChips(),
            ),

          // Weather widget — hidden in Minimal mode and during navigation
          if (mapMode != MapDisplayMode.minimal && !isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 226,
              right: 16,
              child: const WeatherWidget(),
            ),

          // Traffic legend — only in Color-coded mode, not during navigation
          if (mapMode == MapDisplayMode.colorCoded && !isNavigating)
            const Positioned(
              bottom: 16,
              left: 16,
              child: TrafficLegend(),
            ),

          // Connection status indicator — shows map source, not backend
          if (!isNavigating)
            Positioned(
              bottom: mapMode == MapDisplayMode.colorCoded ? 60 : 16,
              left: 16,
              child: GestureDetector(
                onTap: () async {
                  if (!mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await connMgr.checkNow();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(result
                          ? 'Backend connected — live traffic data'
                          : 'Map online — backend not reachable'),
                      backgroundColor: result
                          ? Colors.green
                          : const Color(0xFF00897B),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E).withAlpha(220),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: connMgr.isOnline
                              ? Colors.green
                              : const Color(0xFF00897B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        connMgr.isOnline ? 'Live' : 'Online',
                        style: TextStyle(
                          color: connMgr.isOnline
                              ? Colors.green
                              : const Color(0xFF00897B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // FABs at bottom-right (hidden during navigation)
          if (!isNavigating)
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'report_fab',
                    onPressed: _openReportSheet,
                    backgroundColor: AppColors.accent,
                    child: const Icon(Icons.warning_amber,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'location_fab',
                    onPressed: _locateMe,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      _userLocation != null
                          ? Icons.my_location
                          : Icons.location_searching,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // Navigation mode overlay
          if (isNavigating)
            NavigationOverlay(
              routeName: routeService.navigatingRouteName ?? '',
              etaMinutes: routeService.navigatingEta,
              alternativeRouteNames: routeService.currentRoutes
                  .where((r) =>
                      r.name != routeService.navigatingRouteName)
                  .map((r) => r.name)
                  .toList(),
              onSwitchRoute: (newIndex, newName) {
                routeService.switchRoute(newIndex, newName);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Route updated! Now via $newName'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              onEndNavigation: () {
                routeService.stopNavigation();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Navigation ended'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOSMap(
      bool isDark, MapDisplayMode mapMode, RouteService routeService) {
    final routePolylines = _buildRoutePolylines(routeService);
    final hasRoutePolylines = routePolylines.isNotEmpty;
    final hasLiveReports = _liveReports.isNotEmpty;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(
            AppConstants.kathmanduLat, AppConstants.kathmanduLng),
        initialZoom: AppConstants.defaultZoom,
        maxZoom: 18,
        minZoom: 5,
      ),
      children: [
        TileLayer(
          urlTemplate: AppConstants.osmTileUrl,
          userAgentPackageName: 'com.wayture.app',
          maxZoom: 18,
          keepBuffer: 5,
          evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
        ),
        // Traffic polylines (shown when no route search is active)
        if (!hasRoutePolylines && mapMode == MapDisplayMode.colorCoded)
          PolylineLayer(polylines: _fallbackTrafficPolylines),
        if (!hasRoutePolylines && mapMode == MapDisplayMode.simple)
          PolylineLayer(polylines: _simplePolylines),
        // Route polylines (from Find Routes)
        if (hasRoutePolylines) PolylineLayer(polylines: routePolylines),
        // ALWAYS show Kathmandu hotspot markers (colored by live data if available)
        if (!hasRoutePolylines && mapMode != MapDisplayMode.minimal)
          MarkerLayer(markers: _hotspotMarkers),
        // LIVE community report markers from Firestore
        if (!hasRoutePolylines && hasLiveReports &&
            mapMode == MapDisplayMode.colorCoded)
          MarkerLayer(markers: _liveIncidentMarkers),
        // Route-specific incident markers
        if (hasRoutePolylines)
          MarkerLayer(markers: _buildRouteIncidentMarkers()),
        // User location marker — pulsing blue dot
        if (_userLocation != null)
          MarkerLayer(markers: [_buildUserLocationMarker()]),
      ],
    );
  }

  Marker _buildUserLocationMarker() {
    return Marker(
      point: _userLocation!,
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withAlpha(30),
            ),
          ),
          // Middle ring
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withAlpha(60),
            ),
          ),
          // Inner dot
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(100),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Route Chips ──
  Widget _buildQuickRouteChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _quickRouteChip(
            icon: Icons.home,
            label: 'Home → Work',
            from: 'Koteshwor Chowk',
            to: 'Lazimpat',
          ),
          const SizedBox(width: 8),
          _quickRouteChip(
            icon: Icons.star,
            label: 'Koteshwor → Thamel',
            from: 'Koteshwor Chowk',
            to: 'Thamel',
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Save routes from route planning'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: AppColors.primary, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickRouteChip({
    required IconData icon,
    required String label,
    required String from,
    required String to,
  }) {
    return GestureDetector(
      onTap: () => _openRoutePlanning(from: from, to: to),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style:
                  const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── Event Details Bottom Sheet ──
  void _showEventDetails(KathmanduEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${event.emoji} ${event.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: event.affectedAreas.map((area) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      area,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _openRoutePlanning();
                  },
                  icon: const Icon(Icons.alt_route, size: 18),
                  label: const Text(
                    'Avoid this area',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Route Planning Bottom Sheet ──
  void _showRoutePlanningSheet({String? prefillFrom, String? prefillTo}) {
    // Capture service reference BEFORE opening the sheet so we don't
    // use context.read inside the callback (widget may be disposed).
    final routeService = context.read<RouteService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoutePlanningSheet(
        prefillFrom: prefillFrom,
        prefillTo: prefillTo,
        onNavigate: (index, name) {
          routeService.startNavigation(index, name);
          _highlightRoute(index, routeService);
        },
      ),
    );
  }

  void _highlightRoute(int index, [RouteService? rs]) {
    final routeService = rs ?? context.read<RouteService>();
    final routes = routeService.currentRoutes;
    if (index < routes.length && routes[index].polylinePoints.isNotEmpty) {
      final points = routes[index].polylinePoints;
      final midIdx = points.length ~/ 2;
      _mapController.move(LatLng(points[midIdx][0], points[midIdx][1]), 14);
    } else if (index < MockData.routePolylines.length) {
      final points = MockData.routePolylines[index];
      final midIdx = points.length ~/ 2;
      _mapController.move(LatLng(points[midIdx][0], points[midIdx][1]), 14);
    }
  }

  // ── Add Report Bottom Sheet ──
  void _showAddReportSheet() async {
    IncidentType selectedType = IncidentType.accident;
    final descController = TextEditingController();

    try {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Report an Incident',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<IncidentType>(
                          value: selectedType,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2A2A4E),
                          style:
                              const TextStyle(color: Colors.white),
                          items: IncidentType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Text(type.emoji,
                                      style: const TextStyle(
                                          fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(type.label),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setSheetState(
                                  () => selectedType = v);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: descController,
                      hintText: 'Describe the incident...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.white70, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Location: Detected from GPS',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final desc = descController.text.trim().isEmpty
                              ? 'Reported via app'
                              : descController.text.trim();

                          // 1. Get current GPS location
                          double lat = AppConstants.kathmanduLat;
                          double lng = AppConstants.kathmanduLng;
                          try {
                            LocationPermission permission =
                                await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission =
                                  await Geolocator.requestPermission();
                            }
                            if (permission != LocationPermission.denied &&
                                permission !=
                                    LocationPermission.deniedForever) {
                              final pos = await Geolocator.getCurrentPosition(
                                desiredAccuracy: LocationAccuracy.high,
                              );
                              lat = pos.latitude;
                              lng = pos.longitude;
                            }
                          } catch (e) {
                            debugPrint('GPS error: $e');
                          }

                          // Map IncidentType enum -> backend report_type string
                          final backendType = switch (selectedType) {
                            IncidentType.accident => 'accident',
                            IncidentType.trafficJam => 'traffic_jam',
                            IncidentType.roadBlock => 'road_closure',
                            IncidentType.construction => 'construction',
                            IncidentType.weatherIssue => 'flooding',
                            IncidentType.protest => 'other',
                          };

                          // 2. POST to FastAPI backend (Authorization header
                          //    is now attached automatically by ApiService).
                          bool postOk = false;
                          try {
                            postOk = await ApiService.submitReport(
                              type: backendType,
                              description: desc,
                              latitude: lat,
                              longitude: lng,
                            );
                          } catch (e) {
                            debugPrint('Backend submit error: $e');
                          }

                          // 3. ALWAYS write to Firestore so the report is
                          //    never lost — even if the backend POST failed.
                          try {
                            final uid = FirebaseAuth
                                    .instance.currentUser?.uid ??
                                'anonymous';
                            await FirebaseFirestore.instance
                                .collection('CommunityReports')
                                .add({
                              'uid': uid,
                              'type': backendType,
                              'report_type': backendType,
                              'description': desc,
                              'latitude': lat,
                              'longitude': lng,
                              'timestamp': FieldValue.serverTimestamp(),
                              'created_at': FieldValue.serverTimestamp(),
                              'upvotes': 0,
                            });
                          } catch (e) {
                            debugPrint('Firestore write error: $e');
                          }

                          if (!mounted) return;
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(postOk
                                  ? 'Report submitted successfully'
                                  : 'Report saved'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text(
                          'Submit Report',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    } finally {
      descController.dispose();
    }
  }
}
