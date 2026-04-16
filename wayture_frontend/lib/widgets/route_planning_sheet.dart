import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/models/route_model.dart';
import 'package:wayture/services/firestore_service.dart';
import 'package:wayture/services/route_service.dart';
import 'package:wayture/widgets/route_alert_banner.dart';
import 'package:wayture/widgets/route_card.dart';
import 'package:wayture/widgets/route_history_section.dart';
import 'package:wayture/widgets/route_map_preview.dart';
import 'package:wayture/widgets/time_picker_row.dart';

// ── Kathmandu location data ──────────────────────────────

class KtmLocation {
  final String name;
  final double lat;
  final double lng;
  const KtmLocation(this.name, this.lat, this.lng);
}

const _locations = [
  KtmLocation('Current Location', 27.7090, 85.3038),
  KtmLocation('Koteshwor Chowk', 27.6781, 85.3499),
  KtmLocation('Kalanki Chowk', 27.6933, 85.2814),
  KtmLocation('Thamel', 27.7153, 85.3123),
  KtmLocation('New Baneshwor', 27.6882, 85.3419),
  KtmLocation('Maharajgunj', 27.7369, 85.3300),
  KtmLocation('Lazimpat', 27.7220, 85.3238),
  KtmLocation('Balaju', 27.7343, 85.3042),
  KtmLocation('Chabahil', 27.7178, 85.3457),
  KtmLocation('Maitighar Mandala', 27.6947, 85.3222),
  KtmLocation('Thapathali', 27.6926, 85.3220),
  KtmLocation('Tinkune', 27.6844, 85.3465),
  KtmLocation('Putalisadak', 27.7030, 85.3200),
  KtmLocation('Gaushala', 27.7119, 85.3427),
  KtmLocation('Samakhusi', 27.7280, 85.3150),
  KtmLocation('Bouddha', 27.7215, 85.3620),
  KtmLocation('Swayambhunath', 27.7149, 85.2903),
  KtmLocation('Tribhuvan Airport', 27.6966, 85.3591),
  KtmLocation('Ratnapark', 27.7050, 85.3150),
  KtmLocation('Baneshwor', 27.6882, 85.3419),
  KtmLocation('Kalimati', 27.6975, 85.3020),
];

// ── View modes ───────────────────────────────────────────

enum _SheetView { form, fromPicker, toSearch }

// ── Main widget ──────────────────────────────────────────

/// Full-featured route planning bottom sheet.
/// Accepts [onNavigate] callback with (routeIndex, routeName).
/// Optionally accepts [prefillFrom] and [prefillTo] to pre-fill fields.
class RoutePlanningSheet extends StatefulWidget {
  final void Function(int routeIndex, String routeName) onNavigate;
  final String? prefillFrom;
  final String? prefillTo;

  const RoutePlanningSheet({
    super.key,
    required this.onNavigate,
    this.prefillFrom,
    this.prefillTo,
  });

  @override
  State<RoutePlanningSheet> createState() => _RoutePlanningSheetState();
}

