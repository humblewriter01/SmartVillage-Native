# Porting notes — React/Capacitor → native Flutter

The React app (`humblewriter01/SmartVillage`) was kept untouched as the
behavioural blueprint. This file records where each piece went and, more
importantly, **where the native build deliberately differs**.

## 1. Module map

| React / Capacitor | Flutter | Notes |
| --- | --- | --- |
| `src/data/cropReferenceData.ts` | `lib/data/crop_data.dart` | Generated from a JSON snapshot (`tool/source_data/`), same ids, same 69 diseases. Inline SVG data-URIs became `leafColor`/`spotColor` ints for `CustomPainter`. |
| `src/services/livestockService.ts` | `lib/data/livestock_data.dart` + `lib/services/livestock_service.dart` | Weighted scoring ported 1:1 (coverage/relevance 0.5/0.5, weight 3 ⇒ +12, clamp 15–100, top 3). |
| `src/utils/translations.ts` | `lib/data/translations_data.dart` + `lib/utils/translations.dart` | 150 keys × {en, ha}; `t(locale, key)` kept, `AppLanguage` enum added. |
| `src/utils/safeStorage.ts` | `lib/services/storage_service.dart` | `SharedPreferences` + in-memory fallback; same failure-tolerant contract. |
| `src/utils/textPreprocessor.ts` | `lib/services/text_preprocessor.dart` | Extended: 0–10 word expansion, digit-by-digit for longer numbers, decimals via “digo”, ~260 loanwords. |
| `src/services/ttsService.ts` | `lib/services/tts/*` | Web Speech API replaced by `flutter_tts` (system) + `onnxruntime` (Murya, in an isolate). `murya_pcm.dart` holds the pure-Dart tokeniser/WAV encoder; `murya_config.dart` parses the real Piper config (8 speakers, `phoneme_id_map`). |
| `src/services/cropService.ts` | `lib/services/crop_service.dart` | Identical heuristics and confidences (0.92 green leaf, 0.96 text match, 0.85–0.94 per-crop visual map). |
| `src/services/healthService.ts` | `lib/services/health_service.dart` | Same triage ladder and confidence ladder (0.70 generic → 0.95 snakebite). |
| `src/services/waterQualityService.ts` | `lib/services/water_quality_service.dart` | Same 160×160 ROI maths: glare `brightness > 242 && chroma < 14`, yellow > 0.07, algae > 0.08, particles ≥ 6, turbidity clamped 4–100. |
| `src/services/soilService.ts` | `lib/services/soil_service.dart` | Same pH/moisture breakpoints and weighted overall score (0.6 pH / 0.4 moisture). |
| `src/services/plantingCalendarService.ts` | `lib/services/planting_calendar_service.dart` | Same month-window wrap logic (Nov–Feb), seasons and recommendations. |
| `src/services/reminderService.ts` | `lib/services/reminder_service.dart` | **Different transport, same keys/dates/copy** — see §2. |
| `src/services/locationService.ts` | `lib/services/location_service.dart` | Capacitor Geolocation → `geolocator`; 4 s quick fix kept, cached fix in storage. |
| `src/services/cameraService.ts` | `lib/services/media_service.dart` + `lib/widgets/camera_capture_screen.dart` | `@capacitor/camera` → `camera` + `image_picker`. |
| `src/services/mapService.ts` | `lib/services/map_service.dart` | Pin store + haversine kept; rendering changed — see §2. |
| `src/services/historyService.ts` | `lib/services/history_service.dart` | Same record shape, stored as JSON. |
| `src/services/weatherService.ts` | `lib/services/weather_service.dart` | Same Open-Meteo call + cache; still optional. |
| `src/App.tsx` navigation | `lib/widgets/app_shell.dart` | Same tab indices 0–12, drawer + bottom bar, header EN/HA toggle. |
| `HarvestCountdownCard` / `HomeHarvestCountdown` | `lib/services/harvest_service.dart` + `lib/widgets/harvest_countdown_card.dart` | Same maths, same seeded plantings, same storage key `smartvillage.harvest_countdowns`. |
| `FullScreenCameraModal`, `QuickAlertCard`, `VoiceRecorderModal`, `MicrophonePermissionModal` | `camera_capture_screen.dart`, `sos_card.dart`, `voice_settings_sheet.dart` | Voice *recording* modal dropped (§2). |

