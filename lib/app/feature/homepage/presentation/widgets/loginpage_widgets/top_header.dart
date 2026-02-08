import 'package:flutter/material.dart';

class TopHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const TopHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.location_on, size: 80, color: Color(0xFF0A2540)),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A2540),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
