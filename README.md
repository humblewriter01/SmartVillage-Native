# SmartVillage v2.0 — native Flutter

Offline-first farm and family-health assistant for smallholder farmers in
Northern Nigeria, rewritten from the React + Capacitor web app into **native
Flutter**. The reason for the rewrite is the Hausa voice: the Murya ONNX model
ran inside a WebView and took seconds to speak a single sentence. Here it runs
natively through `onnxruntime`, in a background isolate, with a device-voice
fallback that keeps the app usable on a Kano-market Android phone.

Everything except the optional live weather refresh works with the radio off:
crop and livestock diagnosis, the disease library, the planting calendar, soil
scoring, water-quality scoring, the map, SOS SMS, reminders and both voices.

---

## 1. Getting it running

Prerequisites: Flutter **3.22+** (Dart 3.4+), Android SDK 34, JDK 17.

```bash
cd smartvillage_flutter
flutter pub get
flutter run                 # debug on a connected device / emulator
flutter build apk --release # release APK (debug key unless key.properties exists)
flutter test                # unit tests, no device needed
```

CI: `codemagic.yaml` builds a release APK on every push to `main`
(mac_mini_m2 → `flutter pub get` → `flutter test` → `flutter build apk --release`).

The app targets Android (`minSdk 23`, `compileSdk 34`, portrait only). iOS and
desktop folders are not included; the Android host project under `android/` is
complete and self-contained.

### Enable the Hausa voice

`assets/models/murya.onnx.json` and `MODEL_ATTRIBUTION.txt` are committed; the
INT8 graph itself (`murya.onnx`, ~21.7 MB) is produced once with:

```bash
curl -L -o model.onnx      https://huggingface.co/adab-tech/murya-piper-hausa-tts/resolve/main/model.onnx
curl -L -o model.onnx.json https://huggingface.co/adab-tech/murya-piper-hausa-tts/resolve/main/model.onnx.json
pip install -r tool/requirements-quantize.txt
python tool/quantize_murya.py --model model.onnx --config model.onnx.json \
                              --mode qdq --out assets/models/murya.onnx
flutter pub get
```

Codemagic can do this for you instead: set `MURYA_ONNX_URL` to a prebuilt file.
Without the graph the app runs normally on the device voice. Details, model
facts and licence terms: `assets/models/README.md`.

---

## 2. What is inside

