<div align="center">

# 📝 NoteHeaven

**A private, local-first note-taking app for Android.**

Capture ideas with rich text, images, voice recordings and freehand sketches —
organise them with pins and colours, search instantly, get AI writing help, and
share notes device-to-device over your local network. Everything stays on your
phone.

</div>

---

## ✨ Features

- **Rich notes** — title + body with custom text and note colours.
- **Images** — attach from gallery, pinch-to-zoom preview, share out.
- **Voice notes** — record and play back inline; one clip at a time.
- **Sketches** — freehand drawing with colours, brush sizes, eraser, undo &
  clear. Saved with the note as scalable vector strokes.
- **AI assistant** *(optional)* — summarise, improve, fix grammar, continue
  writing or ask anything, powered by DeepSeek.
- **Pin & organise** — pin important notes to the top, masonry grid layout.
- **Fast search** — live results with match highlighting.
- **Swipe-free delete with Undo** — nothing is lost by accident.
- **Light / Dark / System** themes.
- **Peer-to-peer sharing** — send a note (text, sketch and media) to a nearby
  device on the same Wi-Fi, no account or internet required.

Your notes live in a local SQLite database. There is no cloud account and no
tracking.

## 🚀 Getting started

```bash
git clone https://github.com/maaz-bin-hassan/NoteHeaven.git
cd NoteHeaven

# Optional: enable the AI assistant. The DeepSeek key lives in the backend
# proxy (./server), never in the app — point the app at your proxy:
cp .env.example .env          # then set AI_PROXY_URL (and AI_APP_KEY)

flutter pub get
flutter run
```

> The app is fully functional without the proxy configured — AI features simply
> stay disabled. The DeepSeek API key never ships inside the app; deploy the
> proxy in [`server/`](server/) and the app calls that. See
> [`server/README.md`](server/README.md) to run it locally.

## 🛠 Tech

Flutter • Material 3 • SQLite (`sqflite`) • `record` / `audioplayers` •
`web_socket_channel` • DeepSeek via a Node/Express backend proxy
([`server/`](server/)).

See [`AGENTS.md`](AGENTS.md) for architecture and contributor conventions.

## 📦 Building a release

1. Create an upload keystore and copy `android/key.properties.example` to
   `android/key.properties` with its details.
2. Build the Play Store bundle:
   ```bash
   flutter build appbundle --release
   ```

The Android build targets the latest SDK, supports **16 KB memory pages**
(Android 15+), and ships R8-minified. See the *Release / Play Store* section of
[`AGENTS.md`](AGENTS.md) for details.

## 📄 License

Released under the terms in [`LICENSE`](LICENSE) (add one before publishing).
