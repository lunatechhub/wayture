import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/kathmandu_event.dart';

class EventCarousel extends StatefulWidget {
  final List<KathmanduEvent> events;
  final ValueChanged<KathmanduEvent>? onEventTap;

  const EventCarousel({
    super.key,
    required this.events,
    this.onEventTap,
  });

  @override
  State<EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<EventCarousel> {
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  final Set<int> _dismissedIndices = {};

  List<KathmanduEvent> get _visibleEvents {
    return widget.events
        .asMap()
        .entries
        .where((e) => !_dismissedIndices.contains(e.key))
        .map((e) => e.value)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final events = _visibleEvents;
      if (events.length <= 1 || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % events.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Color _severityColor(EventImpactLevel level) {
    switch (level) {
      case EventImpactLevel.high:
        return const Color(0xFFF44336);
      case EventImpactLevel.medium:
        return const Color(0xFFFF9800);
      case EventImpactLevel.low:
        return const Color(0xFFFFC107);
    }
  }

  String _severityIcon(EventImpactLevel level) {
    switch (level) {
      case EventImpactLevel.high:
        return '⚠️';
      case EventImpactLevel.medium:
        return '🎉';
      case EventImpactLevel.low:
        return '🚧';
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _visibleEvents;
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 82,
          child: PageView.builder(
            controller: _pageController,
            itemCount: events.length,
            onPageChanged: (i) {
              if (mounted) setState(() => _currentPage = i);
            },
            itemBuilder: (context, index) {
              final event = events[index];
              final color = _severityColor(event.impactLevel);
              final icon = _severityIcon(event.impactLevel);

              return GestureDetector(
                onTap: () => widget.onEventTap?.call(event),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E).withAlpha(230),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(color: color, width: 4),
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                event.name,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                event.description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            final origIdx = widget.events.indexOf(event);
                            if (mounted) {
                              setState(() {
                                _dismissedIndices.add(origIdx);
                                if (_currentPage >= _visibleEvents.length) {
                                  _currentPage = 0;
                                }
                              });
                            }
                          },
                          child: const Icon(Icons.close,
                              color: Colors.white38, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Dot indicators
        if (events.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(events.length, (i) {
              final isActive = _currentPage == i;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
