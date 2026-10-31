import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/map_data.dart';
import '../models/map_pin.dart';
import 'storage_service.dart';

/// Offline agricultural pinning (port of `src/services/mapService.ts`).
///
/// Pins are stored locally; there is no tile server, so the map screen draws a
/// coordinate grid of Northern Nigeria with the pins positioned by lat/long.
class MapService {
  MapService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  static const String storageKey = 'smartvillage.map.pins';

  /// Seed pins shipped with the app.
  List<MapPin> get seedPins => initialCommunityPins;

  Future<List<MapPin>> allPins() async {
    final raw = await _storage.getString(storageKey);
    final userPins = <MapPin>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map<String, dynamic>>()) {
            userPins.add(MapPin.fromJson(item));
          }
        }
      } catch (error) {
        debugPrint('[MapService] read failed: $error');
      }
    }
    return <MapPin>[...userPins, ...initialCommunityPins];
  }

  Future<void> addPin(MapPin pin) async {
    final existing = await _userPins();
    final updated = <MapPin>[pin, ...existing];
    await _persist(updated);
  }

  Future<void> removePin(String id) async {
    final existing = await _userPins();
    await _persist(
      existing.where((pin) => pin.id != id).toList(growable: false),
    );
  }

  Future<List<MapPin>> _userPins() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return const <MapPin>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <MapPin>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MapPin.fromJson)
          .toList(growable: false);
    } catch (error) {
      debugPrint('[MapService] user pin read failed: $error');
      return const <MapPin>[];
    }
  }

  Future<void> _persist(List<MapPin> pins) async {
    await _storage.setString(
      storageKey,
      jsonEncode(pins.map((pin) => pin.toJson()).toList()),
    );
  }
}
