# 0005 — Cliente del protocolo Stremio (Fase 2)

- **Fecha:** 2026-10-08
- **Sesión:** 0005
- **Estado:** ✅ hecho (Fase 2 completa)

## Objetivo

Implementar el cliente del protocolo de addons de Stremio (**manifest, catalog, meta,
stream**), según la Fase 2 del roadmap, como capa de datos pura (sin UI).

## Decisiones tomadas

- **Dependencia:** `http ^1.6.0` para las requests.
- **Modelos en `domain/`** (Dart puro, sin red ni Flutter) y **cliente HTTP en `data/addons/`**,
  respetando la regla de dependencias del README (`ui → domain → data`).
- Alcance exacto del roadmap: **manifest, catalog, meta, stream**. `subtitles` queda afuera.
- **Decodificación UTF-8 explícita** (`utf8.decode(response.bodyBytes)`): `http` cae a latin1
  cuando la respuesta no declara charset, y los addons reales devuelven metadata no-ASCII.
- **Parseo defensivo:** los payloads son de terceros, así que un campo raro degrada a
  `null`/vacío en vez de tirar todo el response.
- Errores con una excepción propia: **`StremioAddonException`** (red, HTTP ≠ 200, JSON
  inválido, forma inesperada).
- **Descartado: indentación de 4 espacios.** Se evaluó (por legibilidad) y se rechazó:
  `dart format` tiene la indentación de 2 espacios *hardcodeada* y **no es configurable** (ni
  por CLI, ni `analysis_options.yaml`, ni `.editorconfig`) — verificado empíricamente. Lo que
  sí es configurable, y centralizado en el repo, es `formatter.page_width`.

## Qué se hizo

1. `flutter pub add http`.
2. Se crearon los modelos de dominio: `AddonManifest` (+ `AddonResource`, `AddonCatalog`,
   `AddonCatalogExtra`), `MetaPreview`, `MetaDetail` (+ `MetaVideo`) y `Stream`
   (+ `StreamBehaviorHints`).
3. Se creó `StremioAddonClient` con `fetchManifest`, `fetchCatalog`, `fetchMeta` y
   `fetchStreams`, más el armado de URLs (incluido el segmento `extra` codificado).
4. Se escribieron tests: parseo de modelos + cliente con `MockClient` de `package:http`.
5. Se verificó contra addons públicos reales (script temporal, ya borrado).

## Archivos tocados

| Archivo | Cambio |
| --- | --- |
| `pubspec.yaml` / `pubspec.lock` | **cambiado** — `http ^1.6.0` |
| `lib/domain/addons/addon_manifest.dart` | **nuevo** — `AddonManifest`, `AddonResource`, `AddonCatalog`(+`Extra`) |
| `lib/domain/addons/meta.dart` | **nuevo** — `MetaPreview`, `MetaDetail`, `MetaVideo` |
| `lib/domain/addons/stream.dart` | **nuevo** — `Stream`, `StreamBehaviorHints` |
| `lib/domain/addons/json_utils.dart` | **nuevo** — coerción defensiva de JSON |
| `lib/data/addons/stremio_addon_client.dart` | **nuevo** — el cliente |
| `lib/data/addons/.gitkeep` | **borrado** — el directorio ya tiene contenido |
| `test/domain/addons/addon_manifest_test.dart` | **nuevo** |
| `test/data/addons/stremio_addon_client_test.dart` | **nuevo** |

## Código relevante

El cliente (una instancia = un addon):

```dart
final client = StremioAddonClient(baseUrl: 'https://v3-cinemeta.strem.io');

final manifest = await client.fetchManifest();
final items = await client.fetchCatalog(type: 'movie', id: 'top');
final meta = await client.fetchMeta(type: 'movie', id: 'tt1254207');
final streams = await client.fetchStreams(type: 'movie', id: 'tt1254207');
```

Armado del segmento `extra` del catálogo (`search=batman&skip=0` → un solo segmento
codificado):

```dart
final encoded = extra.entries
    .map((entry) => '${entry.key}=${entry.value}')
    .join('&');
return Uri.parse('$path/${Uri.encodeComponent(encoded)}.json');
```

Decodificación UTF-8 explícita:

```dart
// `http` falls back to latin1 when the response has no charset, which mangles
// non-ASCII metadata.
decoded = jsonDecode(utf8.decode(response.bodyBytes));
```

## Problemas encontrados

Ninguno bloqueante. Dos decisiones que vale la pena recordar:

1. **UTF-8.** `http` usa latin1 si la respuesta no declara charset. Se confirmó con datos
   reales: los títulos de Torrentio traen emoji (`👤 💾 ⚙️`), que con el default saldrían como
   mojibake.
2. **Forma del JSON.** Los `resources` del manifest pueden venir como string (`"stream"`) o
   como objeto, y los campos numéricos a veces son strings (`"7.9"`). Todo eso se cubre con
   los helpers de `json_utils.dart` y hay tests para cada caso.

## Verificación

| Prueba | Resultado |
| --- | --- |
| `flutter analyze` | ✅ Sin issues |
| `flutter test` | ✅ **16 tests** |
| **Cinemeta** (real) | manifest `Cinemeta v3.0.14`; `movie/top` → **48 items**; meta `Big Buck Bunny` |
| **Torrentio** (real) | manifest `Torrentio v0.0.15`; **`streams` → 5** con nombres/títulos reales |
| Rutas de error | ✅ 404 (Cinemeta no sirve streams, Torrentio no sirve meta) y 500 (Torrentio no sirve catalog) → `StremioAddonException` |
| UTF-8 real | ✅ emoji y acentos correctos en la respuesta de Torrentio |

## Pendiente / Próximos pasos

1. **El cliente no se usa todavía desde la UI.** Por la arquitectura, la UI nunca lo llama
   directo; la UI de producto es la **Fase 4**. Hoy solo se ejercita vía tests.
2. **No es probable a mano desde la app.** Alternativas: una herramienta CLI en `tool/` para
   ver datos reales, o adelantar una UI mínima de catálogo (Fase 4) que conecte
   catálogo → meta → streams → reproductor.
3. **`subtitles`** no está implementado (fuera del alcance de la Fase 2).
4. **Fase 3:** backend de Nuvio (`lib/data/backend/` → `BackendProvider`).
