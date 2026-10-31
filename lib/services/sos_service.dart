import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'location_service.dart';

class DistressType {
  const DistressType({
    required this.id,
    required this.nameEn,
    required this.nameHa,
    required this.emoji,
    required this.defaultMessageEn,
    required this.defaultMessageHa,
  });

  final String id;
  final String nameEn;
  final String nameHa;
  final String emoji;
  final String defaultMessageEn;
  final String defaultMessageHa;

  String displayName(bool hausa) => hausa ? nameHa : nameEn;
  String defaultMessage(bool hausa) => hausa ? defaultMessageHa : defaultMessageEn;
}

/// Offline emergency broadcast.
///
/// Port of `QuickAlertCard`: GPS coordinates + a pre-written distress message
/// are pushed into the phone's SMS composer with `url_launcher`, so the alert
/// still leaves the farm when there is no mobile data — only a GSM signal.
class SosService {
  SosService({LocationService? location})
      : _location = location ?? LocationService();

  final LocationService _location;

  static const String defaultContact = '112';
  static const String contactStorageKey = 'smartvillage.emergency_contact';

  static const List<DistressType> distressTypes = <DistressType>[
    DistressType(
      id: 'medical',
      nameEn: 'Medical Emergency / Snake Bite',
      nameHa: 'Gaggawar Lafiya / Cizon Maciji',
      emoji: '🚑',
      defaultMessageEn:
          'Critical medical emergency / snakebite in the field! Urgent medical help needed.',
      defaultMessageHa:
          'Gaggawar lafiya / cizon maciji ko hadari a gona! Ana neman taimakon likita cikin gaggawa.',
    ),
    DistressType(
      id: 'security',
      nameEn: 'Security Alert / Kidnapping',
      nameHa: 'Faɗakarwar Tsaro / Neman Ɗauki',
      emoji: '🛡️',
      defaultMessageEn:
          'Security threat / distress at farmland! Immediate community or security assistance needed.',
      defaultMessageHa:
          "Matsalar tsaro ko barazana a gona! Ana neman ɗaukin jami'an tsaro ko 'yan sintiri cikin gaggawa.",
    ),
    DistressType(
      id: 'breakdown',
      nameEn: 'Stranding / Vehicle Breakdown',
      nameHa: 'Makalewa / Lalacewar Taraktoci',
      emoji: '🚜',
      defaultMessageEn:
          'Machinery breakdown / vehicle stranded in remote farmland. Assistance required.',
      defaultMessageHa:
          'Lalacewar tarakta ko abin hawa a dajin gona. Ana buƙatar ɗauki don janyewa ko gyara.',
    ),
    DistressType(
      id: 'fire',
      nameEn: 'Bush / Farm Fire',
      nameHa: 'Gobarar Daji / Gona',
      emoji: '🔥',
      defaultMessageEn:
          'Wildfire / bushfire threatening farms and crop storage! Urgent firefighting help needed.',
      defaultMessageHa:
          'Gobarar daji na barazana ga amfanin gona da rumbuna! Ana neman ɗaukin kashe gobara.',
    ),
    DistressType(
      id: 'flood',
      nameEn: 'Farm Flood',
      nameHa: 'Ambaliyar Ruwa a Gona',
      emoji: '🌊',
      defaultMessageEn:
          'Flash flood or river overflow submerging farm fields! Urgent evacuation or flood response needed.',
      defaultMessageHa:
          'Ambaliyar ruwa ko karyewar madatsar ruwa na lalata gona! Ana neman taimakon gaggawa.',
    ),
  ];

  static DistressType distressById(String id) => distressTypes.firstWhere(
        (type) => type.id == id,
        orElse: () => distressTypes.first,
      );

