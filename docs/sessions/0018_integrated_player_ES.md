# 0018 — Reproductor integrado (Fase 4.5)

- **Fecha:** 2026-10-10
- **Sesión:** 0018
- **Estado:** ✅ hecho

## Objetivo

Reemplazar el reproductor *stopgap* de la fase 1 (controles de `media_kit`) por
un reproductor integrado: controles propios, fullscreen, resume y **reporte de
progreso** al backend.

## Qué se hizo

### Reproductor

- `PlayerScreen` reescrito. Ya no usa los controles de `media_kit`
  (`controls: NoVideoControls`); pinta un overlay propio.
- `PlayerControls` (`lib/ui/player/`): play/pause, ±10 s, barra de progreso,
  tiempo, volumen, fullscreen y back. Se **auto-ocultan** a los 3 s (el ratón los
  reaparece) y el cursor se oculta con ellos.
- **Atajos:** `espacio`/`K` play-pause, `←`/`→` ±10 s, `F` fullscreen, `Esc`
  salir.
- **Fullscreen** vía `WindowController.setFullScreen`; el shell ya ocultaba riel
  y barra de título al entrar.
- **Resume:** retoma desde la posición guardada, solo si la fracción está entre
  2% y 90%.

### Modelo y progreso

- `PlaybackTarget` (`domain/player/`): fuente + título + identidad de cuenta.
  `fromContent` arma `content_id`, `video_id`, `season`/`episode` desde el id
  reproducible, partiendo por el final para no romper ids con `:` (`tmdb:123`).
  `progressKey` usa el formato de Nuvio: `content_s{season}e{episode}` o
  `content`. `raw(source)` cubre el atajo `--play`.
- `PlaybackProgressReporter`: guarda cada 10 s, más en pausa, fin y salida.
  Ignora targets sin identidad.

### `proxyHeaders`

`streamHttpHeaders(Stream)` extrae `behaviorHints.proxyHeaders.request.headers`
y se los pasa a `media_kit` vía `Media(httpHeaders:)`.

### Hallazgo: el RPC de progreso

Escribir `watch_progress` directo por PostgREST **no** crea el marcador de visto
(eso vive en la función de sync). El camino canónico es el RPC
**`sync_push_watch_progress`**, que además deriva `watched_items` de las entradas
completadas (≥90%, ≥60 s). Está en el allowlist de `authenticated`
(migración 00000004). `NuvioProgressRepository.save` ahora lo llama, así que al
terminar un título queda marcado como visto y el check aparece. Un trigger
(`fix_watch_progress_key`) normaliza `progress_key` al mismo formato que enviamos.

Se eliminó `NuvioClient.upsert` (quedó sin uso) y el `userId` del mapper de
progreso.

## Archivos

### Nuevos

| Archivo | Qué |
| --- | --- |
| `lib/domain/player/playback_target.dart` | Fuente + identidad de reproducción |
| `lib/services/player/playback_progress_reporter.dart` | Guardado de progreso |
| `lib/ui/player/player_controls.dart` | Controles (widget puro) |
| `test/domain/player/playback_target_test.dart` | 4 tests |
| `test/services/player/playback_progress_reporter_test.dart` | 5 tests |
| `test/ui/player_controls_test.dart` | 4 tests |
| `test/ui/open_streams_test.dart` | 2 tests (`proxyHeaders`) |

### Modificados

| Archivo | Cambio |
| --- | --- |
| `lib/services/player/player_service.dart` | `open(target)`, `httpHeaders`, streams de volumen/completed |
| `lib/ui/screens/player_screen.dart` | Reescribo con controles propios |
| `lib/ui/streams/open_streams.dart` | Arma `PlaybackTarget` y `httpHeaders` |
| `lib/app/app.dart`, `lib/ui/screens/settings_screen.dart` | `PlayerScreen(target:)` / `PlaybackTarget.raw` |
| `lib/data/backend/nuvio_client.dart` | `callRpc`, fuera `upsert` |
| `lib/data/backend/nuvio_progress_repository.dart` | `save` por RPC |
| `lib/data/backend/nuvio_mappers.dart` | `watchProgressToRow` sin `user_id` |
| `test/data/backend/nuvio_repositories_test.dart` | `save` por RPC |

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ **151** (eran 136) |
| `flutter build windows --debug` | ✅ |

## Pendiente

1. **Subtítulos** y **pistas de audio**.
2. **Autoplay** del siguiente episodio.
3. **Torrents / enlaces externos** (sigue el aviso “cannot be played”).
4. **“Mark as watched” y “Rate”** siguen deshabilitados en el detalle.
