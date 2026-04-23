# Backlog Funcional — Fase 1

date: 2026-04-23
owner_agent: Functional Analyst
phase: 1
status: DRAFT — pendiente de aprobación por Phase Guardian y Orchestrator
referenced_decision: OD-003 (en preparación)

---

## Functional Breakdown

phase: 1
objective: Validar que Panel B (resumen del workspace) genera valor adicional
           sobre Panel A + Panel C solos.

validates:
- utilidad del resumen del workspace como capa de síntesis
- si el resumen reduce el tiempo de re-entrada al contexto de trabajo
- reacción del usuario ante un workspace con tres paneles (A + B + C)
- si las plantillas de resumen de Panel B son suficientes sin LLM

does_not_validate:
- product-market fit
- hipótesis del puente móvil→desktop (eso es 0b)
- fiabilidad de sync
- aprendizaje longitudinal
- Panel D ni paneles futuros

in_scope:
- Panel B: resumen del workspace por cluster o por episodio
- generación de resumen por plantilla según tipo de contenido (D8 baseline)
- integración de Panel B en el Shell desktop entre Panel A y Panel C
- LLM como mejora opcional si el hardware lo permite (D8 — no es requisito)

out_of_scope:
- FS Watcher (Fase 1 lo permite según arch-note, pero no entra en esta iteración
  hasta que haya justificación de validación específica)
- Panel D ni paneles adicionales
- Share Extension iOS (track separado — bloqueado por plataforma)
- Sync Layer (track separado — bloqueado por plataforma)
- Pattern Detector (Fase 2)
- Trust Scorer (Fase 2)
- State Machine (Fase 2)
- Explainability Log (Fase 2)
- LLM local como requisito (D8 lo prohíbe como dependencia; plantilla debe
  funcionar sola)

dependencies:
- Panel A (T-0a-005) implementado — Panel B recibe los mismos clusters
- Panel C (T-0a-006) implementado — Panel B se posiciona entre A y C
- Episode Detector (0b) implementado — Panel B puede usar el label del episodio
  como contexto del resumen (mejora opcional, no requisito)

risks_of_misinterpretation:
- añadir LLM como requisito de Panel B "porque los templates quedan genéricos"
  — viola D8; el baseline de plantilla debe funcionar sin modelo local
- fusionar Panel B con Panel A como una sola vista "para simplificar"
  — Panel B es una capa de síntesis independiente
- usar Panel B para validar el puente móvil→desktop
  — Panel B valida la utilidad del resumen, no el puente (eso es 0b)
- introducir memoria longitudinal en Panel B "para personalizar el resumen"
  — Pattern Detector es Fase 2; Panel B en Fase 1 es stateless

---

## Mapa De Dependencias

```
Session Builder (0b) ──┐
Episode Detector (0b) ──┤
                        ↓
Panel A (0a) ──────────► Panel B (Fase 1) ──► Shell actualizado
Panel C (0a) ──────────►
```

Panel B puede operar solo con la salida del Grouper (clusters de Panel A).
La salida del Episode Detector es entrada opcional para enriquecer el resumen.

---

## Tareas Y Criterios De Aceptación

---

### T-1-001 — Panel B: Resumen Del Workspace

task_id: T-1-001
title: Panel B — Resumen del workspace por plantilla
phase: 1
owner_agent: Desktop Tauri Shell Specialist (revisión obligatoria: Technical Architect)

#### Objective

Implementar Panel B como capa de síntesis del workspace: un resumen por cluster
(o por episodio activo) generado por plantilla según el tipo de contenido.
Panel B se posiciona entre Panel A y Panel C en la vista del shell.

LLM es mejora opcional, no requisito (D8). El baseline de plantilla debe
funcionar en cualquier entorno.

#### In Scope

