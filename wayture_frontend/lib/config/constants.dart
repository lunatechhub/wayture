/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Wayture';
  static const String appVersion = '1.0.0';

  // Kathmandu center coordinates (from OpenStreetMap)
  static const double kathmanduLat = 27.70899;
  static const double kathmanduLng = 85.30369;
  static const double defaultZoom = 13.0;

  // OpenStreetMap tile URLs
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmDarkTileUrl = 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  // Background image path
  static const String backgroundImage = 'lib/app/assets/welcome.jpg';
}
