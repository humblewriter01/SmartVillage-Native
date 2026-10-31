import 'package:flutter/foundation.dart';

import '../models/planting_calendar.dart';
import 'harvest_service.dart';
import 'storage_service.dart';

/// Reminder categories mirrored from `src/services/reminderService.ts`.
enum ReminderCategory { planting, harvest, livestock, water, soil, cropFollowup }

ReminderCategory _categoryFromName(Object? raw) {
  final value = raw?.toString();
  return ReminderCategory.values.firstWhere(
    (category) => category.name == value,
    orElse: () => ReminderCategory.harvest,
  );
}

/// A single reminder stored on the device.
///
/// The React app pushed these into the OS notification tray through
/// `@capacitor/local-notifications`. The native build keeps the same model,
/// keys and bilingual copy but keeps the schedule **inside the app**: it needs
/// no notification plugin, no channel setup and no OS permission, so reminders
/// still resolve correctly on a bare Android install that has never had
/// Google Play services.
class StoredReminder {
  const StoredReminder({
    required this.id,
    required this.category,
    required this.key,
    required this.title,
    required this.titleHa,
    required this.body,
    required this.bodyHa,
    required this.target,
    required this.createdAt,
    this.extra = const <String, dynamic>{},
  });

  final int id;
  final ReminderCategory category;
  final String key;
  final String title;
  final String titleHa;
  final String body;
  final String bodyHa;
  final DateTime target;
  final DateTime createdAt;
  final Map<String, dynamic> extra;

  String titleFor(bool hausa) => hausa && titleHa.isNotEmpty ? titleHa : title;
  String bodyFor(bool hausa) => hausa && bodyHa.isNotEmpty ? bodyHa : body;

  bool isDueAt(DateTime now) => !target.isAfter(now);

  bool isFutureAt(DateTime now) => target.isAfter(now);

  /// Whole days from [now] until the reminder fires (negative when late).
  int daysLeft(DateTime now) {
    final days = target.difference(now).inHours / 24;
    return days.floor();
  }

  StoredReminder copyWith({
    String? title,
    String? body,
    DateTime? target,
    Map<String, dynamic>? extra,
  }) =>
      StoredReminder(
        id: id,
        category: category,
        key: key,
        title: title ?? this.title,
        titleHa: titleHa,
        body: body ?? this.body,
        bodyHa: bodyHa,
        target: target ?? this.target,
        createdAt: createdAt,
        extra: extra ?? this.extra,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'category': category.name,
        'key': key,
        'title': title,
        'titleHa': titleHa,
        'body': body,
        'bodyHa': bodyHa,
        'targetDateIso': target.toIso8601String(),
        'targetTimestamp': target.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'extra': extra,
      };

  static StoredReminder fromJson(Map<String, dynamic> json) {
    final iso = json['targetDateIso'] as String?;
    final stamp = (json['targetTimestamp'] as num?)?.toInt();
    final target = DateTime.tryParse(iso ?? '') ??
        (stamp != null
            ? DateTime.fromMillisecondsSinceEpoch(stamp)
            : DateTime.now());
    return StoredReminder(
      id: (json['id'] as num?)?.toInt() ?? ReminderService.notificationIdForKey(
        json['key']?.toString() ?? 'reminder',
      ),
      category: _categoryFromName(json['category']),
      key: json['key']?.toString() ?? 'reminder',
      title: json['title']?.toString() ?? '',
      titleHa: json['titleHa']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      bodyHa: json['bodyHa']?.toString() ?? '',
      target: target,
      createdAt: (json['createdAt'] as num?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['createdAt'] as num).toInt(),
            )
          : DateTime.now(),
      extra: (json['extra'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          const <String, dynamic>{},
    );
  }
}

/// Offline reminder scheduling for harvests and planting windows.
///
/// Everything is deterministic and testable: pass [now] to any method that
/// looks at the clock.
class ReminderService {
  ReminderService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  static const String storageKey = 'smartvillage.reminders';

