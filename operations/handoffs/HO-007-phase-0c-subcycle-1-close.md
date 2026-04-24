# Standard Handoff

document_id: HO-007
from_agent: Handoff Manager
  (ciclo producido por: Android Share Intent Specialist + QA Auditor)
to_agent: Android Share Intent Specialist (T-0c-002 + T-0c-003 en paralelo)
status: ready_for_execution
phase: 0c
date: 2026-04-24
cycle: Cierre del sub-ciclo 1 de Fase 0c (T-0c-000 + T-0c-001)
closes: T-0c-000 (build pipeline Android), T-0c-001 (backend Android)
opens: T-0c-002 (relay bidireccional) + T-0c-003 (galería Android) — en paralelo

---

## Objetivo

Cerrar formalmente el sub-ciclo de fundamentos de Fase 0c (build pipeline
validado + backend Android operativo) y habilitar el inicio en paralelo de
T-0c-002 y T-0c-003, las dos ramas de producto de Fase 0c.

---

## Módulos Completados en Este Sub-Ciclo

Toda la implementación está en el repo del producto FlowWeaver
(`https://github.com/EstefJMDev/FlowWeaver`, branch `main`).

| Tarea | Módulos / Archivos principales | Commit | Estado |
| --- | --- | --- | --- |
| T-0c-000 — Build pipeline | Cargo.toml (deps condicionales), storage.rs (cfg Android), BuildTask.kt (workaround symlinks) | f0385c5 (EquipoEnjambre) / d219a69 (FlowWeaver) | COMPLETADO |
| T-0c-001 — Backend Android | commands.rs (`get_mobile_resources`, `MobileResource`, `CategoryGroup`), lib.rs (registro) | a45ad65 (FlowWeaver) | COMPLETADO |

### T-0c-000 — Build Pipeline Validado

El APK debug `app-arm64-debug.apk` se genera para `aarch64-linux-android`.
SQLCipher falló por incompatibilidad del Configure script de OpenSSL en
cross-compilación Windows → Android. Fallback pre-autorizado activado:
SQLite bundled + cifrado de campos a nivel de campo via `crypto.rs`.

Dos workarounds activos en este entorno Windows:
1. Symlinks: la `.so` se copia manualmente a `jniLibs/arm64-v8a/`
2. Target único aarch64 en Gradle (`-PtargetList=aarch64`)

Procedimiento de rebuild documentado en `arch-note-T-0c-000-milestone0-result.md`.

### T-0c-001 — Backend Android Operativo

El pipeline del Share Intent ahora persiste localmente:

```
Share Intent → captura → cifra url/title → INSERT SQLite Android
                              ↓
                     classify_domain() → category (en claro)
                              ↓
                      group_by_category() → CategoryGroup[]
                              ↓
                    get_mobile_resources → frontend (title descifrado)
```

Classifier y Grouper son el mismo crate Rust compilado para Android.
D8 operativo: mismo output para mismo input en Android y desktop.

---

## Cobertura de Tests al Cierre del Sub-Ciclo

| Módulo | Tests | Estado |
| --- | --- | --- |
| classifier.rs | 2 | OK |
| grouper.rs | 3 | OK |
| session_builder.rs | 2 | OK |
| episode_detector.rs | 4 | OK |
| storage.rs | 3 | OK |
| **Total** | **14/14** | **PASSING** |

Sin regresiones. T-0c-001 añade el comando Android sobre la base de
storage.rs sin modificar la suite de tests existente.

---

## Invariantes Verificados al Cierre del Sub-Ciclo

| Invariante | Estado |
| --- | --- |
| D1 — url/title cifrados | RESPETADO — cifrado a nivel de campo antes del INSERT (ver riesgo R-0c-001) |
| D8 — Classifier determinístico sin LLM | RESPETADO — mismo crate, mismo output en Android y desktop |
| D9 — Sin observer activo | RESPETADO — T-0c-001 solo añade persistencia al Share Intent; no hay watcher ni polling |
| D20 — App Android como cliente completo | EN PROGRESO — T-0c-001 es el núcleo; T-0c-002 y T-0c-003 completan D20 |
| AR-0c-001 A — Idempotencia (device_id, event_id) | PENDIENTE — a implementar en T-0c-002 |
| AR-0c-001 B — Fallback sin escalar | APLICADO — activado dentro del derecho de decisión del implementador |

---

## Revisiones Completadas en Este Sub-Ciclo

| Documento | Agente | Resultado |
| --- | --- | --- |
| arch-note-T-0c-000-milestone0-result.md | Android Share Intent Specialist | COMPLETADO |
| qa-review-0c-T0c-000-T0c-001.md | QA Auditor | APROBADO con observación O-001 |

---

## Riesgos Abiertos Heredados

| ID | Riesgo | Severidad | Estado | Acción requerida |
| --- | --- | --- | --- | --- |
| R-0c-001 | Cifrado de campo XOR vs AES-256-GCM autorizado en AR-0c-001 | MEDIA | ABIERTO | El Android Share Intent Specialist confirma si AES-256-GCM via Android Keystore está ya implementado en T-0c-001 o lo implementa antes del gate de Fase 0c. No bloquea T-0c-002 ni T-0c-003. |
| R12 WATCH | Pattern Detector ≠ Episode Detector | WATCH | ACTIVO | Declarar explícitamente en T-0c-002 y T-0c-003 que ninguno de estos módulos aparece en Android. |

