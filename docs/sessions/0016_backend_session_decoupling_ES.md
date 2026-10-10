# 0016 — Desacoplo del seam de cuenta/backend

- **Fecha:** 2026-10-10
- **Sesión:** 0016
- **Estado:** ✅ hecho

## Objetivo

Revisar si la sesión con Nuvio estaba realmente desacoplada y usaba interfaces
genéricas, con la meta de que cambiar a Stremio, a un store local o a un sistema
de autenticación propio sea barato. El análisis encontró que la capa de contenido
(Stremio) ya estaba bien aislada, pero la de cuenta/sesión no: las interfaces y
los modelos de dominio estaban moldeados a Nuvio/Supabase.

Este refactor ejecuta el plan derivado de ese análisis. No cambia la experiencia
visible salvo que ahora la sesión se recuerda entre arranques.

## Diagnóstico (punto de partida)

Acoplamientos encontrados:

1. **El perfil era obligatorio.** `AppShell` bloqueaba toda la app si había sesión
   sin `activeProfile`, y los repos concretos exigían `activeProfile.profileId`.
   Un backend sin perfiles (Stremio, auth propia) se habría quedado en el picker.
2. **`signIn` devolvía `BackendSession`** (tokens Supabase) y la interfaz exponía
   `session`. Detalle de transporte filtrado a `domain/`.
3. **`BackendConnection`** (discovery `/.well-known/nuvio`) vivía en `domain/`.
4. **Sin restauración de sesión** ni refresh; la sesión moría al cerrar la app.
5. **Modelos de dominio con forma de fila PostgREST:** `LibraryItem.fromJson`,
   `WatchProgress.fromJson`, `Addon.fromJson`, `BackendProfile.fromJson` mapeaban
   columnas de Supabase dentro de `domain/`.
6. **Sin selector de backend:** `main.dart` construía Nuvio a mano.
7. Textos "Nuvio" hardcodeados en UI y regla 2 del README obsoleta.

## Qué se hizo

### 1. Perfiles opcionales

`AccountRepository` gana `bool get requiresProfile`. El gate del shell pasa a:

```dart
if (account.isSignedIn &&
    account.requiresProfile &&
    account.activeProfile == null) {
  // ProfilePicker
}
```

`NuvioAccountRepository` responde `true`; un backend sin perfiles responde
`false` y la app es usable justo después del login.

### 2. `signIn` neutro y tokens fuera del dominio

```dart
// Antes
Future<BackendSession> signIn({required String email, required String password});
BackendSession? get session;

// Después
Future<void> signIn({required String email, required String password});
Future<bool> restoreSession();
```

La UI solo usaba `isSignedIn` y `email`, así que `session` era fuga innecesaria.
`BackendSession` se movió a `lib/data/backend/backend_session.dart`.

### 3. `BackendConnection` a `data/`

Movido a `lib/data/backend/backend_connection.dart`. Es discovery/transporte, no
dominio.

### 4. Restauración de sesión + refresh

- `AccountRepository.restoreSession()` → `NuvioClient.restoreSession()`.
- Nuevo `SessionStore` en `lib/data/store/session_store.dart`: `NoopSessionStore`
  (tests / sin persistencia) y `FileSessionStore`, que escribe
  `%APPDATA%\Agustream\session.json` en Windows (XDG en el resto).
- Si el access token expiró, se renueva con
  `POST /auth/v1/token?grant_type=refresh_token`. Si falla, se limpia el store y
  `restoreSession` devuelve `false`.
- `main.dart` restaura **antes** de `runApp`; si no hay sesión, cae al atajo
  `NUVIO_EMAIL`/`NUVIO_PASSWORD`.

### 5. DTO separado del modelo

El mapeo de filas sale de `domain/` a `lib/data/backend/nuvio_mappers.dart`
(`backendProfileFromRow`, `libraryItemFromRow`, `watchProgressFromRow`,
`addonFromRow`). Los modelos de dominio quedan sin `fromJson` de fila ni imports
de `json_utils`. `LibraryItem.fromPreview` se conserva (es una transformación de
dominio, no de base de datos).

### 6. Selector de backend

`lib/app/backend/backend_factory.dart`:

