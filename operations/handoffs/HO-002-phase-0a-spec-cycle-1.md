# Standard Handoff

document_id: HO-002
from_agent: Handoff Manager
  (ciclo producido por: Desktop Tauri Shell Specialist, Technical Architect,
  QA Auditor)
to_agent: Desktop Tauri Shell Specialist
status: ready_for_execution
phase: 0a
date: 2026-04-22
cycle: Segundo ciclo operativo — Especificación de TS-0a-001 y TS-0a-007
closes: ciclo de especificación de TS-0a-001 y TS-0a-007
opens: ciclo de especificación de TS-0a-002, TS-0a-003, TS-0a-004, TS-0a-005,
  TS-0a-006

---

## Objective

Cerrar formalmente el segundo ciclo operativo de Fase 0a.

Este ciclo especificó y validó los contratos de los dos primeros módulos
documentales de 0a: el contenedor Desktop Workspace Shell (TS-0a-001) y el
almacenamiento local cifrado (TS-0a-007). Ambos pasaron revisión QA y
revisión arquitectónica sin bloqueos.

El Desktop Tauri Shell Specialist asume a partir de este handoff el siguiente
ciclo de especificación: producir TS-0a-002 (Bookmark Importer), TS-0a-003
(Classifier), TS-0a-004 (Grouper), TS-0a-005 (Panel A) y TS-0a-006 (Panel C),
en ese orden de dependencias.

---

## Context Read

Documentos leídos en este ciclo:

- `operations/task-specs/TS-0a-001-desktop-workspace-shell.md`
- `operations/task-specs/TS-0a-007-sqlcipher-local-storage.md`
- `operations/architecture-notes/arch-note-phase-0a.md`
- `operations/qa-reviews/qa-review-phase-0a-task-specs.md` (QA-REVIEW-0a-002)
- `operations/architecture-reviews/AR-0a-001-task-specs-review.md`
- `operations/backlogs/backlog-phase-0a.md`
- `Project-docs/decisions-log.md` (D1, D6, D8, D16)
- `Project-docs/risk-register.md` (R11, R12)
- `operating-system/phase-gates.md`
- `Project-docs/scope-boundaries.md`
- `Project-docs/phase-definition.md`

---

## Tareas Ya Suficientemente Especificadas

| Tarea | Documento | Revisiones completadas | Estado |
| --- | --- | --- | --- |
| T-0a-001 Desktop Workspace Shell | TS-0a-001 | QA Auditor (QA-REVIEW-0a-002) + Technical Architect (AR-0a-001) | CERRADO |
| T-0a-007 SQLCipher Local Storage | TS-0a-007 | QA Auditor (QA-REVIEW-0a-002) + Technical Architect (AR-0a-001) | CERRADO |

Corrección aplicada en TS-0a-007 durante este ciclo: inversión de dirección
de flujo en último criterio de aceptación (Importer → SQLCipher → Grouper).
Corrección validada arquitectónicamente. TS-0a-007 queda sin deuda documental.

---

## Revisiones Ya Ocurridas

| Revisión | Documento | Agente | Resultado |
| --- | --- | --- | --- |
| QA de task specs | QA-REVIEW-0a-002 | QA Auditor | APROBADO — sin bloqueos |
| Revisión arquitectónica TS-0a-001 | AR-0a-001 (sección A) | Technical Architect | APROBADO — sin bloqueos |
| Acuse de recibo arquitectónico TS-0a-007 | AR-0a-001 (sección B) | Technical Architect | APROBADO — corrección aceptada |

---

## Decisions Applied

| Decisión | Aplicación en este ciclo |
| --- | --- |
| D1 | Verificado campo a campo en TS-0a-007: URL y título cifrados, dominio y categoría en claro. |
| D6 | Sync excluida de TS-0a-001 con referencia explícita. Schema de TS-0a-007 sin campos de relay ni de sync. |
| D8 | LLM no es requisito en TS-0a-001 ni en TS-0a-007. Classifier no puede bloquear el INSERT por LLM. |
| D16 | INTEGER PRIMARY KEY + UUID indexado confirmado en schema de TS-0a-007. |

