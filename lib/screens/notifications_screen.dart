import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/services/api_service.dart';
import 'package:wayture/services/theme_service.dart';
import 'package:wayture/models/notification_model.dart';
import 'package:wayture/services/mock_data.dart';
import 'package:wayture/widgets/notification_card.dart';

/// Notifications screen — glassmorphism over sunset background.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<NotificationModel> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = MockData.notifications;
    _loadNotificationsFromApi();
  }

  Future<void> _loadNotificationsFromApi() async {
    final apiNotifications = await ApiService.getNotifications();
    if (apiNotifications != null && mounted) {
      setState(() => _notifications = apiNotifications);
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _markAllRead() {
    ApiService.markAllNotificationsRead();
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeService>().isDarkMode;
    return Scaffold(
      body: Stack(
        children: [
          if (!isDark)
            Image.asset(
              AppConstants.backgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D0D1A) : null,
              gradient: isDark
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(140),
                        Colors.black.withAlpha(220),
                      ],
                    ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_unreadCount > 0)
                        GestureDetector(
                          onTap: _markAllRead,
                          child: const Text(
                            'Mark all read',
                            style: TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_unreadCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      '$_unreadCount unread',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                // Notification list
                Expanded(
                  child: _notifications.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 64, color: Colors.white24),
                              SizedBox(height: 12),
                              Text('No notifications', style: TextStyle(color: Colors.white54, fontSize: 16)),
                              Text("You're all caught up!", style: TextStyle(color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            return NotificationCard(
                              notification: _notifications[index],
                              onDismiss: () {
                                setState(() => _notifications.removeAt(index));
                              },
                              onTap: () {
                                ApiService.markNotificationRead(_notifications[index].id);
                                setState(() => _notifications[index].isRead = true);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
