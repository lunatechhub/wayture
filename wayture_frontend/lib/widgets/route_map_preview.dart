import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayture/models/route_model.dart';
import 'package:wayture/services/mock_data.dart';

class RouteMapPreview extends StatefulWidget {
  final List<RouteModel> routes;
  final int? selectedRouteIndex;
  final ValueChanged<int>? onRouteTapped;

  const RouteMapPreview({
    super.key,
    required this.routes,
    this.selectedRouteIndex,
    this.onRouteTapped,
  });

  @override
  State<RouteMapPreview> createState() => _RouteMapPreviewState();
}

class _RouteMapPreviewState extends State<RouteMapPreview> {
  int? _highlightedIndex;

  List<List<LatLng>> get _routePolylines {
    return List.generate(widget.routes.length, (i) {
      final route = widget.routes[i];
      if (route.polylinePoints.isNotEmpty) {
        return route.polylinePoints
            .map((p) => LatLng(p[0], p[1]))
            .toList();
      }
      // Fallback to mock data
      if (i < MockData.routePolylines.length) {
        return MockData.routePolylines[i]
            .map((p) => LatLng(p[0], p[1]))
            .toList();
      }
      return <LatLng>[];
    });
  }

  /// Compute map center from all route points.
  LatLng get _mapCenter {
    final allPoints = _routePolylines.expand((p) => p).toList();
    if (allPoints.isEmpty) return const LatLng(27.7000, 85.3300);
    double latSum = 0, lngSum = 0;
    for (final p in allPoints) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / allPoints.length, lngSum / allPoints.length);
  }

  Color _routeColor(int index) {
    if (index >= widget.routes.length) return const Color(0xFF4CAF50);
    switch (widget.routes[index].trafficLevel) {
      case TrafficLevel.light:
        return const Color(0xFF4CAF50);
      case TrafficLevel.moderate:
        return const Color(0xFFFFC107);
      case TrafficLevel.heavy:
        return const Color(0xFFF44336);
    }
  }

  @override
  Widget build(BuildContext context) {
    final polylines = _routePolylines;
    if (polylines.isEmpty || polylines.every((p) => p.isEmpty)) {
      return const SizedBox.shrink();
    }
    final highlighted = _highlightedIndex ?? widget.selectedRouteIndex;

    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wayture.app',
              ),
              PolylineLayer(
                polylines: List.generate(polylines.length, (i) {
                  if (polylines[i].isEmpty) {
                    return Polyline(points: [], color: Colors.transparent, strokeWidth: 0);
                  }
                  final isHighlighted = highlighted == i;
                  return Polyline(
                    points: polylines[i],
                    color:
                        _routeColor(i).withAlpha(isHighlighted ? 230 : 100),
                    strokeWidth: isHighlighted ? 5.0 : 3.0,
                  );
                }),
              ),
            ],
          ),
          // Overlay route selector chips
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.routes.length, (i) {
                final isActive = highlighted == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _highlightedIndex = i);
                      widget.onRouteTapped?.call(i);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _routeColor(i)
                            : const Color(0xFF1A1A2E).withAlpha(200),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _routeColor(i).withAlpha(isActive ? 255 : 100),
                        ),
                      ),
                      child: Text(
                        widget.routes[i].name,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
