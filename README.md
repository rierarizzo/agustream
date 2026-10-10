# Agus Desktop

A desktop client for Windows 11 (and Linux later) that connects to the **Nuvio** backend,
is compatible with the **Stremio addon protocol**, and plays with **libmpv**.

## What it is

- Connects to the **Nuvio backend**: login, library, watch progress, addons/plugins.
- Uses **Stremio addons** (HTTP/JSON) as content sources.
- Plays with **libmpv** (through `media_kit`), with debrid as the primary source.
- Is **complementary to Nuvio**, not a replacement.

**Working name:** `agus-desktop` (folder) / Dart package: `agustream`.

## Motivation

A **learning project** for desktop software development.

## Stack

| Layer | Technology | Reason |
| --- | --- | --- |
| Language / UI | **Flutter + Dart** | One codebase for W11/Linux/mobile, declarative UI, hot reload |
| Render / animation | **Impeller** | Fluid up to display refresh rate |
| Playback | **`media_kit`** (uses **libmpv**) | Embedded libmpv via GPU texture, many formats, hardware decoding |
| Accounts/sync backend | **Nuvio API** (Supabase) | Reuse login/library/progress |
| Sources | **Stremio addons** (HTTP/JSON) | Open and documented protocol |
| Debrid | Phase 2 (Real-Debrid, AllDebrid, Premiumize, TorBox) | v1 uses addons with debrid configured (direct URLs) |
| Local persistence | TBD | Local cache |

## Architecture

```text
lib/
├── main.dart
├── app/            # bootstrap, theme, routing
├── ui/             # screens and widgets (Flutter)
├── domain/         # models and logic (no UI or network dependencies)
├── data/
│   ├── backend/    # Nuvio backend client      -> Account/Library/Progress repos
│   ├── local/      # local backend (no account)
│   ├── addons/     # Stremio protocol client
│   ├── debrid/     # DebridProvider
│   └── store/      # local persistence (session + JSON files)
└── services/
    └── player/     # media_kit wrapper -> PlayerService
```

### Rules

1. The **UI never talks HTTP directly**; it uses `data/` and `domain/`.
2. The **account backend is isolated** behind interfaces (`AccountRepository`,
   `LibraryRepository`, `ProgressRepository`, `AddonRepository`). Only
   `data/backend/` is replaced if it changes, and `BackendKind` in
   `lib/app/backend/` picks the implementation. Profiles are optional: a backend
   without them declares `requiresProfile == false` and the app never shows the
   profile picker.
3. The **player is isolated** behind `PlayerService` (never call `media_kit` from widgets).
4. **Dependency rule:** `ui → domain → data`. Never the other way around.

### Backend modes

`AGUSTREAM_BACKEND` picks the account backend (`BackendKind.fromEnvironment`):

| Value | Account | Library / progress | Addons |
| --- | --- | --- | --- |
| `nuvio` (default) | Nuvio login + profiles | Nuvio (Supabase) | from the account |
| `local` | none, always ready | JSON files under `%APPDATA%\Agustream\local` | `AGUSTREAM_LOCAL_ADDONS` (comma-separated manifest URLs) |

Content always comes from Stremio addons; `local` only removes the account
backend. Writes (`add`/`remove` to the library, `save` progress) are part of the
`LibraryRepository`/`ProgressRepository` contracts.

## Environment & setup

- **System:** native **Windows 11**. **Do NOT use WSL2** for the Windows desktop app
  (the MSVC toolchain does not work there). WSL2 would only apply to the Linux target.
- **Terminal:** Git Bash or PowerShell. VS Code for editing.
- **Build prerequisites (Windows):**
  1. **Flutter SDK** (stable) on PATH.
  2. **Visual Studio 2022 Build Tools** with the *"Desktop development with C++"* workload.
- Verify with: `flutter doctor -v` (the Windows section must be OK).

### Install commands (winget)

```bash
# 1) Visual Studio Build Tools with C++
winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"

# 2) Flutter SDK (via git, stable channel)
#    Recommended: clone into C:\src\flutter and add C:\src\flutter\bin to PATH.
git clone -b stable https://github.com/flutter/flutter.git C:/src/flutter

# 3) Reload PATH and verify
flutter doctor -v
flutter config --enable-windows-desktop
```

## Roadmap by phase

1. **Phase 0 — Setup:** toolchain + a Flutter Windows-only project that runs.
2. **Phase 1 — Player:** embed `media_kit` and play a local file and a direct URL.
3. **Phase 2 — Addons:** Stremio protocol client (manifest, catalog, meta, stream).
4. **Phase 3 — Nuvio backend:** discovery → login → read library/progress.
5. **Phase 4 — Product UI:** catalogs, detail, stream list, integrated player.
6. **Phase 5 — Debrid:** our own `DebridProvider` + cache.
7. **Phase 6 — Extras:** subtitles, tracking, Linux, optional P2P.

## Developer tools

- **`tool/nuvio_login.dart`** — signs in to a Nuvio backend and prints profiles, library and
  watch progress, so the backend client can be exercised before the UI exists. See
  [`docs/tools/nuvio_login.md`](docs/tools/nuvio_login.md).

## Known issues / TODO

- **Custom title bar — top edge dead zone.** The top ~10 px (windowed) / ~15 px
  (maximized) of the custom title bar receives no pointer events: Windows reserves
  it as the `WS_THICKFRAME` resize border, so it is neither draggable nor
  resizable. The rest of the bar works, and dragging a maximized window restores
  it first. To resolve it completely, either handle `WM_NCHITTEST` on the Flutter
  child window in the runner (native drag + Snap Layouts) or make the window truly
  frameless and resize from Dart. See `docs/sessions/0003_custom_title_bar_ES.md`.
- **Mica backdrop is currently invisible** (the title bar and `Scaffold` are
  opaque). Decide whether to keep `flutter_acrylic` or remove it.

## References

- Stremio addon protocol: `https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/protocol.md`
- `media_kit`: `https://github.com/media-kit/media-kit`
- Nuvio backend (self-host): `https://github.com/NuvioMedia/self-host`
- Nuvio backend discovery: `GET <BACKEND_URL>/.well-known/nuvio`
- Flutter desktop: `https://docs.flutter.dev/platform-integration/desktop`
