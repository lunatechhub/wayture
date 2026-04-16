import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wayture/services/firestore_service.dart';

/// Saved Routes screen — dark themed to match the rest of the app.
class SavedRoutesScreen extends StatelessWidget {
  const SavedRoutesScreen({super.key});

  static const Color _bg = Color(0xFF0D0D1A);
  static const Color _teal = Color(0xFF00897B);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Saved Routes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Your favourite routes at a glance',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: uid == null
                  ? _buildSignInPrompt()
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream:
                          FirestoreService.instance.savedRoutesStream(uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child:
                                CircularProgressIndicator(color: _teal),
                          );
                        }
                        final routes = snapshot.data ?? [];
                        if (routes.isEmpty) return _buildEmptyState();

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: routes.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final route = routes[index];
                            return _SavedRouteCard(
                              from: route['from'] ?? '',
                              to: route['to'] ?? '',
                              routeName: route['routeName'] ?? '',
                              onDelete: () async {
                                final routeId = route['id'] as String?;
                                if (routeId != null) {
                                  await FirestoreService.instance
                                      .deleteSavedRoute(uid, routeId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text('Route removed'),
                                        backgroundColor: _teal,
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded,
              size: 64, color: _teal.withAlpha(80)),
          const SizedBox(height: 16),
          const Text('Sign in to save routes',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 6),
          const Text('Your saved routes will appear here',
              style: TextStyle(fontSize: 13, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_rounded, size: 64, color: _teal.withAlpha(80)),
          const SizedBox(height: 16),
          const Text('No saved routes yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 6),
          const Text(
            'Save a route from the route planner\nto see it here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _SavedRouteCard extends StatelessWidget {
  final String from;
  final String to;
  final String routeName;
  final VoidCallback onDelete;

  static const Color _teal = Color(0xFF00897B);

  const _SavedRouteCard({
    required this.from,
    required this.to,
    required this.routeName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                    color: _teal, shape: BoxShape.circle),
              ),
              Container(
                  width: 2, height: 28, color: Colors.white.withAlpha(40)),
              const Icon(Icons.location_on,
                  color: Colors.redAccent, size: 14),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(from,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (routeName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(routeName,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                const SizedBox(height: 4),
                Text(to,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  content: Text(
                    'Remove "$from → $to"?',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF1A1A2E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'REMOVE',
                    textColor: Colors.redAccent,
                    onPressed: onDelete,
                  ),
                ));
            },
          ),
        ],
      ),
    );
  }
}
