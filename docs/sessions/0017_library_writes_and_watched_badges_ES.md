# 0017 — Escrituras de biblioteca y badges de visto

- **Fecha:** 2026-10-10
- **Sesión:** 0017
- **Estado:** ✅ hecho

## Objetivo

Habilitar la primera escritura real (agregar/quitar de la biblioteca) y hacer
que las insignias de “visto” reflejen lo que Nuvio realmente tiene marcado, sin
bloquear la carga de contenido.

## Contexto

Parte de la sesión 0016 (“perfiles opcionales + backend intercambiable”). Este
trabajo cubre el pendiente nº1 (escrituras + store local) y arregla que el check
de visto saliera de `watch_progress` (posición) en vez del historial real.

## 1. Escrituras y backend local

### Contratos

- `LibraryRepository` gana `contains`, `add`, `remove` y `changes`.
- `ProgressRepository` gana `save` y `changes`.

### Nuvio

- `NuvioClient` suma `insert`, `upsert` (`?on_conflict=` +
  `Prefer: resolution=merge-duplicates`) y `delete`; `_request` soporta `DELETE`,
  headers extra y cuerpo vacío (`204`).
- `nuvio_mappers` gana `libraryItemToRow` / `watchProgressToRow`.
- Los repos escriben scoped al perfil activo. `library_items` y `watch_progress`
  tienen `user_id uuid` **obligatoria y sin default** (lo confirmó el OpenAPI de
  PostgREST): las filas la incluyen desde la sesión. `added_at` se envía siempre
  porque la columna tiene `default 0`.

### Store local (`data/store/`, `data/local/`)

- `JsonFileStore` (array JSON en fichero) y `app_paths` (`%APPDATA%\Agustream`).
- Backend completo: `LocalAccountRepository` (sin perfiles), `LocalLibraryRepository`,
  `LocalProgressRepository`, `LocalAddonRepository`; `BackendKind.local` con
  `AGUSTREAM_LOCAL_ADDONS` para darle catálogos.

### UI

- El botón de favorito del detalle (antes `coming soon`) agrega/quita de la
  biblioteca; `LibraryController` escucha `library.changes`/`progress.changes`.

## 2. Badges de visto

La insignia salía de `watch_progress` (posición de “seguir viendo”), no del
historial real. Datos reales (perfil 1, 178 títulos): `watch_progress` daba 2
películas; `watched_items` tenía 1000+ filas.

- `ProgressRepository.watchedEntries(candidateIds)` trae el historial por lotes
  de 40 (evita el tope de 1000 de PostgREST).
- **Película**: vista si hay marcador (`season`/`episode` nulos) en `watched_items`
  (el backend lo crea al completar).
- **Serie**: vista si **todos los episodios emitidos de temporadas principales**
  están vistos o completados (progreso ≥ 90%). Es la regla de Nuvio.
- El mismo check se pinta en la biblioteca y en Home (`WatchedBadge` compartido).
- Verificado contra la cuenta real: 88 películas + 29 series = **117** checks
  (antes 2). El backend no crea marcadores de serie desde el progreso: hay que
  calcularlos contra el metadata.

## 3. Caché y carga en segundo plano

Nuvio no recalcula cada vez: `resolveWatchedBadgesBulk` corre desde Home cuando
los insumos cambian y persiste `fullyWatchedSeriesKeys` **en local** (el adaptador
de Supabase no lo sincroniza).

- `WatchedSeriesCache` (puerto) + `FileWatchedSeriesCache`
  (`watched_series.json`), por perfil y con firma.
- La firma por serie es `día + hash(keys vistos) + hash(keys completadas)`. Si no
  cambió, no se pide metadata. Al ver un episodio se recalcula solo esa serie.
- Lookups de metadata con concurrencia acotada (4) y escritura de caché **en un
  solo lote**.
- **Carga no bloqueante:** el contenido pinta primero; los badges se resuelven en
  segundo plano (`unawaited`) con una guarda de `requestId` (cambios de perfil o
  recargas descartan resultados viejos). La UI muestra un pill **“Syncing…”** arriba
  a la derecha (`SyncingIndicator`) mientras dura.

