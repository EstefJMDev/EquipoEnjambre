# Standard Handoff

document_id: HO-028
from_agent: Orchestrator
to_agent: Functional Analyst
status: ready_for_execution
phase: 3 (T-3-006 nueva + scope extension de T-3-005 — preparación documental)
date: 2026-05-04
cycle: Aprobación de CR-004 (Classifier enrichment Capas A y B) y activación
       del Functional Analyst para actualización de TS-0a-003 y
       backlog-phase-3.md
depends_on: CR-004 (2026-05-04), AR-CR-004 (Technical Architect, 2026-05-04,
            APROBADO CON CONDICIONES), PGR-CR-004 (Privacy Guardian,
            2026-05-04, APROBADO CON CONDICIONES)
unblocks: actualización formal de TS-0a-003 (sección Capa A nueva +
          exclusiones matizadas), incorporación de T-3-006 al
          backlog-phase-3.md, scope extension de T-3-005 al Classifier.
          Tras esos commits del Functional Analyst, el Technical Architect
          puede emitir la TS ejecutable de T-3-006 con AC-A1..AC-A8 ya
          declarados en AR-CR-004.

---

## Objective

Notificar formalmente al Functional Analyst que CR-004 está APROBADO
por el Orchestrator. La aprobación se basa en la composición conjunta
de:

- **CR-004** (`operations/change-requests/CR-004-classifier-enrichment.md`)
  — propuesta de Capa A (inferencia determinística) y Capa B (LLM
  opcional como scope extension de T-3-005).
- **AR-CR-004** (`operations/architecture-reviews/AR-CR-004-classifier-enrichment.md`)
  — Technical Architect aprueba con condiciones, emite AC-A1..AC-A8 para
  Capa A y AC-B1..AC-B7 para Capa B.
- **PGR-CR-004** (`operations/architecture-reviews/PGR-CR-004-classifier-enrichment.md`)
  — Privacy Guardian aprueba con condiciones, declara controles
  PG-A1..PG-A5 (auditoría diccionario) y PG-B1..PG-B5 (input LLM).

El Functional Analyst debe ahora producir dos commits independientes
que materialicen la aprobación en TS y backlog. La implementación en
FlowWeaver queda bloqueada hasta que esos dos commits existan y la TS
de T-3-006 sea emitida por el Technical Architect.

---

## Context Read

| Documento | Lectura |
|---|---|
| `operations/change-requests/CR-004-classifier-enrichment.md` | LEÍDO — propuesta original con dos capas y restricciones declaradas |
| `operations/architecture-reviews/AR-CR-004-classifier-enrichment.md` | LEÍDO — contrato `classify(url, title) -> Classified` preservado; `lookup_category` ampliada con 3 pasos antes del fallback `otro`; AC-A1..AC-A8 + AC-B1..AC-B7 emitidos |
| `operations/architecture-reviews/PGR-CR-004-classifier-enrichment.md` | LEÍDO — Capa A compatible con D1 sin controles nuevos; Capa B bajo 4 condiciones; controles PG-A1..PG-A5 + PG-B1..PG-B5 |
| `operations/task-specs/TS-0a-003-domain-category-classifier.md` | LEÍDO — exclusiones explícitas a matizar en §"Qué NO Hace" |
| `operations/backlogs/backlog-phase-3.md` | LEÍDO — T-3-005 condicional vigente; T-3-006 a añadir en posición correcta del mapa de dependencias |
| `Project-docs/decisions-log.md` | LEÍDO — D1, D4, D8, D14, D17 vigentes |

---

## Decisions Applied

### Aprobación final del CR-004

El Orchestrator aprueba CR-004 con el siguiente perímetro:

1. **Capa A — APROBADA** para implementación en Fase 3 como tarea
   nueva **T-3-006**. El Functional Analyst la incorpora al
   backlog-phase-3.md siguiendo el patrón de T-3-001..T-3-005.
2. **Capa B — APROBADA como scope extension de T-3-005** con la
   condicionalidad existente preservada: solo se activa por OD
   explícita del Orchestrator basada en datos de beta de T-3-002 y
   T-3-003 que muestren que `otro` sigue siendo no despreciable
   (cota propuesta por AR-CR-004: > 10 % de capturas con `otro`
   tras Capa A).
