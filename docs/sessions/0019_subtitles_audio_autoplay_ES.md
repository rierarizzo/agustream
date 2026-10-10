# 0019 — Subtítulos, pistas de audio, autoplay, visto y rating

- **Fecha:** 2026-10-10
- **Sesión:** 0019
- **Estado:** ✅ hecho

## Objetivo

Completar el reproductor de la 0018 con selección de subtítulos y audio,
autoplay del siguiente episodio, y activar “Mark as watched” y “Rate” en el
detalle.

## Subtítulos

- Dominio: `Subtitle` + `SubtitleRepository` (con `NoSubtitleRepository`).
- Stremio: `StremioAddonClient.fetchSubtitles` (`GET /subtitles/{type}/{id}.json`)
  y `StremioSubtitleRepository` (agrega de todos los addons, en paralelo, y
  deduplica por URL).
- Reproductor: botón de subtítulos → hoja con **Off**, pistas embebidas
  (`player.stream.tracks`) y subtítulos de los addons (se cargan al abrir con
  `videoId ?? contentId`). Los de addon se cargan con
  `SubtitleTrack.uri(url, language:)`.

## Pistas de audio

- `PlayerService` expone `tracks` (disponibles) y `track` (actuales), y los
  setters `setSubtitleTrack` / `setAudioTrack`.
- Reproductor: botón de audio → hoja con las pistas embebidas y la activa.

## Autoplay

- Al `completed`, si es un episodio: pide el metadata de la serie, ordena los
  episodios de temporada principal, busca el siguiente y pide streams; reproduce
  el **primer stream directo** con `pushReplacement`. Best-effort (si falla, se
  queda al final). No aplica a películas.

## Mark as watched

- `ProgressRepository.markWatched` / `unmarkWatched`.
  - Nuvio: RPCs `sync_push_watched_items` y `sync_delete_watched_items`
    (están en el allowlist de `authenticated`; el push también emite los delta
    events para los demás clientes).
  - Local: segundo store `watched.json` (`markWatched`/`unmarkWatched`);
    `watchedEntries` combina marcadores explícitos + progreso completado.
- Detalle: el botón (antes “coming soon”) marca/desmarca; su estado se lee de
  `watchedEntries` (marcador a nivel de título).
- `WatchedBadgeResolver` ahora **honra el marcador de título**: una serie marcada
  a mano sale con check sin recalcular metadata.

## Rate (local)

- **Nuvio no tiene columna de rating de usuario** (solo `library_items.imdb_rating`),
  así que el rating es local: `RatingRepository` + `LocalRatingRepository` sobre
  `JsonMapStore` (`ratings.json`), de 1 a 10.
- Detalle: el botón abre un diálogo (slider + Clear/Save); el icono refleja la nota.
- **No sincroniza entre dispositivos** (limitación del backend).

## Extra

- `proxyHeaders` pasó a un getter de dominio `Stream.httpHeaders`, para que el
  reproductor y `--play` lo compartan sin import circular.
- Orden de controles: Subtítulos, Audio, **Fullscreen al final**.

## Archivos

### Nuevos

| Archivo | Qué |
| --- | --- |
| `lib/domain/addons/subtitle.dart` | Modelo `Subtitle` |
| `lib/domain/addons/subtitle_repository.dart` | Contrato + no-op |
| `lib/data/addons/stremio_subtitle_repository.dart` | Implementación Stremio |
| `lib/domain/backend/rating_repository.dart` | Contrato + no-op |
| `lib/data/store/json_map_store.dart` | Store JSON de objeto |
| `lib/data/store/local_rating_repository.dart` | Ratings locales |
| `lib/ui/detail/rating_dialog.dart` | Diálogo 1–10 |
| `test/data/addons/stremio_subtitle_repository_test.dart` | 3 tests |
| `test/data/store/local_rating_repository_test.dart` | 1 test |

### Modificados

| Archivo | Cambio |
| --- | --- |
| `lib/data/addons/stremio_addon_client.dart` | `fetchSubtitles` |
| `lib/services/player/player_service.dart` | tracks + setters |
| `lib/ui/screens/player_screen.dart` | hojas de subtítulos/audio + autoplay |
| `lib/ui/player/player_controls.dart` | botones y orden |
| `lib/domain/backend/progress_repository.dart` | `markWatched`/`unmarkWatched` |
| `lib/data/backend/nuvio_progress_repository.dart` | RPCs de watched |
| `lib/data/local/local_progress_repository.dart` | store de marcadores |
| `lib/domain/backend/watched_badges.dart` | marcador de título |
| `lib/domain/addons/stream.dart` | getter `httpHeaders` |
| `lib/app/services/app_services.dart`, `lib/app/app.dart`, `lib/main.dart` | `subtitles` + `ratings` |
| `lib/ui/detail/detail_screen.dart` | botones de visto y rating |
| `lib/ui/streams/open_streams.dart` | usa `stream.httpHeaders` |
| `test/**` | cobertura |
| `test/ui/open_streams_test.dart` | eliminado (movido a `stream_test.dart`) |

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ **160** (eran 151) |
| `flutter build windows --debug` | ✅ |

## Pendiente

1. **Torrents / enlaces externos** (sin tocar, a pedido).
2. **Ajustes de subtítulos** (tamaño/estilo) y audio externo.
3. **Autoplay**: elegir mejor el stream (mismo addon/calidad) y cuenta atrás.
4. **Rate sin sync** (el backend no tiene campo).
