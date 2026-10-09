# 0003 — Barra de título custom estilo Windows 11

- **Fecha:** 2026-10-08
- **Sesión:** 0003
- **Estado:** 🟡 parcial (la barra funciona; el borde superior del caption es una
  limitación conocida, ver *Pendiente / TODO*)

## Objetivo

Reemplazar el caption nativo de Windows por una barra de título dibujada en Flutter, con el
estilo de Windows 11, sin desentonar con el tema de la app y sin romper los comportamientos
nativos de la ventana (mover, redimensionar, minimizar, maximizar, cerrar).

## Decisiones tomadas

- **Barra de título totalmente custom** (no solo recolorear el caption nativo): ocultar el
  caption nativo con `TitleBarStyle.hidden` y dibujar la barra con widgets Flutter.
- **Stack:** `window_manager` 0.5.2 (control de la ventana + botones reales de Windows 11) y
  `flutter_acrylic` 1.1.4 (fondo Mica).
- La barra vive en `MaterialApp.builder`, **encima del `Navigator`**, para que se mantenga en
  todas las rutas.
- Reutilizar los glifos **reales** de Windows 11 que trae `window_manager`
  (`WindowCaptionButton`, con sus estados hover/pressed) en vez de dibujar iconos propios.
- Aislar **todas** las llamadas nativas de la ventana en `WindowController`; nada más habla
  con `window_manager` ni `flutter_acrylic`.
- El fondo de la barra es **opaco** (no transparente). Ver *Problemas encontrados*.
- La barra mide 32 px lógicos de alto, igual que el caption de Win11.

## Qué se hizo

1. Se agregaron las dos dependencias y `pub add` regeneró el registrante de plugins.
2. Se creó `WindowController` (concern del shell): `Window.initialize()`,
   `windowManager.ensureInitialized()`, `WindowOptions` (caption oculto, centrada, tamaño
   mínimo), efecto Mica, y helpers (`minimize`, `maximize`, `unmaximize`, `close`).
3. Se creó `TitleBar`: icono + nombre de la app a la izquierda, los tres botones reales de
   Win11 a la derecha, envuelto en `Material` y con fondo opaco.
4. Se montó vía `MaterialApp.builder` como `Column([TitleBar, Expanded(child)])`, para que
   renderice encima del `Navigator`.
5. Se quitó el `AppBar` placeholder de `HomeScreen` para evitar el título duplicado.
6. Se escribió un `_TitleBarDragArea` propio para sortear que el `DragToMoveArea` de
   `window_manager` no puede mover una ventana maximizada.
7. Se verificó con `flutter analyze`, `flutter test`, un build de Windows y corridas reales
   (capturas + input de mouse sintético vía `SendInput`).

## Archivos tocados

| Archivo | Cambio |
| --- | --- |
| `pubspec.yaml` / `pubspec.lock` | **cambiado** — `window_manager`, `flutter_acrylic` |
| `lib/main.dart` | **cambiado** — bootstrap async, `WidgetsFlutterBinding.ensureInitialized()`, `WindowController.initialize()` |
| `lib/app/app.dart` | **cambiado** — `MaterialApp.builder` monta el `TitleBar` encima del `Navigator` |
| `lib/app/window/window_controller.dart` | **nuevo** — único dueño de `window_manager` / `flutter_acrylic` |
| `lib/ui/widgets/title_bar.dart` | **nuevo** — la barra y su área de arrastre |
| `lib/ui/screens/home_screen.dart` | **cambiado** — se quitó el `AppBar` placeholder |
| `windows/flutter/generated_plugin_registrant.cc` / `generated_plugins.cmake` | **cambiado** — generados por `pub add` |
| `windows/runner/win32_window.cpp` | **experimentado y revertido** — sin cambio neto (ver *Problemas*) |
| `README.md` | **cambiado** — entrada de TODO por la limitación conocida |

## Código relevante