## 2. Deliberate behavioural differences

1. **Notifications → in-app reminders.**
   `@capacitor/local-notifications` does not exist on the native side, and
   pulling in a notification plugin would add an OS-permission dance plus
   Play-services variance on cheap devices. `ReminderService` keeps the exact
   reminder model, keys (`planting-<crop>`, `harvest-<id>-3d`,
   `harvest-<id>-day`), 08:00 targeting and bilingual copy, and `ReminderCard`
   surfaces due/upcoming items on the home screen. Swapping in
   `flutter_local_notifications` later only requires calling it from
   `upsert()`/`remove()`.
2. **Map.** Leaflet/OSM tiles are gone; `offline_map_screen.dart` paints a
   projection of the six community pins over a stylised canvas and keeps the
   same tap-to-report flow. Nothing loads from the network.
3. **Voice input dropped.** The React app used the browser Web Speech API for
   “show me gona”. There is no dependable offline equivalent for Hausa, so the
   native build keeps the tap targets and drops recognition.
4. **Illustrations.** Inline SVGs became `CustomPainter` art
   (`leaf_illustration.dart`); the reference colours are parsed out of the
   original SVGs by the generator, so the palette still matches.
5. **Splash / icon.** Capacitor splash assets became a vector drawable, an
   adaptive icon (API 26+) and a layer-list fallback (API 23–25), all in the
   brand green `#1F7A4C`.

## 3. Unchanged on purpose

The diagnostic algorithms were treated as trusted domain logic, so they were
port-of-the-letter rather than improved:

* crop disease confidences and the “never mix crops” rule,
* livestock coverage/relevance weighting and hallmark bonus,
* health urgency ladder and first-aid copy,
* water turbidity clamping and the “clean iff < 25” threshold,
* soil scoring breakpoints,
* harvest maturity days for all 13 crops,
* every Hausa string, verbatim.

That means a result shown by the web app and by this build should agree; if a
test disagrees, the port is wrong, not the reference.

## 4. Murya integration details (v2.0.1)

The upstream model (`adab-tech/murya-piper-hausa-tts`) is character-level with
eight speakers, which changed four things compared with the earlier scaffold:

1. **Token layout is Piper's**, not a naive per-character list:
   `BOS(1), id₁, PAD(0), id₂, PAD(0), …, idₙ, PAD(0), EOS(2)`. The old code
   emitted a single pad after each character *and* an extra pad after
   apostrophes, and never sent `BOS`/`EOS`; that produces noise from this graph.
2. **Speaker id is sent per request.** `speaker_id_map` (F2…F3) is parsed and the
   default is `M1` (id 6). The voice sheet exposes all eight voices and the
   choice persists in `smartvillage.murya_speaker`.
3. **Tokenisation is testable in isolation.** `murya_pcm.dart` imports neither
   `onnxruntime` nor `audioplayers`, so `test/murya_tokenizer_test.dart` can
   assert the exact ids against the committed `murya.onnx.json`.
4. **The graph is quantised to INT8** (`tool/quantize_murya.py`, QDQ, ~21.7 MB
   from 77.1 MB) and verified by running a real Hausa phrase through ONNX
   Runtime before it is accepted.

## 5. Repository layout change

The project started inside `smartvillage_flutter/` and was moved to the
repository root (commit `fa7f318`) so Codemagic can pick up `codemagic.yaml`,
`pubspec.yaml` and `android/` without a working directory. All paths in this
document are now relative to the repository root; `tool/` and `test/` moved with
it unchanged.
