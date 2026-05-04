# Change Request

request_id: CR-003
owner_agent: Orchestrator (registro retroactivo)
change_type: Normativo interno
date: 2026-05-04 (registro retroactivo del cambio efectivo en 2026-04-23/24)
status: APROBADO retroactivamente — refleja el estado ya implementado por OD-003, OD-004 y AR-2-002
triggered_by: Auditoría de coherencia entre product-spec y backlogs de fase

---

## Proposed Change

Mover el FS Watcher de Fase 1 a Fase 2 como entregable T-2-000 (delimitación
documental obligatoria antes de implementación). Reducir el alcance efectivo
de Fase 1 a "Panel B con plantillas".

Este CR es retroactivo: no propone un cambio nuevo, sino que documenta de forma
explícita un movimiento que ya quedó implementado en los backlogs de Fase 1 y
Fase 2 y en las decisiones cerradas D9/R12, pero que no contaba con un registro
único de change control que cerrara la trazabilidad.

---

## Why It Is Needed

### Motivo técnico
La decisión D9 exige que cualquier módulo de observación activa en desktop
delimite formalmente:
1. qué observa
2. por cuánto tiempo
3. con qué controles de privacidad

Estas tres preguntas no eran contestables dentro del marco de Fase 1, cuyo
objetivo era exclusivamente validar Panel B. Implementar el FS Watcher en
Fase 1 habría:

- introducido observación activa de desktop sin la cadena Pattern Detector →
  Trust Scorer → State Machine que le da significado longitudinal (R12 WATCH);
- forzado a Fase 1 a validar dos hipótesis distintas (Panel B + observación
  activa), violando la regla "una fase, una hipótesis";
- adelantado decisiones de scope (extensiones, controles de privacidad,
  retención) que requerían input arquitectónico documentado.

### Motivo de gobernanza
La condición 1 del gate formal de Fase 1 (phase-gates.md) quedó pendiente
hasta que existiera una delimitación formal del FS Watcher. AR-2-002
(2026-04-24) cerró esa condición aprobando TS-2-000 como el entregable que
satisface D9.

---

## Documents Affected

| Documento | Estado |
|---|---|
| `Project-docs/decisions-log.md` (D9, R12 WATCH) | Ya consistente — D9 marca FS Watcher como observación activa de Fase 2 |
| `operations/backlogs/backlog-phase-1.md` | Ya consistente — FS Watcher listado como `out_of_scope` |
| `operations/backlogs/backlog-phase-2.md` | Ya consistente — T-2-000 listado como `in_scope` |
| `operations/orchestration-decisions/OD-004-phase-2-activation.md` | Ya consistente — abre Fase 2 con T-2-000 |
| `operations/architecture-reviews/AR-2-002-fs-watcher-delimitation-approval.md` | Ya consistente — aprueba TS-2-000 y cierra Condición 1 del gate de Fase 1 |
| `docs/product-spec.md` | **Requiere actualización** — sección 14 Fase 1 sigue listando "FS Watcher" y "organización de descargas y screenshots" como entregables |

---

## Impact By Phase

- **Fase 1:** alcance efectivo reducido a Panel B con plantillas. Sin FS
  Watcher, sin organización de descargas, sin adaptación del Episode Detector
  más allá de lo entregado. Gate de Fase 1 (PIR-003, 2026-04-24) pasado con
  esta interpretación.
- **Fase 2:** absorbe FS Watcher como T-2-000 (delimitación) + implementación
  posterior. Cadena Pattern Detector → Trust Scorer → State Machine se
  ejecuta antes de cualquier acción autónoma del FS Watcher.
- **Fase 3:** sin impacto.

---

## Architectural Impact

- R12 WATCH ACTIVO se respeta: la observación activa solo entra cuando existe
  el motor longitudinal que la interpreta.
- D9 se respeta: la delimitación es entregable previo a la implementación.
- D14 se respeta: Privacy Dashboard completo (T-2-004) entra en la misma fase
  que el FS Watcher operativo.

---

## Scope Creep Risk

Bajo. Este CR no añade scope; lo redistribuye entre fases ya activadas. La
única acción correctiva pendiente es alinear la sección 14 de la product spec
para reflejar el alcance real entregado en Fase 1.

---

## Alternatives Considered

1. **Implementar FS Watcher en Fase 1 sin Pattern Detector / Trust Scorer.**
   Descartada: viola R12 WATCH y produce observación activa sin escalera de
   confianza.
2. **Mantener FS Watcher en Fase 1 como entregable opcional.**
   Descartada: deja el gate de Fase 1 con condición indefinida y bloquea
   indefinidamente la activación de Fase 2.
3. **Crear una Fase 1.5 dedicada al FS Watcher.**
   Descartada: añade complejidad operativa sin valor de validación
   diferenciado, dado que el FS Watcher solo tiene sentido junto con
   Pattern Detector + Trust Scorer.

---

## Final Recommendation

Registrar formalmente el movimiento como ya implementado. Actualizar la
sección 14 de `docs/product-spec.md` para que la descripción de Fase 1
refleje el alcance real entregado (Panel B con plantillas), y mantener
T-2-000 como entregable canónico de FS Watcher en Fase 2.
