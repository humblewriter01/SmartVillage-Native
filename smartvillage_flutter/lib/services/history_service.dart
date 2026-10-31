import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'storage_service.dart';

enum HistoryType { crop, health, water, livestock, mapPin, soil }

class HistoryRecord {
  const HistoryRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.createdAt,
  });

  final int id;
  final HistoryType type;
  final String title;
  final String detail;
  final DateTime createdAt;

  String get emoji {
    switch (type) {
      case HistoryType.crop:
        return '🌾';
      case HistoryType.health:
        return '🏥';
      case HistoryType.water:
        return '💧';
      case HistoryType.livestock:
        return '🐄';
      case HistoryType.mapPin:
        return '🗺️';
      case HistoryType.soil:
        return '🌱';
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'title': title,
        'detail': detail,
        'createdAt': createdAt.toIso8601String(),
      };

  static HistoryRecord fromJson(Map<String, dynamic> json) => HistoryRecord(
        id: (json['id'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        type: _typeFrom(json['type'] as String?),
        title: json['title'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  static HistoryType _typeFrom(String? name) {
    switch (name) {
      case 'health':
        return HistoryType.health;
      case 'water':
        return HistoryType.water;
      case 'livestock':
        return HistoryType.livestock;
      case 'map_pin':
      case 'mapPin':
        return HistoryType.mapPin;
      case 'soil':
        return HistoryType.soil;
      case 'crop':
      default:
        return HistoryType.crop;
    }
  }
}

/// Local evaluation log (port of `src/services/historyService.ts`).
class HistoryService {
  HistoryService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  static const String storageKey = 'smartvillage.history';
  static const int maxRecords = 60;

  Future<List<HistoryRecord>> list() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return const <HistoryRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <HistoryRecord>[];
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => HistoryRecord.fromJson(
                item.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList(growable: false);
    } catch (error) {
      debugPrint('[HistoryService] read failed: $error');
      return const <HistoryRecord>[];
    }
  }

  Future<HistoryRecord> add({
    required HistoryType type,
    required String title,
    required String detail,
  }) async {
    final record = HistoryRecord(
      id: DateTime.now().millisecondsSinceEpoch,
      type: type,
      title: title,
      detail: detail,
      createdAt: DateTime.now(),
    );
    final existing = await list();
    final updated = <HistoryRecord>[record, ...existing]
        .take(maxRecords)
        .toList(growable: false);
    await _persist(updated);
    return record;
  }

  Future<void> delete(int id) async {
    final existing = await list();
    await _persist(
      existing.where((record) => record.id != id).toList(growable: false),
    );
  }

  Future<void> clear() async {
    await _storage.remove(storageKey);
  }

  Future<void> _persist(List<HistoryRecord> records) async {
    try {
      await _storage.setString(
        storageKey,
        jsonEncode(records.map((r) => r.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('[HistoryService] write failed: $error');
    }
  }
}
