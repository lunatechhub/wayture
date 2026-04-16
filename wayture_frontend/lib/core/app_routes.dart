/// ──────────────────────────────────────────────────────────────────────────
/// AppRoutes
/// ──────────────────────────────────────────────────────────────────────────
/// Single source of truth for every named route in Wayture.
///
/// Always call `Navigator.pushNamed(context, AppRoutes.home)` instead of
/// building a [MaterialPageRoute] inline. The route table lives in
/// [main.dart] and ties each of these constants to the matching screen.
/// ──────────────────────────────────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  static const String splash        = '/';
  static const String login         = '/login';
  static const String register      = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home          = '/home';
  static const String map           = '/map';
  static const String routeSearch   = '/route-search';
  static const String routeResult   = '/route-result';
  static const String savedRoutes   = '/saved-routes';
  static const String profile       = '/profile';
  static const String permissions   = '/permissions';
  static const String qrShare       = '/qr-share';
  static const String notifications = '/notifications';
  static const String reports       = '/reports';
  static const String settings      = '/settings';
}
