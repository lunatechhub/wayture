import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wayture/core/app_dialog.dart';
import 'package:wayture/core/app_routes.dart';
import 'package:wayture/core/app_theme.dart';

import 'package:wayture/screens/forgot_password_screen.dart';
import 'package:wayture/screens/login_screen.dart';
import 'package:wayture/screens/main_screen.dart';
import 'package:wayture/screens/notifications_screen.dart';
import 'package:wayture/screens/permission_request_screen.dart';
import 'package:wayture/screens/reports_screen.dart';
import 'package:wayture/screens/saved_routes_screen.dart';
import 'package:wayture/screens/settings_screen.dart';
import 'package:wayture/screens/signup_screen.dart';
import 'package:wayture/screens/splash_screen.dart';

import 'package:wayture/services/auth_service.dart';
import 'package:wayture/services/connection_manager.dart';
import 'package:wayture/services/route_service.dart';
import 'package:wayture/services/theme_service.dart';

/// Top-level handler for background FCM messages (must be a top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — wrapped in try-catch so the app still
  // works in demo mode if Firebase is not configured.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  // Initialize Firebase Cloud Messaging
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final token = await messaging.getToken();
    debugPrint('FCM token: $token');

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
    });
  } catch (e) {
    debugPrint('FCM init skipped: $e');
  }

  // Initialize connection manager
  final connectionManager = ConnectionManager();
  connectionManager.initialize();

  runApp(WaytureApp(connectionManager: connectionManager));
}

class WaytureApp extends StatelessWidget {
  final ConnectionManager connectionManager;

  const WaytureApp({super.key, required this.connectionManager});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => RouteService()),
        ChangeNotifierProvider.value(value: connectionManager),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeSvc, _) => MaterialApp(
          title: 'Wayture',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeSvc.themeMode,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: _generateRoute,
          onUnknownRoute: _unknownRoute,
        ),
      ),
    );
  }

  // ── Route generator ────────────────────────────────────────────────────────
  /// Maps every [AppRoutes] constant onto the corresponding screen. All
  /// routes are wrapped in a [_slidePageRoute] so navigation uses a smooth
  /// right-to-left slide transition consistently across the app.
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _slidePageRoute(const SplashScreen(), settings);

      case AppRoutes.login:
        return _slidePageRoute(const LoginScreen(), settings);

      case AppRoutes.register:
        return _slidePageRoute(const SignupScreen(), settings);

      case AppRoutes.forgotPassword:
        final initialEmail = settings.arguments is String
            ? settings.arguments as String
            : null;
        return _slidePageRoute(
          ForgotPasswordScreen(initialEmail: initialEmail),
          settings,
        );

      case AppRoutes.home:
        return _slidePageRoute(const MainScreen(), settings);

      case AppRoutes.permissions:
        return _slidePageRoute(const PermissionRequestScreen(), settings);

      case AppRoutes.notifications:
        return _slidePageRoute(const NotificationsScreen(), settings);

      case AppRoutes.reports:
        return _slidePageRoute(const ReportsScreen(), settings);

      case AppRoutes.settings:
      case AppRoutes.profile:
        return _slidePageRoute(const SettingsScreen(), settings);

      case AppRoutes.savedRoutes:
        return _slidePageRoute(const SavedRoutesScreen(), settings);

      // ── Not yet implemented: route back to the map ──
      case AppRoutes.routeSearch:
      case AppRoutes.routeResult:
      case AppRoutes.qrShare:
        return _slidePageRoute(const MainScreen(), settings);
    }
    return null;
  }

  /// Fallback when [Navigator.pushNamed] is called with an unknown route —
  /// send the user to home rather than crashing, and show a small info
  /// dialog explaining the redirect.
  Route<dynamic> _unknownRoute(RouteSettings settings) {
    return _slidePageRoute(
      Builder(
        builder: (ctx) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppDialog.info(
              ctx,
              title: 'Screen not found',
              message:
                  'We couldn\'t find "${settings.name}". Taking you home instead.',
              autoDismiss: true,
            );
          });
          return const MainScreen();
        },
      ),
      settings,
    );
  }

  /// Slide-in-from-right page transition used for every named route.
  PageRouteBuilder<T> _slidePageRoute<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          ),
          child: child,
        );
      },
    );
  }
}
