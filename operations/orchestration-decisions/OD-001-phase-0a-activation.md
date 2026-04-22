# Orchestration Decision

## OD-001 — Activación Formal De Fase 0a

date: 2026-04-22
issued_by: Orchestrator
status: APPROVED

---

## issue

El sistema multiagente está estructuralmente completo: todos los agentes están
definidos, todas las matrices existen y todos los documentos normativos están en
vigor. Sin embargo, ninguna fase había sido declarada formalmente activa. Sin
esta declaración, ningún agente puede producir entregables operativos con
trazabilidad válida.

Se detectan además dos defectos documentales bloqueantes corregidos en este
ciclo:

1. `agents/09_desktop_tauri_shell_specialist.md` declaraba
   `default_state: LISTENING`, contradiciendo la matriz de activación (ACTIVE
   en 0a, 0b y 1). Corregido a `default_state: ACTIVE`.
2. Panel B no estaba clausurado explícitamente en `scope-boundaries.md` ni en
   `phase-definition.md` para 0a ni para 0b, generando riesgo de contaminación
   de fase. Clausurado en ambos documentos.

## affected_phase

0a

## agents_involved

| Agente | Estado en Fase 0a |
| --- | --- |
| Orchestrator | ACTIVE |
| Functional Analyst | ACTIVE |
| Technical Architect | ACTIVE |
| QA Auditor | ACTIVE |
| Context Guardian | ACTIVE |
| Privacy Guardian | LISTENING |
| Phase Guardian | ACTIVE |
| Handoff Manager | ACTIVE |
| Desktop Tauri Shell Specialist | ACTIVE (default_state corregido) |
| Constraint-Solving & Fallback Strategy Specialist | LISTENING |
| iOS Share Extension Specialist | LOCKED |
| Session & Episode Engine Specialist | LOCKED |
| Sync & Pairing Specialist | LOCKED |

## decision

1. Fase 0a queda declarada activa a partir de esta decisión.
2. Los estados de agente quedan fijados según la columna 0a de la matriz de
   activación (`project-docs/agent-activation-matrix.md`).
3. Las correcciones documentales listadas en el campo `issue` se aplican en este
   mismo ciclo antes de entregar al siguiente agente.
4. Se inicia el primer ciclo operativo del enjambre con los siguientes
   entregables en este orden:
   - Functional Analyst → `operations/backlogs/backlog-phase-0a.md`
   - Technical Architect → `operations/architecture-notes/arch-note-phase-0a.md`
   - QA Auditor → `operations/qa-reviews/qa-review-phase-0a-activation.md`
   - Handoff Manager → `operations/handoffs/HO-001-phase-0a-activation-cycle.md`

## rationale

Fase 0a es la primera fase del roadmap. Su objetivo es validar que el formato
workspace genera valor, no PMF y no el puente móvil→desktop.

El enjambre no puede gobernar trabajo sin una fase declarada activa.

Las correcciones documentales eran menores pero bloqueantes: un `default_state`
incorrecto puede activar agentes con estado erróneo en sesiones futuras; la
ambigüedad de Panel B puede generar trabajo fuera de fase en la demo de 0a o
en la construcción de 0b.

Declarar Fase 0a activa no autoriza implementación del producto. Autoriza al
enjambre a producir sus primeros entregables operativos de gobernanza.

## constraints_respected

- D9: desktop no observa activamente. Share Extension Specialist LOCKED en 0a.
- D10: 0a valida formato workspace; 0b valida el puente.
- D12: único caso núcleo es el puente móvil→desktop. Bookmarks son bootstrap.
- D2/D17: Pattern Detector solo en Fase 2. Session & Episode Engine LOCKED en 0a.
- D6: Sync LOCKED en 0a.
- AGENTS.md §6: restricciones no negociables del MVP respetadas.
- AGENTS.md §3: este repo produce solo documentos de gobernanza, no código del
  producto.

## next_agent

Functional Analyst → producir `operations/backlogs/backlog-phase-0a.md`

## documentation_updates_required

| Archivo | Acción | Estado |
| --- | --- | --- |
| `agents/09_desktop_tauri_shell_specialist.md` | corregir default_state | COMPLETADO |
| `project-docs/scope-boundaries.md` | añadir Panel B a exclusiones de 0a y 0b | COMPLETADO |
| `project-docs/phase-definition.md` | clausurar ambigüedad Panel B en 0a y 0b | COMPLETADO |
| `operations/backlogs/backlog-phase-0a.md` | crear | COMPLETADO |
| `operations/architecture-notes/arch-note-phase-0a.md` | crear | COMPLETADO |
| `operations/qa-reviews/qa-review-phase-0a-activation.md` | crear | COMPLETADO |
| `operations/handoffs/HO-001-phase-0a-activation-cycle.md` | crear | COMPLETADO |
| `operating-system/file-ownership-map.md` | añadir entradas para operations/ | PENDIENTE |
