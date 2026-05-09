import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:wayture/models/simple_route.dart';
import 'package:wayture/services/api_service.dart';

/// Find Routes demo screen.
///
/// User flow (for the presentation):
///   1. Type an origin (e.g. "Koteshwor") and destination (e.g. "Thamel")
///   2. Tap "Find Routes"
///   3. Screen calls GET /api/simple/find-routes on the FastAPI backend
///   4. Up to 3 colored polylines appear on the OpenStreetMap map
///      (green = free-flowing, orange = moderate, red = heavy traffic)
///   5. A card under the map summarises each route's ETA and distance
///
/// This screen is intentionally self-contained — no Firebase, no provider,
/// just text fields, an HTTP call, and flutter_map.
class FindRoutesScreen extends StatefulWidget {
  const FindRoutesScreen({super.key});

  @override
  State<FindRoutesScreen> createState() => _FindRoutesScreenState();
}

class _FindRoutesScreenState extends State<FindRoutesScreen> {
  // Controllers for the two search boxes.
  final TextEditingController _originController =
      TextEditingController(text: 'Koteshwor');
  final TextEditingController _destController =
      TextEditingController(text: 'Thamel');

  // Map controller used to fit the camera to the routes.
  final MapController _mapController = MapController();

  // Center the map on Kathmandu by default so the first frame looks right
  // even before any routes have been fetched.
  static const LatLng _kathmanduCenter = LatLng(27.7172, 85.3240);

  // State that drives the UI.
  bool _loading = false;
  String? _errorMessage;
  SimpleRoutesResponse? _response;

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  /// Call the backend and update the UI with the 3 routes.
  Future<void> _onFindRoutesPressed() async {
    final origin = _originController.text.trim();
    final destination = _destController.text.trim();

    // Guard: both boxes must be filled in.
    if (origin.isEmpty || destination.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both an origin and a destination.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _response = null;
    });

    try {
      final result = await ApiService.findSimpleRoutes(
        origin: origin,
        destination: destination,
      );

      if (!mounted) return;

      // If the backend returned zero routes, treat it as an error.
      if (result.routes.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'No routes found. Try different place names.';
        });
        return;
      }

      setState(() {
        _response = result;
        _loading = false;
      });

      // Fit the map camera to show every route end-to-end.
      _fitMapToRoutes(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Zoom + center the map so all route polylines fit on screen.
  void _fitMapToRoutes(SimpleRoutesResponse r) {
    final allPoints = <LatLng>[
      r.originLatLng,
      r.destinationLatLng,
      for (final route in r.routes) ...route.points,
    ];
    if (allPoints.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(allPoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Routes'),
      ),
      body: Column(
        children: [
          _buildSearchCard(),
          if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
          Expanded(child: _buildMap()),
          if (_response != null) _buildRouteSummary(_response!),
        ],
      ),
    );
  }

  // ── UI pieces ──────────────────────────────────────────────────────────

  /// Top card with the two input fields and the Find Routes button.
  Widget _buildSearchCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _originController,
              decoration: const InputDecoration(
                labelText: 'From',
                hintText: 'e.g. Koteshwor',
                prefixIcon: Icon(Icons.trip_origin, color: Colors.green),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _destController,
              decoration: const InputDecoration(
                labelText: 'To',
                hintText: 'e.g. Thamel',
                prefixIcon: Icon(Icons.place, color: Colors.red),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _onFindRoutesPressed,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.alt_route),
                label: Text(_loading ? 'Finding routes...' : 'Find Routes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Red banner that shows error messages from the API or validation.
  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// OpenStreetMap tile layer + one colored Polyline per route.
  Widget _buildMap() {
    // Build the polylines in reverse so the first (fastest) route ends up
    // on top when drawn.
    final polylines = <Polyline>[];
    if (_response != null) {
      final reversed = _response!.routes.reversed.toList();
      for (final r in reversed) {
        polylines.add(Polyline(
          points: r.points,
          color: r.color,
          strokeWidth: r.index == 0 ? 6.0 : 4.5, // fastest route is thickest
        ));
      }
    }

    // Origin + destination pins (only shown when we have a response).
    final markers = <Marker>[];
    if (_response != null) {
      markers.add(Marker(
        point: _response!.originLatLng,
        width: 40,
        height: 40,
        child: const Icon(Icons.trip_origin, color: Colors.green, size: 32),
      ));
      markers.add(Marker(
        point: _response!.destinationLatLng,
        width: 40,
        height: 40,
        child: const Icon(Icons.place, color: Colors.red, size: 36),
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _kathmanduCenter,
        initialZoom: 13,
        minZoom: 3,
        maxZoom: 19,
      ),
      children: [
        // Free OpenStreetMap tiles — no API key required.
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.wayture.app',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  /// Scrollable summary card at the bottom — one row per route.
  Widget _buildRouteSummary(SimpleRoutesResponse r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.routes.length} route${r.routes.length == 1 ? '' : 's'} found',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          for (final route in r.routes) _buildRouteRow(route),
        ],
      ),
    );
  }

  /// One row inside the summary — color dot, label, distance, ETA, badge.
  Widget _buildRouteRow(SimpleRoute route) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Color dot matches the polyline on the map.
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: route.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              route.label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${route.distanceKm.toStringAsFixed(1)} km  •  '
            '${route.durationMinutes.toStringAsFixed(0)} min',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 8),
          _congestionBadge(route.congestion, route.color),
        ],
      ),
    );
  }

  /// Little pill that spells out the congestion level in words.
  Widget _congestionBadge(String congestion, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        congestion.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