class _RoutePlanningSheetState extends State<RoutePlanningSheet> {
  _SheetView _view = _SheetView.form;
  String _fromLocation = 'Current Location';
  String? _toLocation;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _showResults = false;
  double _swapTurns = 0;
  TimeOfDay? _departureTime;
  List<RouteModel> _routes = [];

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.prefillFrom != null) {
      _fromLocation = widget.prefillFrom!;
    }
    if (widget.prefillTo != null) {
      _toLocation = widget.prefillTo;
      // Auto-search after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findRoutes();
      });
    }
  }

  // From picker shows a curated subset
  static const _fromLocationNames = [
    'Koteshwor Chowk',
    'Kalanki Chowk',
    'Thamel',
    'New Baneshwor',
    'Maharajgunj',
    'Lazimpat',
    'Balaju',
    'Chabahil',
    'Kalimati',
    'Ratnapark',
  ];

  List<KtmLocation> get _fromLocations => [
        _locations[0], // Current Location
        ..._locations
            .sublist(1)
            .where((l) => _fromLocationNames.contains(l.name)),
      ];

  List<KtmLocation> get _filteredDestinations {
    final destinations =
        _locations.where((l) => l.name != 'Current Location').toList();
    if (_searchQuery.isEmpty) return destinations;
    return destinations
        .where(
            (l) => l.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _findRoutes() async {
    if (_toLocation == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a destination',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _showResults = false;
    });

    final routeService = context.read<RouteService>();
    final routes = await routeService.generateRoutes(
      _fromLocation,
      _toLocation!,
      departureTime: _departureTime,
    );

    if (mounted) {
      setState(() {
        _routes = routes;
        _isLoading = false;
        _showResults = true;
      });
    }
  }

  void _swapLocations() {
    if (_toLocation == null) return;
    if (!mounted) return;
    setState(() {
      final temp = _fromLocation;
      _fromLocation = _toLocation!;
      _toLocation = temp;
      _swapTurns += 0.5;
      _showResults = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(76),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: switch (_view) {
            _SheetView.form => _buildFormView(scrollController),
            _SheetView.fromPicker => _buildFromPicker(scrollController),
            _SheetView.toSearch => _buildToSearch(scrollController),
          },
        );
      },
    );
  }

  // ── Form view (main) ─────────────────────────────────────

  Widget _buildFormView(ScrollController scrollController) {
    final routeService = context.watch<RouteService>();
    final screenWidth = MediaQuery.of(context).size.width;
    final pad = screenWidth < 360 ? 12.0 : 20.0;
    final activeAlerts = routeService.activeAlerts;
    final todaysEvents = routeService.todaysEvents;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
      children: [
        _dragHandle(),
        const SizedBox(height: 12),

        // Title + close
        Row(
          children: [
            const Expanded(
              child: Text(
                'Plan Your Route',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            _closeButton(),
          ],
        ),
        const SizedBox(height: 24),

        // Event awareness banner
        if (todaysEvents.isNotEmpty)
          ...todaysEvents.map((event) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF9800).withAlpha(60),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${event.name} today',
                            style: const TextStyle(
                              color: Color(0xFFFF9800),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${event.description} — expect delays near ${event.affectedAreas.join(", ")}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),

        // From / To fields with route indicator & swap
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left dots / line
            Padding(
              padding: const EdgeInsets.only(top: 18, right: 12),
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.trafficGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 44, color: Colors.white24),
                  const Icon(Icons.location_on,
                      color: AppColors.trafficRed, size: 16),
                ],
              ),
            ),

            // Fields
            Expanded(
              child: Column(
                children: [
                  // From
                  GestureDetector(
                    onTap: () {
                      if (mounted) setState(() => _view = _SheetView.fromPicker);
                    },
                    child: _locationField(
                      label: 'From',
                      text: _fromLocation,
                      isPlaceholder: false,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // To
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _searchQuery = '';
                      if (mounted) setState(() => _view = _SheetView.toSearch);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _searchFocus.requestFocus();
                      });
                    },
                    child: _locationField(
                      label: 'To',
                      text: _toLocation ?? 'Where are you going?',
                      isPlaceholder: _toLocation == null,
                    ),
                  ),
                ],
              ),
            ),

            // Swap button
            Padding(
              padding: const EdgeInsets.only(top: 22, left: 8),
              child: GestureDetector(
                onTap: _swapLocations,
                child: AnimatedRotation(
                  turns: _swapTurns,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_vert,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Time picker row
        TimePickerRow(
          selectedTime: _departureTime,
          onTimeChanged: (time) {
            if (mounted) {
              setState(() {
                _departureTime = time;
                _showResults = false;
              });
            }
          },
        ),

        // Find Routes button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _toLocation != null ? AppColors.primary : const Color(0xFF2A2A3E),
              foregroundColor:
                  _toLocation != null ? Colors.white : Colors.white38,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _toLocation != null && !_isLoading ? _findRoutes : null,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'Find Routes',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Route history (shown when no results)
        if (!_showResults && !_isLoading)
          RouteHistorySection(
            history: routeService.routeHistory,
            favorites: routeService.favorites,
            onItemTap: (from, to) {
              if (!mounted) return;
              setState(() {
                _fromLocation = from;
                _toLocation = to;
                _showResults = false;
              });
              // Auto-search
              Future.microtask(_findRoutes);
            },
            onToggleFavorite: (index) {
              routeService.toggleFavorite(index);
            },
          ),

        // Loading shimmer
        if (_isLoading)
          ...List.generate(3, (_) => _shimmerCard()),

        // Route alerts
        if (_showResults && !_isLoading && activeAlerts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RouteAlertBanner(
              alerts: activeAlerts,
              onDismiss: (id) => routeService.dismissAlert(id),
            ),
          ),

        // AI Insight banner
        if (_showResults && !_isLoading) _buildAiInsightBanner(routeService),

        // Route map preview
        if (_showResults && !_isLoading && _routes.isNotEmpty)
          RouteMapPreview(routes: _routes),

        // Route results header
        if (_showResults && !_isLoading && _routes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Text(
                  'Available Routes',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_routes.length} found',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        // Route results (stagger animation)
        if (_showResults && !_isLoading)
          ...List.generate(_routes.length, (i) {
            return TweenAnimationBuilder<double>(
              key: ValueKey('route_$i'),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 400 + i * 100),
              curve: Curves.easeOut,
              builder: (_, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              ),
              child: RouteCard(
                route: _routes[i],
                departureLabel: _departureTime != null
                    ? _formatDepartureLabel(_departureTime!)
                    : null,
                onNavigate: () {
                  // Save to history
                  routeService.addToHistory(
                    _fromLocation,
                    _toLocation!,
                    _routes[i].name,
                  );
                  Navigator.pop(context);
                  widget.onNavigate(i, _routes[i].name);
                },
                onSave: () async {
                  // Quick-add to history as favorite
                  routeService.addToHistory(
                    _fromLocation,
                    _toLocation!,
                    _routes[i].name,
                  );
                  routeService.toggleFavorite(0); // Just added at index 0

                  final messenger = ScaffoldMessenger.of(context);

                  // Persist to Firestore
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirestoreService.instance.saveRoute(
                      uid: uid,
                      from: _fromLocation,
                      to: _toLocation!,
                      routeName: _routes[i].name,
                    );
                  }
                  if (context.mounted) {
                    messenger
                      ..clearSnackBars()
                      ..showSnackBar(SnackBar(
                        content: const Row(children: [
                          Icon(Icons.bookmark_added_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Route saved!',
                              style: TextStyle(color: Colors.white)),
                        ]),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ));
                  }
                },
              ),
            );
          }),
      ],
    );
  }

  // ── From picker ──────────────────────────────────────────

  Widget _buildFromPicker(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        _dragHandle(),
        const SizedBox(height: 12),

        // Back + title
        Row(
          children: [
            GestureDetector(
              onTap: () {
                if (mounted) setState(() => _view = _SheetView.form);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Select Starting Point',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Location list
        ..._fromLocations.map((loc) {
          final isSelected = _fromLocation == loc.name;
          final isCurrentLoc = loc.name == 'Current Location';

          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isCurrentLoc
                      ? Icons.my_location
                      : Icons.location_on_outlined,
                  color: isSelected ? AppColors.primary : Colors.white54,
                  size: 20,
                ),
                title: Text(
                  loc.name,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white,
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 20)
                    : null,
                onTap: () {
                  if (!mounted) return;
                  setState(() {
                    _fromLocation = loc.name;
                    _view = _SheetView.form;
                    _showResults = false;
                  });
                },
              ),
              const Divider(color: Colors.white12, height: 1),
            ],
          );
        }),
      ],
    );
  }

  // ── To search ────────────────────────────────────────────

  Widget _buildToSearch(ScrollController scrollController) {
    final filtered = _filteredDestinations;

    return Column(
      children: [
        // Fixed header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              _dragHandle(),
              const SizedBox(height: 12),

              // Back + search field
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (mounted) setState(() => _view = _SheetView.form);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search destination...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white38),
                        ),
                        onChanged: (v) {
                          if (mounted) setState(() => _searchQuery = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // Scrollable results
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Type to search for a destination'
                          : 'No locations found for "$_searchQuery"',
                      style: const TextStyle(color: Colors.white38),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, idx) =>
                      const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (_, i) {
                    final loc = filtered[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined,
                          color: Colors.white54, size: 20),
                      title: Text(
                        loc.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                      ),
                      subtitle: Text(
                        '${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 12),
                      ),
                      onTap: () {
                        if (!mounted) return;
                        setState(() {
                          _toLocation = loc.name;
                          _view = _SheetView.form;
                          _showResults = false;
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDepartureLabel(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // ── Shared small widgets ─────────────────────────────────

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _closeButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white54, size: 20),
      ),
    );
  }

  Widget _locationField({
    required String label,
    required String text,
    required bool isPlaceholder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: isPlaceholder ? Colors.white38 : Colors.white,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ],
      ),
    );
  }

  Widget _shimmerCard() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A3E),
      highlightColor: const Color(0xFF3A3A4E),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ── AI Insight + Route Suggestion Banner ──────────────

  Widget _buildAiInsightBanner(RouteService routeService) {
    final insight = routeService.aiInsight;
    final suggestion = routeService.aiRouteSuggestion;
    final isLoading = routeService.isLoadingAi;

    if (isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withAlpha(80),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF42A5F5).withAlpha(60)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF42A5F5),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'AI analyzing traffic routes...',
              style: TextStyle(color: Color(0xFF90CAF9), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (insight == null && suggestion == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF42A5F5).withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF90CAF9), size: 18),
              SizedBox(width: 8),
              Text(
                'AI Traffic Advisor',
                style: TextStyle(
                  color: Color(0xFF90CAF9),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (insight != null) ...[
            const SizedBox(height: 10),
            Text(
              insight,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
            ),
          ],
          if (suggestion != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4CAF50).withAlpha(60)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.alt_route, color: Color(0xFF81C784), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        color: Color(0xFFC8E6C9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