  /// All reminders fire at 08:00 local time, matching the React app.
  static const int reminderHour = 8;

  /// Harvest warnings go out three days early.
  static const int harvestWarningDays = 3;

  static const List<String> monthNamesEn = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> monthNamesHa = <String>[
    'Janairu',
    'Fabrairu',
    'Maris',
    'Afirilu',
    'Mayu',
    'Yuni',
    'Yuli',
    'Agusta',
    'Satumba',
    'Oktoba',
    'Nuwamba',
    'Disamba',
  ];

  /// Stable 32-bit notification id for a reminder key.
  ///
  /// Identical arithmetic to the JavaScript implementation so the ids stay
  /// compatible with reminders written by an older Capacitor build.
  static int notificationIdForKey(String key) {
    var hash = 0;
    for (final code in key.codeUnits) {
      hash = ((hash << 5) - hash + code) & 0xFFFFFFFF;
      if (hash >= 0x80000000) hash -= 0x100000000;
    }
    final magnitude = hash < 0 ? -hash : hash;
    return magnitude % 2147483640 + 1000;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<Map<String, StoredReminder>> load() async {
    final raw = await _storage.getJson(storageKey);
    if (raw == null) return <String, StoredReminder>{};
    final reminders = <String, StoredReminder>{};
    raw.forEach((key, value) {
      if (value is Map) {
        final reminder = StoredReminder.fromJson(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
        reminders[key] = reminder;
      }
    });
    return reminders;
  }

  Future<void> _write(Map<String, StoredReminder> reminders) async {
    await _storage.setJson(
      storageKey,
      reminders.map((key, value) => MapEntry(key, value.toJson())),
    );
  }

  Future<void> upsert(StoredReminder reminder) async {
    final current = await load();
    current[reminder.key] = reminder;
    await _write(current);
  }

  Future<void> remove(String key) async {
    final current = await load();
    current.remove(key);
    await _write(current);
  }

  /// Drops reminders whose moment passed more than [keepDays] ago.
  Future<int> prune({DateTime? now, int keepDays = 7}) async {
    final reference = now ?? DateTime.now();
    final current = await load();
    final expired = current.entries
        .where(
          (entry) =>
              entry.value.target.difference(reference).inDays < -keepDays,
        )
        .map((entry) => entry.key)
        .toList(growable: false);
    if (expired.isEmpty) return 0;
    for (final key in expired) {
      current.remove(key);
    }
    await _write(current);
    return expired.length;
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Every stored reminder, soonest first.
  Future<List<StoredReminder>> all() async {
    final reminders = (await load()).values.toList(growable: true);
    reminders.sort((a, b) => a.target.compareTo(b.target));
    return reminders;
  }

  /// Reminders that should be shown to the farmer right now.
  Future<List<StoredReminder>> due({DateTime? now, int keepDays = 7}) async {
    final reference = now ?? DateTime.now();
    final reminders = await all();
    return reminders
        .where(
          (reminder) =>
              reminder.isDueAt(reference) &&
              reminder.target.difference(reference).inDays >= -keepDays,
        )
        .toList(growable: false);
  }

  /// Reminders coming up inside [days].
  Future<List<StoredReminder>> upcoming({DateTime? now, int days = 14}) async {
    final reference = now ?? DateTime.now();
    final limit = reference.add(Duration(days: days));
    final reminders = await all();
    return reminders
        .where(
          (reminder) =>
              reminder.isFutureAt(reference) && !reminder.target.isAfter(limit),
        )
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Harvest countdown (3-day warning + harvest day)
  // ---------------------------------------------------------------------------

  /// Schedules the three-day warning and the harvest-day alarm for [planting].
  ///
  /// Returns the reminders that are still in the future; a planting that is
  /// already ripe simply produces nothing.
  Future<List<StoredReminder>> scheduleHarvestReminders(
    PlantedCrop planting, {
    DateTime? now,
  }) async {
    final reference = now ?? DateTime.now();
    final harvestDate = HarvestService.status(planting, now: reference).harvestDate;
    final harvestDay = DateTime(
      harvestDate.year,
      harvestDate.month,
      harvestDate.day,
      reminderHour,
    );
    final warningDay = harvestDay.subtract(
      const Duration(days: harvestWarningDays),
    );

    final parentKey = 'harvest-${planting.id}';
    final warningKey = '$parentKey-3d';
    final harvestKey = '$parentKey-day';

    final scheduled = <StoredReminder>[];

    if (warningDay.isAfter(reference)) {
      final reminder = StoredReminder(
        id: notificationIdForKey(warningKey),
        category: ReminderCategory.harvest,
        key: warningKey,
        title: 'Harvest preparation for ${planting.name}! '
            '3 days left • Shirin girbin ${planting.hausaName}! Sauran kwanaki 3',
        titleHa: 'Sauran kwanaki 3 a fara girbin ${planting.hausaName}!',
        body: '3 days remaining until harvest at ${planting.fieldLabel}. '
            'Prepare drying mats and storage.',
        bodyHa: 'Shirya rumbu da wurin shanya amfanin gona na '
            '${planting.fieldLabel}.',
        target: warningDay,
        createdAt: reference,
        extra: <String, dynamic>{
          'plantedCropId': planting.id,
          'cropId': planting.cropId,
          'cropName': planting.name,
          'cropHausaName': planting.hausaName,
          'type': '3day_warning',
        },
      );
      await upsert(reminder);
      scheduled.add(reminder);
    } else {
      await remove(warningKey);
    }

    if (harvestDay.isAfter(reference)) {
      final reminder = StoredReminder(
        id: notificationIdForKey(harvestKey),
        category: ReminderCategory.harvest,
        key: harvestKey,
        title: 'Harvest Day for ${planting.name}! • '
            'Ranar girbin ${planting.hausaName} ta yi!',
        titleHa: 'Ranar girbin ${planting.hausaName} ta yi!',
        body: 'Your crop at ${planting.fieldLabel} has reached full maturity '
            'today!',
        bodyHa: 'Amfanin gonarka na ${planting.fieldLabel} ya nuna a yau '
            'don girbi.',
        target: harvestDay,
        createdAt: reference,
        extra: <String, dynamic>{
          'plantedCropId': planting.id,
          'cropId': planting.cropId,
          'cropName': planting.name,
          'cropHausaName': planting.hausaName,
          'type': 'harvest_day',
        },
      );
      await upsert(reminder);
      scheduled.add(reminder);
    } else {
      await remove(harvestKey);
    }

    await upsert(
      StoredReminder(
        id: notificationIdForKey(harvestKey),
        category: ReminderCategory.harvest,
        key: parentKey,
        title: 'Harvest Alarms for ${planting.name}',
        titleHa: 'Tunatarwar Girbin ${planting.hausaName}',
        body: 'Scheduled for 3 days before and on harvest day '
            '(${_dateLabelEn(harvestDay)}, 8:00 AM).',
        bodyHa: 'An shirya tunatarwa kwanaki 3 kafin girbi da ranar girbi '
            '(${_dateLabelHa(harvestDay)}, 8:00 na safe).',
        target: harvestDay,
        createdAt: reference,
        extra: <String, dynamic>{
          'plantedCropId': planting.id,
          'cropId': planting.cropId,
        },
      ),
    );

    return scheduled;
  }

  Future<void> cancelHarvestReminders(String plantedCropId) async {
    final current = await load();
    final prefix = 'harvest-$plantedCropId';
    current.removeWhere(
      (key, reminder) =>
          key == prefix ||
          key.startsWith('$prefix-') ||
          reminder.extra['plantedCropId'] == plantedCropId,
    );
    await _write(current);
  }

  // ---------------------------------------------------------------------------
  // Planting window
  // ---------------------------------------------------------------------------

  /// Next 08:00 opening of [crop]'s planting window on or after [now].
  static DateTime nextPlantingDate(
    CropCalendarSchedule crop, {
    int? selectedMonth,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final window = _windowForMonth(crop, selectedMonth);
    final month = window?.startMonth ?? crop.plantingStartMonth;
    final day = window?.startDay ?? crop.plantingStartDay;

    var target = DateTime(reference.year, month, day, reminderHour);
    if (!target.isAfter(reference)) {
      target = DateTime(reference.year + 1, month, day, reminderHour);
    }
    return target;
  }

  static PlantingWindow? _windowForMonth(
    CropCalendarSchedule crop,
    int? selectedMonth,
  ) {
    if (selectedMonth == null) return null;
    for (final window in crop.plantingWindows) {
      final inWindow = window.startMonth <= window.endMonth
          ? selectedMonth >= window.startMonth &&
              selectedMonth <= window.endMonth
          : selectedMonth >= window.startMonth ||
              selectedMonth <= window.endMonth;
      if (inWindow) return window;
    }
    return null;
  }

  Future<StoredReminder> schedulePlantingReminder(
    CropCalendarSchedule crop, {
    int? selectedMonth,
    DateTime? now,
  }) async {
    final reference = now ?? DateTime.now();
    final target = nextPlantingDate(
      crop,
      selectedMonth: selectedMonth,
      now: reference,
    );
    final key = 'planting-${crop.id}';
    final reminder = StoredReminder(
      id: notificationIdForKey(key),
      category: ReminderCategory.planting,
      key: key,
      title: 'Time to plant ${crop.name}! • '
          'Lokacin shuka ${crop.hausaName} ya yi!',
      titleHa: 'Lokacin shuka ${crop.hausaName} ya yi!',
      body: 'SmartVillage Calendar: Start of ${crop.name} '
          '(${crop.hausaName}) planting window on '
          '${_dateLabelEn(target)} at 8:00 AM.',
      bodyHa: 'Lokacin fara shuka ${crop.hausaName} a gona ya yi a ranar '
          '${_dateLabelHa(target)} da ƙarfe 8:00 na safe.',
      target: target,
      createdAt: reference,
      extra: <String, dynamic>{
        'cropId': crop.id,
        'cropName': crop.name,
        'cropHausaName': crop.hausaName,
        'startMonth': target.month,
        'startDay': target.day,
        'startDateFormattedEn': _dateLabelEn(target),
        'startDateFormattedHa': _dateLabelHa(target),
      },
    );
    await upsert(reminder);
    return reminder;
  }

  Future<void> cancelPlantingReminder(String cropId) async {
    final current = await load();
    current.removeWhere(
      (key, reminder) =>
          key == 'planting-$cropId' ||
          (reminder.category == ReminderCategory.planting &&
              reminder.extra['cropId'] == cropId),
    );
    await _write(current);
  }

  /// True when a harvest reminder pair already exists for [planting].
  Future<bool> hasHarvestReminders(String plantedCropId) async {
    final current = await load();
    return current.containsKey('harvest-$plantedCropId-3d') ||
        current.containsKey('harvest-$plantedCropId-day');
  }

  /// Re-schedules every stored planting without touching harvest reminders.
  Future<void> rebuildForPlantings(List<PlantedCrop> plantings, {
    DateTime? now,
  }) async {
    for (final planting in plantings) {
      await scheduleHarvestReminders(planting, now: now);
    }
  }

  static String _dateLabelEn(DateTime date) =>
      '${monthNamesEn[date.month - 1]} ${date.day}';

  static String _dateLabelHa(DateTime date) =>
      '${date.day} ga ${monthNamesHa[date.month - 1]}';

  /// Debug helper — never used in release flows.
  @visibleForTesting
  Future<void> clearAll() async {
    await _storage.remove(storageKey);
  }
}
