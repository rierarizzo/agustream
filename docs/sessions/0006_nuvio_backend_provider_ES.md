# 0006 — Backend de Nuvio (Fase 3)

- **Fecha:** 2026-10-08
- **Sesión:** 0006
- **Estado:** ✅ hecho (Fase 3 completa)

## Objetivo

Implementar el cliente del backend de Nuvio (**discovery → login → leer biblioteca y
progreso**), según la Fase 3 del roadmap, aislado detrás de una interfaz `BackendProvider`.

## Hallazgo clave

**El backend de Nuvio es un deployment de Supabase.** El endpoint de discovery
(`<BACKEND_URL>/.well-known/nuvio`) devuelve la URL de Supabase y su **anon key**:

```json
{
  "version": 1,
  "service": "nuvio",
  "self_hosted": true,
  "backend_url": "https://api.nuvio.tv",
  "publishable_key": "<supabase anon key>",
  "capabilities": { "email_password_auth": true, "tv_login": true }
}
```

Por lo tanto: **auth = Supabase Auth** y **datos = PostgREST**. No hizo falta el SDK de
Supabase; con `http` alcanza.

El esquema se obtuvo de la propia API (`GET /rest/v1/` devuelve el OpenAPI de PostgREST).
Tablas relevantes: `profiles`, `library_items`, `watch_progress` (y otras como `collections`,
`watched_items`, `home_catalog_settings`, que quedan para más adelante).

## Decisiones tomadas

- **HTTP crudo en vez del SDK de Supabase**: mantiene `lib/data/backend/` fino, sin
  dependencias grandes, y hace que `BackendProvider` sea realmente reemplazable (regla del
  README: *"only that module is replaced if it changes"*).
- La **interfaz** `BackendProvider` vive en `domain/`; la implementación
  (`NuvioBackendProvider`) en `data/backend/`.
- **Auto-discovery**: `signIn` y las lecturas llaman a `discover()` si todavía no se hizo.
- Las lecturas van con `apikey` + `Authorization: Bearer <access_token>`; **RLS** filtra por
  usuario del lado del servidor.
- `signOut` invalida la sesión en el backend (best-effort) y limpia la local.
- Se mueve `json_utils.dart` de `domain/addons/` a **`domain/shared/`** para reusarlo entre
  addons y backend.
- **Unidades (confirmadas con datos reales):** `position`/`duration` en **milisegundos**;
  `added_at`/`last_watched` en **epoch-milisegundos**.

## Qué se hizo

1. Se documentó la API real (discovery, auth, PostgREST) sondeando el servidor con la anon
   key pública y el repo `NuvioMedia/self-host`.
2. Se crearon los modelos de dominio: `BackendConnection` (+ `BackendCapabilities`),
   `BackendSession`, `BackendProfile`, `LibraryItem` y `WatchProgress`.
3. Se definió la interfaz `BackendProvider` y `BackendException`.
4. Se implementó `NuvioBackendProvider` (discovery, `signIn`, `signOut`, `fetchProfiles`,
   `fetchLibrary`, `fetchWatchProgress`).
5. Se agregaron tests con `MockClient` (10) cubriendo URLs, headers, body y errores.
6. Se agregó la herramienta de desarrollo `tool/nuvio_login.dart` para probar el flujo con
   una cuenta real antes de que exista UI.
7. Se verificó contra el backend real con una cuenta real.

## Archivos tocados

