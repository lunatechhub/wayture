import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/services/connection_manager.dart';

/// Small floating weather card for the map screen.
/// Calls the free Open-Meteo API directly (no API key required).
class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String _temp = '--°';
  String _condition = 'Loading…';
  String _wind = '-- km/h';
  String _emoji = '🌤️';

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${AppConstants.kathmanduLat}'
      '&longitude=${AppConstants.kathmanduLng}'
      '&current_weather=true',
    );

    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final body = json.decode(response.body) as Map<String, dynamic>;
      final current = body['current_weather'] as Map<String, dynamic>?;
      if (current == null) return;

      final temperature = (current['temperature'] as num?)?.toDouble() ?? 0;
      final windspeed = (current['windspeed'] as num?)?.toDouble() ?? 0;
      final weathercode = (current['weathercode'] as num?)?.toInt() ?? 0;

      if (!mounted) return;
      setState(() {
        _temp = '${temperature.round()}°C';
        _wind = '${windspeed.round()} km/h';
        _condition = _labelForCode(weathercode);
        _emoji = _emojiForCode(weathercode);
      });
    } catch (e) {
      debugPrint('Open-Meteo fetch error: $e');
    }
  }

  /// WMO weather code → human label (per spec)
  String _labelForCode(int code) {
    if (code == 0) return 'Clear';
    if (code >= 1 && code <= 3) return 'Partly Cloudy';
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 67) return 'Rainy';
    if (code >= 71 && code <= 77) return 'Snowy';
    if (code >= 80 && code <= 82) return 'Rain Showers';
    if (code == 95 || code == 96 || code == 99) return 'Thunderstorm';
    return 'Unknown';
  }

  /// WMO weather code → matching emoji
  String _emojiForCode(int code) {
    if (code == 0) return '☀️';
    if (code >= 1 && code <= 3) return '⛅';
    if (code >= 45 && code <= 48) return '🌫️';
    if (code >= 51 && code <= 67) return '🌧️';
    if (code >= 71 && code <= 77) return '🌨️';
    if (code >= 80 && code <= 82) return '🌦️';
    if (code == 95 || code == 96 || code == 99) return '⛈️';
    return '🌤️';
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectionManager>().isOnline;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(140),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _temp,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _condition,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.air,
                          color: Colors.white60, size: 11),
                      const SizedBox(width: 3),
                      Text(
                        _wind,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                      if (!isOnline) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
