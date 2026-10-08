# 0004 — Reproductor con media_kit (Fase 1)

- **Fecha:** 2026-10-08
- **Sesión:** 0004
- **Estado:** ✅ hecho (Fase 1 completa)

## Objetivo

Empotrar `media_kit` y reproducir un **archivo local** y una **URL directa** (Fase 1 del
roadmap del README).

## Decisiones tomadas

- **Dependencias:** `media_kit` 1.2.6, `media_kit_video` 2.0.1,
  `media_kit_libs_windows_video` 1.0.11 (binarios de libmpv para Windows) y `file_selector`
  1.1.0 (elegir archivo local).
- Se usan los **controles que ya trae** `media_kit_video` (`AdaptiveVideoControls`): play,
  seek, volumen, fullscreen. Los controles propios llegan en la Fase 4.
- El reproductor queda aislado tras **`PlayerService`** (regla 3 del README: ningún widget
  llama a `media_kit` directamente).
- El **fullscreen se enruta por `window_manager`**, no por el de `media_kit` (ver *Problemas*).
- El **chrome persistente se centraliza en `AppShell`**, y el fullscreen se decide en un solo
  lugar.
- Se agregó el flag de línea de comandos **`--play=<source>`** para probar sin UI.

## Qué se hizo

1. Se agregaron las dependencias (y `pub add` regeneró el registrante de plugins).
2. Se creó `PlayerService` (`lib/services/player/player_service.dart`): envuelve `Player` +
   `VideoController` y expone `open`, `playOrPause`, `seek`, `setVolume`, `dispose` y los
   streams (`position`, `duration`, `playing`, `buffering`, `error`).
3. Se creó `PlayerScreen`: `Video` + controles, con los callbacks de fullscreen enrutados a
   `WindowController.setFullScreen(...)`, y un `SnackBar` ante errores de reproducción.
4. `HomeScreen` pasó a ser el punto de entrada de Fase 1: input de URL + "Open local file"
   (vía `file_selector`) → navega a `PlayerScreen`.
5. `main.dart`: `MediaKit.ensureInitialized()` y parseo de `--play=<source>`.
6. Se corrigió el **fullscreen** (ver *Problemas*) y se agregó
   `WindowController.setFullScreen` + `ValueNotifier<bool> isFullScreen`.
7. Se centralizó el chrome en **`AppShell`** (`lib/app/shell/app_shell.dart`): el `TitleBar`
   se oculta en fullscreen desde un único lugar, dejando la puerta abierta para el sidebar.

## Archivos tocados

| Archivo | Cambio |
| --- | --- |
| `lib/services/player/player_service.dart` | **nuevo** — wrapper de `media_kit` |
| `lib/ui/screens/player_screen.dart` | **nuevo** — `Video` + controles + fullscreen + errores |
| `lib/ui/screens/home_screen.dart` | **cambiado** — URL + archivo local → `PlayerScreen` |
| `lib/app/app.dart` | **cambiado** — `initialSource` y `builder` → `AppShell` |
| `lib/app/shell/app_shell.dart` | **nuevo** — dueño único del chrome persistente |
| `lib/app/window/window_controller.dart` | **cambiado** — `setFullScreen` + `isFullScreen` |
| `lib/ui/widgets/title_bar.dart` | **sin cambio neto** — se auto-ocultó y luego se movió esa decisión a `AppShell` |
| `lib/main.dart` | **cambiado** — `MediaKit.ensureInitialized()` + `--play=` |
| `test/widget_test.dart` | **cambiado** — ahora verifica el `HomeScreen` nuevo |
| `pubspec.yaml` / `pubspec.lock` / `windows/flutter/generated_*` | **cambiado** — dependencias |

## Código relevante

`PlayerService` (aislamiento del reproductor):

```dart
class PlayerService {
  PlayerService() {
    _controller = VideoController(_player);
  }

  final Player _player = Player();
  late final VideoController _controller;

  VideoController get controller => _controller;

  Future<void> open(String source, {bool play = true}) {
    return _player.open(Media(source), play: play);
  }
}
```

Fullscreen enrutado a `window_manager` (`lib/ui/screens/player_screen.dart`):

```dart
Video(
  controller: _player.controller,
  onEnterFullscreen: () => WindowController.setFullScreen(true),
  onExitFullscreen: () => WindowController.setFullScreen(false),
),
```

Decisión de chrome en un solo lugar (`lib/app/shell/app_shell.dart`):

```dart
ValueListenableBuilder<bool>(
  valueListenable: WindowController.isFullScreen,
  builder: (context, isFullScreen, _) => Column(
    children: [
      if (!isFullScreen) const TitleBar(),
      Expanded(child: child),
    ],
  ),
);
```

## Problemas encontrados

1. **El fullscreen no funcionaba bien.** Dos síntomas con la misma causa:
   - **La barra seguía visible.** `media_kit.enterFullscreen()` pushea una **ruta** en el
     `rootNavigator`, y como el `TitleBar` vive en el `builder` (encima del Navigator), la
     ruta no lo tapa.
   - **Bordes visibles a los lados.** `media_kit` usa su propio fullscreen nativo
     (`Utils.EnterNativeFullscreen`), que quita `WS_OVERLAPPEDWINDOW` pero **no** actualiza el
     flag de `window_manager`. Entonces el `WM_NCCALCSIZE` de `window_manager` seguía
     aplicando su recorte de **8 px** por izquierda/derecha/abajo ("necesario para
     redimensionar") → huecos en los bordes.

   **Solución.** Enrutar el fullscreen por **`window_manager.setFullScreen`**: su
   `WM_NCCALCSIZE` calcula `l = t = 0` en fullscreen → sin recortes; y ocultar el chrome vía
   `AppShell`. Detalle: `window_manager.setFullScreen` **no emite** el evento
   `enter-full-screen` (usa `SetWindowPos`, no `SC_MAXIMIZE`), así que el estado se trackea en
   un `ValueNotifier` en vez de por eventos.

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ Pasa |
| `flutter build windows` | ✅ `agustream.exe` |
| URL directa | ✅ Big Buck Bunny, `00:07 / 00:10`, controles |
| Archivo local | ✅ Mismo archivo desde disco |
| Fullscreen (rect) | ✅ `(0,0)-(2560,1440)` = monitor completo |
| Fullscreen (barra/bordes) | ✅ barra oculta, sin huecos laterales |
| Salir de fullscreen | ✅ vuelve a `(480,240)-(2080,1140)` con la barra |

El log confirma decodificación por hardware:

```
media_kit: ANGLESurfaceManager: Direct3D Feature Level: 11_0
media_kit: VideoOutput: Using H/W rendering.
```

## Pendiente / Próximos pasos

1. **Fase 2:** cliente del protocolo Stremio (`lib/data/addons/`).
2. **Fase 4:** reemplazar los controles de `media_kit` por los propios.
3. **Sidebar (chrome):** cuando se agregue, vivirá en `AppShell` y **también** deberá
   ocultarse en fullscreen. Decisión pendiente: cómo navega el shell (encima del Navigator,
   así que necesita un `GlobalKey<NavigatorState>` o un router tipo `go_router` con
   `ShellRoute`).
