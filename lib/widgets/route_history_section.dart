import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/route_history_item.dart';

class RouteHistorySection extends StatelessWidget {
  final List<RouteHistoryItem> history;
  final List<RouteHistoryItem> favorites;
  final void Function(String from, String to) onItemTap;
  final void Function(int index) onToggleFavorite;

  const RouteHistorySection({
    super.key,
    required this.history,
    required this.favorites,
    required this.onItemTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty && favorites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Favorites section
        if (favorites.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFFFC107), size: 16),
              SizedBox(width: 6),
              Text(
                'Favorites',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: favorites.map((item) {
              return GestureDetector(
                onTap: () => onItemTap(item.from, item.to),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star,
                          color: Color(0xFFFFC107), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${item.from} → ${item.to}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Recent routes section
        if (history.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.history, color: Colors.white54, size: 16),
              SizedBox(width: 6),
              Text(
                'Recent Routes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...history.take(5).toList().asMap().entries.map((entry) {
            final item = entry.value;
            return GestureDetector(
              onTap: () => onItemTap(item.from, item.to),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route,
                        color: Colors.white38, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.from} → ${item.to}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.routeName} · ${item.timeAgo}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Find the actual index in the full history list
                        final fullIndex = history.indexOf(item);
                        if (fullIndex != -1) onToggleFavorite(fullIndex);
                      },
                      child: Icon(
                        item.isFavorite ? Icons.star : Icons.star_border,
                        color: item.isFavorite
                            ? const Color(0xFFFFC107)
                            : Colors.white24,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
