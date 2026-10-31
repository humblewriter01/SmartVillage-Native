import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/locations_data.dart';
import '../models/weather.dart';
import 'storage_service.dart';

class WeatherForecast {
  const WeatherForecast({
    required this.days,
    required this.isCached,
    required this.locationName,
    this.cachedAt,
  });

  final List<WeatherDay> days;
  final bool isCached;
  final String locationName;
  final DateTime? cachedAt;

  bool get isEmpty => days.isEmpty;
}

/// 7-day forecast with offline cache (port of `weatherService`).
///
/// The app is offline-first: the last successful forecast is stored and shown
/// with a "cached" badge when the network is unavailable.
class WeatherService {
  WeatherService({StorageService? storage, http.Client? client})
      : _storage = storage ?? StorageService.instance,
        _client = client ?? http.Client();

  final StorageService _storage;
  final http.Client _client;

  static const String storageKey = 'smartvillage.weather_forecast';
  static const String locationKey = 'smartvillage.weather_location';

  List<NigerianLocation> get locations => nigerianLocations;

  Future<WeatherForecast> load({
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    final lat = latitude ?? 12.0022; // Kano default
    final lon = longitude ?? 8.5919;
    final name = locationName ?? 'Kano';

    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toStringAsFixed(4),
        'longitude': lon.toStringAsFixed(4),
        'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum',
        'timezone': 'Africa/Lagos',
        'forecast_days': '7',
      });

      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final daily = decoded is Map ? decoded['daily'] : null;
        if (daily is Map) {
          final dates = (daily['time'] as List?)?.cast<dynamic>() ?? const [];
          final maxes =
              (daily['temperature_2m_max'] as List?)?.cast<dynamic>() ?? const [];
          final mins =
              (daily['temperature_2m_min'] as List?)?.cast<dynamic>() ?? const [];
          final rains =
              (daily['precipitation_sum'] as List?)?.cast<dynamic>() ?? const [];

          final days = <WeatherDay>[];
          for (var i = 0; i < dates.length; i++) {
            days.add(
              WeatherDay(
                date: dates[i].toString(),
                max: i < maxes.length ? (maxes[i] as num).toDouble() : 0,
                min: i < mins.length ? (mins[i] as num).toDouble() : 0,
                rain: i < rains.length && rains[i] != null
                    ? (rains[i] as num).toDouble()
                    : 0,
              ),
            );
          }

          if (days.isNotEmpty) {
            await _cache(days, name);
            return WeatherForecast(
              days: days,
              isCached: false,
              locationName: name,
              cachedAt: DateTime.now(),
            );
          }
        }
      }
    } catch (error) {
      debugPrint('[WeatherService] fetch failed, using cache: $error');
    }

    return cached();
  }

  Future<void> _cache(List<WeatherDay> days, String locationName) async {
    await _storage.setJson(storageKey, <String, dynamic>{
      'location': locationName,
      'cachedAt': DateTime.now().toIso8601String(),
      'days': days.map((d) => d.toJson()).toList(),
    });
  }

  Future<WeatherForecast> cached() async {
    final json = await _storage.getJson(storageKey);
    if (json == null) {
      return const WeatherForecast(
        days: <WeatherDay>[],
        isCached: true,
        locationName: 'Kano',
      );
    }

    final rawDays = json['days'];
    final days = <WeatherDay>[];
    if (rawDays is List) {
      for (final item in rawDays.whereType<Map<String, dynamic>>()) {
        days.add(WeatherDay.fromJson(item));
      }
    }

    return WeatherForecast(
      days: days,
      isCached: true,
      locationName: json['location'] as String? ?? 'Kano',
      cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? ''),
    );
  }

  Future<void> savePreferredLocation(String name) async {
    await _storage.setString(locationKey, name);
  }

  Future<String?> preferredLocation() => _storage.getString(locationKey);

  static String weekdayLabel(String isoDate, bool hausa) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    const en = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const ha = <String>['Lit', 'Tal', 'Lar', 'Alh', 'Jum', 'Asa', 'Lah'];
    final list = hausa ? ha : en;
    return list[(date.weekday - 1).clamp(0, 6)];
  }
}
