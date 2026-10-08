# 0002 — Chequeo del toolchain y scaffold de Flutter

- **Fecha:** 2026-10-08
- **Sesión:** 0002
- **Estado:** ✅ hecho (Fase 0 completa)

## Objetivo

Tener un toolchain funcional y un proyecto Flutter Windows-only que corra.

## Decisiones tomadas

- Nombre del paquete Dart: **`agustream`** (una sola palabra; guiones y mayúsculas no son
  válidos).
- **Windows-only** por ahora: `--platforms=windows`.
- `pubspec.lock` **se versiona** (esto es una app, no una librería).
- Los session logs se escriben **solo cuando se piden explícitamente**.

## Qué se hizo

1. Se verificó el toolchain con `flutter doctor -v`:
   - **Flutter 3.47.6** (Dart 3.13.5), stable, en `C:\src\flutter`.
   - **Visual Studio Build Tools 2022** + Windows SDK `10.0.26100`.
   - Windows 11 detectado. Las filas de Android y Chrome corresponden a otros targets y se
     ignoraron (la app es de escritorio Windows).
2. Se creó el proyecto dentro del repo existente:

   ```bash
   flutter create --project-name agustream --org com.agus --platforms=windows .
   ```

3. Se confirmó que corre con `flutter run -d windows`.
4. Se ajustó la configuración:
   - `.gitignore`: se quitó la regla de `pubspec.lock` para versionar el lockfile.
   - `pubspec.yaml`: se puso una `description` real.
5. Se respaldaron los docs previos al scaffold en
   `C:\Users\keneth\projects\agus-desktop-docs-backup`. `flutter create` **no** sobrescribió
   el `README.md` ni el `.gitignore` existentes.

## Nombres generados

| Dónde | Valor |
| --- | --- |
| Paquete Dart (`pubspec.yaml`) | `agustream` |
| Binario / CMake (`BINARY_NAME`) | `agustream` |
| Título de ventana (`main.cpp`) | `agustream` |

## Archivos tocados

- `pubspec.yaml` — **cambiado**. `description`.
- `.gitignore` — **cambiado**. Se quitó `pubspec.lock`.
- `lib/main.dart`, `test/widget_test.dart`, `analysis_options.yaml`, `.metadata`,
  `pubspec.lock`, `windows/**`, `agustream.iml` — **nuevos** (generados por `flutter create`).
- `docs/sessions/0002_flutter_scaffold_ES.md` — **nuevo** (este archivo).

## Código relevante

La app sigue siendo el contador por defecto de Flutter (`lib/main.dart`). Aún no hay código
propio.

## Problemas encontrados

Ninguno.

## Pendiente / Próximos pasos

1. **Commit** inicial de git (baseline).
2. Limpiar `lib/main.dart` y crear el esqueleto de capas de `lib/`
   (`app/`, `ui/`, `domain/`, `data/`, `services/`).
3. Fase 1: agregar **`media_kit`** y reproducir un archivo local y una URL directa.
