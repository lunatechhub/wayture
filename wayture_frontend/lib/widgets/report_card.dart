import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wayture/models/report_model.dart';

/// Glassmorphism-style report card for the reports screen.
class ReportCard extends StatelessWidget {
  final ReportModel report;

  const ReportCard({super.key, required this.report});

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
                    color: report.type.color.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(report.type.emoji, style: const TextStyle(fontSize: 20)),
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
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
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
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
