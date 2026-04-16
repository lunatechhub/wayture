import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/config/theme.dart';
import 'package:wayture/services/api_service.dart';
import 'package:wayture/services/firestore_service.dart';
import 'package:wayture/services/theme_service.dart';
import 'package:wayture/models/report_model.dart';
import 'package:wayture/widgets/custom_text_field.dart';

/// Community reports screen — dark themed with live Firestore data.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedFilter = 0;
  bool _showingSaved = false;
  List<ReportModel> _reports = [];
  List<String> _reportDocIds = [];
  List<String> _reportUids = []; // uid of each report's author
  Set<String> _savedReportIds = {};
  StreamSubscription? _reportsSub;
  StreamSubscription? _savedSub;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  final _filters = const ['All', 'Accidents', 'Jams', 'Roadblocks', 'Protests'];

  @override
  void initState() {
    super.initState();
    _listenToLiveReports();
    _listenToSavedReports();
    _loadReportsFromApi();
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _savedSub?.cancel();
    super.dispose();
  }

  /// Stream live community reports from Firestore.
  void _listenToLiveReports() {
    _reportsSub = FirestoreService.instance.communityReportsStream().listen(
      (data) {
        if (!mounted) return;
        final reports = <ReportModel>[];
        final docIds = <String>[];
        final uids = <String>[];
        for (final r in data) {
          docIds.add(r['id'] ?? '');
          uids.add(r['uid'] ?? '');
          reports.add(ReportModel(
            id: r['id'] ?? '',
            type: _parseType(r['report_type'] ?? r['type']),
            location: r['description'] ?? 'Reported Location',
            description: r['description'] ?? '',
            reporterName: r['uid'] ?? 'Anonymous',
            timestamp: (r['timestamp'] as Timestamp?)?.toDate() ??
                (r['created_at'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            latitude: (r['latitude'] as num?)?.toDouble() ?? 27.7172,
            longitude: (r['longitude'] as num?)?.toDouble() ?? 85.3240,
            upvotes: (r['upvotes'] as num?)?.toInt() ?? 0,
          ));
        }
        setState(() {
          _reports = reports;
          _reportDocIds = docIds;
          _reportUids = uids;
        });
      },
      onError: (e) => debugPrint('Reports stream error: $e'),
    );
  }

  /// Stream saved report IDs for the current user.
  void _listenToSavedReports() {
    final uid = _currentUid;
    if (uid == null) return;
    _savedSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedReports')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _savedReportIds = snap.docs.map((d) => d.id).toSet();
      });
    });
  }

  IncidentType _parseType(String? type) {
    switch (type) {
      case 'accident': return IncidentType.accident;
      case 'traffic_jam': return IncidentType.trafficJam;
      case 'road_closure': return IncidentType.roadBlock;
      case 'construction': return IncidentType.construction;
      case 'flooding': return IncidentType.weatherIssue;
      case 'other': return IncidentType.protest;
      default: return IncidentType.accident;
    }
  }

  Future<void> _loadReportsFromApi() async {
    final apiReports = await ApiService.getReports();
    if (apiReports != null && _reports.isEmpty && mounted) {
      setState(() => _reports = apiReports);
    }
  }

  Future<void> _deleteReport(int realIndex) async {
    if (realIndex < 0 || realIndex >= _reportDocIds.length) return;
    final docId = _reportDocIds[realIndex];
    if (docId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('communityReports')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report deleted'),
            backgroundColor: Color(0xFF00897B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleSaveReport(String reportDocId) async {
    final uid = _currentUid;
    if (uid == null || reportDocId.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedReports')
        .doc(reportDocId);
    try {
      if (_savedReportIds.contains(reportDocId)) {
        await ref.delete();
      } else {
        await ref.set({'savedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint('Toggle save error: $e');
    }
  }

  List<ReportModel> get _filteredReports {
    var list = _reports;
    // If showing saved, filter to only saved report IDs
    if (_showingSaved) {
      list = [];
      for (int i = 0; i < _reports.length; i++) {
        if (i < _reportDocIds.length &&
            _savedReportIds.contains(_reportDocIds[i])) {
          list.add(_reports[i]);
        }
      }
    }
    switch (_selectedFilter) {
      case 1: return list.where((r) => r.type == IncidentType.accident).toList();
      case 2: return list.where((r) => r.type == IncidentType.trafficJam).toList();
      case 3: return list.where((r) => r.type == IncidentType.roadBlock).toList();
      case 4: return list.where((r) => r.type == IncidentType.protest).toList();
      default: return list;
    }
  }

  void _showDeleteDialog(int realIndex) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text('Delete this report?',
              style: TextStyle(color: Colors.white)),
        ]),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DELETE',
          textColor: Colors.redAccent,
          onPressed: () => _deleteReport(realIndex),
        ),
      ));
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

                // All Reports / Saved toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _tabChip('All Reports', !_showingSaved, () {
                        if (mounted) setState(() => _showingSaved = false);
                      }),
                      const SizedBox(width: 8),
                      _tabChip(
                        'Saved (${_savedReportIds.length})',
                        _showingSaved,
                        () {
                          if (mounted) setState(() => _showingSaved = true);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

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
                          onTap: () {
                            if (mounted) setState(() => _selectedFilter = index);
                          },
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
                      ? Center(
                          child: Text(
                            _showingSaved
                                ? 'No saved reports yet'
                                : 'No reports in this category',
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
                            final realIndex = _reports.indexOf(report);
                            final reportDocId = realIndex >= 0 && realIndex < _reportDocIds.length
                                ? _reportDocIds[realIndex]
                                : '';
                            final reportUid = realIndex >= 0 && realIndex < _reportUids.length
                                ? _reportUids[realIndex]
                                : '';
                            final isOwn = _currentUid != null &&
                                reportUid.isNotEmpty &&
                                reportUid == _currentUid;
                            final isSaved = _savedReportIds.contains(reportDocId);

                            return _ReportCardWithActions(
                              report: report,
                              isOwnReport: isOwn,
                              isSaved: isSaved,
                              onDelete: isOwn
                                  ? () => _showDeleteDialog(realIndex)
                                  : null,
                              onToggleSave: reportDocId.isNotEmpty
                                  ? () => _toggleSaveReport(reportDocId)
                                  : null,
                            );
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

  Widget _tabChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00897B) : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFF00897B) : Colors.white.withAlpha(30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showAddReportSheet() async {
    IncidentType selectedType = IncidentType.accident;
    final descController = TextEditingController();

    try {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
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
                          Icon(Icons.location_on, color: Colors.white70, size: 18),
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
                        onPressed: () async {
                          final navigator = Navigator.of(sheetContext);
                          final messenger = ScaffoldMessenger.of(context);
                          final desc = descController.text.isEmpty
                              ? 'Reported via app'
                              : descController.text;

                          final backendType = switch (selectedType) {
                            IncidentType.accident => 'accident',
                            IncidentType.trafficJam => 'traffic_jam',
                            IncidentType.roadBlock => 'road_closure',
                            IncidentType.construction => 'construction',
                            IncidentType.weatherIssue => 'flooding',
                            IncidentType.protest => 'other',
                          };

                          ApiService.submitReport(
                            type: backendType,
                            location: 'Your Location',
                            description: desc,
                          );

                          // Write to Firestore with uid for ownership tracking
                          final uid = _currentUid ?? 'anonymous';
                          try {
                            await FirebaseFirestore.instance
                                .collection('communityReports')
                                .add({
                              'uid': uid,
                              'type': backendType,
                              'report_type': backendType,
                              'description': desc,
                              'latitude': 27.7172,
                              'longitude': 85.3240,
                              'timestamp': FieldValue.serverTimestamp(),
                              'created_at': FieldValue.serverTimestamp(),
                              'upvotes': 0,
                            });
                          } catch (e) {
                            debugPrint('Firestore write error: $e');
                          }

                          if (!mounted) return;
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Report submitted!'),
                              backgroundColor: Color(0xFF00897B),
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
    } finally {
      descController.dispose();
    }
  }
}

/// Report card with conditional delete button (own reports only) and bookmark.
class _ReportCardWithActions extends StatelessWidget {
  final ReportModel report;
  final bool isOwnReport;
  final bool isSaved;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleSave;

  const _ReportCardWithActions({
    required this.report,
    required this.isOwnReport,
    required this.isSaved,
    this.onDelete,
    this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Incident emoji
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: report.type.color.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(report.type.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        report.timeAgo,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.type.label,
                    style: TextStyle(
                      color: report.type.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.description,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isOwnReport)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Your report',
                        style: TextStyle(
                          color: const Color(0xFF00897B).withAlpha(180),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Action buttons column
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bookmark/save
                if (onToggleSave != null)
                  GestureDetector(
                    onTap: onToggleSave,
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved
                          ? const Color(0xFF00897B)
                          : Colors.white38,
                      size: 22,
                    ),
                  ),
                // Delete — only for own reports
                if (isOwnReport && onDelete != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 20),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
