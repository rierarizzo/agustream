# 0012 — Streams (parte 4.4 de la Fase 4)

## Objetivo

Cuarta parte de la Fase 4 (Product UI): la **selección de fuentes**. El botón
**Play** (y los episodios, en series) abre un selector de streams y reproduce el
elegido.

## Qué se hizo

### Datos

- `StreamRepository` (interfaz en `domain/`) + `StreamGroup` (addon + streams).
- `StremioStreamRepository` (en `data/`): a diferencia del metadata (que es
  "gana el primero"), los streams se **agregan** de **todos** los addons
  habilitados, en paralelo, agrupados por addon. Un addon que falla o no tiene
  streams para el título se omite.

### UI

- `StreamsController`: carga, estados y conteo total.
- `StreamsDialog`: modal **centrado** (no bottom sheet), siguiendo la referencia
  `streams.png`:
  - Header con el **backdrop** del título, nombre, año y `N versions`, más
    refresh y cerrar.
  - **Campo de filtro** ("Filter versions") que filtra por texto.
  - **Cards** por stream: botón de play circular, `name` en negrita,
    `description` debajo (multi-línea preservada), chip de tamaño y botón de
    copiar link.
  - Estados de carga, error y vacío.

### Enganche

- `AppServices`/`App`/`main` exponen el `StreamRepository` (reusa el mismo
  `NuvioAddonRepository` que el metadata).
- En el detalle: **Play** (película = `contentId`; serie = primer episodio) y
  **tap en episodio** (`video.id`, tipo `series`) abren el diálogo.
- Al elegir un stream **directo** → abre el `PlayerScreen` actual (**stopgap**;
  el player integrado es 4.5). Torrent/externo → mensaje.

## El hallazgo clave: cómo se consume el formato

La referencia muestra cards ricas (calidad, HDR/audio, tamaño, idiomas). La
tentación es parsear heurísticamente, pero no hace falta:

- **AIOStreams** arma el texto con un **formatter configurable** y lo emite en
  **`stream.name`** y **`stream.description`** (multi-línea, con emojis). El
  `name` puede traer saltos de línea.
- **Nuvio no parsea**: su `StreamCard` renderiza `name` + `description` tal cual
  (`streamSubtitle = description`), más un chip de tamaño y badges opcionales.
- **Nuestro bug:** el modelo `Stream` **no leía `description`**, así que toda esa
  info se perdía. Se agregó el campo y se renderiza el texto **como viene**, que
  es lo correcto y client-agnóstico.

## Archivos

### Nuevos

| Archivo | Qué |
| --- | --- |
| `lib/domain/addons/stream_repository.dart` | `StreamRepository` + `StreamGroup` |
| `lib/data/addons/stremio_stream_repository.dart` | Agrega streams por addon |
| `lib/ui/streams/streams_controller.dart` | Estado del selector |
| `lib/ui/streams/streams_dialog.dart` | El modal + cards |
| `test/data/addons/stremio_stream_repository_test.dart` | 3 tests |
| `test/domain/addons/stream_test.dart` | `description` del stream |
| `test/ui/streams_dialog_test.dart` | 5 tests del diálogo |

### Modificados

| Archivo | Cambio |
| --- | --- |
| `lib/domain/addons/stream.dart` | Parsea `description` |
| `lib/app/services/app_services.dart` | Expone `StreamRepository` |
| `lib/app/app.dart` | Pasa el repositorio de streams |
| `lib/main.dart` | Construye `StremioStreamRepository` (reusa `NuvioAddonRepository`) |
| `lib/ui/detail/detail_screen.dart` | Play y episodios abren el diálogo; reproduce el elegido |
| `lib/ui/detail/detail_controller.dart` | Getter `year` para el header |
| `test/support/fake_repositories.dart` | `FakeStreamRepository` |
| `test/ui/*`, `test/widget_test.dart` | Nuevo parámetro `streams` |

## Verificación

- `flutter analyze` sin problemas.
- `flutter test`: **74 tests** (eran 64).
- `flutter build windows --debug` correcto.

## Limitaciones conocidas

1. **Player**: se abre el `PlayerScreen` de desarrollo; el **player integrado es
   4.5**.
2. **Torrent/externo**: se listan pero no se reproducen todavía (`infoHash`,
   `externalUrl`).
3. **Sin badges configurables**: Nuvio permite importar reglas de badges con
   imágenes; no está implementado.
4. **Botón "Details"** de la referencia: omitido por ahora.
5. `_play` en series usa el primer episodio de la lista (sin ordenar aún).

## Pendiente

1. **4.5 Player integrado**: conectar el stream elegido al player dentro de la
   app (progreso, subtítulos, fullscreen).
2. **4.6 Home**, 4.7 Search, 4.8 Settings.
3. Pulido de UI/UX (tabs superiores, title bar full-bleed, performance de
   imágenes) y pendientes de 0010 (store local, selector de perfil, sesión).
