import 'package:flutter/material.dart';

/// Map display modes for the home screen map.
enum MapDisplayMode { colorCoded, simple, minimal }

/// App-wide theme & display settings, exposed via Provider.
class ThemeService extends ChangeNotifier {
  bool _isDarkMode = false;
  MapDisplayMode _mapDisplayMode = MapDisplayMode.colorCoded;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  MapDisplayMode get mapDisplayMode => _mapDisplayMode;

  void toggleDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setMapDisplayMode(MapDisplayMode mode) {
    _mapDisplayMode = mode;
    notifyListeners();
  }
}
