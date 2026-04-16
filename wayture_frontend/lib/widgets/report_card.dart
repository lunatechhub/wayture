import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wayture/models/report_model.dart';

/// Glassmorphism-style report card for the reports screen.
class ReportCard extends StatefulWidget {
  final ReportModel report;

  const ReportCard({super.key, required this.report});

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  late int _upvotes;
  bool _upvoted = false;

  @override
  void initState() {
    super.initState();
    _upvotes = widget.report.upvotes;
  }

  Future<void> _toggleUpvote() async {
    setState(() {
      if (_upvoted) {
        _upvoted = false;
        _upvotes -= 1;
      } else {
        _upvoted = true;
        _upvotes += 1;
      }
    });
    try {
      await FirebaseFirestore.instance
          .collection('CommunityReports')
          .doc(widget.report.id)
          .update({'upvotes': _upvotes});
    } catch (e) {
      debugPrint('upvote update error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Incident emoji
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: widget.report.type.color.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(widget.report.type.emoji,
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
                              widget.report.location,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            widget.report.timeAgo,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.report.type.label,
                        style: TextStyle(
                          color: widget.report.type.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.report.description,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Spacer(),
                          GestureDetector(
                            onTap: _toggleUpvote,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _upvoted
                                    ? const Color(0xFF00897B)
                                    : Colors.white.withAlpha(25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _upvoted
                                      ? const Color(0xFF00897B)
                                      : Colors.white.withAlpha(60),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.thumb_up,
                                    size: 14,
                                    color: _upvoted
                                        ? Colors.white
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_upvotes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _upvoted
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
