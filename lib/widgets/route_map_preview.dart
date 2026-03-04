import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayture/models/route_model.dart';

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

  // Generate mock polylines for each route (spread around Kathmandu center)
  List<List<LatLng>> get _routePolylines {
    const center = LatLng(27.7090, 85.3120);
    return List.generate(widget.routes.length, (i) {
      final offset = (i - 1) * 0.008;
      return [
        LatLng(center.latitude - 0.015, center.longitude - 0.02 + offset),
        LatLng(center.latitude - 0.005, center.longitude - 0.01 + offset * 0.5),
        LatLng(center.latitude + 0.005, center.longitude + offset * 0.3),
        LatLng(center.latitude + 0.012, center.longitude + 0.015 + offset),
      ];
    });
  }

  Color _routeColor(int index) {
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
            options: const MapOptions(
              initialCenter: LatLng(27.7090, 85.3120),
              initialZoom: 13.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wayture.app',
              ),
              PolylineLayer(
                polylines: List.generate(polylines.length, (i) {
                  final isHighlighted = highlighted == i;
                  return Polyline(
                    points: polylines[i],
                    color: _routeColor(i).withAlpha(isHighlighted ? 230 : 100),
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
                          color: _routeColor(i).withAlpha(isActive ? 255 : 100),
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
