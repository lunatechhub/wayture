import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/screens/splash_screen.dart';
import 'package:wayture/services/auth_service.dart';
import 'package:wayture/services/route_service.dart';
import 'package:wayture/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — wrapped in try-catch so the app still
  // works in demo mode if Firebase is not configured.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  runApp(const WaytureApp());
}

class WaytureApp extends StatelessWidget {
  const WaytureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => RouteService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeSvc, _) => MaterialApp(
          title: 'Wayture',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeSvc.themeMode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
