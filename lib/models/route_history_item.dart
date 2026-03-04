class RouteHistoryItem {
  final String from;
  final String to;
  final String routeName;
  final DateTime timestamp;
  bool isFavorite;

  RouteHistoryItem({
    required this.from,
    required this.to,
    required this.routeName,
    required this.timestamp,
    this.isFavorite = false,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
