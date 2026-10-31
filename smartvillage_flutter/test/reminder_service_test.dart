import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartvillage/data/calendar_data.dart';
import 'package:smartvillage/services/harvest_service.dart';
import 'package:smartvillage/services/reminder_service.dart';
import 'package:smartvillage/services/storage_service.dart';

PlantedCrop _planting({
  required String id,
  required DateTime plantedOn,
  int maturityDays = 100,
}) =>
    PlantedCrop(
      id: id,
      cropId: 'maize',
      name: 'Maize',
      hausaName: 'Masara',
      fieldLabel: 'Gona ta Arewa',
      plantingDate: plantedOn,
      maturityDays: maturityDays,
      criticalTipsEn: 'Harvest when the black layer forms.',
      criticalTipsHa: 'A girbe idan baƙin layi ya bayyana.',
    );

void main() {
  final now = DateTime(2026, 10, 31, 12, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.instance.remove(ReminderService.storageKey);
  });

  group('reminder ids', () {
    test('are stable and inside the 32-bit notification range', () {
      final first = ReminderService.notificationIdForKey('harvest-abc-3d');
      final second = ReminderService.notificationIdForKey('harvest-abc-3d');
      expect(first, second);
      expect(first, greaterThanOrEqualTo(1000));
      expect(first, lessThanOrEqualTo(2147483640 + 1000));
    });

    test('differ between the warning and the harvest day', () {
      expect(
        ReminderService.notificationIdForKey('harvest-abc-3d'),
        isNot(ReminderService.notificationIdForKey('harvest-abc-day')),
      );
    });
  });

  group('harvest scheduling', () {
    test('creates a 3-day warning plus the harvest day at 08:00', () async {
      final service = ReminderService();
      // Planted 50 days ago with 100 days to maturity => 50 days left.
      final planting = _planting(
        id: 'p1',
        plantedOn: now.subtract(const Duration(days: 50)),
      );

      final scheduled =
          await service.scheduleHarvestReminders(planting, now: now);
      expect(scheduled.length, 2);

      final byKey = {for (final r in scheduled) r.key: r};
      final warning = byKey['harvest-p1-3d']!;
      final harvest = byKey['harvest-p1-day']!;

      expect(warning.target.hour, ReminderService.reminderHour);
      expect(harvest.target.hour, ReminderService.reminderHour);
      expect(
        harvest.target.difference(warning.target).inDays,
        ReminderService.harvestWarningDays,
      );
      expect(warning.category, ReminderCategory.harvest);
      expect(warning.titleHa, isNotEmpty);
      expect(harvest.bodyHa, isNotEmpty);

      final stored = await service.load();
      expect(stored.containsKey('harvest-p1-3d'), isTrue);
      expect(stored.containsKey('harvest-p1-day'), isTrue);
      expect(stored.containsKey('harvest-p1'), isTrue);
      expect(await service.hasHarvestReminders('p1'), isTrue);
    });

    test('a ripe planting schedules nothing in the past', () async {
      final service = ReminderService();
      final ripe = _planting(
        id: 'p2',
        plantedOn: now.subtract(const Duration(days: 130)),
      );
      final scheduled = await service.scheduleHarvestReminders(ripe, now: now);
      expect(scheduled, isEmpty);
      expect(await service.hasHarvestReminders('p2'), isFalse);
    });

    test('cancelling removes both child keys', () async {
      final service = ReminderService();
      final planting = _planting(
        id: 'p3',
        plantedOn: now.subtract(const Duration(days: 10)),
      );
      await service.scheduleHarvestReminders(planting, now: now);
      expect(await service.hasHarvestReminders('p3'), isTrue);

      await service.cancelHarvestReminders('p3');
      expect(await service.hasHarvestReminders('p3'), isFalse);
      expect(await service.load(), isEmpty);
    });

    test('recommitted scheduling keeps a single pair of reminders', () async {
      final service = ReminderService();
      final planting = _planting(
        id: 'p4',
        plantedOn: now.subtract(const Duration(days: 20)),
      );
      await service.scheduleHarvestReminders(planting, now: now);
      await service.scheduleHarvestReminders(planting, now: now);
      final stored = await service.load();
      expect(stored.length, 3); // -3d, -day, parent
    });
  });

  group('queries', () {
    test('due and upcoming partition the schedule', () async {
      final service = ReminderService();
      // 96 days left: warning due? no. Push a warning into the past instead.
      final planting = _planting(
        id: 'p5',
        plantedOn: DateTime(2026, 7, 30),
      );
      await service.scheduleHarvestReminders(planting, now: planting.plantingDate);

      final later = DateTime(2026, 11, 5, 9, 0);
      final due = await service.due(now: later);
      final upcoming = await service.upcoming(now: later);

      expect(due.every((r) => !r.target.isAfter(later)), isTrue);
      expect(upcoming.every((r) => r.target.isAfter(later)), isTrue);
      expect(due.length + upcoming.length, greaterThan(0));
    });

    test('prune drops long-expired reminders only', () async {
      final service = ReminderService();
      await service.upsert(
        StoredReminder(
          id: 1,
          category: ReminderCategory.water,
          key: 'water-old',
          title: 'Water test',
          titleHa: 'Gwajin ruwa',
          body: 'Retest borehole',
          bodyHa: 'Sake gwada rijiya',
          target: now.subtract(const Duration(days: 30)),
          createdAt: now.subtract(const Duration(days: 40)),
        ),
      );
      await service.upsert(
        StoredReminder(
          id: 2,
          category: ReminderCategory.water,
          key: 'water-fresh',
          title: 'Water test',
          titleHa: 'Gwajin ruwa',
          body: 'Retest borehole',
          bodyHa: 'Sake gwada rijiya',
          target: now.add(const Duration(days: 3)),
          createdAt: now,
        ),
      );

      expect(await service.prune(now: now), 1);
      final stored = await service.load();
      expect(stored.keys, <String>['water-fresh']);
    });
  });

  group('planting windows', () {
    test('next start is always in the future at 08:00', () {
      final crop = cropCalendar.first;
      final target = ReminderService.nextPlantingDate(crop, now: now);
      expect(target.isAfter(now), isTrue);
      expect(target.hour, ReminderService.reminderHour);
      expect(target.minute, 0);
    });

    test('selecting a month honours that window', () async {
      final onion = cropCalendar.firstWhere((c) => c.id == 'onion');
      final service = ReminderService();
      final reminder = await service.schedulePlantingReminder(
        onion,
        selectedMonth: onion.plantingWindows.first.startMonth,
        now: now,
      );
      expect(reminder.key, 'planting-onion');
      expect(reminder.titleHa, isNotEmpty);
      expect(reminder.target.isAfter(now), isTrue);
      expect((await service.load()).containsKey('planting-onion'), isTrue);

      await service.cancelPlantingReminder('onion');
      expect((await service.load()).containsKey('planting-onion'), isFalse);
    });
  });

  group('serialisation', () {
    test('round-trips through JSON', () {
      final reminder = StoredReminder(
        id: 42,
        category: ReminderCategory.livestock,
        key: 'livestock-goat-deworming',
        title: 'Deworm the goats',
        titleHa: 'Ba wa awaki maganin tsutsa',
        body: 'Every 90 days',
        bodyHa: 'Duk kwanaki 90',
        target: DateTime(2026, 12, 1, 8),
        createdAt: DateTime(2026, 10, 31, 9),
        extra: const <String, dynamic>{'animalId': 'goat'},
      );

      final restored = StoredReminder.fromJson(reminder.toJson());
      expect(restored.key, reminder.key);
      expect(restored.category, ReminderCategory.livestock);
      expect(restored.target, reminder.target);
      expect(restored.extra['animalId'], 'goat');
      expect(restored.titleFor(true), reminder.titleHa);
      expect(restored.titleFor(false), reminder.title);
    });

    test('survives a corrupt target date', () {
      final restored = StoredReminder.fromJson(<String, dynamic>{
        'key': 'broken',
        'category': 'not-a-category',
        'targetDateIso': 'not-a-date',
      });
      expect(restored.key, 'broken');
      expect(restored.category, ReminderCategory.harvest);
      expect(restored.id, greaterThan(0));
    });
  });
}
