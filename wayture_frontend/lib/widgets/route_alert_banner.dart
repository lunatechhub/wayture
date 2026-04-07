import 'package:flutter/material.dart';
import 'package:wayture/models/route_alert.dart';

class RouteAlertBanner extends StatelessWidget {
  final List<RouteAlert> alerts;
  final ValueChanged<String>? onDismiss;

  const RouteAlertBanner({
    super.key,
    required this.alerts,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.map((alert) {
        return Dismissible(
          key: ValueKey(alert.id),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => onDismiss?.call(alert.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: alert.severity.color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: alert.severity.color.withAlpha(80),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  alert.severity.icon,
                  color: alert.severity.color,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.severity.label,
                        style: TextStyle(
                          color: alert.severity.color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => onDismiss?.call(alert.id),
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withAlpha(100),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
