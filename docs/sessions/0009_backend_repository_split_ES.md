# 0009 — Separación del backend en repositorios por capacidad

## Objetivo

Refactor del **seam de datos**: partir la interfaz monolítica `BackendProvider`
en repositorios separados por capacidad, antes de arreglar el filtrado por
perfil y antes de la primera escritura.

No agrega ninguna funcionalidad visible. Es un refactor puro: el comportamiento
tiene que quedar idéntico.

## Por qué

Al revisar si la arquitectura servía para extender a "todo local", quedaron
cuatro problemas concretos en `BackendProvider`:

1. **Solo lectura.** La interfaz tenía únicamente `fetchLibrary()`,
   `fetchWatchProgress()` y `fetchProfiles()`. La app no podía guardar nada, ni
   siquiera en Nuvio.
2. **Conceptos de Supabase filtrados hacia arriba.** `discover()`,
   `BackendConnection` y `BackendSession` (con `accessToken`, `refreshToken`,
   `expiresAt`) no tienen sentido en un store local: obligar a un
   `LocalBackendProvider` a implementar `discover()` sería forzar la
   abstracción.
3. **No era observable.** Al ser una interfaz plana, la Library no tenía cómo
   enterarse de que el usuario se había logueado; se había resuelto con un
   `SessionController` **por encima** del provider, que era un parche.
4. **Interfaz monolítica.** Mezclaba cuenta (`signIn`, `profiles`) con contenido
   (`library`, `progress`), así que un modo local habría tenido que implementar
   todo o tirar `UnimplementedError`.

El momento importa: con un solo consumidor (la Library) el refactor es barato;
con cuatro o cinco pantallas encima, es caro. Y la primera escritura
("agregar a favoritos", previsible en la parte 4.3) choca de frente con el
problema 1.

## Qué se hizo

### Interfaces por capacidad

| Antes | Después |
| --- | --- |
| `BackendProvider` | `AccountRepository` — sesión, perfiles, perfil activo |
| | `LibraryRepository` — títulos guardados |
| | `ProgressRepository` — progreso de visionado |

`AccountRepository` es **observable**: expone `Listenable get changes`, que
notifica cuando cambia la sesión o el perfil activo. `Listenable` viene de
`package:flutter/foundation.dart`, que no es UI ni red, así que no rompe la regla
del README para `domain/`.

Además ya declara el **perfil activo** (`activeProfile` + `selectProfile`), que
es el habilitante del fix de perfiles. Por ahora arranca en `null`, que
significa "sin alcance": los repositorios devuelven todo lo que la cuenta puede
ver, es decir, el comportamiento actual.

Las escrituras **no** se declararon todavía: se agregan junto con el store local,
para que las implementaciones de Nuvio y local se puedan ejercitar con los mismos
tests. Declararlas antes sería código muerto.

### Transporte separado

`NuvioBackendProvider` (que hacía todo) se partió en:

- `NuvioClient` — el transporte: URL base, discovery, sesión, `select()` sobre
  PostgREST y el manejo de errores de Supabase.
- `NuvioAccountRepository`, `NuvioLibraryRepository`, `NuvioProgressRepository` —
  las tres implementaciones, que comparten un mismo cliente.

### `SessionController` eliminado

Era el parche del problema 3. Como `AccountRepository` ya es observable, dejó de
tener sentido: `LibraryController` se suscribe directamente a
`account.changes` y recarga cuando aparece (o desaparece) una sesión. La tarjeta
de login de Settings también usa `account.changes`.

## Archivos

**Nuevos**

| Archivo | Qué |
| --- | --- |
| `lib/domain/backend/account_repository.dart` | Sesión + perfiles, observable |
| `lib/domain/backend/library_repository.dart` | Lectura de la biblioteca |
| `lib/domain/backend/progress_repository.dart` | Lectura del progreso |
| `lib/domain/backend/backend_exception.dart` | `BackendException`, movida fuera del provider |
| `lib/data/backend/nuvio_client.dart` | Transporte HTTP del backend |
| `lib/data/backend/nuvio_account_repository.dart` | Implementación de cuenta |
| `lib/data/backend/nuvio_library_repository.dart` | Implementación de biblioteca |
| `lib/data/backend/nuvio_progress_repository.dart` | Implementación de progreso |
| `test/data/backend/nuvio_repositories_test.dart` | Reemplaza el test del provider |
| `test/support/fake_repositories.dart` | Fakes por capacidad |

**Eliminados**

| Archivo | Motivo |
| --- | --- |
| `lib/domain/backend/backend_provider.dart` | Reemplazado por las tres interfaces |
| `lib/data/backend/nuvio_backend_provider.dart` | Partido en cliente + repositorios |
| `lib/app/services/session_controller.dart` | Redundante: `AccountRepository` es observable |
| `test/data/backend/nuvio_backend_provider_test.dart` | Reemplazado |
| `test/support/fake_backend_provider.dart` | Reemplazado por fakes por capacidad |

**Modificados**

| Archivo | Cambio |
| --- | --- |
| `lib/app/services/app_services.dart` | Expone los tres repositorios |
| `lib/app/app.dart` | Recibe los tres repositorios (vuelve a ser `StatelessWidget`) |
| `lib/main.dart` | Construye el cliente y los repositorios |
| `lib/ui/library/library_controller.dart` | Depende de los repositorios, no del provider |
| `lib/ui/screens/library_screen.dart` | Pasa los tres repositorios al controlador |
| `lib/ui/screens/settings_screen.dart` | Usa `AccountRepository` |
| `tool/nuvio_login.dart` | Usa el cliente y los repositorios |
| `test/widget_test.dart`, `test/ui/library_screen_test.dart` | Usan los fakes nuevos |

## Verificación

- `flutter analyze` sin problemas.
- `flutter test`: **35 tests** (eran 32).
  - Los tests de datos pasaron de 11 a 13: los 11 originales se mantuvieron
    **con las mismas aserciones** (para probar que el comportamiento no cambió),
    más dos nuevos: `activeProfile` arranca en `null`, y `changes` notifica al
    loguearse, al cambiar de perfil y al desloguearse.
  - Se agregó un test de UI: la Library se recarga sola cuando la cuenta se
    loguea, sin que la pantalla sepa nada.
- `flutter build windows --debug` correcto.
- Smoke run de la app real: Settings renderiza la tarjeta de cuenta con el
  repositorio nuevo, sin excepciones en el log.

## Pendiente

1. **Fix de perfiles** (el siguiente paso, ya decidido): `fetchLibrary()` no
   filtra por `profile_id` y RLS acota por cuenta, no por perfil, así que con
   varios perfiles la grilla los mezcla. Confirmado con una cuenta real.
   El plan, ahora que el seam existe:
   - `NuvioClient.select()` suma un filtro PostgREST (`&profile_id=eq.<id>`).
   - Los repositorios de library y progreso filtran por `activeProfile`.
   - Al loguearse, cargar los perfiles y seleccionar uno (el primero, por
     `profile_index`).
   - `LibraryController` ya recarga solo cuando cambia el perfil.
   Falta decidir si el perfil se elige automáticamente (arregla el bug ya) o si
   se agrega un selector real en el riel, aprovechando el avatar.
2. **Escrituras + store local** (`data/store/`, previsto en el README y todavía
   vacío): habilitan "favoritos locales" y "todo local".
3. Persistir la sesión (refresh token) para no loguearse en cada arranque.
4. 4.3 Detail, 4.4 Streams, 4.5 Player integrado, 4.6 Home, 4.7 Search, 4.8
   Settings (reemplaza la tarjeta de login temporal).
