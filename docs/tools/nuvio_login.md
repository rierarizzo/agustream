# `tool/nuvio_login.dart`

Signs in to a Nuvio backend and prints the account's profiles, library and watch progress.

It exists to exercise `NuvioBackendProvider` (`lib/data/backend/`) by hand, before the product
UI exists (phase 4). It is a development tool: it is not compiled into the app and does not
ship with it.

## Requirements

- The Flutter SDK's `dart` on your `PATH` (`dart --version`). If it is not, use the full path,
  e.g. `C:\src\flutter\bin\dart`.
- Run it **from the repository root**, so `dart` finds the package configuration.

## Usage

Credentials can come from flags, environment variables, or an interactive prompt.

**Environment variables** (works in both Git Bash and PowerShell):

```bash
NUVIO_EMAIL=you@example.com NUVIO_PASSWORD=secret dart run tool/nuvio_login.dart
```

```powershell
$env:NUVIO_EMAIL="you@example.com"; $env:NUVIO_PASSWORD="secret"; dart run tool/nuvio_login.dart
```

**Interactive prompt** (keeps the password out of your shell history):

```bash
dart run tool/nuvio_login.dart --email=you@example.com
```

### Flags

| Flag | Meaning | Fallback |
| --- | --- | --- |
| `--email=<email>` | Account email | `NUVIO_EMAIL` |
| `--password=<secret>` | Account password (visible in shell history) | `NUVIO_PASSWORD` |
| `--base-url=<url>` | Backend URL | `NUVIO_BASE_URL`, else `https://api.nuvio.tv` |
| `--limit=<n>` | Rows printed per list (default `10`) | |
| `--help` | Print usage | |

## Example output

```
Backend  : https://api.nuvio.tv  (service=nuvio v1, selfHosted=true)
Signing in as you@example.com…
Signed in: user=<uuid> email=you@example.com expires=2026-10-15 18:57:41.000Z

Profiles (3):
  [1] Keneth  profile_id=1 pin=false
  …

Library (179 items):
  movie   The Wailing  (tt5215952) ★7.4  added=2026-10-07
  …

Watch progress (28 entries):
  movie   tt27165187  position=02:47 duration=1:40:00  2.8%  last=2026-10-08
  series  tt0149460 S2E15  position=22:32 duration=22:32  100.0%  last=2026-10-08
  …
```

## What it is useful for

- **Verifying the backend client end to end** without a UI: discovery, sign-in, and the three
  PostgREST reads (profiles, library, watch progress).
- **Checking the backend's time units.** `position`, `duration`, `added_at` and `last_watched`
  are stored as bare integers. The tool prints them as durations and dates so they can be
  sanity-checked: a movie should read around two hours, and a recent item a plausible date.
  They are confirmed to be milliseconds and epoch-milliseconds.

## Security notes

- The password is never stored or logged. With the prompt it is not echoed when the terminal
  supports it.
- **Git Bash / MinTTY cannot always disable echo**; the tool warns when it cannot. Use
  PowerShell, or the environment variables, if that matters.
- Never paste a real password into an issue, a commit or a chat: the output alone is enough.

## Related

- `lib/data/backend/nuvio_backend_provider.dart` — the client it exercises.
- `lib/domain/backend/backend_provider.dart` — the interface it goes through.
- `docs/sessions/0006_nuvio_backend_provider_ES.md` — how the backend was reverse-engineered.