| Archivo | Cambio |
| --- | --- |
| `lib/domain/backend/backend_provider.dart` | **nuevo** — interfaz + `BackendException` |
| `lib/domain/backend/backend_connection.dart` | **nuevo** — `BackendConnection`, `BackendCapabilities` |
| `lib/domain/backend/backend_session.dart` | **nuevo** — `BackendSession` |
| `lib/domain/backend/backend_profile.dart` | **nuevo** — `BackendProfile` |
| `lib/domain/backend/library_item.dart` | **nuevo** — `LibraryItem` |
| `lib/domain/backend/watch_progress.dart` | **nuevo** — `WatchProgress` (+ `fraction`) |
| `lib/domain/shared/json_utils.dart` | **movido** desde `domain/addons/` |
| `lib/domain/addons/{addon_manifest,meta,stream}.dart` | **cambiado** — import del helper movido |
| `lib/data/backend/nuvio_backend_provider.dart` | **nuevo** — la implementación |
| `lib/data/backend/.gitkeep` | **borrado** |
| `test/data/backend/nuvio_backend_provider_test.dart` | **nuevo** — 10 tests |
| `tool/nuvio_login.dart` | **nuevo** — herramienta de desarrollo |

## Código relevante

El contrato (lo único que verá la UI en la Fase 4):

```dart
abstract interface class BackendProvider {
  BackendConnection? get connection;
  BackendSession? get session;
  bool get isSignedIn;

  Future<BackendConnection> discover();
  Future<BackendSession> signIn({required String email, required String password});
  Future<void> signOut();

  Future<List<BackendProfile>> fetchProfiles();
  Future<List<LibraryItem>> fetchLibrary();
  Future<List<WatchProgress>> fetchWatchProgress();
}
```

Login contra Supabase Auth:

```dart
final json = await _request(
  'POST',
  Uri.parse('$_baseUrl/auth/v1/token?grant_type=password'),
  body: {'email': email, 'password': password},
);
return _session = BackendSession.fromJson(json as Map<String, dynamic>);
```

Lectura PostgREST (RLS acota por usuario):

```dart
final query = StringBuffer('?select=*');
if (order != null) query.write('&order=$order');
final json = await _request(
  'GET',
  Uri.parse('$_baseUrl/rest/v1/$table$query'),
  token: current.accessToken,
);
```

## Problemas encontrados

Ninguno bloqueante. Notas:

1. **Unidades.** El backend guarda los tiempos como enteros sin documentar la unidad. Se
   asumió milisegundos/epoch-ms y se **confirmó con datos reales** (ver *Verificación*).
2. **Mensaje de error de Supabase.** Auth devuelve `{"code":…,"error_code":…,"msg":…}` y
   PostgREST `{"message":…}`. `_errorMessage` prueba `msg`, `error_description`, `message` y
   `error` para no perder el texto útil.
3. **`profile_index` es 1-based** (observado: 1, 2, 3).

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ **26 tests** (10 nuevos del backend) |
| Discovery real | ✅ `service=nuvio v1`, `selfHosted=true`, key de 169 chars |
| Login real (credencial inválida) | ✅ `BackendException (HTTP 400): Invalid login credentials` |
| **Login real (cuenta real)** | ✅ sesión con `user_id`, `email` y `expires_at` (~1 semana) |
| **Perfiles reales** | ✅ 3 perfiles con `profile_id` 1, 2, 3 |
| **Biblioteca real** | ✅ 179 items (nombre, id, rating, fecha) |
| **Progreso real** | ✅ 28 entradas con temporada/episodio, posición, duración y porcentaje |
| Unidades confirmadas | ✅ `duration=1:40:00` (ms), `last=2026-10-08` (epoch-ms) |
| Cálculo de `fraction` | ✅ `02:47 / 1:40:00 = 2.8%`, `22:32 / 22:32 = 100%` |

## Pendiente / Próximos pasos

1. **La UI no usa todavía el backend.** Por la arquitectura, la UI consume `BackendProvider`
   a través de la capa de dominio; eso es la Fase 4.
2. **Persistencia de la sesión:** hoy el token vive en memoria. El README tiene la
   persistencia local como *TBD*; habrá que guardar el refresh token para no re-loguear en
   cada arranque.
3. **Renovación de token:** no implementada (hay `refresh_token` disponible para hacerlo).
4. **TV login** (`tv_login: true`) no implementado; solo email + password.
5. **Escritura:** solo lectura. Falta escribir biblioteca y progreso (sync).
6. **Fase 4:** UI de producto (catálogo, detalle, streams, reproductor integrado).
