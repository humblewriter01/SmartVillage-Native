import 'package:flutter/widgets.dart';

import '../models/weather.dart';
import '../services/harvest_service.dart';
import '../services/history_service.dart';
import '../services/location_service.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import '../services/tts/hybrid_tts_service.dart';
import '../services/weather_service.dart';
import '../utils/translations.dart';

/// Navigation targets (mirrors the tab ids used by the React `App.tsx`).
class TabId {
  const TabId._();

  static const int home = 0;
  static const int crop = 1;
  static const int health = 2;
  static const int weather = 3;
  static const int knowledge = 4;
  static const int water = 5;
  static const int livestock = 6;
  static const int map = 7;
  static const int calendar = 8;
  static const int library = 9;
  static const int history = 10;
  static const int soil = 11;
  static const int about = 12;
}

/// Global application state (language, tab, cached weather, history, TTS).
class AppState extends ChangeNotifier {
  AppState({
    HybridTtsService? tts,
    HistoryService? history,
    HarvestService? harvest,
    WeatherService? weather,
    LocationService? location,
    ReminderService? reminders,
    StorageService? storage,
  })  : tts = tts ?? HybridTtsService(),
        _historyService = history ?? HistoryService(),
        _harvestService = harvest ?? HarvestService(),
        _weatherService = weather ?? WeatherService(),
        _locationService = location ?? LocationService(),
        reminders = reminders ?? ReminderService(),
        _storage = storage ?? StorageService.instance;

  final HybridTtsService tts;
  final HistoryService _historyService;
  final HarvestService _harvestService;
  final WeatherService _weatherService;
  final LocationService _locationService;
  final ReminderService reminders;
  final StorageService _storage;

  static const String _languageKey = 'smartvillage.locale';

  AppLanguage _language = AppLanguage.english;
  int _tab = TabId.home;
  bool _cropHarvestTab = false;
  bool _isOnline = true;
  bool _weatherLoading = false;
  WeatherForecast _forecast = const WeatherForecast(
    days: <WeatherDay>[],
    isCached: true,
    locationName: 'Kano',
  );
  List<HistoryRecord> _history = const <HistoryRecord>[];
  List<PlantedCrop> _plantings = const <PlantedCrop>[];
  CachedLocation? _lastLocation;
  bool _initialised = false;

  AppLanguage get language => _language;
  bool get isHausa => _language.isHausa;
  int get tab => _tab;
  bool get cropHarvestTab => _cropHarvestTab;
  bool get isOnline => _isOnline;
  bool get weatherLoading => _weatherLoading;
  WeatherForecast get forecast => _forecast;
  List<HistoryRecord> get history => _history;
  List<PlantedCrop> get plantings => _plantings;
  CachedLocation? get lastLocation => _lastLocation;
  bool get initialised => _initialised;

  /// Shorthand for [Translations.t] with the active language.
  String t(String key) => Translations.t(_language, key);

  String pick(String en, String ha) => _language.isHausa ? ha : en;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    final savedLanguage = await _storage.getString(_languageKey);
    _language = AppLanguage.fromCode(savedLanguage);

    await tts.loadPreferences();
    if (_language.isHausa) {
      // Warm the ONNX model in the background so the first tap is instant.
      fireAndForget(tts.warmUpMurya(), label: 'Murya warm-up');
    }

    await Future.wait<void>(<Future<void>>[
      reloadHistory(),
      reloadPlantings(),
      reloadWeather(),
    ]);

    _lastLocation = await _locationService.lastKnownLocation();
    await _syncReminders();
    notifyListeners();
  }

  /// Keeps the on-device reminder list in step with the stored plantings.
  ///
  /// Runs once per launch: expired entries are dropped and any planting saved
  /// before reminders existed gets its 3-day warning and harvest-day alarm.
  Future<void> _syncReminders() async {
    await reminders.prune();
    for (final planting in _plantings) {
      if (!await reminders.hasHarvestReminders(planting.id)) {
        await reminders.scheduleHarvestReminders(planting);
      }
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    await _storage.setString(_languageKey, language.code);
    if (language.isHausa) fireAndForget(tts.warmUpMurya(), label: 'Murya warm-up');
    notifyListeners();
  }

  void toggleLanguage() {
    setLanguage(isHausa ? AppLanguage.english : AppLanguage.hausa);
  }

  void goToTab(int index, {bool cropHarvest = false}) {
    if (index != TabId.crop) {
      _cropHarvestTab = false;
    } else {
      _cropHarvestTab = cropHarvest;
    }
    _tab = index;
    notifyListeners();
  }

  void openHarvestTracker() {
    _cropHarvestTab = true;
    _tab = TabId.crop;
    notifyListeners();
  }

  void setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    notifyListeners();
  }

  Future<void> reloadWeather({double? latitude, double? longitude}) async {
    _weatherLoading = true;
    notifyListeners();
    try {
      _forecast = await _weatherService.load(
        latitude: latitude,
        longitude: longitude,
      );
      _isOnline = !_forecast.isCached || _forecast.days.isNotEmpty;
    } catch (_) {
      _forecast = await _weatherService.cached();
      _isOnline = false;
    } finally {
      _weatherLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadHistory() async {
    _history = await _historyService.list();
    notifyListeners();
  }

  Future<void> reloadPlantings() async {
    _plantings = await _harvestService.load();
    notifyListeners();
  }

  Future<void> recordHistory({
    required HistoryType type,
    required String title,
    required String detail,
  }) async {
    await _historyService.add(type: type, title: title, detail: detail);
    await reloadHistory();
  }

  Future<void> deleteHistory(int id) async {
    await _historyService.delete(id);
    await reloadHistory();
  }

  Future<void> clearHistory() async {
    await _historyService.clear();
    _history = const <HistoryRecord>[];
    notifyListeners();
  }

  Future<void> addPlanting(PlantedCrop crop) async {
    _plantings = <PlantedCrop>[crop, ..._plantings];
    await _harvestService.save(_plantings);
    // Three-day warning + harvest-day alarm, stored on the device.
    await reminders.scheduleHarvestReminders(crop);
    notifyListeners();
  }

  Future<void> removePlanting(String id) async {
    _plantings = _plantings.where((p) => p.id != id).toList(growable: false);
    await _harvestService.save(_plantings);
    await reminders.cancelHarvestReminders(id);
    notifyListeners();
  }

  /// Due and upcoming reminders, soonest first.
  Future<List<StoredReminder>> loadReminders({int upcomingDays = 14}) async {
    final now = DateTime.now();
    final due = await reminders.due(now: now);
    final upcoming = await reminders.upcoming(now: now, days: upcomingDays);
    return <StoredReminder>[...due, ...upcoming];
  }

  Future<void> refreshLocation() async {
    _lastLocation = await _locationService.bestEffort();
    notifyListeners();
  }

  /// Speak [text] using the active language + voice profile.
  Future<void> speak(String text) =>
      tts.speak(text, language: _language);

  Future<void> stopSpeaking() => tts.stop();

  @override
  void dispose() {
    tts.dispose();
    super.dispose();
  }
}

/// Provides [AppState] to the widget tree and rebuilds dependents.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!.notifier!;
  }

  /// Access without subscribing to rebuilds (for callbacks).
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!.notifier!;
  }
}

/// Fire-and-forget helper.
///
/// Deliberately *not* named `unawaited`: `dart:async` already exports that name,
/// and a widget that imports both this library and `dart:async` would hit an
/// ambiguous-import error.
void fireAndForget(Future<void> future, {String label = 'background task'}) {
  future.catchError((Object error) {
    debugPrint('[AppState] $label failed: $error');
  });
}