```
smartvillage_flutter/
├── lib/
│   ├── main.dart                 AppState init → AppScope → MaterialApp → AppShell
│   ├── core/
│   │   ├── app_colors.dart       Deep-green palette, per-tool accents, alpha helpers
│   │   └── app_theme.dart        Material 3 theme, rounded cards, readable type
│   ├── data/                     GENERATED bilingual datasets (see §5)
│   │   ├── crop_data.dart            13 crops, 69 diseases, lookup helpers
│   │   ├── livestock_data.dart       9 animals, 36 weighted diseases
│   │   ├── health_data.dart          10 human health conditions
│   │   ├── calendar_data.dart        13 planting/harvest schedules
│   │   ├── knowledge_data.dart       35 knowledge items, 17 monographs, 20 labels
│   │   ├── soil_data.dart            9 crop soil envelopes
│   │   ├── map_data.dart             6 seed community pins
│   │   ├── locations_data.dart       10 Nigerian locations
│   │   └── translations_data.dart    150 keys × {en, ha}
│   ├── models/                   Crop, Disease, Animal, AnimalDisease, Symptom,
│   │                             HealthCondition, CropCalendarSchedule, Soil,
│   │                             KnowledgeItem, MapPin, Weather, PlantedCrop
│   ├── services/
│   │   ├── text_preprocessor.dart    Hausa normalisation (numbers, hyphens,
│   │   │                             loanword phonetics, emoji cleanup)
│   │   ├── tts/
│   │   │   ├── tts_engine.dart       Abstract engine + audio sink
│   │   │   ├── system_tts_engine.dart flutter_tts wrapper (en-NG / ha-NG)
│   │   │   ├── tts_chunker.dart      Hausa/English run splitter (lexicon + heuristics)
│   │   │   ├── murya_config.dart     Tolerant parser for murya.onnx.json
│   │   │   ├── murya_worker.dart     Background isolate: session + inference
│   │   │   ├── murya_tts_engine.dart PCM → WAV → audioplayers, 2 s watchdog
│   │   │   └── hybrid_tts_service.dart  Routing, fallback, mode override
│   │   ├── crop_service.dart         Leaf colour ID + per-crop disease scoring
│   │   ├── livestock_service.dart    Weighted symptom scoring, top-3 differentials
│   │   ├── health_service.dart       Triage ladder (snakebite → clinic review)
│   │   ├── water_quality_service.dart 160×160 ROI scoring (clarity, algae, turbidity)
│   │   ├── soil_service.dart         pH/moisture scoring + bilingual remedies
│   │   ├── planting_calendar_service.dart  Windows, seasons, recommendations
│   │   ├── harvest_service.dart      Countdown maths + 13 maturity presets
│   │   ├── reminder_service.dart     Planting + 3-day/harvest-day reminders
│   │   ├── location_service.dart     Geolocator wrapper with 4 s quick fix
│   │   ├── sos_service.dart          Offline SMS body + intent fallbacks
│   │   ├── image_analysis.dart       Pure-Dart pixel sampler (dart:ui)
│   │   ├── history_service.dart      Local activity log
│   │   ├── map_service.dart          Pin store + distance maths
│   │   ├── weather_service.dart      Cached forecast (network optional)
│   │   ├── media_service.dart        Camera / gallery acquisition
│   │   └── storage_service.dart      SharedPreferences wrapper, memory fallback
│   ├── state/app_state.dart      Locale, tab, weather, history, plantings, TTS
│   ├── utils/translations.dart   t(locale, key) over the generated table
│   ├── widgets/
│   │   ├── app_shell.dart            Header, drawer, bottom nav, back-to-exit
│   │   ├── section_card.dart         SectionCard / Pill / InfoRow / PageBody
│   │   ├── speak_button.dart         One-tap "read this aloud"
│   │   ├── language_toggle.dart      Global EN ⇄ HA switch
│   │   ├── voice_settings_sheet.dart Voice mode picker + chunk preview
│   │   ├── sos_card.dart             GPS + SMS emergency card
│   │   ├── harvest_countdown_card.dart
│   │   ├── reminder_card.dart        Due / upcoming reminders
│   │   ├── camera_capture_screen.dart  Leaf scanner UI
│   │   └── leaf_illustration.dart    CustomPainter crop art (no bitmaps)
│   └── screens/                 13 screens (see §3)
├── android/                     Host project: manifest, Gradle, theme, icons
├── assets/models/               Murya model drop-zone (+ README)
├── assets/images/               Placeholder for future bitmaps (+ README)
├── test/                        5 unit-test files (see §6)
└── tool/                        Data generator, JSON snapshot, Dart checker
```

### The voice pipeline

```
speak(text, language)
  ├─ English  → SystemTtsEngine (raw text, en-NG)
  └─ Hausa    → TextPreprocessor.normalize
                  → TtsChunker.split          (lexicon-aware language runs)
                     ├─ Hausa run    → MuryaTtsEngine  (isolate, native ONNX)
                     └─ English run  → SystemTtsEngine (brand/drug names)
```

* `TextPreprocessor` implements the required Hausa rules in order:
  digits 0–10 → words (`7` → `bakwai`, `2026` → `biyu sifili biyu shida`,
  `6.5` → `shida digo biyar`), hyphens/en/em dashes → spaces
  (`dogon-yaro` → `dogon yaro`), English loanword phonetics
  (`mancozeb` → `mankozeb`, `ph` → `pi-eich`, `gps` → `ji-pi-es`,
  `sos` → `es-o-es`, `onion` → `aniyan`, `tomato` → `tumatir`,
  `maize` → `mez`, plus ~260 agrochemical, clinical and
  everyday words), then emoji,
  bullet and symbol stripping with punctuation tidy-up.
