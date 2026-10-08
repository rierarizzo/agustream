# 0001 — Project setup and architecture decisions

- **Date:** 2026-10-08
- **Session:** 0001
- **Status:** 🟡 partial (decisions closed; toolchain still to be installed)

## Objective

Define the product, the stack, and the repository conventions before writing code.

## Decisions made

### Product

- A **Nuvio desktop client, Windows-first**: login to the Nuvio backend, Stremio addons,
  and libmpv playback.
- **Complementary to Nuvio**, not a replacement.

### Stack

| Layer | Chosen | Reason |
| --- | --- | --- |
| UI / language | **Flutter + Dart** | One codebase for W11/Linux/mobile, declarative UI, hot reload. |
| Video | **`media_kit` (libmpv)** | Embedded libmpv via GPU texture, many formats, hardware decoding. |
| Backend | **Nuvio API** (`api.nuvio.tv`, Supabase) | Reuse login/library/progress. |
| Addons | **Stremio** protocol (HTTP/JSON) | Open and documented standard. |
| Debrid | Phase 2 | v1 uses addons with debrid configured (direct HTTPS URLs). |

### Environment

- Development on **native Windows 11**, **NOT WSL2** (Windows desktop builds require
  MSVC + Windows SDK).

## What we did

1. Closed the product scope and the stack (see above).
2. Checked the environment:
   - ✅ `winget`, `git`, VS Code, 110 GB free.
   - ❌ **Flutter SDK** missing.
   - ❌ **Visual Studio 2022 Build Tools** (C++ workload) missing.
3. Created the repository documentation and config:
   - `AGENTS.md` — session-log rule.
   - `README.md` — project details.
   - `.gitignore` — Flutter/Dart + IDEs + OS.
   - `docs/sessions/0001_setup_project.md` — this file.

## Files touched

- `AGENTS.md` — **new**.
- `README.md` — **new**.
- `.gitignore` — **new**.
- `docs/sessions/0001_setup_project.md` — **new**.

## Relevant code

There is **no app code yet**. Only documentation and repository configuration.

## Problems encountered

None.

## Pending / Next steps

1. Install the toolchain (native Windows):

   ```bash
   winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
   git clone -b stable https://github.com/flutter/flutter.git C:/src/flutter
   # add C:\src\flutter\bin to PATH, then:
   flutter doctor -v
   flutter config --enable-windows-desktop
   ```

2. Create the **Windows-only** Flutter project (`agus_desktop`).
3. Phase 1: integrate `media_kit` and play a local video and a direct URL.
4. Record everything in `docs/sessions/0002_*.md`.
