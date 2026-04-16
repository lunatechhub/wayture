import 'package:flutter/material.dart';
import 'package:wayture/models/congestion_factor.dart';

class CongestionBreakdownCard extends StatefulWidget {
  final CongestionBreakdown breakdown;

  const CongestionBreakdownCard({super.key, required this.breakdown});

  @override
  State<CongestionBreakdownCard> createState() =>
      _CongestionBreakdownCardState();
}

class _CongestionBreakdownCardState extends State<CongestionBreakdownCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.breakdown.totalScore;

    return GestureDetector(
      onTap: () {
        if (mounted) setState(() => _expanded = !_expanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E32),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: "See why ▼" with total score
            Row(
              children: [
                const Icon(Icons.analytics_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'See why',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.breakdown.classificationColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.breakdown.classification} · $total pts',
                    style: TextStyle(
                      color: widget.breakdown.classificationColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),

            // Expandable content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Factor bars
                    ...CongestionFactor.values.map((factor) {
                      final score =
                          widget.breakdown.scores[factor] ?? 0;
                      return _factorBar(factor, score);
                    }),

                    // Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                          color: Colors.white.withAlpha(15), height: 1),
                    ),

                    // Insights
                    ...widget.breakdown.insights.map((insight) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.isPositive ? '✓' : '⚠',
                              style: TextStyle(
                                fontSize: 12,
                                color: insight.isPositive
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFFFC107),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                insight.text,
                                style: TextStyle(
                                  color: insight.isPositive
                                      ? Colors.white54
                                      : Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Total score bar
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Total Congestion Score',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$total/100',
                          style: TextStyle(
                            color: widget.breakdown.classificationColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: total / 100),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (_, val, _) => LinearProgressIndicator(
                          value: val.clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withAlpha(15),
                          valueColor: AlwaysStoppedAnimation(
                              widget.breakdown.classificationColor),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _factorBar(CongestionFactor factor, int score) {
    final max = factor.maxScore;
    final color = widget.breakdown.colorForFactor(factor);
    final ratio = max > 0 ? score / max : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(factor.icon, color: color, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              factor.label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (_, val, _) => LinearProgressIndicator(
                  value: val,
                  backgroundColor: Colors.white.withAlpha(15),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              '$score/$max',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
