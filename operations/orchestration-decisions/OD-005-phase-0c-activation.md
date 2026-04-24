# Orchestration Decision

## OD-005 — Creación De Fase 0c: Mobile Client Completo Y Sync Bidireccional

date: 2026-04-24
issued_by: Orchestrator
status: APPROVED
referenced_cr: CR-001-mobile-client-bidirectional-sync.md
triggered_by: Product owner — el móvil debe entregar valor de forma independiente

---

## Issue

El análisis de viabilidad previo (2026-04-24) identificó que la app móvil actual
actúa exclusivamente como punto de captura. El usuario que captura un Reel en
Instagram o un artículo desde el móvil no puede ver su galería organizada sin
abrir el desktop.

El product owner ha identificado esto como un gap de producto crítico:
> "Los usuarios quieren tener los enlaces organizados en otro lugar. Es uno de los
> mayores problemas. Si se puede, tiene que ser parte del producto."

CR-001 propone la creación de Fase 0c para convertir la app Android en un cliente
completo con galería propia y sync bidireccional. La propuesta es aprobada.

---

## Decision

1. **Fase 0c queda creada** como fase formal del roadmap de FlowWeaver.
   Nombre: "Mobile Client — galería organizada y sync bidireccional".

2. **D20 y D21 quedan añadidos** al decisions-log.md como decisiones cerradas:
   - D20: app Android como cliente completo (Classifier + Grouper + SQLCipher + galería)
   - D21: sync bidireccional vía Google Drive relay (raw_events en ambas direcciones)

3. **D12 queda extendido** (no revocado). El puente es ahora bidireccional:
   el móvil captura y organiza; el desktop también prepara el workspace y sincroniza
   hacia el móvil. El caso núcleo original (mobile → desktop) sigue siendo válido.

4. **Fase 0c comienza después del gate de Fase 0b** — no antes. Fase 0b sigue
   su curso sin modificaciones.

5. **Secuencia de entregables de Fase 0c:**
   ```
   backlog-phase-0c.md (Functional Analyst)
       │
       ▼
   AR-0c-001 (Technical Architect — sync bidireccional + SQLCipher Android)
       │
       ▼
   Implementación (Android Share Intent Specialist + Desktop Tauri Shell Specialist)
       │
       ▼
   QA Review → gate de Fase 0c
   ```

6. **Scope estricto de Fase 0c** (no puede ampliarse sin nuevo CR):
   - galería Android: categorías → recursos (tap → abre URL en navegador)
   - Classifier + Grouper en Android (mismo Rust compilado para Android)
   - SQLCipher local en Android (independiente del desktop)
   - Google Drive relay bidireccional
   - Privacy Dashboard mínimo móvil

7. **Prohibiciones explícitas de Fase 0c** (scope creep a bloquear):
   - Panel B en móvil (no)
   - Episode Detector en móvil (no)
   - Pattern Detector ni Trust Scorer en móvil (no — Fase 2 desktop primero)
   - sync en tiempo real (no — el relay sigue siendo async)
   - notificaciones push (no — requeriría backend propia)
   - vista embebida de contenido de redes sociales (no — solo URL que abre navegador)

8. **El track iOS** sigue abierto como track paralelo secundario e independiente.
   Fase 0c aplica primariamente a Android.

---

## Affected Phase

0c (nueva)

## Agents Involved

| Agente | Rol en Fase 0c |
| --- | --- |
| Orchestrator | Emite esta OD; coordina el ciclo |
| Functional Analyst | Produce backlog-phase-0c.md |
| Technical Architect | AR-0c-001: sync bidireccional + SQLCipher Android |
| Android Share Intent Specialist | Owner de implementación móvil |
| Desktop Tauri Shell Specialist | Owner de extensión del relay en desktop |
| Privacy Guardian | Verifica que galería móvil no introduce vectores nuevos (D1, D9) |
| Phase Guardian | Vigilancia de scope — bloquea cualquier vector de los 6 prohibidos |
| QA Auditor | Verifica criterios de aceptación; ausencia de regresiones en 0b |
| Handoff Manager | Produce HO-008 al cierre del ciclo de implementación de Fase 0c |

---

## Rationale

Fase 0b valida el puente móvil→desktop. Pero si el usuario necesita el desktop
para ver el valor de lo que capturó en el móvil, el producto tiene un cuello
de botella en el dispositivo que el usuario tiene siempre en la mano.

Tauri 2 compila el mismo backend Rust para Android sin reescritura. El mecanismo
de sync (Google Drive relay + ACK + idempotencia) ya existe y puede extenderse
a bidireccional. El coste técnico de este cambio es proporcional al valor que
genera — y el valor es fundamental para la propuesta del producto.

La creación de Fase 0c protege a Fase 0b de ampliaciones que la desestabilizarían,
y da a la nueva funcionalidad el ciclo de especificación y validación que merece.

---

## Constraints Respected

- D1: la galería móvil opera sobre domain y category. Los recursos se almacenan
  cifrados en SQLCipher Android igual que en desktop. Sin exposición de url/title
  en el procesamiento longitudinal.
- D6: el relay sigue siendo Google Drive. D21 extiende D6 para declarar la
  bidireccionalidad — no cambia el mecanismo.
- D8: Classifier y Grouper en Android tienen el mismo baseline determinístico
  (sin LLM) que en desktop.
- D9: la galería no introduce observación activa. No hay watcher en Android.
  El único observer sigue siendo el Share Intent (D9 operativo).
- D19: Android + Windows first. Fase 0c es nativa de Android.

---

## Documentation Updates Required

| Archivo | Acción | Urgencia | Estado |
| --- | --- | --- | --- |
| `Project-docs/decisions-log.md` | D20 y D21 añadidos | INMEDIATO | COMPLETADO |
| `Project-docs/roadmap.md` | Fase 0c añadida | INMEDIATO | COMPLETADO |
| `Project-docs/scope-boundaries.md` | Scope de Fase 0c añadido | INMEDIATO | COMPLETADO |
| `Project-docs/phase-definition.md` | Definición de Fase 0c añadida | INMEDIATO | COMPLETADO |
| `operations/change-requests/CR-001-mobile-client-bidirectional-sync.md` | Final Decision actualizado | INMEDIATO | COMPLETADO |
| `operations/backlogs/backlog-phase-0c.md` | Functional Analyst produce | PRIMER PASO POST-GATE-0b | PENDIENTE |
| `operations/handoffs/HO-008-phase-0c-impl-close.md` | Handoff Manager produce al cierre | CUANDO IMPLEMENTACIÓN COMPLETA | PENDIENTE |

---

## Next Agent

Functional Analyst → producir backlog-phase-0c.md una vez que el gate de Fase 0b
sea pasado, tomando:
- `Project-docs/roadmap.md` (Fase 0c recién añadida)
- `Project-docs/scope-boundaries.md` (scope y prohibiciones de Fase 0c)
- `Project-docs/phase-definition.md` (hipótesis a validar)
- `Project-docs/decisions-log.md` (D20, D21)
- Esta OD como contrato de apertura
- `operations/change-requests/CR-001-mobile-client-bidirectional-sync.md`
  (alternativas rechazadas y riesgos de scope creep)
