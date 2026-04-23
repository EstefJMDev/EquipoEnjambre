# Standard Handoff

document_id: HO-003
from_agent: Handoff Manager
  (ciclo producido por: Desktop Tauri Shell Specialist)
to_agent: Technical Architect + QA Auditor (revisión conjunta)
status: ready_for_execution
phase: 0a
date: 2026-04-23
cycle: Tercer ciclo operativo — Revisión conjunta de TS-0a-005 (Panel A) y TS-0a-006 (Panel C)
closes: ciclo de especificación completo de Fase 0a — todos los task specs producidos
opens: revisión conjunta TS-0a-005 + TS-0a-006; preparación del gate de salida de Fase 0a

---

## Objective

Cerrar formalmente el ciclo de especificación de Fase 0a y activar la revisión
conjunta de los dos últimos task specs pendientes.

Con TS-0a-005 (Panel A) y TS-0a-006 (Panel C) producidos hoy, todos los task
specs de Fase 0a están disponibles en estado DRAFT o APROBADO. Este handoff
registra el estado completo del ciclo de especificación y activa la revisión
conjunta obligatoria de los dos últimos documentos.

Cuando Technical Architect y QA Auditor cierren sus revisiones sin bloqueos,
el ciclo de especificación de Fase 0a estará formalmente cerrado. El siguiente
paso tras ese cierre es la preparación del gate de salida de 0a.

---

## Context Read

Documentos leídos en este ciclo para producir TS-0a-005 y TS-0a-006:

- `operations/task-specs/TS-0a-004-basic-similarity-grouper.md`
- `operations/task-specs/TS-0a-003-domain-category-classifier.md`
- `operations/task-specs/TS-0a-001-desktop-workspace-shell.md`
- `operations/architecture-notes/arch-note-phase-0a.md`
- `operations/backlogs/backlog-phase-0a.md`
- `Project-docs/risk-register.md` (R9, R11, R12)
- `Project-docs/decisions-log.md` (D1, D8, D9, D12)

---

## Estado Completo Del Ciclo De Especificación De Fase 0a

| Task Spec | Documento | Revisiones completadas | Estado |
| --- | --- | --- | --- |
| T-0a-007 SQLCipher Local Storage | TS-0a-007 | QA Auditor (QA-REVIEW-0a-002) + Technical Architect (AR-0a-001) | APROBADO con corrección menor |
| T-0a-001 Desktop Workspace Shell | TS-0a-001 | QA Auditor (QA-REVIEW-0a-002) + Technical Architect (AR-0a-001) | APROBADO |
| T-0a-002 Bookmark Importer Retroactive | TS-0a-002 | QA Auditor (QA-REVIEW-TS-0a-002) | APROBADO |
| T-0a-003 Domain/Category Classifier | TS-0a-003 | Technical Architect (AR-0a-002) | APROBADO con corrección menor |
| T-0a-004 Basic Similarity Grouper | TS-0a-004 | Technical Architect (AR-0a-003) + QA Auditor (QA-REVIEW-TS-0a-004) | APROBADO con corrección menor |
| T-0a-005 Panel A | TS-0a-005 | pendiente | DRAFT |
| T-0a-006 Panel C | TS-0a-006 | pendiente | DRAFT |

Todos los task specs están producidos. Los dos únicos DRAFT son los que
activa este handoff para revisión conjunta.

---

## Outputs Producidos En Este Ciclo

| Entregable | Ruta | Estado |
| --- | --- | --- |
| Especificación operativa Panel A | `operations/task-specs/TS-0a-005-panel-a-recursos-agrupados.md` | DRAFT |
| Especificación operativa Panel C | `operations/task-specs/TS-0a-006-panel-c-siguientes-pasos.md` | DRAFT |
| Este handoff | `operations/handoffs/HO-003-phase-0a-spec-cycle-2.md` | COMPLETADO |

---

## Decisiones Aplicadas En Este Ciclo

