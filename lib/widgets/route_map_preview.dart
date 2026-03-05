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
    return List.generate(
      widget.routes.length.clamp(0, MockData.routePolylines.length),
      (i) => MockData.routePolylines[i]
          .map((p) => LatLng(p[0], p[1]))
          .toList(),
    );
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
    if (polylines.isEmpty) return const SizedBox.shrink();
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
              initialCenter: LatLng(27.7000, 85.3300),
              initialZoom: 13.0,
              interactionOptions: InteractionOptions(
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
                  final isHighlighted = highlighted == i;
                  return Polyline(
                    points: polylines[i],
                    color:
                        _routeColor(i).withAlpha(isHighlighted ? 230 : 100),
                    strokeWidth: isHighlighted ? 5.0 : 3.0,
                  );
                }),
              ),
              // Incident markers
              MarkerLayer(
                markers: MockData.routeIncidents.map((incident) {
                  final isProtest = incident['type'] == 'protest';
                  return Marker(
                    point: LatLng(
                      incident['lat'] as double,
                      incident['lng'] as double,
                    ),
                    width: 24,
                    height: 24,
                    child: Icon(
                      isProtest ? Icons.groups : Icons.car_crash,
                      color: isProtest ? Colors.red : Colors.orange,
                      size: 20,
                    ),
                  );
                }).toList(),
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
              children: List.generate(
                  widget.routes.length.clamp(0, polylines.length), (i) {
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