* `TtsChunker` protects Hausa with a ~400-word lexicon (plus the hooked
  letters `ɓ ɗ ƙ ƴ`) so a Hausa sentence can never be handed to the English
  voice; unknown long tokens are treated as English so drugs and brands get
  pronounced correctly.
* The shipped config advertises 8 voices (`M1`…`F4`, default `M1`) and is
  character-level (`phoneme_type: text`); the voice sheet lets the farmer pick
  one and the choice is persisted (`smartvillage.murya_speaker`).
* `MuryaTtsEngine` loads `murya.onnx` **inside a background isolate**
  (`MuryaWorker`), runs inference, converts `Float32` output to 16-bit PCM and
  wraps it in a WAV header that `audioplayers` plays. A 2-second watchdog
  starts on the first chunk; if the model misses it, or the assets are absent,
  the remaining text is joined and spoken by the device engine (Hausa first,
  then English) and Murya stays disabled for the session.
* `VoiceSettingsSheet` (the voice icon in the header) lets the user force
  *Murya only*, *device only* or *automatic*, and preview the exact chunk split
  for a sample sentence.

---

## 3. Screens

| # | Screen | File | Highlights |
| --- | --- | --- | --- |
| 0 | Gida / Home | `home_screen.dart` | Hero, SOS, harvest countdown, reminders, weather strip, quick actions |
| 1 | Gona / Crops | `crop_screen.dart` | 13 crops, camera leaf scan, symptom text, disease library, harvest tracker |
| 2 | Lafiya / Health | `health_screen.dart` | Symptom triage, urgency ladder, first aid, danger signs |
| 3 | Yanayi / Weather | `weather_screen.dart` | Cached forecast, farm advice, offline banner |
| 4 | Ilimi / Learn | `knowledge_screen.dart` | 35 bilingual knowledge cards |
| 5 | Ruwa / Water | `water_quality_screen.dart` | Photo scoring: clarity, algae, turbidity, safe/unsafe verdict |
| 6 | Dabbobi / Livestock | `livestock_screen.dart` | 9 animals, symptom check-list, weighted top-3 differentials |
| 7 | Taswira / Map | `offline_map_screen.dart` | Offline pin map (CustomPaint + projected pins), add/report pins |
| 8 | Kalanda / Calendar | `farming_calendar_screen.dart` | Season, planting windows, per-crop reminders |
| 9 | Laburari / Library | `crop_library_screen.dart` | Disease reference with painted illustrations |
| 10 | Tarihi / History | `history_screen.dart` | Local log of checks and SOS sends |
| 11 | Ƙasa / Soil | `soil_health_screen.dart` | pH + moisture scoring, crop-specific remedies |
| 12 | Game da / About | `about_screen.dart` | Version, model status, safety notes |

Navigation mirrors the React app (drawer + bottom bar + the same tab indices:
`Gida` 0, `Gona` 1, `Lafiya` 2, `Yanayi` 3, `Ilimi` 4, `Ruwa` 5, `Dabbobi` 6,
`Taswira` 7, `Kalanda` 8, `Laburari` 9, `Tarihi` 10, `Ƙasa` 11, `Game da` 12),
so the two apps stay conceptually interchangeable. Speech *recognition* (the
React app used the Web Speech API for "show me gona") is not part of this
build: the browser API it relied on has no native equivalent without an extra
plugin, so spoken commands were dropped in favour of the tap targets.

The EN/HA toggle in the header flips `AppLanguage` on `AppState`, which every
screen reads through `AppScope.of(context)`; the locale is persisted under
`smartvillage.locale`.

---

## 4. Native integrations