Bootstrap (`lib/main.dart`):

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowController.initialize();
  runApp(const AgustreamApp());
}
```

Montar la barra encima del `Navigator` (`lib/app/app.dart`):

```dart
builder: (context, child) {
  return Column(
    children: [
      const TitleBar(),
      Expanded(child: child ?? const SizedBox.shrink()),
    ],
  );
},
```

Mover una ventana maximizada (`lib/ui/widgets/title_bar.dart`): el `DragToMoveArea` de
`window_manager` llama a `startDragging()`, que envía `SC_MOVE`. Windows se niega a iniciar
un bucle de movimiento sobre una ventana maximizada, así que el arrastre no hace nada en
silencio. El workaround la restaura primero:

```dart
Future<void> _startDragging() async {
  if (isMaximized) {
    await windowManager.unmaximize();
  }
  await windowManager.startDragging();
}
```

## Problemas encontrados

1. **Crash al arrancar — binding faltante.** `Window.initialize()` (flutter_acrylic) lanzaba
   *"Binding has not yet been initialized"*. Se arregló llamando a
   `WidgetsFlutterBinding.ensureInitialized()` antes de tocar cualquier plugin. Ni
   `flutter analyze` ni `flutter test` lo detectan; solo una corrida real.

2. **Glifos del caption "glitcheados" al maximizar.** La barra era transparente para dejar
   ver el Mica. Una región transparente **no se repinta** al redimensionar, así que los
   glifos anteriores quedaban como doble imagen (verificado con zoom 14×: la línea de
   minimizar se dibujaba dos veces, con offset). Se arregló dándole a la barra un fondo
   `Material` **opaco**.

3. **Subrayado amarillo bajo el nombre de la app.** El `Text` estaba fuera de cualquier
   `Material`, así que se fusionaba con `DefaultTextStyle.fallback()` (texto blanco con
   subrayado amarillo doble). Se arregló envolviendo la barra en `Material`, que además
   aporta el estilo de texto del tema.

4. **No se podía arrastrar una ventana maximizada.** Reproducido con input sintético: estando
   maximizada, un arrastre daba `delta=(0,0)`. Se arregló con `_TitleBarDragArea` (restaurar
   antes de arrastrar).

5. **Zona muerta del borde superior — ABIERTO.** Ver *Pendiente / TODO*.

## Mediciones (de referencia)

La pantalla es 2560×1440 al 125% de DPI (`dpr = 1.25`), así que 8 px físicos de marco ≈
10 px lógicos.

| Estado de ventana | Rect de ventana (físico) | View de Flutter | Zona muerta (tope de la barra) |
| --- | --- | --- | --- |
| Ventana | `(480,240)-(2080,1140)` | `(488,241)-(2072,1132)` | primeros ~4–11 px |
| Maximizada | `(-9,-9)-(2569,1389)` | `(0,0)-(2560,1380)` | primeros ~12–19 px |

La barra mide 40 px físicos de alto, así que la zona muerta es una parte importante.

## Pendiente / TODO

### 1. Zona muerta del borde superior (resolver al 100%)

**Síntoma.** Los primeros ~10 px (ventana) / ~15 px (maximizada) de la barra no reciben
eventos de puntero: ni se arrastra ni se redimensiona. Todo lo de abajo funciona.

**Causa.** Es un tema del área no-cliente de Windows, no de Flutter. Windows reserva el marco
exterior (`WS_THICKFRAME`, `SM_CXSIZEFRAME + SM_CXPADDEDBORDER`) para redimensionar y lo
hit-testea como no-cliente (`HTTOP`). El `TitleBarStyle.hidden` de `window_manager` conserva
ese marco (para no perder el redimensionado nativo) y solo recorta el cliente por
izquierda/derecha/abajo, así que el borde superior se solapa con el cliente y se come esos
clics. La librería **no lo documenta**; su `CHANGELOG` muestra que la zona se ha parcheado
muchas veces.

**Probado y descartado.** Manejar `WM_NCHITTEST` en `windows/runner/win32_window.cpp` **no
tuvo efecto**: la ventana top-level nunca recibe el mensaje, porque el view de Flutter es una
**ventana hija** que se queda con el puntero. El experimento se revirtió.

Opciones para cerrarlo:

- **Opción B — `WM_NCHITTEST` en la ventana hija de Flutter (mejor resultado).** Subclasear
  la hija (`SetWindowSubclass`) en el runner y devolver `HTCAPTION` para la franja de la
  barra y `HTMAXBUTTON` para el botón de maximizar. Esto da **arrastre nativo** (elimina la
  necesidad de `_TitleBarDragArea` y su timing de `SC_MOVE`) y **recupera el flyout de Snap
  Layouts** de Windows 11. Costo: el proc nativo no sabe dónde están los botones de Flutter,
  así que hay que acordar/duplicar la geometría (p. ej. "primeros N px menos los ~140 px de
  la derecha") y convertirla con `GetDpiForWindow`.

- **Opción C — ventana realmente frameless + resize desde Dart (más autocontenida).**
  Quitar `WS_THICKFRAME`/`WS_CAPTION` en el runner y manejar `WM_NCCALCSIZE` (**no** confiar
  en `windowManager.setAsFrameless()`: en 0.5.2 solo pone una bandera). Sin marco no hay
  borde que robe clics, así que la zona muerta desaparece. El resize se hace entonces en Dart
  con `DragToResizeArea`. Costo: el resize es un poco menos nativo; hay que revisar la sombra
  y las esquinas DWM.

- **Opción A — aceptarlo (elección actual).** Arrastrar desde el medio de la barra. Costo
  cero; la limitación es cosmética.

### 2. Mica quedó invisible

Como la barra es opaca y el `Scaffold` es opaco, ya nada muestra el fondo Mica, así que
`flutter_acrylic` quedó inerte. Decidir más adelante: quitar la dependencia, o volver a una
superficie translúcida (que reintroduce el ghosting salvo que se resuelva el repintado).

### 3. Commit pendiente

Todo lo de la sesión 0003 quedó **sin commitear**. Mensaje sugerido:
`feat: add Windows 11 style custom title bar`.
