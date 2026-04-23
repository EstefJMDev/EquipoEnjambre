# Orchestration Decision

## OD-004 — Cierre De Gate De Fase 1 Y Apertura De Fase 2

date: 2026-04-23
issued_by: Orchestrator
status: APPROVED
referenced_pir: PIR-003-phase-1-gate.md
referenced_handoff: HO-006-phase-1-impl-close.md

---

## Issue

PIR-003 confirma que el gate de OD-003 está pasado: el usuario ha confirmado
que el workspace de tres paneles es comprensible y que Panel B reduce el tiempo
de re-entrada al contexto.

Las condiciones de no-paso del gate formal de Fase 1 (phase-gates.md) no han
sido activadas. La única condición pendiente del gate formal es la delimitación
de FS Watcher, que no bloquea la apertura de Fase 2: FS Watcher se delimitará
como primer entregable documental de Fase 2 antes de cualquier implementación.

La phase-definition.md y el roadmap definen Fase 2 como:
- aprendizaje longitudinal y escalera de confianza
- Pattern Detector, Trust Scorer, State Machine, Privacy Dashboard completo

---

## Affected Phase

2

## Agents Involved

| Agente | Rol en Fase 2 |
| --- | --- |
| Orchestrator | Emite esta OD; coordina el ciclo |
| Functional Analyst | Produce backlog-phase-2.md con T-2-001 a T-2-00N |
| Technical Architect | Revisa contratos de módulos nuevos (Pattern Detector, Trust Scorer, State Machine) |
| QA Auditor | Verifica criterios de aceptación; ausencia de regresiones |
| Phase Guardian | Vigilancia de condiciones de no-paso del gate de Fase 2 |
| Privacy Guardian | Alerta activa: aprendizaje longitudinal + Privacy Dashboard completo son vectores de riesgo de privacidad |
| Desktop Tauri Shell Specialist | Owner de implementación |
| Handoff Manager | Produce HO-007 al cierre del ciclo de implementación de Fase 2 |

## Decision

1. El gate de OD-003 queda **cerrado como PASADO** a partir de esta decisión.
   Fase 1 (iteración Panel B) queda formalmente completada.

2. El repo del producto queda autorizado para el ciclo de Fase 2 a partir de
   esta decisión.

3. El primer entregable de Fase 2 es **la delimitación formal de FS Watcher**
   como segundo caso de uso local. Este documento debe existir y ser aprobado
   por el Technical Architect antes de que se implemente FS Watcher. Satisface
   la Condición 1 del gate formal de Fase 1 (phase-gates.md) que quedó pendiente.

4. El orden de entregables de Fase 2 sigue la cadena de dependencias del roadmap:

   ```
   T-2-000  Delimitación de FS Watcher (documental, pre-implementación)
   T-2-001  Pattern Detector
       └── T-2-002  Trust Scorer
           └── T-2-003  State Machine
   T-2-004  Privacy Dashboard completo
   ```

   La numeración es orientativa. El Functional Analyst define el orden definitivo
   en backlog-phase-2.md junto con los criterios de aceptación.

5. Ninguna implementación de Fase 2 puede introducirse sin backlog aprobado.
   La delimitación documental de FS Watcher (T-2-000) es el único entregable
   que puede producirse en paralelo al backlog.

6. La escalera de confianza (Pattern Detector → Trust Scorer → State Machine)
   debe tratarse como cadena de dependencias estricta, no como módulos
   independientes. Ningún módulo de esta cadena puede implementarse sin que el
   anterior esté aprobado.

7. El track iOS (Share Extension + Sync Layer de Fase 0b) sigue abierto como
   track paralelo. No interfiere con el gate de Fase 2.

## Rationale

Fase 2 puede abrirse con Phase 1 en el estado actual porque:
- El gate de OD-003 está pasado con evidencia real
- Ninguna condición de no-paso del gate formal se ha activado
- FS Watcher se puede delimitar documentalmente en paralelo al backlog de Fase 2
  sin bloquear la apertura del ciclo

La cadena de dependencias de Fase 2 (Pattern Detector → Trust Scorer → State
Machine) es estricta por diseño: Trust Scorer no puede rankear sin patrones
detectados; State Machine no puede gestionar transiciones sin scores de confianza.
Implementar en paralelo produciría módulos sin input real y sin capacidad de
integración verificada.

## Constraints Respected

- D8: LLM sigue siendo mejora opcional, no requisito. Pattern Detector y Trust
  Scorer deben tener baseline determinístico. El backlog-phase-2.md debe
  declarar explícitamente el baseline sin LLM de cada módulo.
- D9: FS Watcher es el único módulo de Fase 2 que introduce observación activa.
  Su delimitación debe establecer con precisión qué observa, durante cuánto
  tiempo y con qué controles de privacidad. D9 no prohíbe FS Watcher; prohíbe
  observación activa sin delimitación y sin control del usuario.
- D1: el Privacy Dashboard completo de Fase 2 debe seguir operando sólo sobre
  campos en claro (domain, category). Ninguna funcionalidad nueva puede exponer
  url ni title.
- R12 WATCH ACTIVO extendido: Pattern Detector NO es una extensión del Episode
  Detector. Son módulos con propósitos distintos (patrones longitudinales vs
  episodios de sesión). Esta distinción debe declararse explícitamente en
  backlog-phase-2.md y en cada TS de Fase 2.

## Next Agent

Functional Analyst → producir backlog-phase-2.md tomando:
- `Project-docs/roadmap.md` (entregables de Fase 2)
- `Project-docs/phase-definition.md` (qué valida y qué no valida Fase 2)
- `operating-system/phase-gates.md` (gate de salida de Fase 2)
- Esta OD como contrato de apertura

## Documentation Updates Required

| Archivo | Acción | Urgencia | Estado |
| --- | --- | --- | --- |
| `operations/backlogs/backlog-phase-2.md` | Functional Analyst produce | PRIMER PASO | PENDIENTE |
| `operations/phase-integrity-reviews/PIR-003-phase-1-gate.md` | Ya creado — cierre del gate de Fase 1 | — | COMPLETADO |
| `operations/handoffs/HO-007-phase-2-impl-close.md` | Handoff Manager produce al cierre de Fase 2 | CUANDO IMPLEMENTACIÓN COMPLETA | PENDIENTE |