3. **TS-0a-003 — actualizable** en sección "Qué NO Hace" para
   matizar (no eliminar) las dos filas afectadas, y para incorporar
   sección nueva "Capa A — Inferencia determinística" con
   diccionario mínimo viable y criterios de aceptación.
4. **decisions-log.md — D8 con nota aclaratoria**. La actualización
   de D8 NO es responsabilidad del Functional Analyst en este
   handoff: el Context Guardian la materializará cuando T-3-005
   con scope ampliado se active formalmente. Aquí basta con que la
   TS y el backlog dejen evidencia del scope extension.

### Composición de las restricciones de las tres revisiones

| Origen | Restricción | Owner de incorporación |
|---|---|---|
| AR-CR-004 §1 | Contrato público `classify(url, title)` se preserva. `lookup_category` recibe `path_tokens` y `title_tokens`. | Functional Analyst (TS-0a-003) |
| AR-CR-004 §2 | Diccionario estático en código, ≤ 200 entradas, mínimo viable 5 categorías × 8-10 keywords. | Functional Analyst (TS-0a-003) |
| AR-CR-004 §3 | O(1) amortizado verificable por benchmark (AC-A4). | Functional Analyst (referencia) + Technical Architect (TS T-3-006) |
| AR-CR-004 §4 | Input del LLM exclusivamente `(domain, path_tokens)`. | Functional Analyst (backlog T-3-005 ampliado) |
| AR-CR-004 §5 | T-3-006 prerequisito de Capa B. | Functional Analyst (mapa de dependencias) |
| PGR-CR-004 §3 | Auditoría del diccionario PG-A1..PG-A5. | Functional Analyst (TS-0a-003) |
| PGR-CR-004 §4 | Input LLM ratificado + tests estructurales PG-B1..PG-B5. | Functional Analyst (backlog T-3-005 ampliado) |
| PGR-CR-004 §5 condición 4 | Privacy Dashboard incluye sección "Modelo local — clasificador" cuando Capa B activa. | Functional Analyst (backlog T-3-005 ampliado) |
| PGR-CR-004 §6 PGR-R7 | Capa B se instala con valor por defecto OFF. Activación manual del usuario. | Functional Analyst (backlog T-3-005 ampliado) |

---

## Constraints Respected

- **D1** — Privacy Guardian ratifica que ni Capa A ni Capa B
  introducen acceso a campos cifrados de SQLCipher. El Classifier
  opera upstream del cifrado.
- **D4** — el Classifier no toma decisiones de acción. La autoridad
  de transición sigue exclusivamente en `state_machine.rs`. Capa B
  no rompe esto.
- **D8** — el baseline determinístico (tabla + Capa A) sigue
  funcionando sin LLM. Capa B es enriquecedor opcional. AC-B5
  obliga a `cargo test` verde con y sin Ollama.
- **D14** — Privacy Dashboard se amplía cuando Capa B esté activa
  con sección visible y control de desactivación.
- **D17** — Pattern Detector cerrado en Fase 2 no se toca. T-3-006
  vive en Fase 3 sin reabrir Fase 2.
- **R12** — Pattern Detector ≠ Episode Detector ≠ Classifier. Capa
  B opera dentro del Classifier sin invocar a los otros módulos
  cerrados.

---

## Outputs Produced

Este handoff produce dos cosas:

1. **Aprobación formal de CR-004** — el Orchestrator declara que
   las tres revisiones (CR + AR + PGR) componen una decisión
   coherente y aprobable. La fila correspondiente en
   `decisions-log.md` se considera implícita: el handoff es la
   trazabilidad ejecutiva.

2. **Activación del Functional Analyst** con scope ejecutable:
   - actualizar TS-0a-003 (commit 5)
   - actualizar backlog-phase-3.md (commit 6)

---

## Open Risks

| ID | Riesgo | Mitigación |
|---|---|---|
| HO-028-R1 | El Functional Analyst incluye Capa B en la actualización de TS-0a-003 contaminando el documento de Fase 0a con scope de Fase 3. | TS-0a-003 mantiene su anclaje en Fase 0a. La sección Capa A nueva debe declarar explícitamente que es una extensión aprobada por CR-004 con implementación en Fase 3 (T-3-006). Capa B se documenta solo en backlog-phase-3.md (T-3-005 ampliado). |
| HO-028-R2 | La actualización de las exclusiones de TS-0a-003 elimina filas en lugar de matizarlas, perdiendo trazabilidad histórica. | Las dos filas ("Clasificación por título sin dominio" y "Fallback a LLM si dominio no está en tabla") se conservan con nota de matización referenciando CR-004. No se eliminan. |
| HO-028-R3 | El backlog-phase-3.md se reordena perdiendo coherencia del mapa de dependencias. | T-3-006 se inserta tras T-3-005 con dependency declarada. El mapa de dependencias ASCII se actualiza para reflejar la nueva tarea como independiente de P-0/P-1 (T-3-006 puede arrancar antes de la beta pública porque mejora la calidad de la clasificación que alimentará la telemetría). |

