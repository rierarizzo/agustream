# 0011 — Detail (parte 4.3 de la Fase 4)

## Objetivo

Tercera parte de la Fase 4 (Product UI): la pantalla de **detalle** de un título,
abierta desde la biblioteca. Sigue las capturas de referencia `detail1`/`detail2`:
hero a sangre, cast, crew, details, episodios y "More like this".

## Qué se hizo

### La pantalla

`DetailScreen` se abre al tocar un póster de la biblioteca y se apila **dentro
del Navigator del contenido**, así el riel y la barra de título quedan visibles.

- **Hero**: backdrop a sangre con dos degradados (horizontal y vertical), póster,
  título (logo si viene, si no texto), fila de metadatos (año • duración • ★),
  chips de género, sinopsis y acciones.
- **Secciones**: `Cast`, `Crew`, `Details` (Released/Country), `More like this`
  (con flechas) y `Episodes` para series (dropdown de temporada + carrusel).
- **Fallback inmediato**: el `LibraryItem` se renderiza al instante y el
  `MetaDetail` lo enriquece cuando llega, así la pantalla nunca queda vacía.
- **Botón Back** en el hero: la referencia no lo muestra, pero con el riel fijo
  no había otra forma de volver.
- **Acciones**: `Play` y los episodios muestran "Streams arrive in part 4.4";
  `Trailer`, visto, favorito y rate quedan **deshabilitados** con tooltip (no hay
  store local ni endpoints de escritura todavía).

### El hallazgo clave: de dónde sale el metadata

El primer intento consultaba solo `library_items.addon_base_url`. Con una cuenta
real **no aparecía ninguna sección**: ese campo puede ser `null` o apuntar al
addon de *streams*, que no sirve `meta`.

Revisando el código de Nuvio (`NuvioMobile`) y su schema self-host
(`GET /rest/v1/` da el OpenAPI de PostgREST) quedó claro cómo funciona:

- El metadata **no depende de un addon fijo**: se busca `meta` entre **todos los
  addons habilitados** de la cuenta (tabla `addons`), en orden, y el primero que
  responde gana.
- **Nada de proveedores incrustados**: no hay fallback a Cinemeta en el código.
  Si la cuenta no tiene ningún addon que sirva `meta`, no hay metadata. Nuvio sí
  instala Cinemeta por defecto, pero eso es de la cuenta, no del cliente.
- **No se prioriza por `addon_base_url`**: la metadata sale siempre del primer
  addon de la lista activa, no del addon con el que se agregó el título.
- Los addons se guardan como **URL de manifest** (`.../manifest.json`), y los
  recursos cuelgan de la base sin `/manifest.json`.

Algunos addons devuelven `cast` como **lista de strings** y los episodios usan
`name` (no `title`), cosas que el parser no manejaba.

El caso que faltaba era **AIOMetadata** (lo que se usa dentro de AIOStreams):
guarda los créditos ricos en el objeto **no estándar** `app_extras` —
`app_extras.cast` (con `photo` y `character`), `app_extras.directors` y
`app_extras.writers`—, y Nuvio lo lee así (`MetaDetailsParser`). El parser solo
miraba `cast`/`director`/`writer` de nivel superior, por eso aparecía el crew
(que sí viene arriba) y no el cast. Ahora `MetaDetail` fusiona `app_extras` con
el nivel superior, sin duplicados y con `app_extras` ganando (conserva la foto).

Además, el protocolo marca `cast`/`director`/`writer` como deprecados y propone
`links` (`{name, category, url}`). También se leen sus categorías
`actor`/`cast`, `director(s)` y `writer(s)`/`screenplay` —AIOMetadata usa
`Cast`/`Directors`/`Writers`—. El orden de prioridad es:
`app_extras` → nivel superior → `links`.

## Archivos

### Nuevos

| Archivo | Qué |
| --- | --- |
| `lib/domain/addons/metadata_repository.dart` | Interfaz `MetadataRepository` |
| `lib/data/addons/stremio_metadata_repository.dart` | Resuelve `meta`/catálogos por addon |
| `lib/domain/backend/addon.dart` | Modelo `Addon` |
| `lib/domain/backend/addon_repository.dart` | Interfaz `AddonRepository` |
| `lib/data/backend/nuvio_addon_repository.dart` | Lee `addons` por perfil |
| `lib/ui/detail/detail_controller.dart` | Carga y fusiona item + metadata |
| `lib/ui/detail/detail_screen.dart` | Pantalla + hero |
| `lib/ui/detail/detail_sections.dart` | Cast, crew, details, similar, episodios |
| `test/domain/addons/meta_test.dart` | Parseo de cast/crew/detalle |
| `test/data/addons/stremio_metadata_repository_test.dart` | Candidatos y fallback |
| `test/ui/detail_screen_test.dart` | 4 tests de la pantalla |

### Modificados

| Archivo | Cambio |
| --- | --- |
| `lib/domain/addons/meta.dart` | `cast`/`director`/`writer`/`released`/`country`; `cast` string u objeto; título de episodio desde `name` |
| `lib/data/addons/stremio_addon_client.dart` | `normalizeAddonBaseUrl` (quita `/manifest.json` y query) |
| `lib/app/services/app_services.dart` | Expone `MetadataRepository` |
| `lib/app/app.dart` | Pasa el repositorio de metadata |
| `lib/main.dart` | Construye `StremioMetadataRepository` + `NuvioAddonRepository` |
| `lib/ui/screens/library_screen.dart` | `_open` navega al detalle |
| `test/support/fake_repositories.dart` | `FakeMetadataRepository` + `FakeAddonRepository` |
| `test/data/backend/nuvio_repositories_test.dart` | 2 tests de `addons` |
| `test/ui/library_screen_test.dart` | Navegación al detalle |
| `test/ui/profile_picker_test.dart`, `test/widget_test.dart` | Nuevo parámetro `metadata` |

## Verificación

- `flutter analyze` sin problemas.
- `flutter test`: **64 tests** (eran 44).
- `flutter build windows --debug` correcto.
- Verificado con una cuenta real (AIOStreams self-hosted): aparecen crew, details
  y episodios. El cast necesitó el parseo de `app_extras` (ver arriba).

## Limitaciones conocidas

1. **Fotos del reparto**: dependen del addon. AIOMetadata las trae
   (`app_extras.cast[].photo`); Cinemeta no, y ahí los avatares usan la inicial.
2. **"More like this"**: usa el catálogo "Popular" por género del addon de
   metadata; no es la fila TMDB/Trakt de Nuvio.
3. **Config en el query del manifest**: `normalizeAddonBaseUrl` descarta el query
   string. Nuvio lo reengancha a cada request de recurso; si un addon lleva la
   configuración ahí, `meta` podría fallar. Con AIOStreams no fue el caso.
4. **Escrituras y trailer**: deshabilitados; dependen del store local y de
   `url_launcher`.

## Pendiente

1. **4.4 Streams**: lista de fuentes (`fetchStreams`) conectada al botón Play y a
   los episodios.
2. **4.5 Player integrado**, 4.6 Home, 4.7 Search, 4.8 Settings.
3. Ajustes de UI/UX del detalle (quedaron anotados para después).
4. Pendientes de 0010: store local + escrituras, selector de perfil en el riel,
   persistir la sesión.
