# 0014 — Pulido de escala de UI

## Objetivo

Mini sesión de pulido transversal (no de una fase concreta). Se notó que el
contenido de la app quedaba **un poco más chico** que las capturas de referencia
(`agus-refs/`, fuera del repo). El objetivo era encontrar si faltaba alguna
configuración y alinear la escala.

## Diagnóstico

Comparando las capturas de referencia (**2560×1380 físicos a 125% de DPI**, o sea
**2048×1104 lógicos**) contra nuestro código, la unidad de medida correcta es
`físico / 1.25`. Hallazgos:

### Lo que sí faltaba: `visualDensity`

En Flutter, `ThemeData` usa la densidad **por plataforma**:

```dart
// packages/flutter/lib/src/material/theme_data.dart
static VisualDensity defaultDensityForPlatform(TargetPlatform platform) => switch (platform) {
  android || iOS || fuchsia => standard,
  linux || macOS || windows => compact,   // <-- Windows
};
```

`VisualDensity.compact` es `(-2, -2)` → `baseSizeAdjustment` = **−8 px lógicos
por eje**. Como el tema no la tocaba, todos los componentes Material (botones,
chips, campos, dropdowns) salían 8 px más chicos que la referencia. Verificado
con la captura `detail1.png`: el botón **Play** mide **50 físicos = 40 lógicos**
(altura estándar de un `FilledButton` M3); el nuestro salía en **32**.

### Lo que no era un problema

- **DPI:** el manifiesto ya es `PerMonitorV2`; `window_manager` crea la ventana a
  1280×720 **lógicos** (1600×900 físicos). No es un problema de escala global.
- **Texto base:** `titleLarge` (22) y los iconos del riel (20) **ya coincidían**
  con la referencia. No hacía falta `textScaler` global.

### Diferencias de medidas

Los tokens propios estaban ~20% por debajo de la referencia (riel ~78, hero
~575, card "Continue watching" ~336, grilla ~225) y el texto de cuerpo usaba un
paso menos (`bodyMedium` 14 / `bodySmall` 12 en vez de 16 / 14).

## Qué se hizo

### Tema (`lib/app/theme/app_theme.dart`)

- `visualDensity: VisualDensity.standard`.
- Tokens: `sideRailWidth` 64 → **80**, `railButton` 40 → **48**.
- Se agregaron `headlineLarge` y `bodyLarge` al `TextTheme`.

### Escala de texto

Intercambio sistemático en `lib/ui/**`:

- cuerpo primario `bodyMedium` → **`bodyLarge`** (16);
- texto secundario `bodySmall` → **`bodyMedium`** (14);
- títulos de página `headlineMedium` → **`headlineLarge`** (32), para igualar
  `Settings`/`Library`/etc. Los títulos de sección se quedan en `titleLarge`
  (22), que ya coincidía.

### Tamaños

| Elemento | Antes | Ahora |
| --- | --- | --- |
| Riel / botón del riel | 64 / 40 | 80 / 48 |
| Hero de Home | 440 | 576 |
| Fila "Continue watching" | 220 | 248 |
| Card "Continue watching" | 280 | 336 |
| Fila de catálogo / póster | 285 / 150 | 332 / 180 |
| Grilla (Library y Catalog) | 190 | 230 |
| Póster del detalle | 150 | 224 |

Se subió también la altura de la lista de reparto (**156 → 176**) para que el
texto más grande no desborde.

### Ventana

La referencia corre **maximizada**. Se agregó `WindowController.isMaximized`
(ValueNotifier) y `windowManager.maximize()` al arrancar. `TitleBar` dejó de
guardar su `_isMaximized` local y ahora lee/escribe ese notifier, así muestra el
botón correcto (restaurar/maximizar) desde el primer frame. La barra sigue
ocultándose en fullscreen (`isFullScreen`).

## Archivos

**Modificados**

| Archivo | Cambio |
| --- | --- |
| `lib/app/theme/app_theme.dart` | `visualDensity`, tokens de tamaño, `headlineLarge`/`bodyLarge` |
| `lib/app/window/window_controller.dart` | `isMaximized` + arranque maximizado |
| `lib/ui/widgets/title_bar.dart` | Estado maximizado desde `WindowController` |
| `lib/ui/home/home_screen.dart` | Hero, filas, cards, texto de cuerpo |
| `lib/ui/detail/detail_screen.dart` | Póster 224, textos de cuerpo |
| `lib/ui/detail/detail_sections.dart` | Textos + altura de la lista de reparto |
| `lib/ui/library/poster_tile.dart` | Textos de cuerpo |
| `lib/ui/screens/library_screen.dart` | Encabezado, grilla 230, textos |
| `lib/ui/catalog/catalog_screen.dart` | Encabezado, grilla 230, textos |
| `lib/ui/streams/streams_dialog.dart` | Textos de cuerpo |
| `lib/ui/profiles/profile_picker.dart` | Encabezado y textos |
| `lib/ui/screens/settings_screen.dart` | Encabezado y textos |
| `lib/ui/screens/section_placeholder.dart` | Encabezado y textos |
| `lib/ui/widgets/meta_poster_card.dart` | Textos de cuerpo |
| `test/ui/home_screen_test.dart` | `ensureVisible` antes de tocar "See all" |

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ **85 tests** |
| `flutter build windows --debug` | ✅ |

Los dos tests que fallaron al principio eran esperables: el texto más grande
desbordaba la tarjeta de reparto (4 px) y el botón "See all" quedaba fuera de la
pantalla del test (800×600). Se corrigió la altura de la lista y se añadió
`ensureVisible` en el test.

## Notas

- Los tamaños de la tabla son **estimaciones medidas** de las capturas
  (`físico / 1.25`): el riel se dedujo del centro de los iconos/avatar (49
  físicos) y del píxel del ítem seleccionado; el hero, de dónde arranca
  "Continue watching". Se pueden afinar tras verlo en pantalla.
- No se corrió la app para una comparación 1:1; la verificación fue por análisis,
  tests y build.

## Pendiente

1. Confirmar en pantalla si algún tamaño quedó corto/largo y ajustar.
2. Retomar lo pendiente de 0013: **4.5 Player integrado**, **4.7 Search**,
   **4.8 Settings**, y 4.6b (Home curado desde el backend).
