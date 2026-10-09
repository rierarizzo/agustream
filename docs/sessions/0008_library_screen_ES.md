# 0008 — Library (parte 4.2 de la Fase 4)

## Objetivo

Segunda parte de la Fase 4 (Product UI): la sección **Library**, que muestra la
biblioteca real guardada en la cuenta de Nuvio — grilla de pósters, filtros por
tipo, y decoración según el progreso de visionado.

## El bloqueante: no había login

El plan original de 4.2 era simplemente "conectar `fetchLibrary()`". Al
implementarlo apareció un problema que el plan no contemplaba: **la app no tenía
forma de autenticarse**, y sin sesión el backend no devuelve nada.

`library_items` es una tabla de Supabase con row-level security: el backend
acota cada consulta al usuario autenticado. `NuvioBackendProvider` lanza
`BackendException('Not signed in')` a propósito cuando no hay sesión. La pantalla
de login estaba prevista recién para 4.8.

Se resolvió con **dos caminos temporales**, ninguno de los cuales es la solución
final:

1. Una **tarjeta de login en Settings** (email + contraseña), para poder probar
   con una cuenta real desde la UI.
2. **Auto-login por variables de entorno** (`NUVIO_EMAIL` / `NUVIO_PASSWORD`) en
   `main.dart`, para no escribir la contraseña en cada ejecución.

Las credenciales se leen del entorno **solo para esa ejecución**: no se escriben
en el repositorio ni en disco. El repositorio es público, así que esto importa.

## Decisiones de arquitectura

### Inyección de servicios

`AppServices` (`InheritedWidget`) expone el `BackendProvider` al árbol de
widgets. Antes no existía ninguna forma de que una pantalla accediera al
backend; ahora la UI sigue sin tocar `data/` (regla del README) y los tests
pueden inyectar un backend falso.

### Sesión observable

`BackendProvider` es una interfaz plana, sin notificación de cambios, así que la
Library no tenía cómo enterarse de que el usuario se logueó. Se agregó
`SessionController` (`ChangeNotifier`) por encima, que envuelve `signIn` /
`signOut` y notifica.

`LibraryController` se suscribe a él: cuando aparece una sesión carga la
biblioteca, y cuando desaparece limpia el estado. Así el login desde Settings
recarga la Library sin acoplar las dos pantallas.

### Estado de la sección

`LibraryController` (`ChangeNotifier`) concentra la carga y el filtrado:

- `fetchLibrary()` + `fetchWatchProgress()`.
- Filtro `All` / `Movies` / `Shows` (`contentType == 'movie'` / `'series'`).
- Estados: cargando, error, sin sesión, biblioteca vacía, filtro sin resultados.

El progreso se indexa por `content_id` quedándose con la entrada **más reciente**
(`last_watched`), porque las series tienen una fila por episodio.

## Interfaz

- `LibraryScreen`: título, contador de títulos, botón de recargar, chips de
  filtro y grilla responsive (`maxCrossAxisExtent: 190`, aspecto 0.58).
- `PosterTile`: póster 2:3, título, año, hover con borde ámbar y tooltip.
- **Badge de visto**: círculo oscuro con un check ámbar.
- **Barra de progreso**: franja ámbar de 3 px al pie del póster.

El año se deriva de `release_info` (`2019`, `2019-2023`, ...) con un getter
`year` en `LibraryItem`, para no parsearlo en la UI.

## Cambio en el shell: `Material` → `Scaffold`

El área de contenido del shell pasó de `Material` a `Scaffold`:

```dart
- Material(color: AppColors.background, child: Navigator(...))
+ Scaffold(backgroundColor: AppColors.background, body: Navigator(...))
```

Motivo: los `SnackBar` necesitan un `Scaffold` donde mostrarse. Sin él, el tap en
un póster no daba ninguna respuesta. `Scaffold` es un superconjunto de `Material`
para este uso (aporta el ancestro Material igual, y además aloja SnackBars y
BottomSheets), no agrega AppBar ni padding, y se verificó visualmente que el
shell queda idéntico. **No cambió ninguna dependencia.**

## Archivos

### Nuevos

| Archivo | Qué |
| --- | --- |
| `lib/app/services/app_services.dart` | `InheritedWidget` con el backend y la sesión |
| `lib/app/services/session_controller.dart` | Estado de sesión observable |
| `lib/ui/library/library_controller.dart` | Carga, filtro y estados de la biblioteca |
| `lib/ui/library/poster_tile.dart` | Tile de póster con badges |
| `lib/ui/screens/library_screen.dart` | La sección |
| `test/support/fake_backend_provider.dart` | `BackendProvider` en memoria para tests |
| `test/ui/library_screen_test.dart` | 6 tests de la sección |

### Modificados

| Archivo | Cambio |
| --- | --- |
| `lib/app/app.dart` | Recibe el backend, crea `SessionController`, provee `AppServices` |
| `lib/main.dart` | Crea `NuvioBackendProvider` + auto-login por entorno |
| `lib/app/shell/section_host.dart` | Rutea `AppSection.library` a la pantalla |
| `lib/app/shell/app_shell.dart` | `Material` → `Scaffold` |
| `lib/domain/backend/library_item.dart` | Getter `year` |
| `lib/ui/screens/settings_screen.dart` | Tarjeta de login temporal |
| `test/widget_test.dart` | Usa el backend falso |

## Verificación

- `flutter analyze` sin problemas.
- `flutter test`: **32 tests** (6 nuevos).
- `flutter build windows --debug` correcto.
- Verificación visual con un preview temporal (`tool/library_preview.dart`, ya
  borrado) que corría las pantallas reales contra un backend falso con imágenes
  de relleno: se confirmaron la grilla, los chips, el badge de visto, las barras
  de progreso, los títulos con su año y que el shell sigue igual tras el cambio a
  `Scaffold`.

## Limitaciones conocidas

1. **El badge se deriva de `watch_progress`**, que para series tiene una fila por
   episodio. Por eso el check solo se muestra en películas terminadas
   (`fraction >= 0.95`); las series muestran barra de progreso. La señal correcta
   sería la tabla `watched_items`, pero no se pudo verificar su esquema sin una
   cuenta real.
2. **Sin escrituras.** `BackendProvider` solo tiene `fetch*`: la app todavía no
   puede guardar nada, ni siquiera en Nuvio.
3. **Sin persistencia de sesión.** No se guarda el refresh token, así que hay que
   loguearse en cada arranque.
4. **Sin filtro por perfil.** `fetchLibrary()` no filtra por `profile_id`, y RLS
   acota por cuenta, no por perfil: con varios perfiles la grilla los mezcla.
   Hay que verificarlo con una cuenta real y, si aplica, elegir un perfil activo.

## Pendiente

- **Refactor del seam de datos** (paso siguiente, decidido): partir
  `BackendProvider` por capacidad (`LibraryRepository`, `ProgressRepository`,
  `AccountRepository`) con escrituras y notificación de cambios, e implementar
  `data/store/` local. Es el habilitante de "favoritos locales" y de "todo
  local", y conviene hacerlo **antes de la primera escritura**.
- 4.3 Detail, 4.4 Streams, 4.5 Player integrado, 4.6 Home, 4.7 Search, 4.8
  Settings (reemplaza la tarjeta de login temporal).
- Selector de perfil activo.