- resumen de 2-4 líneas por cluster visible en Panel A
- generación por plantilla según categoría (mismas 10 categorías del Classifier)
- integración en el Shell entre Panel A y Panel C
- si hay episodio Precise activo: el resumen del Anticipated Workspace puede
  tomar el label del episodio como contexto (opcional, sin romper el baseline)

#### Out Of Scope

- generación con LLM como requisito (D8)
- personalización del resumen por usuario
- memoria de resúmenes anteriores
- scraping de contenido de páginas para mejorar el resumen (D1)
- resumen que requiera datos no disponibles localmente

#### Acceptance Criteria

- [ ] Panel B muestra un resumen de 2-4 líneas por cluster o por categoría
- [ ] el resumen se genera por plantilla sin LLM (D8 baseline)
- [ ] Panel B se renderiza entre Panel A y Panel C en el Shell
- [ ] Panel B funciona sin red y sin LLM
- [ ] Panel B no accede a URLs ni títulos completos de páginas (D1)
- [ ] las plantillas cubren las 10 categorías del Classifier
- [ ] si hay episodio Precise activo, el resumen refleja el contexto del episodio
  (opcional — no bloquea el criterio de aceptación si no está)

#### Risks

- que se añada dependencia de LLM "para que los resúmenes sean útiles" (viola D8)
- que Panel B se fusione con Panel A perdiendo la separación de responsabilidades
- que el resumen acceda a contenido completo de páginas "para ser más preciso" (D1)

#### Required Handoff

Al Technical Architect para verificar que el contrato de Panel B es coherente
con el posicionamiento en el Shell y que no viola D1 ni D8.

---

### T-1-002 — Shell Actualizado Con Panel B

task_id: T-1-002
title: Desktop Shell actualizado — Panel A + Panel B + Panel C
phase: 1
owner_agent: Desktop Tauri Shell Specialist
depends_on: T-1-001

#### Objective

Actualizar el Shell para integrar Panel B entre Panel A y Panel C. El Shell
de Fase 0a tenía dos paneles; el de Fase 1 tiene tres.

#### In Scope

- layout de tres paneles: Panel A (izquierda) + Panel B (centro) + Panel C (derecha)
- Panel B ocupa el espacio central del workspace
- el layout es responsive dentro de los límites de la ventana Tauri

#### Out Of Scope

- Panel D ni paneles adicionales
- layout adaptativo para móvil (el Shell es desktop)
- cambios en Panel A o Panel C existentes (solo se añade Panel B)

#### Acceptance Criteria

- [ ] Panel A, Panel B y Panel C se renderizan en el mismo Shell
- [ ] Panel B está visualmente entre Panel A y Panel C
- [ ] Panel A y Panel C no sufren regresiones visuales ni funcionales
- [ ] el layout con tres paneles es usable en ventana de tamaño estándar

#### Required Handoff

Al QA Auditor para verificar que la integración no introduce regresiones
en Panel A ni Panel C.

---

## Hipótesis Que Fase 1 Debe Validar (Gate De Salida)

Antes de pasar el gate de Fase 1, debe existir evidencia de que:

- un observador externo entiende el workspace de tres paneles sin explicación
- Panel B reduce visiblemente el tiempo de re-entrada al contexto
- las plantillas de Panel B son suficientemente específicas sin LLM
- la presencia de Panel B no confunde la función de Panel A ni Panel C
- el equipo distingue claramente Fase 1 (resumen) de Fase 2 (aprendizaje)

---

## Track Paralelo iOS — Pendiente De Entorno macOS

Los siguientes módulos de Fase 0b siguen pendientes por dependencia de
plataforma. Se retomarán cuando el entorno macOS esté disponible. Son
independientes del gate de Fase 1 y pueden completarse en paralelo.

| Módulo | Bloqueo | Lado desktop |
| --- | --- | --- |
| Share Extension iOS | Requiere macOS + Xcode | Listo — add_capture recibe el mismo payload |
| Sync Layer MVP (D6) | Requiere Share Extension operativa | Listo — pipeline recepción implementado |
