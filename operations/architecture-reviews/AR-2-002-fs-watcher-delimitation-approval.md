# Revisión Arquitectónica — Delimitación De FS Watcher (T-2-000)

document_id: AR-2-002
owner_agent: Technical Architect
phase: 2
date: 2026-04-24
status: APROBADO — sin correcciones; implementación de FS Watcher autorizada
documents_reviewed:
  - operations/task-specs/TS-2-000-fs-watcher-delimitation.md
  - operations/backlogs/backlog-phase-2.md (T-2-000, criterios de aceptación)
  - operations/orchestration-decisions/OD-004-phase-2-activation.md
reference_normativo:
  - Project-docs/decisions-log.md (D1, D9, D17, R12 WATCH ACTIVO)
  - operating-system/phase-gates.md (Condición 1 del gate de Fase 1)
precede_a: Desktop Tauri Shell Specialist → implementación de fs_watcher.rs

---

## Objetivo De Esta Revisión

T-2-000 es un entregable documental: la delimitación formal de FS Watcher.
D9 exige que cualquier módulo de observación activa en desktop responda tres
preguntas antes de ser implementado: qué observa, por cuánto tiempo y con qué
controles de privacidad. Esta AR verifica que TS-2-000 responde las tres.

Adicionalmente, esta aprobación satisface la Condición 1 del gate formal de
Fase 1 (phase-gates.md), que quedó pendiente cuando OD-004 abrió Fase 2.

---

## Resultado Global

| Criterio de aceptación del backlog | Respondido en TS-2-000 | Estado |
| --- | --- | --- |
| ≥1 directorio observable con criterios de selección por el usuario | `~/Downloads` + `~/Desktop`, activación manual por directorio | ✅ |
| Sin monitoring en background declarado explícitamente | Sección 2: "únicamente mientras la app está en primer plano" | ✅ |
| Controles de privacidad: consentimiento, revocación, Privacy Dashboard | Sección 3 completa con los tres controles | ✅ |
| Extensiones en scope y fuera de scope declaradas | Lista blanca de 18 ext. en 5 grupos + exclusiones explícitas | ✅ |
| Separación FS Watcher vs Pattern Detector (R12) | Sección 4 con tabla comparativa completa | ✅ |
| **Aprobación del Technical Architect** | **Esta AR** | ✅ |

**Todos los criterios de aceptación de T-2-000 están satisfechos.**

---

## A. Verificación De Las Tres Preguntas De D9

### A.1 — ¿Qué observa FS Watcher?

**Directorios:** `~/Downloads` y `~/Desktop`. Ambos candidatos razonables — son
los directorios donde aterrizan recursos externos (descargas, capturas de
pantalla) sin incluir directorios de sistema, red, código o credenciales.

La lista blanca de extensiones es correcta y cerrada:
- Documentos, imágenes, video, archivos comprimidos.
- Ejecutables, archivos de sistema, código y credenciales explícitamente fuera.
- Regla de lista blanca: "si no está incluido, no se observa" — arquitectónicamente
  sólido. Elimina ambigüedad en la implementación.

El campo de nombre de archivo se almacena cifrado (D1). El directorio padre se
almacena en claro como nivel de abstracción (equivalente al dominio en captura
web). **D1 operativo en FS Watcher.**

**Veredicto A.1: qué observa — DEFINIDO y CORRECTO.**

### A.2 — ¿Por cuánto tiempo observa?

Observación exclusivamente mientras la app está en primer plano. La tabla de
estados (app abierta / minimizada / background / cerrada / sistema en reposo)
cubre todos los casos posibles. En ningún caso hay observación en background.

La consecuencia de suspensión (eventos en cola descartados al pasar a background)
es arquitectónicamente correcta: no se acumula estado entre sesiones de
observación. La sesión de FS Watcher es discreta y acotada.

**Veredicto A.2: por cuánto tiempo — DEFINIDO y CORRECTO.**

### A.3 — ¿Con qué controles de privacidad?

Los tres controles exigidos están presentes:

| Control | Especificado en TS-2-000 | Suficiente |
| --- | --- | --- |
| Consentimiento | Confirmación explícita por directorio en primer uso | ✅ |
| Revocación | Botón "Dejar de observar [directorio]" en Privacy Dashboard, inmediato | ✅ |
| Visibilidad en Privacy Dashboard | Sección dedicada con estado en tiempo real, contadores, y botón de purga | ✅ |

