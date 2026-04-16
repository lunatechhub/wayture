import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wayture/screens/home_screen.dart';
import 'package:wayture/screens/reports_screen.dart';
import 'package:wayture/screens/saved_routes_screen.dart';
import 'package:wayture/screens/settings_screen.dart';
import 'package:wayture/services/connection_manager.dart';

// ── Dark theme constants matching the app's existing dark style ──
const Color _navBg = Color(0xFF1A1A2E);
const Color _navSelected = Color(0xFF00897B); // teal accent
const Color _navUnselected = Color(0xFF6B6B7B);
const Color _navBorder = Color(0xFF2A2A3E);

/// Main wrapper screen with bottom navigation bar.
/// Holds the 4 tabs: Home, Search, Saved, Profile.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _hasShownOfflineDialog = false;

  final _screens = const [
    HomeScreen(),
    ReportsScreen(),
    SavedRoutesScreen(),
    SettingsScreen(),
  ];

  Future<bool> _handleBack() async {
    if (_currentIndex != 0) {
      if (mounted) setState(() => _currentIndex = 0);
      return false;
    }
    return true;
  }

  // ── No-Internet Dialog Listener ──
  void _onConnectivityChanged() {
    if (!mounted) return;
    final connMgr = context.read<ConnectionManager>();
    if (!connMgr.isOnline && connMgr.hasChecked && !_hasShownOfflineDialog) {
      _hasShownOfflineDialog = true;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('No connection — check your internet',
                  style: TextStyle(color: Colors.white)),
            ),
          ]),
          backgroundColor: const Color(0xFFFB8C00),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: () async {
              await connMgr.checkNow();
              if (connMgr.isOnline) {
                _hasShownOfflineDialog = false;
              }
            },
          ),
        ));
    } else if (connMgr.isOnline) {
      _hasShownOfflineDialog = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connMgr = context.watch<ConnectionManager>();
    if (connMgr.hasChecked && !connMgr.isOnline && !_hasShownOfflineDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onConnectivityChanged();
      });
    } else if (connMgr.isOnline) {
      _hasShownOfflineDialog = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: _navBg,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: _navBg,
            border: Border(
              top: BorderSide(color: _navBorder, width: 1),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) {
              if (i == _currentIndex) return;
              if (mounted) setState(() => _currentIndex = i);
            },
            backgroundColor: _navBg,
            selectedItemColor: _navSelected,
            unselectedItemColor: _navUnselected,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedFontSize: 12,
            unselectedFontSize: 11,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined),
                activeIcon: Icon(Icons.search),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bookmark_outline),
                activeIcon: Icon(Icons.bookmark),
                label: 'Saved',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
