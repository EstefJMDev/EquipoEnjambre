# Orchestration Decision

## OD-003 — Apertura De Fase 1: Panel B

date: 2026-04-23
issued_by: Orchestrator
status: APPROVED
referenced_handoff: HO-005-phase-0b-desktop-close.md
referenced_backlog: backlog-phase-1.md

---

## Issue

La implementación desktop de Fase 0b está completa. Los módulos Session
Builder, Episode Detector dual-mode, Privacy Dashboard (D14), Workspace
Anticipatorio y los tests de storage (14/14 passing) están entregados y
verificados.

Los módulos iOS de 0b (Share Extension + Sync Layer) están bloqueados por
dependencia de plataforma: el entorno de desarrollo actual es Windows 10 y
no puede compilar código iOS. HO-005 documenta el estado de esos módulos,
el razonamiento para no implementar un workaround de sync por archivo, y
las condiciones bajo las que se retomarán (track paralelo con entorno macOS).

La implementación desktop de 0b satisface los prerequisitos de Fase 1:
- los clusters de Panel A están disponibles como input de Panel B
- el Episode Detector produce episodios con label y categoría que Panel B
  puede usar opcionalmente
- el Shell desktop es estable y los invariantes activos (D1, D8, D9, R12)
  se respetan

El backlog de Fase 1 define Panel B como único módulo de entrega de esta
fase y establece los criterios de aceptación y el gate de salida.

## Affected Phase

1

## Agents Involved

| Agente | Rol en Fase 1 |
| --- | --- |
| Orchestrator | Emite esta OD; coordina el ciclo |
| Desktop Tauri Shell Specialist | Owner de implementación — Panel B y Shell actualizado |
| Technical Architect | Revisa contrato de Panel B; verifica separación de responsabilidades con Panel A y Panel C |
| QA Auditor | Verifica criterios de aceptación; confirma ausencia de regresiones en Panel A y Panel C |
| Phase Guardian | Vigilancia activa de D8 (LLM no como requisito); activa gate de salida cuando exista evidencia de demo |
| Privacy Guardian | LISTENING — alerta si Panel B accede a URLs o contenido completo (D1) |
| Handoff Manager | Produce HO-006 al cierre del ciclo de implementación de Fase 1 |
| iOS Share Extension Specialist | PENDIENTE DE ENTORNO — retoma track iOS cuando macOS esté disponible |
| Sync & Pairing Specialist | PENDIENTE DE ENTORNO — retoma Sync Layer cuando Share Extension esté operativa |

## Decision

1. El repo del producto queda autorizado para implementación de Fase 1 a
   partir de esta decisión.

2. El orden de implementación de Fase 1 sigue la cadena de dependencias
   del backlog:

   ```
   T-1-001  Panel B (resumen por plantilla)
       └── T-1-002  Shell actualizado (Panel A + Panel B + Panel C)
   ```

3. Cada módulo debe implementarse contra el criterio de aceptación de su
   task spec. Ninguna desviación del contrato está autorizada sin revisión
   previa del Technical Architect.

4. El criterio de gate de Fase 1 — "un observador externo entiende el
   workspace de tres paneles y Panel B reduce visiblemente el tiempo de
   re-entrada al contexto" — requiere demo real. No puede satisfacerse con
   capturas de pantalla.

5. El track iOS (Share Extension + Sync Layer) se mantiene abierto como
   track paralelo. Puede completarse en cualquier momento que el entorno
   macOS esté disponible, sin interferir con el gate de Fase 1.

6. El repo de gobernanza sigue siendo el único repositorio de decisiones,
   specs y revisiones. Ningún documento de gobernanza se escribe en el
   repo del producto.

## Rationale

Fase 1 puede abrirse sin completar el track iOS de 0b porque Panel B no
depende de la Share Extension ni del Sync Layer. El input de Panel B son
los clusters del Grouper y, opcionalmente, los episodios del Episode Detector
— ambos ya implementados y testados en el desktop.

Esperar a completar el track iOS antes de abrir Fase 1 no añade valor de
validación de producto: el aprendizaje de Panel B no está condicionado a la
existencia de la Share Extension. Son hipótesis independientes.

## Constraints Respected

- D1: Panel B no puede acceder a URLs ni títulos de páginas completas. El
  resumen se genera a partir de domain y category (en claro) y del label
  del episodio (cuando exista). Ningún campo cifrado se expone en Panel B.
- D8: LLM no es requisito de Panel B. El baseline de plantilla debe funcionar
  sin modelo local disponible. El Phase Guardian bloqueará cualquier
  implementación que haga Panel B dependiente de un LLM.
- D9: Desktop no observa activamente. Panel B es estático; se renderiza cuando
  el usuario abre la app. Sin polling, sin FS watcher, sin proceso en fondo.
- D12: Los bookmarks siguen siendo bootstrap. Panel B no los presenta como
  validación de PMF ni como señales de captura activa.
- R12 WATCH ACTIVO: La narrativa de Panel B no puede presentar el Grouper
  como detector de patrones temporales. Panel B resume clusters (Grouper),
  no episodios (Episode Detector). La distinción debe mantenerse en el código
  y en la demo.
- Panel B es Fase 1: No puede introducirse como placeholder en 0a ni en 0b.
  Esta OD es la primera autorización formal de Panel B.

## Next Agent

Desktop Tauri Shell Specialist → comenzar con T-1-001 (Panel B) tomando
`backlog-phase-1.md` como contrato de referencia y los criterios de
aceptación de T-1-001 como gate de implementación.

## Documentation Updates Required

| Archivo | Acción | Urgencia | Estado |
| --- | --- | --- | --- |
| `operations/backlogs/backlog-phase-1.md` | Ya creado con esta OD | — | COMPLETADO |
| `operations/handoffs/HO-005-phase-0b-desktop-close.md` | Ya creado — cierre de 0b | — | COMPLETADO |
| `operations/handoffs/HO-006-phase-1-impl-close.md` | Handoff Manager produce al cierre de Fase 1 | CUANDO IMPLEMENTACIÓN COMPLETA | PENDIENTE |
