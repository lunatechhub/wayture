import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/report_model.dart';
import 'package:wayture/services/mock_data.dart';
import 'package:wayture/widgets/traffic_legend.dart';
import 'package:wayture/widgets/weather_widget.dart';
import 'package:wayture/services/theme_service.dart';
import 'package:wayture/widgets/route_planning_sheet.dart';
import 'package:wayture/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';

/// Home / Map screen — the core screen of the app.
/// Shows OpenStreetMap centered on Kathmandu with traffic overlays.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  List<Polyline> get _trafficPolylines => [
    // Green: Lazimpat -> Thamel (light traffic)
    Polyline(
      points: MockData.greenRoute.map((p) => LatLng(p[0], p[1])).toList(),
      color: AppColors.trafficGreen,
      strokeWidth: 5,
    ),
    // Yellow: Koteshwor -> Tinkune (moderate)
    Polyline(
      points: MockData.yellowRoute.map((p) => LatLng(p[0], p[1])).toList(),
      color: AppColors.trafficYellow,
      strokeWidth: 5,
    ),
    // Red: Kalanki -> Kalimati (heavy)
    Polyline(
      points: MockData.redRoute.map((p) => LatLng(p[0], p[1])).toList(),
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

  void _openRoutePlanning() {
    _showRoutePlanningSheet();
  }

  void _openReportSheet() {
    _showAddReportSheet();
  }

  // ── Polylines for "Simple" mode (single teal color) ──
  List<Polyline> get _simplePolylines => [
        Polyline(
          points: MockData.greenRoute.map((p) => LatLng(p[0], p[1])).toList(),
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
          points: MockData.redRoute.map((p) => LatLng(p[0], p[1])).toList(),
          color: AppColors.primary.withAlpha(90),
          strokeWidth: 3,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final themeSvc = context.watch<ThemeService>();
    final isDark = themeSvc.isDarkMode;
    final mapMode = themeSvc.mapDisplayMode;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          // OpenStreetMap
          _buildOSMap(isDark, mapMode),

          // Search bar at top
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _openRoutePlanning,
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

          // Weather widget — hidden in Minimal mode
          if (mapMode != MapDisplayMode.minimal)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              right: 16,
              child: const WeatherWidget(),
            ),

          // Traffic legend — only in Color-coded mode
          if (mapMode == MapDisplayMode.colorCoded)
            const Positioned(
              bottom: 16,
              left: 16,
              child: TrafficLegend(),
            ),

          // FABs at bottom-right
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Report incident
                FloatingActionButton.small(
                  heroTag: 'report_fab',
                  onPressed: _openReportSheet,
                  backgroundColor: AppColors.accent,
                  child: const Icon(Icons.warning_amber,
                      size: 20, color: Colors.white),
                ),
                const SizedBox(height: 10),
                // My location
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
                  child:
                      const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOSMap(bool isDark, MapDisplayMode mapMode) {
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
        // Map tiles — dark tiles in dark mode
        TileLayer(
          urlTemplate: isDark
              ? AppConstants.osmDarkTileUrl
              : AppConstants.osmTileUrl,
          userAgentPackageName: 'com.wayture.app',
        ),
        // Traffic polylines — mode-dependent
        if (mapMode == MapDisplayMode.colorCoded)
          PolylineLayer(polylines: _trafficPolylines),
        if (mapMode == MapDisplayMode.simple)
          PolylineLayer(polylines: _simplePolylines),
        // Incident markers — only in Color-coded mode
        if (mapMode == MapDisplayMode.colorCoded)
          MarkerLayer(markers: _incidentMarkers),
      ],
    );
  }

  // -- Route Planning Bottom Sheet --
  void _showRoutePlanningSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoutePlanningSheet(
        onNavigate: (index, name) {
          _highlightRoute(index);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigation started via $name'),
              backgroundColor: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  /// Zoom into the selected route on the map
  void _highlightRoute(int index) {
    final routeData = [MockData.greenRoute, MockData.yellowRoute, MockData.redRoute];
    if (index < routeData.length) {
      final points = routeData[index];
      // Center on the midpoint of the route
      final midIdx = points.length ~/ 2;
      _mapController.move(LatLng(points[midIdx][0], points[midIdx][1]), 15);
    }
  }

  // -- Add Report Bottom Sheet --
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
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
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
                    const Text(
                      'Report an Incident',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    // Type dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<IncidentType>(
                          value: selectedType,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2A2A4E),
                          style: const TextStyle(color: Colors.white),
                          items: IncidentType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Text(type.emoji, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(type.label),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setSheetState(() => selectedType = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Description
                    CustomTextField(
                      controller: descController,
                      hintText: 'Describe the incident...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    // Location info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.white70, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Location: Detected from GPS',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 48,
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
                              content: Text('Report submitted successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text(
                          'Submit Report',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