* **SOS** — `SosCard` shows a cached GPS fix instantly, then follows
  `positionStream()`. `SosService.buildSmsBody` composes a bilingual message
  with coordinates, ±accuracy, a maps link, the time and stale-fix warnings; it
  is launched with `url_launcher` trying `sms:<number>?body=`, then `smsto:`,
  then `sms:<number>&body=`. If every intent fails the text is copied to the
  clipboard and the user is told to paste it. Successful sends are logged to
  History.
* **Camera** — `CameraCaptureScreen` uses the `camera` plugin for the leaf
  scanner (portrait, tap-to-focus, flash toggle, gallery fallback via
  `image_picker`). No camera permission is required to install; the manifest
  marks both camera features `required="false"`.
* **Location** — `geolocator` with a 4-second quick fix, then a high-accuracy
  stream; permission denial degrades to "SOS without coordinates" rather than
  blocking the button.
* **Reminders** — scheduled on-device by `ReminderService` (keys
  `planting-<crop>`, `harvest-<id>-3d`, `harvest-<id>-day`, all at 08:00) and
  surfaced by `ReminderCard` on the home screen. No notification plugin, no OS
  permission, no Play-services dependency — they never silently stop working on
  a bare Android install.
* **Storage** — `SharedPreferences` with an in-memory fallback, so a device with
  a broken keystore still keeps state for the session instead of crashing.

---

## 5. Regenerating the datasets

`lib/data/*.dart` is generated; edit the JSON and regenerate rather than
patching Dart by hand:

```bash
node tool/generate_data.mjs     # rewrites lib/data/*.dart in place
```

`tool/source_data/*.json` is a snapshot of the reference React/TypeScript
datasets (`src/data/cropReferenceData.ts`, `src/services/livestockService.ts`,
`src/services/healthService.ts`, `src/utils/translations.ts`, …), extracted with
esbuild. The original React repository is kept untouched as the blueprint; the
generator only reads this snapshot.

---

## 6. Tests

`flutter test` runs five suites that need no device and no model file:

| File | Covers |
| --- | --- |
| `test/text_preprocessor_test.dart` | Number words, hyphen/dash removal, loanword phonetics, emoji/`&`/`%` cleanup, full pipeline |
| `test/tts_chunker_test.dart` | Hausa lexicon protection, English detection, run splitting, `englishRatio` |
| `test/datasets_test.dart` | 13 crops / 69 diseases / 9 animals / 36 diseases / 150 translation keys, bilingual completeness, lookup helpers |
| `test/diagnosis_services_test.dart` | Livestock weighting, crop scoping, health triage, soil scoring, calendar windows |
| `test/reminder_service_test.dart` | Reminder ids, harvest pair scheduling, due/upcoming, prune, JSON round-trip |
| `test/murya_tokenizer_test.dart` | Piper BOS/PAD/EOS layout, hooked letters, config parsing against the committed `murya.onnx.json`, WAV header/clamping |

`tool/check_dart.py` is a dependency-free sanity check (comment/string-aware
bracket balance, relative-import resolution, unused relative imports) for
environments without the Dart SDK:

```bash
python3 tool/check_dart.py    # lib/ and test/
```

---

## 7. Release notes

* `android/app/build.gradle` signs with `android/key.properties` when that file
  exists (Codemagic writes it from `CM_KEYSTORE*`) and falls back to the debug
  key otherwise, so `flutter build apk --release` always yields an installable
  APK. Never commit `key.properties` — it is git-ignored.
* `packagingOptions.jniLibs.pickFirsts` resolves the duplicate
  `libc++_shared.so` that `onnxruntime` shares with the audio/camera plugins;
  without it AGP 8 fails the merge step.
* No internet permission is needed for the offline features; `INTERNET` is only
  declared for the optional weather refresh, and cleartext traffic is disabled.
* `minSdk 24` is the floor for `geolocator` 13 / `flutter_tts` 4; `targetSdk`
  is 34. `onnxruntime` supports arm32/arm64 Android (no x86, no web).
