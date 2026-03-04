import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/services/theme_service.dart';
import 'package:wayture/models/report_model.dart';
import 'package:wayture/services/mock_data.dart';
import 'package:wayture/widgets/report_card.dart';
import 'package:wayture/widgets/custom_text_field.dart';

/// Community reports screen — glassmorphism style over sunset background.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedFilter = 0;
  late List<ReportModel> _reports;

  final _filters = const ['All', 'Accidents', 'Jams', 'Roadblocks', 'Protests'];

  @override
  void initState() {
    super.initState();
    _reports = MockData.reports;
  }

  List<ReportModel> get _filteredReports {
    switch (_selectedFilter) {
      case 1: return _reports.where((r) => r.type == IncidentType.accident).toList();
      case 2: return _reports.where((r) => r.type == IncidentType.trafficJam).toList();
      case 3: return _reports.where((r) => r.type == IncidentType.roadBlock).toList();
      case 4: return _reports.where((r) => r.type == IncidentType.protest).toList();
      default: return _reports;
    }
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
                // Header
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    'Community Reports',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Filter chips
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedFilter == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white.withAlpha(50),
                              ),
                            ),
                            child: Text(
                              _filters[index],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Report list
                Expanded(
                  child: _filteredReports.isEmpty
                      ? const Center(
                          child: Text(
                            'No reports in this category',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            return ReportCard(report: _filteredReports[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      // FAB to add report
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReportSheet,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddReportSheet() {
    IncidentType selectedType = IncidentType.accident;
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Report an Incident',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<IncidentType>(
                          value: selectedType,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2A2A4E),
                          style: const TextStyle(color: Colors.white),
                          items: IncidentType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Text(type.emoji, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text(type.label),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setSheetState(() => selectedType = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: descController,
                      hintText: 'Describe the incident...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Text('📍', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('Location: Detected from GPS',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _reports.insert(0, ReportModel(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              type: selectedType,
                              location: 'Your Location',
                              description: descController.text.isEmpty
                                  ? 'Reported via app'
                                  : descController.text,
                              reporterName: 'You',
                              timestamp: DateTime.now(),
                              latitude: 27.7172,
                              longitude: 85.3240,
                            ));
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report submitted!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text('Submit Report',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
