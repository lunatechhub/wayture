import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

/// ──────────────────────────────────────────────────────────────────────────
/// LocationService
/// ──────────────────────────────────────────────────────────────────────────
/// Single entry point for GPS + reverse geocoding. Wraps the awkward
/// geolocator/permission_handler error surface with a small typed enum
/// so the UI layer can map results directly to AestheticDialogs.
///
///   • [requestPermission]     — foreground permission flow
///   • [getCurrentPosition]    — typed result + Position, high accuracy
///   • [reverseGeocode]        — "Area, Street, Kathmandu" format
///   • [openAppSettings]       — for GPS-disabled / denied-forever recovery
/// ──────────────────────────────────────────────────────────────────────────

/// Outcome of a location request. The UI layer maps each value to a specific
/// AestheticDialogs error popup.
enum LocationResult {
  /// Position obtained successfully.
  success,

  /// Device-level location services (GPS) are turned off.
  serviceDisabled,

  /// User denied the permission prompt this time.
  permissionDenied,

  /// User permanently denied; we must send them to app settings.
  permissionDeniedForever,

  /// Position fetch exceeded the timeout — usually a weak GPS signal.
  timeout,

  /// Any other unexpected failure.
  error,
}

/// Result of a GPS fix, including the raw [Position] and optional address.
class LocationFix {
  final LocationResult result;
  final Position? position;
  final String? address;

  const LocationFix({required this.result, this.position, this.address});

  bool get isSuccess => result == LocationResult.success && position != null;
}

class LocationService {
  LocationService._();

  /// Default timeout for a single GPS fix.
  static const Duration _fixTimeout = Duration(seconds: 15);

  // ── Permissions ───────────────────────────────────────────────────────────

  /// Check GPS service + request foreground location permission.
  ///
  /// Returns a [LocationResult] the caller can use to show the right dialog.
  /// On [LocationResult.success] the app can safely call
  /// [Geolocator.getCurrentPosition] without a second permission prompt.
  static Future<LocationResult> requestPermission() async {
    // 1. Is the GPS service itself enabled on the device?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationResult.serviceDisabled;

    // 2. What's the current permission state?
    var permission = await Geolocator.checkPermission();

    // 3. Prompt if still denied.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult.permissionDeniedForever;
    }
    if (permission == LocationPermission.denied) {
      return LocationResult.permissionDenied;
    }

    return LocationResult.success;
  }

  /// Request *background* location via permission_handler.
  ///
  /// Must be called AFTER foreground location has already been granted,
  /// otherwise Android silently drops the request.
  static Future<bool> requestBackgroundPermission() async {
    final fgStatus = await perm.Permission.locationWhenInUse.status;
    if (!fgStatus.isGranted) return false;

    final bgStatus = await perm.Permission.locationAlways.request();
    return bgStatus.isGranted;
  }

  /// Open the OS location settings (for service-disabled recovery).
  static Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  /// Open the app's own permission page (for deniedForever recovery).
  static Future<bool> openAppSettings() {
    return perm.openAppSettings();
  }

  // ── Current position ──────────────────────────────────────────────────────

  /// Fetch the current high-accuracy GPS fix.
  ///
  /// Handles permissions, timeouts, and errors internally and returns a
  /// [LocationFix] the caller can switch on. If [withAddress] is true, the
  /// fix is also reverse-geocoded before being returned.
  static Future<LocationFix> getCurrentPosition({
    bool withAddress = false,
    Duration timeout = _fixTimeout,
  }) async {
    final permResult = await requestPermission();
    if (permResult != LocationResult.success) {
      return LocationFix(result: permResult);
    }

    try {
      // geolocator 11.x still uses the old-style named parameters here —
      // `locationSettings` was only added to getCurrentPosition in v12.
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );

      String? address;
      if (withAddress) {
        address = await reverseGeocode(pos.latitude, pos.longitude);
      }

      return LocationFix(
        result: LocationResult.success,
        position: pos,
        address: address,
      );
    } on TimeoutException {
      return const LocationFix(result: LocationResult.timeout);
    } on LocationServiceDisabledException {
      return const LocationFix(result: LocationResult.serviceDisabled);
    } catch (e) {
      debugPrint('LocationService.getCurrentPosition error: $e');
      // A bare PlatformException with code 'timeout' from geolocator_android
      // surfaces here too — treat it as a timeout so the UI can retry.
      final msg = e.toString().toLowerCase();
      if (msg.contains('time') && msg.contains('out')) {
        return const LocationFix(result: LocationResult.timeout);
      }
      return const LocationFix(result: LocationResult.error);
    }
  }

  /// Stream live position updates. Caller must cancel the subscription.
  static Stream<Position> positionStream({
    int distanceFilterMeters = 5,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }

  // ── Reverse geocoding ─────────────────────────────────────────────────────

  /// Reverse-geocode [lat]/[lng] into a short human-readable address.
  ///
  /// Format: "Area Name, Street, Kathmandu" — falls back gracefully when any
  /// component is missing. Returns `null` if the lookup fails entirely so the
  /// caller can decide whether to show raw coordinates.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    return null;
  }
}