```dart
enum BackendKind {
  nuvio;
  static BackendKind fromEnvironment([Map<String, String>? environment]) { ... }
}

class BackendBundle {
  final AccountRepository account;
  final LibraryRepository library;
  final ProgressRepository progress;
  final AddonRepository addons;
  final void Function()? close;
}

BackendBundle createBackend({
  BackendKind kind = BackendKind.nuvio,
  String? baseUrl,
  SessionStore sessionStore = const NoopSessionStore(),
}) { ... }
```

`main.dart` es el único sitio que elige implementación (`AGUSTREAM_BACKEND`).

### 7. Textos y README

Textos "Nuvio" de UI neutralizados. Regla 2 del README reescrita para los repos
por capacidad, `BackendKind` y perfiles opcionales.

## Archivos

### Nuevos

| Archivo | Qué |
| --- | --- |
| `lib/app/backend/backend_factory.dart` | `BackendKind`, `BackendBundle`, `createBackend` |
| `lib/data/backend/backend_session.dart` | `BackendSession` movida + `toJson` |
| `lib/data/backend/backend_connection.dart` | `BackendConnection`/`BackendCapabilities` movidos |
| `lib/data/backend/nuvio_mappers.dart` | Mapeo de filas PostgREST → dominio |
| `lib/data/store/session_store.dart` | `SessionStore`, `NoopSessionStore`, `FileSessionStore` |
| `test/app/backend_factory_test.dart` | `BackendKind.fromEnvironment` |
| `test/data/store/session_store_test.dart` | Round-trip, clear y fichero corrupto |

### Eliminados

| Archivo | Motivo |
| --- | --- |
| `lib/domain/backend/backend_session.dart` | Movido a `data/` (transporte) |
| `lib/domain/backend/backend_connection.dart` | Movido a `data/` (transporte) |

### Modificados

| Archivo | Cambio |
| --- | --- |
| `lib/domain/backend/account_repository.dart` | `requiresProfile`, `restoreSession`, `signIn` void, sin `session` |
| `lib/domain/backend/{library_item,watch_progress,addon,backend_profile}.dart` | Sin `fromJson` de fila |
| `lib/data/backend/nuvio_client.dart` | `SessionStore`, `restoreSession`, refresh, imports locales |
| `lib/data/backend/nuvio_account_repository.dart` | `requiresProfile`, `restoreSession`, mapper |
| `lib/data/backend/nuvio_{library,progress,addon}_repository.dart` | Usan el mapper |
| `lib/app/shell/app_shell.dart` | Gate con `requiresProfile` |
| `lib/main.dart` | `createBackend` + `restoreSession` + store de fichero |
| `lib/ui/**` | Textos neutralizados |
| `tool/nuvio_login.dart` | `signIn` void; imprime `client.session` |
| `test/support/fake_repositories.dart` | Fake de cuenta a la nueva interfaz |
| `test/data/backend/nuvio_repositories_test.dart` | `client.session`, grupo de persistencia |
| `test/ui/profile_picker_test.dart` | Caso "backend sin perfiles" |
| `README.md` | Regla 2 y árbol de arquitectura |

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ **98 tests** (antes 91) |
| `flutter build windows --debug` | ✅ `agustream.exe` |

Tests nuevos: 5 de persistencia/restauración (persistir en signIn, restaurar sin
re-login, sin store, refresh de expirada, limpiar si el refresh falla), 1 de UI
(backend sin perfiles no bloquea), 4 del `FileSessionStore` y 3 del selector.

## Cómo añadir otro backend

1. Añadir el valor al `enum BackendKind`.
2. Implementar los cuatro repos en `data/` (sin perfiles → `requiresProfile = false`).
3. Añadir un `case` en `createBackend`. Ni `ui/` ni `domain/` cambian.

## Pendiente

1. **Escrituras** (biblioteca/progreso) siguen fuera de las interfaces.
2. **`Addon`/`AddonRepository`** siguen en `domain/backend/` aunque son concepto
   Stremio; mover a `domain/addons/` cuando se toque.
3. **`tv_login`** (device code) no implementado.
4. **Seguridad del store:** el refresh token se guarda en claro; valorar cifrado o
   el Credential Manager de Windows.
5. **Persistencia de perfiles:** al restaurar se vuelve a elegir perfil (no se
   recuerda el último).
