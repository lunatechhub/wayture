enum EventImpactLevel { low, medium, high }

class KathmanduEvent {
  final String name;
  final String description;
  final List<String> affectedAreas;
  final DateTime date;
  final EventImpactLevel impactLevel;
  final bool isActive;

  const KathmanduEvent({
    required this.name,
    required this.description,
    required this.affectedAreas,
    required this.date,
    required this.impactLevel,
    this.isActive = true,
  });

  String get emoji {
    switch (impactLevel) {
      case EventImpactLevel.low:
        return '📢';
      case EventImpactLevel.medium:
        return '⚠️';
      case EventImpactLevel.high:
        return '🚨';
    }
  }
}