  /// Builds the exact SMS body used by the React app (English + Hausa lines,
  /// GPS, map link, timestamp and the "send help" plea).
  static String buildSmsBody({
    required DistressType distress,
    required bool hausa,
    CachedLocation? location,
    String? note,
    DateTime? now,
  }) {
    final hasCoords = location != null;
    final lat = hasCoords ? location.latText : '0.00000';
    final lng = hasCoords ? location.lngText : '0.00000';
    final accuracy = hasCoords && location.accuracy > 0
        ? ' (±${location.accuracy.round()}m)'
        : '';
    final mapsUrl = hasCoords ? location.mapsUrl : '';

    final age = location == null ? null : LocationService.formatAge(
      location.timestamp,
      now: now,
    );
    final cachedNotice = location != null && location.isCached
        ? (hausa
            ? ' [Wurin da aka sani: ${age?.ageLabelHa}]'
            : ' [Last Known: ${age?.ageLabelEn}]')
        : '';

    String warningLine = '';
    if (location != null && location.isCached) {
      warningLine = hausa
          ? '\n⚠️ NOTE: Wannan wurin na baya ne (${age?.ageLabelHa}). Yayin da ake neman Live GPS a fili.'
          : '\n⚠️ NOTE: This is the last known location (${age?.ageLabelEn}) while live satellite lock is acquiring.';
    } else if (location != null && location.accuracy > 100) {
      warningLine = hausa
          ? '\n⚠️ GARGAƊI: Ƙarancin daidaiton GPS (±${location.accuracy.round()}m). Wurin na iya zama na kusan (hasumiyar waya).'
          : '\n⚠️ WARNING: Low GPS accuracy (±${location.accuracy.round()}m). Location is approximate (cell tower).';
    }

    final gpsLine = hasCoords
        ? '📍 GPS: Lat $lat, Long $lng$accuracy$cachedNotice$warningLine'
        : (hausa
            ? '📍 GPS: Ana neman GPS... (Ana haɗawa da tauraro a fili)'
            : '📍 GPS: Searching for GPS... (Satellite lock acquiring)');

    final timestamp = _formatTime(now ?? DateTime.now());
    final noteLine = (note == null || note.trim().isEmpty)
        ? ''
        : 'Note: "${note.trim()}"';

    final buffer = StringBuffer()
      ..writeln('[EMERGENCY / GAGGAWA - SMARTVILLAGE]')
      ..writeln('${distress.emoji} ${distress.nameEn} (${distress.nameHa})')
      ..writeln(distress.defaultMessage(hausa))
      ..writeln(noteLine)
      ..writeln()
      ..writeln(gpsLine);
    if (mapsUrl.isNotEmpty) {
      buffer.writeln('🗺️ Map: $mapsUrl');
    }
    buffer
      ..writeln('⏱️ Time: $timestamp')
      ..writeln()
      ..write('Please send help immediately! / A tura agaji cikin gaggawa!');

    return buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static String _formatTime(DateTime now) {
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final suffix = now.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  /// Opens the phone's SMS composer pre-filled with the alert.
  ///
  /// Returns `true` when the OS accepted the intent.
  Future<bool> sendSms({
    required String phone,
    required String body,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final encoded = Uri.encodeComponent(body);

    // Android accepts `sms:<number>?body=`, some OEM dialers need `smsto:`.
    for (final candidate in <Uri>[
      Uri.parse('sms:$cleanPhone?body=$encoded'),
      Uri.parse('smsto:$cleanPhone?body=$encoded'),
      Uri.parse('sms:$cleanPhone&body=$encoded'),
    ]) {
      try {
        final launched = await launchUrl(
          candidate,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (error) {
        debugPrint('[SosService] SMS intent failed for $candidate: $error');
      }
    }
    return false;
  }

  /// Dials a number directly (fallback when SMS intents are blocked).
  Future<bool> callContact(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    try {
      return await launchUrl(
        Uri(scheme: 'tel', path: cleanPhone),
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint('[SosService] call intent failed: $error');
      return false;
    }
  }

  /// Opens the coordinates in a maps app / browser.
  Future<bool> openMaps(CachedLocation location) async {
    try {
      return await launchUrl(
        Uri.parse(location.mapsUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      debugPrint('[SosService] maps intent failed: $error');
      return false;
    }
  }
}