---

## Constraints Respected

- Este repositorio es exclusivamente el proyecto marco. Ningún entregable
  de este ciclo contiene implementación del producto.
- El repo del producto no se ha abierto y no debe abrirse todavía.
- Panel B ausente en TS-0a-001: ni componente ni placeholder. Clausurado
  en criterio de aceptación y señal de contaminación.
- Observer activo ausente: ni watcher de background, ni Accessibility API,
  ni FS Watcher en ningún módulo especificado.
- Sync ausente: ningún campo, endpoint ni estructura preparatoria en ninguno
  de los dos documentos.
- Episode Detector real ausente: TS-0a-001 lo excluye explícitamente.
  TS-0a-007 no contiene tabla de sesiones ni de episodios.
- R12 contenido: TS-0a-001 nombra la señal de contaminación con ID canónico
  y acción ESCALAR.
- iOS Share Extension Specialist: LOCKED en 0a.
- Session & Episode Engine Specialist: LOCKED en 0a.
- Sync & Pairing Specialist: LOCKED en 0a.

---

## Outputs Produced

| Entregable | Tipo | Estado |
| --- | --- | --- |
| `operations/task-specs/TS-0a-001-desktop-workspace-shell.md` | Especificación operativa | APROBADO |
| `operations/task-specs/TS-0a-007-sqlcipher-local-storage.md` | Especificación operativa (corrección aplicada) | APROBADO |
| `operations/qa-reviews/qa-review-phase-0a-task-specs.md` | Revisión QA de task specs | CERRADO |
| `operations/architecture-reviews/AR-0a-001-task-specs-review.md` | Revisión arquitectónica de task specs | CERRADO |
| `operations/handoffs/HO-002-phase-0a-spec-cycle-1.md` | Este handoff | COMPLETADO |

---

## Tareas Pendientes De Especificación

Las cinco tareas siguientes no tienen TS todavía. Deben especificarse en el
orden que impone el mapa de dependencias del backlog:

```
T-0a-007  [CERRADO]
    └── T-0a-002  Bookmark Importer       ← primer objetivo del próximo ciclo
            └── T-0a-003  Classifier      ← segundo
                    └── T-0a-004  Grouper ← tercero (R12 crítico aquí)
                            ├── T-0a-005  Panel A  ← cuarto
                            └── T-0a-006  Panel C  ← cuarto (paralelo con T-0a-005)
                                    └── T-0a-001  [CERRADO]
```

| Tarea | Owner documental | Revisión obligatoria | Riesgo principal |
| --- | --- | --- | --- |
| T-0a-002 Bookmark Importer | Desktop Tauri Shell Specialist | QA Auditor (D1, D12) | Reinterpretación como observer activo o caso núcleo |
| T-0a-003 Classifier | Desktop Tauri Shell Specialist | Technical Architect | Confusión con Episode Detector (R12 adyacente) |
| T-0a-004 Grouper | Desktop Tauri Shell Specialist | Technical Architect + QA Auditor | R12 — confusión Grouper 0a / Episode Detector 0b |
| T-0a-005 Panel A | Desktop Tauri Shell Specialist | Functional Analyst | Introducción de elementos de Panel B |
| T-0a-006 Panel C | Desktop Tauri Shell Specialist | QA Auditor (D8) | LLM como dependencia; Panel C vacío sin plantillas |

---

## Open Risks

