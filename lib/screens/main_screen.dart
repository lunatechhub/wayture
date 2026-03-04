import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/services/theme_service.dart';
import 'package:wayture/screens/home_screen.dart';
import 'package:wayture/screens/reports_screen.dart';
import 'package:wayture/screens/notifications_screen.dart';
import 'package:wayture/screens/settings_screen.dart';

/// Main wrapper screen with bottom navigation bar.
/// Holds the 4 tabs: Home, Reports, Notifications, Settings.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    ReportsScreen(),
    NotificationsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.watch<ThemeService>().isDarkMode
              ? const Color(0xFF0D0D1A)
              : const Color(0xFF1A1A2E),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.map_outlined, Icons.map, 'Home'),
                _navItem(1, Icons.warning_amber_outlined, Icons.warning_amber, 'Reports'),
                _navItem(2, Icons.notifications_outlined, Icons.notifications, 'Alerts'),
                _navItem(3, Icons.settings_outlined, Icons.settings, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData outlinedIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected ? AppColors.primary : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
