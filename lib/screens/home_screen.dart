import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/kathmandu_event.dart';
import 'package:wayture/models/report_model.dart';
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

  // ── Default traffic polylines ──
  List<Polyline> get _trafficPolylines => [
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

  List<Marker> get _incidentMarkers {
    return MockData.reports.map((report) {
      return Marker(
        point: LatLng(report.latitude, report.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showMarkerInfo(report),
          child: Icon(
            _iconForType(report.type),
            color: _colorForType(report.type),
            size: 30,
          ),
        ),
      );
    }).toList();
  }

  // ── Route-specific polylines (shown after Find Routes) ──
  List<Polyline> _buildRoutePolylines(RouteService routeService) {
    if (!routeService.showRoutesOnMap || routeService.currentRoutes.isEmpty) {
      return [];
    }

    final highlighted = routeService.highlightedRouteIndex;
    final routeCount = routeService.currentRoutes.length
        .clamp(0, MockData.routePolylines.length);

    final colors = [AppColors.trafficGreen, AppColors.trafficYellow, AppColors.trafficRed];

    return List.generate(routeCount, (i) {
      final isHighlighted = highlighted == i;
      final points = MockData.routePolylines[i]
          .map((p) => LatLng(p[0], p[1]))
          .toList();
      return Polyline(
        points: points,
        color: colors[i].withAlpha(isHighlighted ? 230 : 80),
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

  IconData _iconForType(IncidentType type) {
    switch (type) {
      case IncidentType.accident:
        return Icons.car_crash;
      case IncidentType.trafficJam:
        return Icons.traffic;
      case IncidentType.roadBlock:
        return Icons.block;
      case IncidentType.protest:
        return Icons.groups;
      case IncidentType.construction:
        return Icons.construction;
      case IncidentType.weatherIssue:
        return Icons.thunderstorm;
    }
  }

  Color _colorForType(IncidentType type) {
    switch (type) {
      case IncidentType.accident:
        return Colors.red;
      case IncidentType.trafficJam:
        return Colors.orange;
      case IncidentType.roadBlock:
        return Colors.deepOrange;
      case IncidentType.protest:
        return Colors.purple;
      case IncidentType.construction:
        return Colors.brown;
      case IncidentType.weatherIssue:
        return Colors.blueGrey;
    }
  }

  void _showMarkerInfo(ReportModel report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${report.type.label} — ${report.location}'),
        backgroundColor: AppColors.primary,
      ),
    );
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

          // Event banner (below search bar, hidden during navigation)
          if (!isNavigating)
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

          // Connection status indicator
          if (!isNavigating && connMgr.hasChecked)
            Positioned(
              bottom: mapMode == MapDisplayMode.colorCoded ? 60 : 16,
              left: 16,
              child: GestureDetector(
                onTap: () async {
                  final result = await connMgr.checkNow();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result
                            ? 'Connected to server'
                            : 'Offline — using local data'),
                        backgroundColor: result ? Colors.green : Colors.orange,
                      ),
                    );
                  }
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
                              : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        connMgr.isOnline ? 'Live' : 'Offline',
                        style: TextStyle(
                          color: connMgr.isOnline
                              ? Colors.green
                              : Colors.red,
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
                    onPressed: () {
                      _mapController.move(
                        const LatLng(AppConstants.kathmanduLat,
                            AppConstants.kathmanduLng),
                        15,
                      );
                    },
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.my_location,
                        color: Colors.white),
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
          urlTemplate: isDark
              ? AppConstants.osmDarkTileUrl
              : AppConstants.osmTileUrl,
          userAgentPackageName: 'com.wayture.app',
        ),
        // Default traffic polylines (hidden when route polylines are shown)
        if (!hasRoutePolylines && mapMode == MapDisplayMode.colorCoded)
          PolylineLayer(polylines: _trafficPolylines),
        if (!hasRoutePolylines && mapMode == MapDisplayMode.simple)
          PolylineLayer(polylines: _simplePolylines),
        // Route polylines (from Find Routes)
        if (hasRoutePolylines) PolylineLayer(polylines: routePolylines),
        // Default incident markers
        if (mapMode == MapDisplayMode.colorCoded && !hasRoutePolylines)
          MarkerLayer(markers: _incidentMarkers),
        // Route-specific incident markers
        if (hasRoutePolylines)
          MarkerLayer(markers: _buildRouteIncidentMarkers()),
      ],
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoutePlanningSheet(
        prefillFrom: prefillFrom,
        prefillTo: prefillTo,
        onNavigate: (index, name) {
          final routeService = context.read<RouteService>();
          routeService.startNavigation(index, name);
          _highlightRoute(index);
        },
      ),
    );
  }

  void _highlightRoute(int index) {
    if (index < MockData.routePolylines.length) {
      final points = MockData.routePolylines[index];
      final midIdx = points.length ~/ 2;
      _mapController.move(LatLng(points[midIdx][0], points[midIdx][1]), 14);
    }
  }

  // ── Add Report Bottom Sheet ──
  void _showAddReportSheet() {
    IncidentType selectedType = IncidentType.accident;
    final descController = TextEditingController();

    showModalBottomSheet(
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
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Report submitted successfully!'),
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
  }
}