| ID canónico | Riesgo | Estado | Acción en próximo ciclo |
| --- | --- | --- | --- |
| R1 | Confundir 0a con PMF | MITIGADO — vigilancia continua | Verificar que TS-0a-002 a TS-0a-006 no usan lenguaje de validación de producto |
| R2 | Bookmarks como caso núcleo | MITIGADO — vigilancia continua | TS-0a-002 debe clausurar el riesgo explícitamente (D12) |
| R7 | Pérdida de trazabilidad | ABIERTO — monitoreado | Cada TS debe citar los documentos normativos que lo sustentan |
| R9 | LLM como dependencia de Panel C | MITIGADO — vigilancia continua | TS-0a-006 debe confirmar baseline por plantillas sin LLM |
| R11 | Panel B como dependencia prematura | MITIGADO — vigilancia continua | TS-0a-005 es el documento de mayor riesgo; Panel B debe quedar ausente |
| R12 | Grouper 0a confundido con Episode Detector 0b | WATCH ACTIVO | TS-0a-003 y TS-0a-004 son los documentos de mayor exposición; diferenciación explícita obligatoria |

R12 es el riesgo más crítico del próximo ciclo. TS-0a-004 (Grouper) es el
documento donde R12 tiene mayor probabilidad de activación. La diferenciación
con el Episode Detector dual-mode de 0b debe ser explícita, con tabla de
atributos comparativos, igual que en arch-note.

---

## Blockers

**Ninguno.**

El segundo ciclo operativo cierra sin bloqueos. Los dos task specs revisados
están architectónicamente alineados y pueden servir como contratos de referencia
para los cinco task specs pendientes.

---

## Restricciones Que Siguen Vigentes En El Siguiente Ciclo

1. Este repositorio es el proyecto marco. Los cinco task specs pendientes son
   especificaciones operativas de gobernanza, no implementación del producto.
2. El repo del producto no debe abrirse hasta que el enjambre lo decida
   explícitamente mediante OD.
3. El siguiente ciclo sigue perteneciendo completamente a Fase 0a. Ningún
   task spec de 0a puede anticipar componentes, estructuras o narrativas de 0b.
4. Panel B permanece excluido de 0a y de 0b. Ningún TS de este ciclo lo
   introduce como componente ni como placeholder.
5. R12 en WATCH ACTIVO durante todo el ciclo. Cualquier señal de confusión
   entre el Grouper de 0a y el Episode Detector de 0b debe escalarse al
   Phase Guardian antes de continuar.
6. El Classifier (T-0a-003) es determinístico. No usa LLM, no usa Jaccard,
   no usa ventanas temporales. Si su especificación introduce alguno de estos
   elementos, debe bloquearse.
7. Los bookmarks se presentan siempre como bootstrap y cold start. Ningún
   task spec los presenta como validación del producto.

---

## Recommended Next Agent

**Desktop Tauri Shell Specialist**

Produce en el siguiente ciclo, en orden de dependencia:

1. **TS-0a-002** — Bookmark Importer Retroactive
   Referencia obligatoria: D1, D12, arch-note (contrato Bookmark Importer),
   backlog T-0a-002.
   Revisión tras producción: QA Auditor.

2. **TS-0a-003** — Domain/Category Classifier
   Referencia obligatoria: D2, D3, D8, arch-note (contrato Classifier),
   backlog T-0a-003.
   Revisión tras producción: Technical Architect (límite de módulo y
   diferenciación con Episode Detector).

3. **TS-0a-004** — Basic Similarity Grouper
   Referencia obligatoria: D2, D3, arch-note (tabla de diferenciación
   Grouper 0a / Episode Detector 0b), backlog T-0a-004, risk-register R12.
   Revisión tras producción: Technical Architect + QA Auditor.
   **Atención R12**: este es el documento de mayor exposición al riesgo de
   confusión. La diferenciación debe ser explícita, con tabla de atributos
   comparativos.

4. **TS-0a-005** y **TS-0a-006** (pueden producirse en paralelo una vez
   cerrado T-0a-004)
   TS-0a-005 Panel A: referencia D8, arch-note (contrato Panel A).
   Revisión: Functional Analyst.
   TS-0a-006 Panel C: referencia D8, arch-note (contrato Panel C).
   Revisión: QA Auditor (D8 baseline).

Cuando todos los task specs estén revisados y aprobados, el Handoff Manager
produce HO-003 para cerrar el ciclo de especificación completo de 0a y
determinar el siguiente paso (Phase Integrity Review o apertura del repo
de producto mediante OD).
