# 0013 — Home (parte 4.6 de la Fase 4)

## Objetivo

Quinta parte de la Fase 4 (Product UI): la sección **Home**, con un hero
destacado, "Continue watching" y filas de catálogos de los addons, más el
catálogo completo con paginación.

## Qué se hizo

### Riel

- Se quitó la sección **History** (`AppSection`). Quedan Home, Discover, Search,
  Library, Calendar y Settings.

### Datos

- `CatalogRepository` (domain) + `StremioCatalogRepository` (data): lista los
  catálogos leyendo los **manifests de los addons habilitados** y trae sus ítems.
  Cero acoplamiento a un proveedor.

### Home

- `HomeController`: compone
  - **Continue watching**: join de `progress` + `library`, solo títulos
    empezados y no terminados, ordenados por `lastWatched`.
  - **Filas de catálogos**: los primeros catálogos (hasta 5), con hasta 20
    ítems cada uno. El **hero** sale de la primera fila.
- `HomeScreen`: **hero carrusel** (backdrop, logo/título, metadatos, sinopsis,
  Play + More info, dots), **Continue watching** (cards 16:9 con barra de
  progreso) y **filas de pósters**. Reusa `MetaPosterCard`.
- `LibraryItem.fromPreview`: un ítem de catálogo abre el mismo `DetailScreen`.
- Helper compartido `openStreamsDialog` / `playStream` (lo usan Home y el
  detalle).

### Catálogo completo + paginación

- Cada fila tiene un botón **"See all"** que abre `CatalogScreen`: grilla del
  catálogo con **paginación** (`skip`), auto-carga hasta llenar la vista y
  guarda anti-duplicados.

## El bug de paginación (cliente de addons)

La paginación no funcionaba. El problema estaba en
`StremioAddonClient._catalogUri`: codificaba **todo el segmento** de extras con
`Uri.encodeComponent`, generando `skip%3D20`. AIOStreams (y Stremio/Nuvio) **no
decodifican** ese segmento: esperan los separadores `=` y `&` **crudos** y solo
los **valores** codificados. Verificado contra un addon real:

| URL | Resultado |
| --- | --- |
| `…/skip=20.json` | página 2 ✅ |
| `…/skip%3D20.json` | página 1 (ignora `skip`) ❌ |
| `…/search=Batman%20Begins.json` | funciona (valor codificado) ✅ |

El fix afecta a **cualquier** request de catálogo con extras: paginación, el
filtro por género de "More like this" y el futuro Search.

## Archivos

**Nuevos**

| Archivo | Qué |
| --- | --- |
| `lib/domain/addons/catalog_repository.dart` | `CatalogRepository` + `CatalogRef` |
| `lib/data/addons/stremio_catalog_repository.dart` | Catálogos desde los manifests |
| `lib/ui/home/home_controller.dart` | Continue watching + filas |
| `lib/ui/home/home_screen.dart` | Hero + filas |
| `lib/ui/catalog/catalog_controller.dart` | Paginación del catálogo |
| `lib/ui/catalog/catalog_screen.dart` | Grilla completa |
| `lib/ui/widgets/meta_poster_card.dart` | Card de `MetaPreview` |
| `lib/ui/streams/open_streams.dart` | Helper compartido de streams |
| `test/data/addons/stremio_catalog_repository_test.dart` | 3 tests |
| `test/ui/home_screen_test.dart` | 4 tests |
| `test/ui/catalog_screen_test.dart` | 3 tests |

**Modificados**

| Archivo | Cambio |
| --- | --- |
| `lib/data/addons/stremio_addon_client.dart` | Extras crudos (`=`/`&`), solo valores codificados |
| `lib/app/shell/app_section.dart` | History fuera |
| `lib/app/shell/section_host.dart` | home → `HomeScreen` |
| `lib/domain/backend/library_item.dart` | `LibraryItem.fromPreview` |
| `lib/ui/detail/detail_screen.dart` | Usa el helper compartido |
| `lib/app/services/app_services.dart`, `app.dart`, `main.dart` | Exponen `CatalogRepository` |
| `test/support/fake_repositories.dart` | `FakeCatalogRepository` |
| `test/ui/*`, `test/widget_test.dart` | Nuevo parámetro `catalogs` |

## Verificación

- `flutter analyze` sin problemas.
- `flutter test`: **85 tests** (eran 74).
- `flutter build windows --debug` correcto.
- Paginación verificada contra el addon real (AIOStreams).

## Limitaciones conocidas

1. Las filas salen de los **catálogos de los addons** (primeros 5), no de
   `home_catalog_settings` de Nuvio. Queda como 4.6b si se quiere el Home curado.
2. El hero no auto-avanza (swipe + dots).
3. Home lee library/progress al arrancar (es el default): la biblioteca se lee
   dos veces (Home + Library).
4. Catálogos con extras **requeridos** (p. ej. `search`) no aparecen como fila
   porque no se les pasa el extra; se resolverán en Search/Discover.

## Pendiente

1. **4.5 Player integrado** (diferido al final de la fase).
2. **4.7 Search**, **4.8 Settings**.
3. **Discover** y **Calendar** (secciones placeholder).
4. 4.6b: Home curado desde el backend (`home_catalog_settings` + `collections`).
5. Deuda de desacoplamiento para una segunda cuenta (Stremio/propia): generalizar
   `AccountRepository`, agregar **escrituras** (favorites/watched/continue
   watching), definir "watched" y un punto de composición.
6. Pulido de UI/UX y pendientes de 0010 (store local, selector de perfil, sesión).
