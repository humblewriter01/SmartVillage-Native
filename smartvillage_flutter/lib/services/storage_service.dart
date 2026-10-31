import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fail-safe key/value storage (the Flutter counterpart of
/// `src/utils/safeStorage.ts`).
///
/// `SharedPreferences` is backed by native SQLite/plist storage, so data
/// survives app restarts without any network connection — exactly what
/// offline-first field work needs.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;
  final Map<String, String> _memory = <String, String>{};

  Future<SharedPreferences?> _instance() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint('[StorageService] falling back to memory store: $error');
    }
    return _prefs;
  }

  Future<String?> getString(String key) async {
    final prefs = await _instance();
    if (prefs != null) {
      try {
        return prefs.getString(key);
      } catch (error) {
        debugPrint('[StorageService] read failed for $key: $error');
      }
    }
    return _memory[key];
  }

  Future<void> setString(String key, String value) async {
    final prefs = await _instance();
    if (prefs != null) {
      try {
        await prefs.setString(key, value);
        return;
      } catch (error) {
        debugPrint('[StorageService] write failed for $key: $error');
      }
    }
    _memory[key] = value;
  }

  Future<void> remove(String key) async {
    final prefs = await _instance();
    if (prefs != null) {
      try {
        await prefs.remove(key);
      } catch (error) {
        debugPrint('[StorageService] remove failed for $key: $error');
      }
    }
    _memory.remove(key);
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = await getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (error) {
      debugPrint('[StorageService] corrupt JSON at $key: $error');
    }
    return null;
  }

  Future<List<dynamic>?> getJsonList(String key) async {
    final raw = await getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (error) {
      debugPrint('[StorageService] corrupt JSON list at $key: $error');
    }
    return null;
  }

  Future<void> setJson(String key, Object? value) async {
    try {
      await setString(key, jsonEncode(value));
    } catch (error) {
      debugPrint('[StorageService] encode failed for $key: $error');
    }
  }
}
