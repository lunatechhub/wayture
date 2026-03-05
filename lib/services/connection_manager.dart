import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wayture/services/api_service.dart';

/// Manages online/offline state for the app.
/// Checks connectivity on startup and periodically.
class ConnectionManager extends ChangeNotifier {
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  bool _hasChecked = false;
  bool get hasChecked => _hasChecked;

  Timer? _periodicCheck;

  /// Check connection once on startup.
  Future<void> initialize() async {
    _isOnline = await ApiService.checkConnection();
    _hasChecked = true;
    notifyListeners();

    // Re-check every 30 seconds
    _periodicCheck = Timer.periodic(const Duration(seconds: 30), (_) async {
      final wasOnline = _isOnline;
      _isOnline = await ApiService.checkConnection();
      if (wasOnline != _isOnline) {
        notifyListeners();
      }
    });
  }

  /// Force a manual connection check.
  Future<bool> checkNow() async {
    _isOnline = await ApiService.checkConnection();
    _hasChecked = true;
    notifyListeners();
    return _isOnline;
  }

  @override
  void dispose() {
    _periodicCheck?.cancel();
    super.dispose();
  }
}