## 4. Pulido

- Claves tipadas: `WatchedKey` (record `{contentId, season, episode}`) en vez de
  strings `id|s|e` con `startsWith`.
- Regla pura extraída: `hasWatchedAllMainSeasonEpisodes(...)` sin repos ni reloj,
  testeable sola.
- `WatchedBadgeSync`: mixin sobre `ChangeNotifier` con el flag de sync, la guarda
  de request y los ids; Library y Home dejan de duplicarlo.
- Resolver **compartido** desde `AppServices` (una instancia y una caché para toda
  la app).

## Archivos

### Nuevos

| Archivo | Qué |
| --- | --- |
| `lib/data/store/json_file_store.dart` | Store JSON en fichero |
| `lib/data/store/app_paths.dart` | Rutas de config (`%APPDATA%\Agustream`) |
| `lib/data/store/file_watched_series_cache.dart` | Caché de series en disco |
| `lib/data/local/*.dart` | Backend local (cuenta, biblioteca, progreso, addons) |
| `lib/domain/backend/watched_entry.dart` | Entrada del historial de visto |
| `lib/domain/backend/watched_rule.dart` | Regla pura de serie completa |
| `lib/domain/backend/watched_badges.dart` | Resolver de badges |
| `lib/domain/backend/watched_series_cache.dart` | Puerto de caché |
| `lib/ui/watched_badge_sync.dart` | Mixin de sync en segundo plano |
| `lib/ui/widgets/watched_badge.dart` | Check reutilizable |
| `lib/ui/widgets/syncing_indicator.dart` | Pill “Syncing…” |
| `test/data/local/local_repositories_test.dart` | Tests del store local |
| `test/data/store/file_watched_series_cache_test.dart` | Tests de la caché |
| `test/domain/watched_rule_test.dart` | Tests de la regla pura |
| `test/domain/watched_badges_test.dart` | Tests del resolver |

### Modificados

| Archivo | Cambio |
| --- | --- |
| `lib/domain/backend/{library,progress}_repository.dart` | Escrituras + `changes` + `watchedEntries` |
| `lib/data/backend/nuvio_client.dart` | `insert`/`upsert`/`delete` |
| `lib/data/backend/nuvio_{library,progress}_repository.dart` | Escrituras, perfil, `user_id`, historial |
| `lib/data/backend/nuvio_mappers.dart` | `*ToRow`, `watchedEntryFromRow` |
| `lib/app/services/app_services.dart` | Resolver compartido |
| `lib/app/backend/backend_factory.dart` | `BackendKind.local` |
| `lib/main.dart`, `lib/app/app.dart` | Caché y wiring |
| `lib/ui/detail/detail_screen.dart` | Toggle de favorito |
| `lib/ui/{home,library}/*controller.dart` | Sync en segundo plano |
| `lib/ui/{screens/library_screen,home/home_screen}.dart` | Indicador “Syncing…” |
| `lib/ui/library/poster_tile.dart`, `lib/ui/widgets/meta_poster_card.dart` | Check |
| `test/**` | Cobertura de todo lo anterior |
| `README.md` | Modos de backend |

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ **136** (eran 120 al empezar la sesión) |
| `flutter build windows --debug` | ✅ |
| Cuenta real: marcadores de visto | ✅ 117 checks (88 pelis + 29 series) |
| Cuenta real: favorito | ✅ insert con `user_id` y `profile_id` |

## Pendiente

1. **Escrituras de progreso sin consumidor en runtime:** `ProgressRepository.save`
   está listo y testeado, pero lo usará el reproductor (4.5).
2. **`ProgressRepository` mezcla** progreso e historial visto; separar en
   `WatchedRepository` cuando haga falta.
3. **Recalculo diario:** el día entra en la firma (regla de Nuvio); el primer
   arranque y una vez al día se paga la metadata.
4. **`tv_login`** (device code) y **cifrado del `SessionStore`** siguen pendientes
   de la 0016.