| Decisión | Aplicación en TS-0a-005 | Aplicación en TS-0a-006 |
| --- | --- | --- |
| D1 | Panel A no accede a contenido completo de páginas; favicon solo desde caché local | Panel C no accede a contenido completo; plantillas operan únicamente sobre el campo `category` |
| D8 | Panel A no usa LLM (es puramente presentacional; no hay texto generado) | Panel C usa plantillas estáticas como baseline; LLM documentado como mejora opcional no bloqueante |
| D9 | Panel A no observa ni actualiza en tiempo real; renderizado estático sin polling | Panel C no detecta intención; no activa flujos automáticos; renderizado estático |
| D12 | Panel A renderiza datos de bootstrap (bookmarks importados); no los presenta como caso núcleo | Panel C opera sobre categorías de recursos de bootstrap; no implica validación de PMF |

---

## Constraints Respetadas En Este Ciclo

- Este repositorio es exclusivamente el proyecto marco. Ningún entregable
  de este ciclo contiene implementación del producto.
- El repo del producto no se ha abierto y no debe abrirse todavía.
- Panel B ausente en TS-0a-005 y TS-0a-006: ni componente, ni dependencia,
  ni placeholder en ninguna de las dos especificaciones.
- Observer activo ausente: Panel A y Panel C son estáticos; ninguno tiene
  polling, push ni proceso de fondo.
- Red ausente: favicon sin red en Panel A; plantillas sin red en Panel C.
- LLM correctamente tratado: ausente en Panel A (no aplica); optional
  enhancement no bloqueante en Panel C conforme a D8.
- R12 contenido por condición 2: ambos documentos citan la tabla de
  diferenciación Grouper 0a vs Episode Detector 0b de TS-0a-004.
- iOS Share Extension Specialist: LOCKED en 0a.
- Session & Episode Engine Specialist: LOCKED en 0a.
- Sync & Pairing Specialist: LOCKED en 0a.

---

## Riesgos Activos En El Momento Del Handoff

| ID | Riesgo | Estado | Relevancia para la revisión |
| --- | --- | --- | --- |
| R7 | Pérdida de trazabilidad | ABIERTO — monitoreado | TS-0a-005 y TS-0a-006 citan sus documentos normativos; las revisiones confirmarán trazabilidad |
| R9 | LLM como dependencia prematura de Panel C | WATCH — mitigado en TS-0a-006 | QA Auditor verifica que el baseline de plantillas funciona sin LLM; si la implementación invierte la relación, R9 se activa |
| R11 | Panel B como dependencia prematura | MITIGADO — vigilancia continua | Panel B explícitamente excluido en TS-0a-005 y TS-0a-006; las revisiones confirman ausencia |
| R12 | Confusión Grouper 0a vs Episode Detector 0b | WATCH ACTIVO | Condición 2 de contención aplicada en ambos documentos; Technical Architect y QA Auditor confirman que el control es operativo |

---

## Blockers

**Ninguno.**

TS-0a-005 y TS-0a-006 se producen sin bloqueos desde TS-0a-004.
La corrección menor de TS-0a-004 (conteo de atributos en tabla de
diferenciación: 14 → 15) no afecta el contrato de input de Panel A ni
el mecanismo de selección de plantillas de Panel C.

---

## Restricciones Que Siguen Vigentes

1. Este repositorio es el proyecto marco. Los dos task specs en revisión son
   especificaciones operativas de gobernanza, no implementación del producto.
2. El repo del producto no debe abrirse hasta que el enjambre lo decida
   explícitamente mediante OD.
3. Panel B permanece excluido de 0a. Ninguna revisión puede aprobar un
   documento que introduzca Panel B bajo ningún nombre.
4. R12 en WATCH ACTIVO. Las revisiones de TS-0a-005 y TS-0a-006 deben
   confirmar explícitamente que la condición 2 de contención es operativa
   en ambos documentos.
5. El LLM no puede convertirse en requisito duro de Panel C. Si la revisión
   detecta que la implementación esperada no puede funcionar sin LLM, R9 se
   activa y el documento debe bloquearse.
6. Los bookmarks se presentan siempre como bootstrap y cold start en los
   documentos de 0a. Las revisiones de Panel A y Panel C confirman que ninguno
   de los dos los presenta como validación del producto.

---

## Activación De La Revisión Conjunta

Este handoff activa dos revisiones paralelas e independientes. Ambas deben
completarse antes de que TS-0a-005 y TS-0a-006 puedan cerrarse.

### Track 1 — Technical Architect → AR-0a-004

