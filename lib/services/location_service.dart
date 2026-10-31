import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'storage_service.dart';

enum LocationSource { liveSatellite, cachedRecent, cachedStored, unavailable }

class CachedLocation {
  const CachedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final LocationSource source;

  bool get isCached =>
      source == LocationSource.cachedStored ||
      source == LocationSource.cachedRecent;

  String get latText => latitude.toStringAsFixed(5);
  String get lngText => longitude.toStringAsFixed(5);

  String get mapsUrl =>
      'https://maps.google.com/?q=${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': double.parse(latitude.toStringAsFixed(6)),
        'longitude': double.parse(longitude.toStringAsFixed(6)),
        'accuracy': accuracy.round(),
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  static CachedLocation fromJson(Map<String, dynamic> json) => CachedLocation(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 100,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
        source: LocationSource.cachedStored,
      );
}

class LocationAge {
  const LocationAge({
    required this.ageLabelEn,
    required this.ageLabelHa,
    required this.isRecent,
    required this.isOld,
  });

  final String ageLabelEn;
  final String ageLabelHa;
  final bool isRecent;
  final bool isOld;

  String label(bool hausa) => hausa ? ageLabelHa : ageLabelEn;
}

/// Offline-first GPS.
///
/// Mirrors `src/services/locationService.ts`:
/// * instant last-known fix from storage so the SOS card is never empty,
/// * a short (4 s) live request when the user asks for it,
/// * age labels so a 12-hour-old fix is never mistaken for a live one.
class LocationService {
  LocationService({StorageService? storage, GeolocatorPlatform? platform})
      : _storage = storage ?? StorageService.instance,
        _platform = platform ?? GeolocatorPlatform.instance;

  final StorageService _storage;
  final GeolocatorPlatform _platform;

  static const String storageKey = 'smartvillage.last_known_location';

  /// Fast, synchronous-ish read of the stored fix.
  Future<CachedLocation?> lastKnownLocation() async {
    final json = await _storage.getJson(storageKey);
    if (json == null) return null;
    try {
      return CachedLocation.fromJson(json);
    } catch (error) {
      debugPrint('[LocationService] bad cached fix: $error');
      return null;
    }
  }

  Future<void> saveLocation(CachedLocation location) async {
    await _storage.setJson(storageKey, location.toJson());
  }

  Future<bool> ensurePermission() async {
    try {
      final enabled = await _platform.isLocationServiceEnabled();
      if (!enabled) return false;
      var permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (error) {
      debugPrint('[LocationService] permission check failed: $error');
      return false;
    }
  }

  /// One-shot fix with a hard timeout (default 4 s, same as the web version).
  Future<CachedLocation?> currentPosition({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!await ensurePermission()) return null;
    try {
      final position = await _platform.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      final location = CachedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        source: LocationSource.liveSatellite,
      );
      await saveLocation(location);
      return location;
    } catch (error) {
      debugPrint('[LocationService] live fix failed: $error');
      return null;
    }
  }

  /// Best available coordinate: live first, then stored fallback.
  Future<CachedLocation?> bestEffort({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final live = await currentPosition(timeout: timeout);
    if (live != null) return live;
    return lastKnownLocation();
  }

  /// Continuous updates for the SOS card while it is expanded.
  Stream<CachedLocation> positionStream() {
    return _platform
        .getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        )
        .map(
          (position) => CachedLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            timestamp: position.timestamp,
            source: LocationSource.liveSatellite,
          ),
        );
  }

  static LocationAge formatAge(DateTime timestamp, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(timestamp);
    final minutes = elapsed.inMinutes < 0 ? 0 : elapsed.inMinutes;
    final hours = minutes ~/ 60;

    if (minutes < 1) {
      return const LocationAge(
        ageLabelEn: 'Just now',
        ageLabelHa: 'Yanzu-yanzu',
        isRecent: true,
        isOld: false,
      );
    }
    if (minutes < 60) {
      return LocationAge(
        ageLabelEn: '${minutes}m ago',
        ageLabelHa: 'minti $minutes da suka wuce',
        isRecent: true,
        isOld: false,
      );
    }
    if (hours < 24) {
      return LocationAge(
        ageLabelEn: '${hours}h ago',
        ageLabelHa: 'awa $hours da suka wuce',
        isRecent: false,
        isOld: hours >= 12,
      );
    }
    final days = hours ~/ 24;
    return LocationAge(
      ageLabelEn: '${days}d ago',
      ageLabelHa: 'kwanaki $days da suka wuce',
      isRecent: false,
      isOld: true,
    );
  }

  /// Debug helper used by tests.
  @visibleForTesting
  static String encode(CachedLocation location) => jsonEncode(location.toJson());
}
