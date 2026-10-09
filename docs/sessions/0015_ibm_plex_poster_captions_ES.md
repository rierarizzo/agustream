# 0015 — Tipografía IBM Plex Sans y ajuste de tarjetas de película

## Objetivo

Mejorar el renderizado del texto, que se veía áspero en Windows, y ajustar la
presentación del nombre y el año de las tarjetas de película. Se probó
primero Inter y luego IBM Plex Sans en Medium, que fue la elección final.

## Diagnóstico del renderizado

Revisión del proyecto para entender por qué el texto se veía áspero:

- Flutter en Windows rasteriza el texto en **escala de grises**. No usa
  ClearType ni suavizado subpíxel, y no hay un switch soportado para activarlo
  (ya documentado en la sesión 0007).
- El motor de render (Skia o Impeller) cambia cómo se rasterizan los glifos. No
  se confirmó cuál es el backend por defecto en esta versión de Flutter (3.47).
  Queda para comprobar con `--enable-impeller` / `--no-enable-impeller`.
- Las fuentes Inter empaquetadas traían hinting TrueType. A escala 125% podía
  deformar formas a tamaños chicos (hipótesis, no confirmada).
- El manifiesto ya es `PerMonitorV2`, y no hay `TextScaler` ni filtros que
  emborronen el texto.

## Qué se hizo

### 1. Tarjetas de película: nombre y año

Se aplicó a todas las tarjetas que muestran nombre + año: Home, Catalog,
Library y la sección "Similar" del detalle.

- Colores nuevos en `AppColors`: nombre `#AFB0B0`, año `#62605D`.
- Tamaños: nombre 16 → **15 px**, año 14 → **13 px**.
- Separación: alto de línea **1.2** en ambos, para acercar nombre y año.
- Los estilos viven en `PosterCaption` (`app_theme.dart`), que se deriva del
  `TextTheme` para conservar familia y peso. El `TextTheme` global no cambió.

El año queda con contraste **≈3:1** sobre el fondo `#0A0A0C`, por debajo del
mínimo recomendado de 4.5:1 para texto chico. Se mantuvo a pedido, para probar.

### 2. Cambio de familia tipográfica: Inter → IBM Plex Sans

- `fontFamily` del tema pasa a `'IBM Plex Sans'`.
- Los `bodyLarge`, `bodyMedium` y `bodySmall` del `TextTheme` usan
  `FontWeight.w500` (Medium) como peso base. Los títulos conservan 600 y 700.
- Los archivos de Inter se borraron. Estaban sin trackear en git y no tenían
  referencias en el código.

### 3. Organización de assets

Una carpeta por fuente, para no mezclar:

```
assets/fonts/
├── ibm_plex_sans/
│   ├── IBMPlexSans-Regular.otf   (400)
│   ├── IBMPlexSans-Medium.otf    (500)
│   ├── IBMPlexSans-SemiBold.otf  (600)
│   ├── IBMPlexSans-Bold.otf      (700)
│   └── IBMPlexSans-OFL.txt       (licencia SIL OFL 1.1, IBM Corp. 2017)
```

Las fuentes salieron de la instalación local de IBM Plex Sans en Windows. La
licencia se descargó del repositorio oficial `IBM/plex`.

## Código tocado

| Archivo | Cambio |
| --- | --- |
| `lib/app/theme/app_theme.dart` | `fontFamily` IBM Plex Sans; peso 500 en body; colores `posterTitle` / `posterYear`; clase `PosterCaption` |
| `lib/ui/widgets/meta_poster_card.dart` | Nombre y año con `PosterCaption` (Home y Catalog) |
| `lib/ui/library/poster_tile.dart` | Nombre y año con `PosterCaption` (Library) |
| `lib/ui/detail/detail_sections.dart` | `_SimilarTile`: nombre y año con `PosterCaption` |
| `pubspec.yaml` | Familia `IBM Plex Sans` con los cuatro pesos, en `ibm_plex_sans/` |
| `assets/fonts/ibm_plex_sans/*` | Fuentes y licencia nuevas |

Nota: `app_theme.dart` y `pubspec.yaml` ya tenían cambios sin commitear de la
primera configuración de Inter. Se incluyeron en este commit porque forman parte
del mismo cambio de tipografía.

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ **85 tests** |
| `flutter build windows --debug` | ✅ Los `.otf` quedan en `flutter_assets/assets/fonts/ibm_plex_sans/` |

No se hizo revisión visual en pantalla. Pendiente con `flutter run -d windows`.

## Notas

- IBM Plex Sans es algo más ancha que Inter. Si algún texto se corta en
  tarjetas o encabezados, hay que ajustar tamaños.
- IBM Plex Sans tiene una variante **Text**, pensada para tamaños pequeños. Está
  instalada localmente, pero no se usó. Es candidata si el texto chico no convence.
- Los archivos OTF (CFF) no traen hinting TrueType. Si el resultado cambia el
  problema de renderizado, habrá que volver a evaluar la hipótesis del hinting.

## Pendiente / Próximos pasos

1. Revisión visual con `flutter run -d windows` en Home, Library, Catalog y el
   detalle: nombre/año, contraste del año, desbordes por el ancho de Plex.
2. Decidir si se usa IBM Plex Sans Text para tamaños chicos.
3. **Centralizar estilos** (plan aprobado en conversación, no implementado):
   - `lib/app/theme/app_typography.dart` con roles tipográficos con nombre de uso
     (`pageTitle`, `cardTitle`, `cardYear`, `body`, `label`, etc.).
   - `AppTheme` construye el `TextTheme` a partir de esos roles.
   - Eliminar los `copyWith` y `TextStyle(...)` sueltos en las pantallas.
   - Mover los colores literales a `AppColors`.
   - Migración en pasos, comparando capturas antes y después de cada pantalla.
   - Decidir si se agrega una regla en `AGENTS.md` que prohíba `textTheme.X` y
     `TextStyle(` fuera de `lib/app/theme/`.
