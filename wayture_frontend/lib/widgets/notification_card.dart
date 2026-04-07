import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/notification_model.dart';

/// Glassmorphism-style notification card with swipe-to-dismiss.
class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(60),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(notification.isRead ? 20 : 40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(50)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji icon
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: notification.type.color.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(notification.type.emoji, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: notification.isRead
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Unread dot
                              if (!notification.isRead)
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notification.timeAgo,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
