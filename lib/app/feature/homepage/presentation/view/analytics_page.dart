import 'package:flutter/material.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2540),
        title: const Text("Traffic Analytics"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Summary Card
            analyticsCard(
              title: "Traffic Summary",
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("• Total Reports Today: 120"),
                  Text("• Peak Congestion Time: 6:00 PM"),
                  Text("• Average Speed: 14 km/h"),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Most Congested Area
            analyticsCard(
              title: "Most Congested Area",
              content: const Text(
                "Kalanki",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // Common Issues
            analyticsCard(
              title: "Most Reported Issues",
              content: Column(
                children: const [
                  AnalyticsRow(label: "Accidents", value: "45%"),
                  AnalyticsRow(label: "Heavy Traffic", value: "35%"),
                  AnalyticsRow(label: "Road Blocks", value: "20%"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable analytics card
  Widget analyticsCard({required String title, required Widget content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }
}

// Simple row
class AnalyticsRow extends StatelessWidget {
  final String label;
  final String value;

  const AnalyticsRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