La sección del Privacy Dashboard está suficientemente especificada para que
T-2-004 (Privacy Dashboard completo) lo implemente sin ambigüedad.

**Veredicto A.3: controles de privacidad — DEFINIDOS y SUFICIENTES.**

---

## B. Verificación De R12 — Separación FS Watcher vs Pattern Detector

La tabla comparativa de la sección 4 de TS-2-000 declara la distinción en seis
dimensiones: función, escala temporal, input, output, persistencia y módulo Rust.

La distinción crítica está correctamente definida:

- **FS Watcher** → eventos efímeros de sesión → `episode_detector.rs` adaptado
- **Pattern Detector** → historial longitudinal de SQLCipher → `pattern_detector.rs`

FS Watcher no alimenta al Pattern Detector directamente. Sus eventos son de
sesión (efímeros); el Pattern Detector lee el historial persistido en SQLCipher.
La confusión R12 quedaría en: "FS Watcher genera los patrones". TS-2-000 lo
descarta explícitamente.

El comentario de cabecera requerido en `fs_watcher.rs`:
```rust
// FS Watcher: detecta eventos de archivo en sesión activa.
// Distinto de pattern_detector.rs (patrones longitudinales) — R12.
// Opera solo mientras la app está en primer plano (D9).
```
Está definido en la TS — verificable en code review.

**R12: separación correctamente declarada. Sin riesgo de contaminación.**

---

## C. Contratos De Módulo Derivados De Esta Aprobación

El implementador de `fs_watcher.rs` debe respetar estos contratos:

```
fs_watcher.rs

input:   eventos del sistema de archivos (inotify en Linux, ReadDirectoryChangesW
         en Windows, FSEvents en macOS) sobre los directorios activados por el usuario
output:  FileEvent { nombre_cifrado, directorio_padre, extension, timestamp }
         → entregado al Episode Detector adaptado (Fase 1)

restricciones duras:
  - solo extiende la observación a los directorios que el usuario activó en el
    Privacy Dashboard (ninguno por defecto)
  - solo observa mientras la app está en primer plano (D9)
  - solo procesa extensiones de la lista blanca definida en TS-2-000
  - nombre del archivo cifrado antes de persistir (D1)
  - directorio padre en claro (D1 — nivel de abstracción)
  - no lee el contenido del archivo bajo ninguna circunstancia (D1 permanente)
  - no importa desde pattern_detector.rs ni desde episode_detector.rs (R12)
  - comentario de cabecera R12 obligatorio (verificable en code review)
```

---

## D. Correcciones

**Ninguna.**

TS-2-000 satisface todos los criterios de aceptación de T-2-000 y responde
las tres preguntas de D9 de forma completa y sin ambigüedad.

---

## E. Condición 1 Del Gate Formal De Fase 1 — SATISFECHA

OD-004 establece: "El primer entregable de Fase 2 es la delimitación formal de
FS Watcher. Este documento debe existir y ser aprobado por el Technical Architect
antes de que se implemente FS Watcher. Satisface la Condición 1 del gate formal
de Fase 1."

Con esta AR, la Condición 1 queda **formalmente satisfecha**.

---

## F. Siguiente Agente Responsable

**Desktop Tauri Shell Specialist** → implementar `src-tauri/src/fs_watcher.rs`
siguiendo el contrato de módulo de la sección C y los criterios de aceptación
de TS-2-000.

El Desktop Tauri Shell Specialist debe leer antes de implementar:
- `operations/task-specs/TS-2-000-fs-watcher-delimitation.md` (contrato completo)
- `operations/architecture-reviews/AR-2-002-fs-watcher-delimitation-approval.md`
  (esta AR — contratos de módulo, sección C)
- `Project-docs/decisions-log.md` (D1, D9, R12)
- `operations/backlogs/backlog-phase-2.md` (T-2-000 criterios de aceptación)

La implementación del Pattern Detector (T-2-001) puede correr en paralelo —
no depende de FS Watcher.

---

## G. Trazabilidad

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado y aprobado | operations/task-specs/TS-2-000-fs-watcher-delimitation.md | APROBADO |
| Condición 1 gate Fase 1 | phase-gates.md (satisfecha formalmente) | COMPLETADO |
| Creado | operations/architecture-reviews/AR-2-002-fs-watcher-delimitation-approval.md | este documento |
