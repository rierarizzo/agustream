# 0010 — Filtrado por perfil y selección obligatoria

## Objetivo

Arreglar la mezcla de perfiles en la biblioteca y hacer que la elección de
perfil sea **obligatoria**.

## El problema

`fetchLibrary()` leía `library_items` sin filtrar por `profile_id`. La seguridad
a nivel de fila (RLS) de Supabase acota las consultas a la **cuenta**, no al
perfil, así que con varios perfiles la grilla devolvía la suma de todos.

Confirmado con una cuenta real de 3 perfiles: los títulos salían mezclados.

## La decisión: obligatorio, no automático

El primer intento fue elegir automáticamente el primer perfil por
`profile_index`. Se descartó: **no hay un default seguro**.

El razonamiento que lo define es el de las escrituras. Si en el futuro se agrega
una película a favoritos y no hay perfil elegido, ¿a cuál de los perfiles de
Nuvio se sincroniza? Cualquier respuesta automática guardaría el dato en el
perfil equivocado, y eso es **dato incorrecto**, no dato faltante.

Por eso:

- Al iniciar sesión **no** se elige ningún perfil.
- La app **se bloquea** con un selector hasta que se elija uno.
- Sin perfil, las lecturas **fallan** con `BackendException('No profile selected')`
  en lugar de devolver una lista vacía.

## Qué se hizo

### Filtrado por perfil

`NuvioClient.select()` acepta ahora un filtro PostgREST, y los repositorios de
biblioteca y progreso lo usan:

```
/rest/v1/library_items?select=*&order=added_at.desc&profile_id=eq.1
/rest/v1/watch_progress?select=*&order=last_watched.desc&profile_id=eq.1
```

Sin perfil activo lanzan `BackendException('No profile selected')`: nunca se
adivina.

### Estado de perfiles en la cuenta

`AccountRepository` pasó a exponer la lista y su estado de carga, porque es
estado de la cuenta y el repositorio ya era observable:

- `List<BackendProfile> get profiles`
- `bool get isLoadingProfiles`
- `Object? get profilesError`
- `Future<void> loadProfiles()`

`signIn()` carga los perfiles como parte del inicio de sesión. Un fallo ahí
**no** deshace la sesión: se reporta por `profilesError` para que la UI ofrezca
reintentar.

`isLoadingProfiles` se agregó para no confundir "cargando" con "la cuenta no
tiene perfiles", que son dos estados distintos con mensajes distintos.

### El selector como bloqueo

`ProfilePicker` (`lib/ui/profiles/profile_picker.dart`) se muestra como un gate
desde `AppShell`: si hay sesión y no hay perfil, reemplaza todo el contenido.

- El **riel se oculta** a propósito: no hay nada que navegar todavía.
- La **barra de título se mantiene**, porque es la única forma de mover o cerrar
  la ventana.
- El gate va envuelto en `Material`: el `InkWell` de cada perfil necesita un
  ancestro Material, que normalmente aporta el área de contenido.
- Estados: cargando (spinner), error con "Try again", cuenta sin perfiles, y la
  grilla de perfiles.
- El avatar usa `avatar_url` si es una URL `http`; si no, cae a un círculo con el
  color de `avatar_color_hex` y la inicial del nombre.

`LibraryController` no necesitó cambios: ya escuchaba `account.changes`, así que
recargar al cambiar de perfil salió gratis.

## Archivos

### Nuevos

| Archivo | Qué |
| --- | --- |
| `lib/ui/profiles/profile_picker.dart` | El selector de perfiles (gate) |
| `test/ui/profile_picker_test.dart` | 5 tests del gate |

### Modificados

| Archivo | Cambio |
| --- | --- |
| `lib/domain/backend/account_repository.dart` | Lista de perfiles, carga y errores |
| `lib/data/backend/nuvio_client.dart` | `select()` acepta `filter` |
| `lib/data/backend/nuvio_account_repository.dart` | Carga los perfiles; ya no elige perfil |
| `lib/data/backend/nuvio_library_repository.dart` | Filtra por perfil; falla sin perfil |
| `lib/data/backend/nuvio_progress_repository.dart` | Filtra por perfil; falla sin perfil |
| `lib/app/shell/app_shell.dart` | El gate que bloquea la app |
| `lib/main.dart` | Pasa la cuenta a los repositorios |
| `tool/nuvio_login.dart` | Elige el primer perfil explícitamente e informa cuál |
| `test/data/backend/nuvio_repositories_test.dart` | 15 tests (eran 13) |
| `test/support/fake_repositories.dart` | Modela el estado de perfiles |
| `test/ui/library_screen_test.dart` | Cubre el flujo login → perfil → biblioteca |

## Verificación

- `flutter analyze` sin problemas.
- `flutter test`: **44 tests** (eran 39).
- `flutter build windows --debug` correcto.
- Verificación visual con un preview temporal (`tool/profile_preview.dart`, ya
  borrado): el selector muestra título, subtítulo, avatares con color e inicial,
  nombres y el distintivo `PIN`, sin riel y con la barra de título.

## Limitaciones conocidas

1. **"Volver a todo local" todavía no es posible**: `data/store/` no existe. Un
   fallo al cargar perfiles muestra un error con reintento, no un fallback local.
2. **Avatares reales sin verificar**: no se pudo comprobar con una cuenta real si
   `avatar_url` viene como URL completa o como ruta relativa; en el segundo caso
   se muestra la inicial.
3. **Cambiar de perfil en caliente** todavía no tiene UI: se puede hacer desde el
   código (`selectProfile`), y el avatar del riel es el lugar natural para el
   selector. El gate solo aparece al iniciar sesión o si se desloguea.

## Pendiente

1. **Escrituras + store local** (`data/store/`): habilitan "favoritos locales",
   "todo local" y el fallback local ante fallos de Nuvio.
2. **Selector de perfil en el riel** (aprovechando el avatar), para cambiar de
   perfil sin desloguearse.
3. Persistir la sesión (refresh token) para no loguearse en cada arranque.
4. 4.3 Detail, 4.4 Streams, 4.5 Player integrado, 4.6 Home, 4.7 Search, 4.8
   Settings (reemplaza la tarjeta de login temporal).
