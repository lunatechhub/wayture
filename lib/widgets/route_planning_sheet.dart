import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/services/mock_data.dart';
import 'package:wayture/widgets/route_card.dart';

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
  KtmLocation('Jawalakhel', 27.6727, 85.3141),
  KtmLocation('Satdobato', 27.6583, 85.3252),
  KtmLocation('Tinkune', 27.6844, 85.3465),
  KtmLocation('Putalisadak', 27.7030, 85.3200),
  KtmLocation('Gaushala', 27.7119, 85.3427),
  KtmLocation('Samakhusi', 27.7280, 85.3150),
  KtmLocation('Bouddha', 27.7215, 85.3620),
  KtmLocation('Patan Durbar Square', 27.6727, 85.3250),
  KtmLocation('Swayambhunath', 27.7149, 85.2903),
  KtmLocation('Tribhuvan Airport', 27.6966, 85.3591),
];

// ── View modes ───────────────────────────────────────────

enum _SheetView { form, fromPicker, toSearch }

// ── Main widget ──────────────────────────────────────────

/// Full-featured route planning bottom sheet.
/// Accepts [onNavigate] callback with (routeIndex, routeName).
class RoutePlanningSheet extends StatefulWidget {
  final void Function(int routeIndex, String routeName) onNavigate;

  const RoutePlanningSheet({super.key, required this.onNavigate});

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

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

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
    'Jawalakhel',
    'Satdobato',
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

  void _findRoutes() {
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
    setState(() {
      _isLoading = true;
      _showResults = false;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showResults = true;
        });
      }
    });
  }

  void _swapLocations() {
    if (_toLocation == null) return;
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
    final routes = MockData.routes;
    final screenWidth = MediaQuery.of(context).size.width;
    final pad = screenWidth < 360 ? 12.0 : 20.0;

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
                    onTap: () =>
                        setState(() => _view = _SheetView.fromPicker),
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
                      setState(() => _view = _SheetView.toSearch);
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
        const SizedBox(height: 24),

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

        // Loading shimmer
        if (_isLoading)
          ...List.generate(3, (_) => _shimmerCard()),

        // Route results (stagger animation)
        if (_showResults && !_isLoading)
          ...List.generate(routes.length, (i) {
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
                route: routes[i],
                onNavigate: () {
                  Navigator.pop(context);
                  widget.onNavigate(i, routes[i].name);
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
              onTap: () => setState(() => _view = _SheetView.form),
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
                onTap: () => setState(() {
                  _fromLocation = loc.name;
                  _view = _SheetView.form;
                  _showResults = false;
                }),
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
                    onTap: () => setState(() => _view = _SheetView.form),
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
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
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
                      onTap: () => setState(() {
                        _toLocation = loc.name;
                        _view = _SheetView.form;
                        _showResults = false;
                      }),
                    );
                  },
                ),
        ),
      ],
    );
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
}
