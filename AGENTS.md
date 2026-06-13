# NoteHeaven

NoteHeaven is a local-first Flutter note-taking app with rich media (images,
voice, freehand sketches), SQLite persistence, peer-to-peer LAN sharing, and an
optional DeepSeek-powered writing assistant.

## Setup

1. Install Flutter SDK `^3.12.2` (developed against Flutter 3.44 / Dart 3.12).
2. (Optional) Enable AI by copying the environment config and adding a key:
   ```bash
   cp .env.example .env
   # then set DEEPSEEK_API_KEY in .env
   ```
   The app runs fully without a key — AI features simply stay disabled.
3. Install dependencies and run:
   ```bash
   flutter pub get
   flutter run
   ```

`.env` is loaded at startup via `flutter_dotenv` and is listed as a Flutter
asset, so the file must exist at build time (`cp .env.example .env` is enough —
an empty key is fine). Never commit `.env`; only commit `.env.example`.

> **Security:** bundling an API key as an asset means it ships inside the
> APK/AAB and can be extracted. For a real production release, proxy DeepSeek
> calls through a backend you control and have the app call that instead.

## Project layout

```
lib/
  main.dart                     # App entry, theme wiring, dotenv init
  models/
    note.dart                   # Note model (JSON + SQLite mappers)
    drawing_stroke.dart         # Serializable sketch stroke
  theme/
    app_theme.dart              # Material 3 light/dark ThemeData
    app_palette.dart            # Note-colour palette + light/dark resolution
  screens/                      # home, note_editor, search, settings, drawing(+preview)
  services/                     # business logic & platform integration
  widgets/                      # note_card, audio_player, image_preview, drawing_canvas
  utils/animations.dart         # Shared page transition
test/                           # Unit tests for the model and palette
```

## Architecture

- **SettingsController** (`services/settings_controller.dart`): `ChangeNotifier`
  holding the persisted `ThemeMode` (system/light/dark).
- **NoteService** (`services/note_service.dart`): singleton facade over note
  CRUD with a broadcast stream. Delete is two-phase — `removeNote` drops the row
  but keeps media so the UI can offer Undo; `purgeNoteFiles` reclaims the files
  once the undo window passes. Supports `setPinned`.
- **DatabaseHelper** (`services/database_helper.dart`): SQLite (`sqflite`),
  schema v2 with `onUpgrade` migration. Owns media persistence — copies picked
  files into app storage and cleans up removed/orphaned files.
- **AudioService** (`services/audio_service.dart`): recording via `record`
  (mic permission only — no storage permission, which is denied on Android 13+)
  and a `ValueNotifier` that coordinates single-clip playback across
  `AudioPlayerWidget`s (each owns its own `AudioPlayer`).
- **DeepSeekService** (`services/deepseek_service.dart`): OpenAI-compatible chat
  client. Degrades gracefully via `isConfigured`; model is overridable with
  `DEEPSEEK_MODEL` (default `deepseek-chat`).
- **NetworkService / DiscoveryService / NoteShareManager**: LAN peer discovery
  (UDP) + transfer (WebSocket). Media is embedded as base64 so received notes
  reference files that exist locally; received notes get a fresh id.

Screens receive services via constructor injection. Prefer extending existing
services over duplicating persistence logic.

## Conventions

- Material 3 theming lives in `lib/theme/` (Poppins, seeded colour scheme). Do
  not hand-roll `ThemeData` in widgets.
- Note backgrounds are stored as `#RRGGBB`; resolve display colours through
  `AppPalette.resolve(hex, brightness)` (handles dark mode) and pick text
  contrast with `AppPalette.onColor`.
- Keep platform-specific code inside `services/`, not in widgets.
- Use `debugPrint` instead of `print`.
- Guard async UI updates with `mounted` checks in `State` classes.
- Request runtime permissions through the plugin's own API where possible
  (e.g. the recorder's `hasPermission()`), not a blanket `permission_handler`
  storage request.
- Modern APIs only: `Color.withValues()` (not `withOpacity`), `toARGB32()`
  (not `.value`), `PopScope` (not `WillPopScope`), `SharePlus.instance.share`
  (not `Share.share`).

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DEEPSEEK_API_KEY` | No | Enables the AI assistant. Without it, AI is disabled. |
| `DEEPSEEK_MODEL` | No | Override the chat model (default `deepseek-chat`). |

## Commands

```bash
flutter pub get          # Resolve dependencies
flutter analyze          # Static analysis (expected: no issues)
flutter test             # Run unit tests
flutter run              # Run on a device/emulator
dart run flutter_launcher_icons   # Regenerate launcher icons from assets/images/logo.png
```

## Release / Play Store

- **Application id:** `com.noteheaven.app` (set in `android/app/build.gradle`).
- **Signing:** copy `android/key.properties.example` to `android/key.properties`
  and point it at your upload keystore. Without that file the build falls back
  to debug signing (fine for development, not for upload). `key.properties` and
  `*.jks/*.keystore` are git-ignored.
- **Toolchain:** Gradle 8.13, AGP 8.11.1, Kotlin 2.3.20 (pinned — do not bump to
  the Flutter template defaults without reason).
- **16 KB page size (Android 15+):** NDK r27 (`27.0.12077973`) plus
  uncompressed/aligned native libs (`jniLibs.useLegacyPackaging = false`) make
  the app 16 KB-compatible. Verified: `libapp.so` / `libflutter.so` LOAD
  segments are 64 KB-aligned (a superset of 16 KB).
- **Canonical release build** (extracts symbols for crash de-obfuscation):
  ```bash
  flutter build appbundle --release --split-debug-info=build/symbols --obfuscate
  ```
  Keep `build/symbols/` to symbolicate Play Console crash reports. The AAB is
  ~48 MB because it bundles all ABIs; Play delivers ~16–20 MB per device.
- **Release minification:** R8 + resource shrinking are enabled; keep rules are
  in `android/app/proguard-rules.pro`. After dependency bumps, smoke-test a
  release build to ensure nothing was stripped.
- A "failed to strip debug symbols" warning appears when the local Android
  `cmdline-tools` component is missing; it is benign here — the native libs are
  already at their stripped size.

## Package notes

Major-version upgrades in use:

- **share_plus 13.x**: `SharePlus.instance.share(ShareParams(...))`.
- **record 7.x**: `AudioRecorder` with `RecordConfig`; mic permission via
  `hasPermission()`.
- **audioplayers 6.x**: one `AudioPlayer` per clip; `DeviceFileSource`.
- **permission_handler 12.x**: only used where genuinely required.

When bumping dependencies, run `flutter pub get`, `flutter analyze`,
`flutter test`, and a device smoke test of: note create/edit, pin, swipe/Undo
delete, image attach + preview/share, audio record/play, sketch save/edit, AI
assist, and nearby share.
