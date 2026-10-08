# 0007 — Tema y shell navegable (Fase 4, parte 1)

- **Fecha:** 2026-10-08
- **Sesión:** 0007
- **Estado:** ✅ hecho (Fase 4.1 completa)

## Objetivo

Primera parte de la Fase 4 (UI de producto): centralizar el diseño en un tema y tener un
**shell navegable** (rail de iconos + barra de título + área de contenido), antes de empezar
a construir pantallas reales.

## Referencia de diseño

Se usaron capturas de **AIOStreams** (no de Nuvio) como referencia visual. Se mantienen
**fuera del repo**, para no commitear datos personales (el repo es público).

De ahí salieron los tokens y la estructura:

| Token | Valor |
| --- | --- |
| Fondo | `#0A0A0C` |
| Superficie | `#151518` |
| Superficie alta (hover/selección) | `#1F1F24` |
| **Acento** | `#F0A020` (ámbar) |
| Texto primario / secundario | `#F5F5F7` / `#9A9AA4` |
| Divisores | `#26262B` |
| Radios | 6 / 10 / 16 |

## Decisiones tomadas

- **Tema centralizado** en `lib/app/theme/app_theme.dart`: colores, espaciados, radios y
  tamaños en un solo lugar. Ninguna pantalla hardcodea valores.
- **Rail de iconos** (64 px), con el avatar arriba y Settings fijado abajo, como la referencia.
- **Barra de título simplificada**: solo los tres botones de ventana, sin texto ni ícono. La
  referencia no muestra título.
- **Navegación: `IndexedStack`** (opción A de las alternativas evaluadas). Sin dependencias
  nuevas, conserva el estado por sección y no necesita router.
- **Construcción perezosa de secciones**: `IndexedStack` conserva el estado, pero una sección
  no visitada se deja como `SizedBox.shrink()`, así no dispara peticiones al arrancar.
- **El shell pasa a ser la ruta raíz con un Navigator anidado** (ver *Problemas*).
- Se eliminó `home_screen.dart` (era el lanzador de la Fase 1); su contenido quedó como
  **tarjeta temporal en Settings**, para no perder la prueba de reproducción.

## Qué se hizo

1. Se definieron los tokens y `AppTheme.dark()`.
2. Se creó `AppSection` (enum: label + icono normal/seleccionado) con las 7 secciones.
3. Se creó `SideRail`: avatar (placeholder por ahora), botones con tooltip, estado seleccionado,
   Settings abajo.
4. Se reescribió `AppShell`: rail + barra de título + área de contenido, con el `Navigator`
   anidado y el `ValueNotifier` de la sección seleccionada.
5. Se creó `SectionHost`: `IndexedStack` de secciones con construcción perezosa.
6. Se creó `SectionPlaceholder` y una `SettingsScreen` con la tarjeta temporal.
7. Se simplificó `TitleBar` (solo los botones) y se actualizó el test de widget para navegar
   entre secciones.

## Archivos tocados

| Archivo | Cambio |
| --- | --- |
| `lib/app/theme/app_theme.dart` | **nuevo** — tokens + `AppTheme.dark()` |
| `lib/app/shell/app_section.dart` | **nuevo** — enum de secciones |
| `lib/app/shell/side_rail.dart` | **nuevo** — rail de iconos |
| `lib/app/shell/app_shell.dart` | **reescrito** — chrome + Navigator anidado |
| `lib/app/shell/section_host.dart` | **nuevo** — `IndexedStack` con construcción perezosa |
| `lib/ui/screens/section_placeholder.dart` | **nuevo** |
| `lib/ui/screens/settings_screen.dart` | **nuevo** — incluye la tarjeta temporal |
| `lib/ui/screens/home_screen.dart` | **borrado** |
| `lib/ui/widgets/title_bar.dart` | **cambiado** — solo los botones de ventana |
| `lib/app/app.dart` | **cambiado** — usa el tema y monta `AppShell` como ruta raíz |
| `test/widget_test.dart` | **cambiado** — navega entre secciones |

## Código relevante

El shell como ruta raíz con el contenido en un Navigator propio:

```dart
Row(
  children: [
    ValueListenableBuilder<AppSection>(
      valueListenable: _selected,
      builder: (context, section, _) => SideRail(selected: section, onSelected: _select),
    ),
    Expanded(
      child: Column(
        children: [
          const TitleBar(),
          Expanded(
            child: Material(
              color: AppColors.background,
              child: Navigator(key: _contentNavigator, onGenerateRoute: _onGenerateRoute),
            ),
          ),
        ],
      ),
    ),
  ],
)
```

Construcción perezosa de secciones:

```dart
for (final section in AppSection.values)
  _visited.contains(section) ? _screenFor(section) : const SizedBox.shrink(),
```

## Problemas encontrados

1. **El rail no tenía `Overlay`.** El diseño anterior ponía el shell **encima** del Navigator
   (vía `MaterialApp.builder`). El `Overlay` lo crea el Navigator, así que los `Tooltip` del
   rail fallaban con *"No Overlay widget found"* — y lo mismo pasaría con menús y diálogos
   lanzados desde el rail.

   **Solución:** el shell pasó a ser la **ruta raíz**, y el área de contenido tiene su **propio
   `Navigator`**. Eso da tres cosas:
   - los detalles (parte 4.3) se apilan en el Navigator anidado → el rail y la barra siguen
     visibles;
   - el chrome queda bajo un `Overlay` → tooltips y menús funcionan;
   - los diálogos siguen cubriendo toda la ventana, porque `showDialog` usa el navigator raíz
     por defecto (`useRootNavigator: true`).

2. **Las secciones no tenían `Material` ancestro.** Antes lo aportaba el `Scaffold` de
   `HomeScreen`. Se agregó un `Material` en el área de contenido del shell, que además sirve de
   base para las rutas apiladas.

## Notas

- **Renderizado de texto:** Flutter **no usa ClearType**. Rasteriza con Skia/Impeller en
  **escala de grises**; en Windows usa DirectWrite solo para localizar fuentes, no para
  rasterizarlas. Es por diseño (el subpíxel se rompe con capas rotadas/escaladas o con
  opacidad) y no hay switch soportado. Consecuencia: a tamaños chicos el texto se ve un poco
  más suave que en una app Win32 nativa.

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ **26 tests** |
| `flutter build windows` | ✅ |
| Ejecución real | ✅ rail + navegación entre secciones (capturas) |

El test de widget verifica: arranca en Home, clic en Library → Library visible y Home offstage,
clic en Settings → Settings visible.

## Pendiente / Próximos pasos

1. **4.2 — Library**: grilla de pósters con `library_items` de Nuvio, chips `All/Movies/Shows`.
2. **4.3 — Detail**: meta del addon + lista de episodios (ahí entra `NavigatorPopHandler` y un
   botón de volver, que hoy no hacen falta porque no hay pantallas apiladas).
3. **4.4 — Streams**, **4.5 — Player integrado**, **4.6 — Home**, **4.7 — Search**,
   **4.8 — Settings**.
4. **Avatar real**: el rail usa un placeholder; falta conectarlo al perfil de Nuvio.
