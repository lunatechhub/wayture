import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wayture/models/traffic_model.dart';

/// Direct Firestore reads for real-time traffic streams.
///
/// This service connects directly to Firestore (not via the FastAPI backend)
/// so the Flutter app receives instant updates via Firestore's built-in
/// snapshot listeners — no polling needed.
///
/// Collections:
///   traffic_realtime  — one doc per location, updated by backend/sensors
///   traffic_data      — historical traffic records (for listing)
///   communityReports  — community-submitted incident reports
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Real-Time Traffic Stream ──────────────────────────────────

  /// Stream all real-time traffic documents.
  /// Each document represents the CURRENT traffic state at a location.
  /// Firestore pushes updates automatically — no polling.
  Stream<List<TrafficData>> realtimeTrafficStream() {
    return _db
        .collection('traffic_realtime')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return TrafficData.fromFirestore(doc.id, doc.data());
            }).toList());
  }

  /// Stream traffic data for a specific location.
  Stream<List<TrafficData>> locationTrafficStream(String location) {
    return _db
        .collection('traffic_data')
        .where('location_name', isEqualTo: location)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return TrafficData.fromFirestore(doc.id, doc.data());
            }).toList());
  }

  // ── Historical Traffic Data ───────────────────────────────────

  /// Fetch the latest N traffic records (one-time read).
  Future<List<TrafficData>> getRecentTraffic({int limit = 100}) async {
    try {
      final snapshot = await _db
          .collection('traffic_data')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => TrafficData.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('FirestoreService.getRecentTraffic error: $e');
      return [];
    }
  }

  /// Fetch traffic data for a specific location (one-time read).
  Future<List<TrafficData>> getTrafficByLocation(String location) async {
    try {
      final snapshot = await _db
          .collection('traffic_data')
          .where('location_name', isEqualTo: location)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => TrafficData.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('FirestoreService.getTrafficByLocation error: $e');
      return [];
    }
  }

  // ── Community Reports Stream ──────────────────────────────────

  /// Stream community reports (used by map_screen for markers).
  Stream<List<Map<String, dynamic>>> communityReportsStream() {
    return _db
        .collection('communityReports')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // ── Write traffic data directly to Firestore ──────────────────

  /// Submit a traffic observation directly (bypass backend).
  /// Useful for device-side submissions.
  Future<void> submitTrafficUpdate({
    required String location,
    required double latitude,
    required double longitude,
    required String congestionLevel,
    int vehicleCount = 0,
    double averageSpeed = 30.0,
  }) async {
    final docId = location.toLowerCase().replaceAll(' ', '_');
    try {
      await _db.collection('traffic_realtime').doc(docId).set({
        'location_name': location,
        'latitude': latitude,
        'longitude': longitude,
        'congestion_level': congestionLevel,
        'vehicle_count': vehicleCount,
        'average_speed_kmh': averageSpeed,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.submitTrafficUpdate error: $e');
    }
  }

  // ── App Ratings Stream ─────────────────────────────────────────

  /// Stream all app ratings (for real-time summary display).
  Stream<List<Map<String, dynamic>>> ratingsStream() {
    return _db.collection('appRatings').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  /// Fetch a single user's rating (one-time read).
  Future<Map<String, dynamic>?> getUserRating(String uid) async {
    try {
      final doc = await _db.collection('appRatings').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      debugPrint('FirestoreService.getUserRating error: $e');
      return null;
    }
  }

  /// Fetch rating summary (one-time read, computed client-side).
  Future<Map<String, dynamic>> getRatingSummary() async {
    try {
      final snapshot = await _db.collection('appRatings').get();
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        return {
          'total_ratings': 0,
          'average_stars': 0.0,
          'star_distribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
        };
      }

      final stars = docs.map((d) => (d.data()['stars'] as num?)?.toInt() ?? 0).toList();
      final avg = stars.reduce((a, b) => a + b) / stars.length;
      final dist = {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0};
      for (final s in stars) {
        final key = s.clamp(1, 5).toString();
        dist[key] = (dist[key] ?? 0) + 1;
      }

      return {
        'total_ratings': docs.length,
        'average_stars': double.parse(avg.toStringAsFixed(1)),
        'star_distribution': dist,
      };
    } catch (e) {
      debugPrint('FirestoreService.getRatingSummary error: $e');
      return {
        'total_ratings': 0,
        'average_stars': 0.0,
        'star_distribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
      };
    }
  }

  // ── Saved Routes ────────────────────────────────────────────────

  /// Save a route to Firestore under users/{uid}/savedRoutes.
  Future<void> saveRoute({
    required String uid,
    required String from,
    required String to,
    required String routeName,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('savedRoutes')
          .add({
        'from': from,
        'to': to,
        'routeName': routeName,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.saveRoute error: $e');
    }
  }

  /// Stream all saved routes for a user.
  Stream<List<Map<String, dynamic>>> savedRoutesStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('savedRoutes')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Get saved routes count for a user (one-time read).
  Future<int> getSavedRoutesCount(String uid) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('savedRoutes')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('FirestoreService.getSavedRoutesCount error: $e');
      return 0;
    }
  }

  /// Delete a saved route.
  Future<void> deleteSavedRoute(String uid, String routeId) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('savedRoutes')
          .doc(routeId)
          .delete();
    } catch (e) {
      debugPrint('FirestoreService.deleteSavedRoute error: $e');
    }
  }

  // ── Utility: get all unique location names ────────────────────

  Future<List<String>> getLocationNames() async {
    try {
      final snapshot = await _db.collection('traffic_realtime').get();
      return snapshot.docs
          .map((doc) => doc.data()['location_name'] as String? ?? doc.id)
          .toSet()
          .toList()
        ..sort();
    } catch (e) {
      debugPrint('FirestoreService.getLocationNames error: $e');
      return [];
    }
  }
}
