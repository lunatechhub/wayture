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
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
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
            // Header row
            Row(
              children: [
                const Icon(Icons.analytics_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Congestion Breakdown',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: CongestionFactor.values.map((factor) {
                    final value = widget.breakdown.factors[factor] ?? 0.0;
                    return _factorBar(factor, value);
                  }).toList(),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _factorBar(CongestionFactor factor, double value) {
    final color = widget.breakdown.colorForValue(value);
    final percent = (value * 100).round();

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
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
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
            width: 32,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