---

## Lo Que Abre Este Handoff

### T-0c-002 — Relay Bidireccional (desbloqueada)

**Owner**: Android Share Intent Specialist (lado Android) +
            Desktop Tauri Shell Specialist (lado desktop)

**Dependencia satisfecha**: T-0c-001 completado — el backend Android puede
persistir los eventos recibidos del desktop.

**Contrato arquitectónico ya resuelto** en AR-0c-001 sección A:

```
flowweaver-relay/
  ├── android-<device_id>/    ← escribe Android, lee Desktop
  │     ├── pending/
  │     └── acked/
  └── desktop-<device_id>/    ← escribe Desktop, lee Android (NUEVO en 0c)
        ├── pending/
        └── acked/
```

Clave de idempotencia: `(device_id, event_id)`.
Regla de no-autoconsumo: cada dispositivo solo lee del namespace del otro.

**El implementador debe leer antes de empezar**:
- `operations/backlogs/backlog-phase-0c.md` — sección T-0c-002 (ACs completos)
- `operations/architecture-reviews/AR-0c-001-phase-0c-contracts.md` — sección A

### T-0c-003 — Galería Android (desbloqueada, en paralelo con T-0c-002)

**Owner**: Android Share Intent Specialist

**Dependencia directa**: T-0c-001 completado — `get_mobile_resources` ya
devuelve los datos que la galería necesita renderizar.

**Dependencia indirecta**: T-0c-002 — la galería debe mostrar también los
recursos recibidos del desktop vía relay; puede desarrollarse antes de que
T-0c-002 esté completo, pero el criterio "recursos del desktop aparecen en
galería" requiere T-0c-002.

**La galería es deliberadamente simple** (OD-005 lo protege):

```
Pantalla principal → categorías con recuento → tap → lista de recursos → tap → navegador
```

Sin Panel B, sin Episode Detector, sin workspace narrativo.

**El implementador debe leer antes de empezar**:
- `operations/backlogs/backlog-phase-0c.md` — sección T-0c-003 (wireframe + ACs)

---

## Blockers

**Ninguno para T-0c-002 ni T-0c-003.**

R-0c-001 (cifrado XOR vs AES-256-GCM) no bloquea el arranque de ninguna
de las dos tareas. Sí bloquea el gate de salida de Fase 0c si no se resuelve.

---

## Restricciones Explícitas para el Siguiente Ciclo

1. **D9 activo**: la galería no puede introducir ningún nuevo observer activo
   (sin polling, sin FS Watcher, sin Accessibility). Lee de SQLite local. 
2. **R12 WATCH**: el implementador debe declarar explícitamente en el TS o nota
   de T-0c-003 que la galería no incorpora Episode Detector ni Pattern Detector.
3. **OD-005 prohibiciones**: Panel B, Session Builder, Pattern Detector, sync
   en tiempo real siguen prohibidos en Android en este ciclo.
4. **Idempotencia (AR-0c-001)**: T-0c-002 debe implementar la clave
   `(device_id, event_id)` y la regla de no-autoconsumo sin excepción.
5. **R-0c-001**: el Android Share Intent Specialist debe resolver el estado del
   cifrado de campo (XOR vs AES-256-GCM) como primera acción del siguiente ciclo.

---

## Condición de Cierre del Sub-Ciclo 2

El siguiente sub-ciclo (T-0c-002 + T-0c-003) cierra cuando ambas tareas tienen
sus ACs verificados por QA Auditor. T-0c-004 (Privacy Dashboard móvil) se
activa tras T-0c-003.

El gate de Fase 0c (al cierre de T-0c-004) requiere evidencia E2E de:
- galería con datos reales del dispositivo + datos del desktop vía relay
- modo offline funcional (sin conexión a internet)
- Privacy Dashboard móvil honesto y comprensible
- R-0c-001 resuelto (AES-256-GCM confirmado)

---

## Trazabilidad de Entregables de Este Sub-Ciclo

| Commit / Documento | Módulo | Estado |
| --- | --- | --- |
| f0385c5 (EquipoEnjambre) | Cierre documental T-0c-000 | COMPLETADO |
| d219a69 (FlowWeaver) | Fallback Cargo.toml + storage.rs + BuildTask.kt | COMPLETADO |
| a45ad65 (FlowWeaver) | get_mobile_resources, MobileResource, CategoryGroup | COMPLETADO |
| 074809a (EquipoEnjambre) | ACs T-0c-000 y T-0c-001 marcados en backlog | COMPLETADO |
| arch-note-T-0c-000-milestone0-result.md | Resultado build pipeline + workarounds | COMPLETADO |
| qa-review-0c-T0c-000-T0c-001.md | QA Auditor — aprobado con observación | COMPLETADO |
| HO-007 (este documento) | Cierre sub-ciclo 1; apertura T-0c-002 + T-0c-003 | COMPLETADO |
