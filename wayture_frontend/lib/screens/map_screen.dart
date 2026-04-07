import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Live Google Maps screen.
///
/// - Native Google traffic layer (real-time congestion colours on roads)
/// - User's real GPS via myLocationEnabled
/// - Real-time community report markers from Firestore (no polling)
/// - Optional location persistence to Firestore (one doc per user via set())
///
/// Routing is intentionally NOT done here — the home screen still owns the
/// route planning sheet (OSRM-backed). This screen is a pure live map.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Position? _currentPosition;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSub;
  StreamSubscription<Position>? _locationSub;
  bool _isLoading = true;

  // Kathmandu Durbar Square area — initial camera target.
  static const CameraPosition _kathmanduCenter = CameraPosition(
    target: LatLng(27.7172, 85.3240),
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
    _initLocation();
    _listenToFirestoreReports();
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      await _persistLocation(position);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );

      // Stream subsequent updates and persist them. distanceFilter keeps the
      // write rate sane — one update per 50 m of real movement.
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).listen((pos) {
        _persistLocation(pos);
        if (mounted) setState(() => _currentPosition = pos);
      });
    } catch (e) {
      debugPrint('MapScreen location error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// One Firestore doc per user, updated in place via set(merge: true).
  /// Avoids the "thousands of documents per user per day" write storm that
  /// .add() would cause on a moving driver.
  Future<void> _persistLocation(Position position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(user.uid)
          .set({
        'userid': user.uid,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Location persist error: $e');
    }
  }

  // ── Firestore real-time community reports ─────────────────

  void _listenToFirestoreReports() {
    _reportsSub = FirebaseFirestore.instance
        .collection('communityReports')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final newMarkers = <Marker>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        // Accept the rules-allowed type names AND the backend enum aliases
        // currently written by home_screen.dart's submit handler.
        final rawType =
            (data['type'] ?? data['report_type'] ?? 'jam').toString();

        final BitmapDescriptor icon;
        switch (rawType) {
          case 'accident':
            icon =
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
            break;
          case 'strike':
          case 'protest':
            icon = BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange);
            break;
          case 'roadblock':
          case 'road_closure':
            icon = BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet);
            break;
          default:
            // jam / traffic_jam / construction / flooding / other
            icon = BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow);
        }

        newMarkers.add(Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          icon: icon,
          infoWindow: InfoWindow(
            title: rawType.toUpperCase(),
            snippet: (data['description'] ?? '').toString(),
          ),
        ));
      }

      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
      });
    }, onError: (e) {
      debugPrint('communityReports stream error: $e');
    });
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _kathmanduCenter,
            mapType: MapType.normal,
            // The headline feature: native Google real-time traffic overlay.
            trafficEnabled: true,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                    15,
                  ),
                );
              }
            },
          ),

          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // Legend (bottom-left)
          Positioned(
            bottom: 24,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 6,
                    color: Colors.black26,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Incident Types',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _legendItem(Colors.red, 'Accident'),
                  _legendItem(Colors.orange, 'Strike'),
                  _legendItem(Colors.purple, 'Road Block'),
                  _legendItem(Colors.amber.shade700, 'Traffic Jam'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_pin, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }
}
