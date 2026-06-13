# NoteHeaven (flutter_application_1)

NoteHeaven is a Flutter note-taking app with rich media support, local persistence, peer sharing, and DeepSeek AI features.

## Setup

1. Install Flutter SDK `^3.12.2`.
2. Copy environment config:
   ```bash
   cp .env.example .env
   ```
3. Set `DEEPSEEK_API_KEY` in `.env` to a valid DeepSeek API key.
4. Install dependencies and run:
   ```bash
   flutter pub get
   flutter run
   ```

The app loads `.env` at startup via `flutter_dotenv` and lists it as a Flutter asset in `pubspec.yaml`. Never commit `.env`; only commit `.env.example`.

## Project layout

```
lib/
  main.dart                 # App entry, theme, dotenv init
  models/note.dart          # Note data model
  screens/                  # UI screens (home, editor, search, drawing)
  services/                 # Business logic and platform integrations
  widgets/                  # Reusable UI components
  utils/animations.dart     # Shared animation helpers
assets/
  fonts/Poppins/            # App font family
  images/                   # Static images
```

## Architecture

- **NoteService** (`lib/services/note_service.dart`): Singleton facade over note CRUD and stream updates.
- **DatabaseHelper** (`lib/services/database_helper.dart`): SQLite storage via `sqflite`.
- **AudioService** (`lib/services/audio_service.dart`): Recording/playback with `record` and `audioplayers`.
- **DeepSeekService** (`lib/services/deepseek_service.dart`): OpenAI-compatible chat completions against DeepSeek (`deepseek-v4-flash`).
- **NetworkService / DiscoveryService / NoteShareManager**: Local network note sharing over WebSockets.
- **StorageService**: File and preference helpers.

Screens receive services via constructor injection where possible. Prefer extending existing services over duplicating persistence logic.

## Conventions

- Use Material 3 theming defined in `lib/main.dart` (Poppins font, purple/teal palette).
- Keep platform-specific code inside `services/`, not in widgets.
- Use `debugPrint` instead of `print` for diagnostics.
- Guard async UI updates with `mounted` checks in `State` classes.
- Request runtime permissions through `permission_handler` before microphone/storage use.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DEEPSEEK_API_KEY` | Yes | DeepSeek API key for `https://api.deepseek.com/chat/completions` |

Access env values with `dotenv.env['DEEPSEEK_API_KEY']` after `await dotenv.load(fileName: '.env')`.

## Commands

```bash
flutter pub get          # Resolve dependencies
flutter analyze          # Static analysis
flutter test             # Run widget/unit tests
flutter pub outdated     # Check for package updates
```

## Package notes

Major-version upgrades in use:

- **share_plus 13.x**: Prefer `SharePlus.instance.share(ShareParams(...))` over deprecated `Share.share()`.
- **record 7.x**: Uses `AudioRecorder` with `RecordConfig`.
- **audioplayers 6.x**: Uses `AudioPlayer` with `DeviceFileSource` / `AssetSource`.
- **permission_handler 12.x**: Check platform setup in AndroidManifest and Info.plist when adding permissions.

When bumping dependencies, run `flutter pub get`, `flutter analyze`, and a device/emulator smoke test for note create/edit, audio record/play, image attach, and share flows.
