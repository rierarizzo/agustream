# 0001 — Setup del proyecto y decisiones de arquitectura

- **Fecha:** 2026-10-08
- **Sesión:** 0001
- **Estado:** 🟡 parcial (decisiones cerradas; falta instalar el toolchain)

## Objetivo

Definir el producto, el stack y las convenciones del repositorio antes de escribir código.

## Decisiones tomadas

### Producto

- Un **cliente de escritorio de Nuvio, Windows-first**: login al backend de Nuvio, addons
  de Stremio y reproducción con libmpv.
- **Complementario a Nuvio**, no un reemplazo.

### Stack

| Capa | Elegido | Motivo |
| --- | --- | --- |
| UI / lenguaje | **Flutter + Dart** | Una sola base de código para W11/Linux/móvil, UI declarativa, hot reload. |
| Video | **`media_kit` (libmpv)** | libmpv embebido vía textura de GPU, muchos formatos, decodificación por hardware. |
| Backend | **API de Nuvio** (`api.nuvio.tv`, Supabase) | Reutilizar login/biblioteca/progreso. |
| Addons | Protocolo **Stremio** (HTTP/JSON) | Estándar abierto y documentado. |
| Debrid | Fase 2 | La v1 usa addons con debrid configurado (URLs HTTPS directas). |

### Entorno

- Desarrollo en **Windows 11 nativo**, **NO WSL2** (los builds de escritorio de Windows
  requieren MSVC + Windows SDK).

## Qué se hizo

1. Se cerró el alcance del producto y el stack (ver arriba).
2. Se revisó el entorno:
   - ✅ `winget`, `git`, VS Code, 110 GB libres.
   - ❌ Faltaba el **Flutter SDK**.
   - ❌ Faltaban los **Visual Studio 2022 Build Tools** (workload de C++).
3. Se creó la documentación y configuración del repositorio:
   - `AGENTS.md` — regla de session logs.
   - `README.md` — detalles del proyecto.
   - `.gitignore` — Flutter/Dart + IDEs + SO.
   - `docs/sessions/0001_setup_project_ES.md` — este archivo.

## Archivos tocados

- `AGENTS.md` — **nuevo**.
- `README.md` — **nuevo**.
- `.gitignore` — **nuevo**.
- `docs/sessions/0001_setup_project_ES.md` — **nuevo**.

## Código relevante

Todavía **no hay código de la app**. Solo documentación y configuración del repositorio.

## Problemas encontrados

Ninguno.

## Pendiente / Próximos pasos

1. Instalar el toolchain (Windows nativo):

   ```bash
   winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
   git clone -b stable https://github.com/flutter/flutter.git C:/src/flutter
   # agregar C:\src\flutter\bin al PATH, y luego:
   flutter doctor -v
   flutter config --enable-windows-desktop
   ```

2. Crear el proyecto Flutter **Windows-only** (`agus_desktop`).
3. Fase 1: integrar `media_kit` y reproducir un video local y una URL directa.
4. Registrar todo en `docs/sessions/0002_*.md`.
