# Standard Handoff

document_id: HO-009
from_agent: Orchestrator
to_agent: Technical Architect
status: ready_for_execution
phase: 2
date: 2026-04-27
cycle: Kickoff Fase 2 — primer entregable
opens: T-2-000 (Delimitación documental de FS Watcher)
unblocks: T-2-001 (Pattern Detector) tras aprobación

---

## Objetivo

Producir `TS-2-000-fs-watcher-delimitation.md`: delimitación formal y exclusivamente documental del FS Watcher como segundo caso de uso local de observación activa, conforme a D9 (FS Watcher es el único módulo de observación activa en Fase 2 y requiere delimitación formal antes de implementar).

No es implementación. Es contrato de qué observa, qué no, y los límites de privacidad.

---

## Inputs

- `Project-docs/decisions-log.md` — D1, D9, D14, R12 (no negociables)
- `operations/backlogs/backlog-phase-2.md` — T-2-000 in_scope (líneas 28-33)
- `operations/orchestration-decisions/OD-004-phase-2-activation.md`
- `operations/architecture-reviews/AR-2-001*.md`

---

## Entregable esperado

`operations/task-specs/TS-2-000-fs-watcher-delimitation.md` con como mínimo:

1. **Scope observado** — qué eventos, qué rutas, qué tipos de archivo
2. **Scope NO observado** — exclusiones explícitas (rutas sensibles, tipos vetados)
3. **Modelo de datos** — qué se persiste, qué se cifra (D1), qué se descarta
4. **Límites de privacidad** — alineación con Privacy Dashboard (D14)
5. **Diferenciación R12** — FS Watcher ≠ Pattern Detector ≠ Episode Detector
6. **Criterios de aprobación** — qué debe validar el Orchestrator antes de cerrar

---

## Restricciones

- D1: solo `domain` y `category` en claro; cualquier path/nombre archivo cifrado
- D9: FS Watcher es el único observer activo de Fase 2 — no proponer otros
- D14: cualquier dato observado debe ser visible/controlable en Privacy Dashboard completo (T-2-004)
- No implementación, no pseudocódigo extenso, no diseño de UI
- No bloquea T-2-001 conceptualmente — Pattern Detector trabaja sobre datos ya capturados

---

## Cierre

Entregar TS-2-000 al Orchestrator para revisión. Tras aprobación se desbloquea T-2-001 (Pattern Detector).