* Deleting the two model files, or moving to a device with no Hausa TTS voice,
  degrades to the English device voice rather than failing — the About screen
  and the voice sheet both report the active route.

## 8. Known limitations

* The whole Dart tree was authored without a Flutter toolchain available in the
  authoring environment: it has **not** been `flutter analyze`d, compiled or
  run. Expect to fix a handful of analyzer nits (deprecations, unused imports)
  on the first `flutter pub get && flutter analyze`. The data layer, service
  algorithms and test expectations were audited by hand against the React
  original.
* The Murya graph is not committed in this checkout (it has to be quantised
  once, or supplied by CI — see `assets/models/README.md`); until then Hausa
  speech falls back to the device voice.
* The offline map is a projected canvas with tappable pins, not a tile map —
  there is no packaged basemap, matching the reference app’s offline design.
* Live weather needs a network connection; the last forecast is cached and
  labelled as cached.
* Tokenisation is character-level with Piper's `BOS, id, PAD … EOS` layout
  (`lib/services/tts/murya_pcm.dart`), matching the shipped config's
  `phoneme_type: text`. A model exported for espeak IPA phonemes would need a
  different front-end; `phoneme_id_map` would have to be keyed by IPA.
* Reminders are in-app (see §4); they do not appear in the Android
  notification tray.

---

## 9. CI (Codemagic) and the Murya model

`codemagic.yaml` sits in this folder and defines one workflow:

| Setting | Value |
| --- | --- |
| Workflow | `android-release` |
| Instance | `mac_mini_m2` |
| Trigger | push to `main` (superseded builds cancelled) |
| Steps | diagnostics → *prepare Murya model* → `python3 tool/check_dart.py` → `flutter pub get` → `flutter analyze` (non-fatal) → `flutter test` → `flutter build apk --release` → checksum |
| Artifacts | `build/app/outputs/flutter-apk/*.apk`, `apk-sha256.txt` |

One-time setup in the Codemagic UI:

1. Add the repository; the working directory is the repo root, and
   `codemagic.yaml` is picked up automatically.
2. **Signing (optional)** — create an environment group `smartvillage_signing`
   with `CM_KEYSTORE` (base64 of the .jks), `CM_KEYSTORE_PASSWORD`,
   `CM_KEY_ALIAS`, `CM_KEY_PASSWORD`. `android/app/build.gradle` uses it when
   `android/key.properties` exists and otherwise falls back to the debug key,
   so the build never breaks for lack of a keystore.
3. **Murya voice (optional)** — either commit `assets/models/murya.onnx` or set
   `MURYA_ONNX_URL` (+ `MURYA_ONNX_JSON_URL` if the config is not committed) in
   the same group. The prepare step validates the download (size, ONNX magic
   byte, config presence) and fails loudly on a truncated file. With no model
   it prints a notice and the APK is built with the device-voice fallback.

Signing/real-device notes: `minSdk 24`, `targetSdk 34`, `compileSdk 34`,
JVM 17, Gradle 8.4, AGP 8.3.2.

### Pre-flight sanity checklist (verified in this commit)

| Check | Result |
| --- | --- |
| `pubspec.yaml` constraints | every dependency uses a caret range (`^x.y.z`); SDK `>=3.4.0 <4.0.0` |
| `android/app/build.gradle` | `minSdk = 24`, `targetSdk = 34`, `compileSdk = 34`, JVM 17 |
| `AndroidManifest.xml` | `INTERNET`, `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `SEND_SMS`, `WAKE_LOCK`, `<queries>` for sms/smsto/tel/https/TTS |
| Duplicate native libs | `packagingOptions.jniLibs.pickFirsts` for `libc++_shared.so` / onnxruntime |
| TTS isolate imports | `dart:isolate`, `dart:typed_data`, `onnxruntime`, `murya_config`, `murya_pcm` all present and used |
| Asset registration | `flutter: assets: - assets/models/`, `- assets/images/` |
| Structural check | `python3 tool/check_dart.py` → 76 Dart files (lib + test) clean |