---

## Blockers

Ninguno. El Functional Analyst puede ejecutar este handoff de forma
inmediata. Los documentos referenciados están commiteados en `main`
del repo EquipoEnjambre.

---

## Required Documents To Update

| Documento | Cambio | Commit |
|---|---|---|
| `operations/task-specs/TS-0a-003-domain-category-classifier.md` | Matizar §"Qué NO Hace" para las dos filas afectadas (sin eliminar). Añadir sección nueva "Capa A — Inferencia determinística" con: (a) contrato actualizado de `classify(url, title)` y `lookup_category(domain, path_tokens, title_tokens)`; (b) diccionario mínimo viable de 5 categorías × 8-10 keywords; (c) controles PG-A1..PG-A5; (d) cota dura ≤ 200 entradas; (e) referencia a CR-004 / AR-CR-004 / PGR-CR-004; (f) nota de implementación en Fase 3 (T-3-006). | commit 5 |
| `operations/backlogs/backlog-phase-3.md` | (a) Añadir T-3-006 con: scope, AC-A1..AC-A8, dependencias (P-0 y P-1 NO bloquean T-3-006 — la tarea es paralelizable a la infraestructura de beta), risks. (b) Actualizar T-3-005 con scope extension al Classifier: añadir párrafo "Scope extension via CR-004", AC-B1..AC-B7, controles PG-B1..PG-B5, restricción de input `(domain, path_tokens)`, requisito de sección Privacy Dashboard cuando esté activa, valor por defecto OFF. (c) Actualizar mapa de dependencias ASCII para mostrar T-3-006. (d) Mantener todas las restricciones existentes de T-3-005 (D8, condicionalidad). | commit 6 |

**No actualizar `Project-docs/decisions-log.md` en este handoff.**
La nota aclaratoria de D8 entra al decisions-log cuando el Context
Guardian la materialice tras la activación efectiva de T-3-005
ampliado. En este handoff basta con que el backlog y la TS dejen la
trazabilidad documentada.

---

## Recommended Next Step

El Functional Analyst ejecuta los commits 5 y 6 en este orden:

1. **Commit 5:** `docs(TS-0a-003): actualizar exclusiones + añadir Capa A`
   — solo el archivo `operations/task-specs/TS-0a-003-domain-category-classifier.md`.
2. **Commit 6:** `docs(backlog-phase-3): añadir T-3-006 + scope T-3-005`
   — solo el archivo `operations/backlogs/backlog-phase-3.md`.

Tras ambos commits, el Functional Analyst notifica al Technical
Architect que puede emitir la **TS ejecutable de T-3-006**
(documento independiente fuera del scope de este handoff) con
AC-A1..AC-A8 desglosados en pasos de implementación.

La implementación en FlowWeaver de T-3-006 queda bloqueada hasta
que esa TS exista y sea aprobada por Privacy Guardian (re-auditoría
declarada en PGR-CR-004 §8).

---

## Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Aprobado | operations/change-requests/CR-004-classifier-enrichment.md | APROBADO por Orchestrator (este handoff) |
| Aprobado | operations/architecture-reviews/AR-CR-004-classifier-enrichment.md | APROBADO CON CONDICIONES (Technical Architect, 2026-05-04) |
| Aprobado | operations/architecture-reviews/PGR-CR-004-classifier-enrichment.md | APROBADO CON CONDICIONES (Privacy Guardian, 2026-05-04) |
| Pendiente | operations/task-specs/TS-0a-003-domain-category-classifier.md | actualización por Functional Analyst (commit 5) |
| Pendiente | operations/backlogs/backlog-phase-3.md | actualización por Functional Analyst (commit 6) |
| Creado | operations/handoffs/HO-028-cr-004-classifier-enrichment-approval.md | este documento |