El Technical Architect produce **AR-0a-004** cubriendo TS-0a-005 y TS-0a-006.

Para **TS-0a-005 (Panel A)**, el Technical Architect verifica:

- que Panel A no adelanta ningún elemento de Panel B
- que el contrato de input/output es coherente con arch-note-phase-0a.md
  (input: clusters del Grouper; output: lista visual título + favicon + dominio + subtema)
- que la restricción de favicon sin red es implementable con el perfil de
  exportación de bookmarks de 0a
- que Panel A no introduce acceso directo a SQLCipher ni invocaciones a módulos
  upstream durante el renderizado
- que la condición 2 de contención de R12 queda operativa (referencia a tabla
  de diferenciación de TS-0a-004)

Para **TS-0a-006 (Panel C)**, el Technical Architect verifica:

- que la aplicación de D8 es correcta: el baseline de plantillas funciona sin
  LLM y el LLM queda documentado como mejora opcional no bloqueante
- que el contrato de input/output es coherente con arch-note-phase-0a.md
  (input: clusters + tipo de contenido; output: checklist 3-5 acciones por
  plantilla según tipo de contenido)
- que Panel C no introduce acceso directo a SQLCipher ni invocaciones a módulos
  upstream durante el renderizado
- que la relación Panel C → campo `category` del Grouper está correctamente
  especificada y no anticipa lógica del Episode Detector de 0b
- que la condición 2 de contención de R12 queda operativa

### Track 2 — QA Auditor → QA-REVIEW-TS-0a-005-006

El QA Auditor produce **QA-REVIEW-TS-0a-005-006** cubriendo TS-0a-005 y
TS-0a-006.

Para **TS-0a-005 (Panel A)**, el QA Auditor verifica:

- que los criterios de aceptación son verificables externamente
- que el criterio de gate — "un observador externo entiende la organización
  del workspace sin explicación previa" — está correctamente incorporado y
  queda claro que requiere demo real
- que ningún criterio introduce ambigüedad que permita justificar Panel B,
  LLM, red o temporalidad dentro de 0a
- que la tabla de señales de contaminación cubre los vectores de riesgo más
  probables para Panel A
- que el control de R12 (condición 2) es operativo y trazable

Para **TS-0a-006 (Panel C)**, el QA Auditor verifica:

- que los criterios de aceptación son verificables externamente
- que el criterio de baseline sin LLM es verificable: existe una condición de
  verificación que confirme que Panel C funciona en ausencia de modelo local
- que el criterio de cobertura de categorías (las 10 categorías del Classifier
  tienen plantilla de fallback) es auditable
- que ningún criterio introduce ambigüedad que permita justificar LLM como
  dependencia, Panel B como prerequisito o temporalidad dentro de 0a
- que la tabla de señales de contaminación cubre los vectores de riesgo más
  probables para Panel C, incluido R9
- que el control de R12 (condición 2) es operativo y trazable

### Cierre De La Revisión Conjunta

Si ambas revisiones cierran sin bloqueos:

- TS-0a-005 actualiza status a APROBADO (con o sin corrección menor)
- TS-0a-006 actualiza status a APROBADO (con o sin corrección menor)
- el ciclo de especificación completo de Fase 0a queda formalmente cerrado

Si alguna revisión produce una corrección:

- el Desktop Tauri Shell Specialist aplica la corrección antes de cerrar
- el agente que produjo la corrección confirma el cierre
- el documento no puede cerrarse con la revisión de solo uno de los dos
  agentes requeridos

---

## Cadena Pendiente Tras Este Handoff

```
HO-003 [este handoff]
    ├── AR-0a-004 (Technical Architect — Panel A + Panel C)
    └── QA-REVIEW-TS-0a-005-006 (QA Auditor — Panel A + Panel C)
              ↓  (ambas sin bloqueos)
        Ciclo de especificación de Fase 0a: CERRADO
              ↓
        Preparación del gate de salida de Fase 0a
        (Phase Integrity Review de cierre de especificación + demo real)
```

Cuando ambas revisiones cierren, el Handoff Manager determina el siguiente
paso: Phase Integrity Review de cierre de especificación de 0a o activación
directa del proceso de demo para el gate de salida.
