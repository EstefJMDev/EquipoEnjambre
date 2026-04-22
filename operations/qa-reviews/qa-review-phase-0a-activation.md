# QA Review — Activación De Fase 0a

date: 2026-04-22
owner_agent: QA Auditor
phase: 0a
status: APPROVED — sin hallazgos bloqueantes
referenced_decision: OD-001

Revisión del primer ciclo operativo del enjambre. Verifica coherencia entre el
backlog funcional, la nota de arquitectura, las correcciones documentales y los
documentos normativos: scope-boundaries, decisions log y phase gates.

---

## 1. Checklist Global

| Ítem | Estado | Nota |
| --- | --- | --- |
| Protege el caso de uso núcleo (puente móvil→desktop) | PASS | 0a no toca el puente. Backlog y arch-note son desktop standalone. |
| Pertenece a la fase activa (0a) | PASS | Todos los componentes del backlog tienen primera_fase = 0a. |
| Respeta decisiones cerradas (D1-D18) | PASS — ver sección 3 | Revisión detallada abajo. |
| No introduce implementación funcional del producto | PASS | Todos los documentos son gobernanza: contratos, criterios, límites. |
| Declara inputs, outputs y límites duros | PASS | Cada tarea y cada contrato de módulo los declara explícitamente. |
| Deja trazabilidad y siguiente paso claro | PASS | OD-001 → backlog → arch-note → esta revisión → HO-001. |

---

## 2. Checklist De Scope Y Fase

| Ítem | Estado | Nota |
| --- | --- | --- |
| 0a no se describe como validación de PMF | PASS | El backlog y la arch-note lo explicitan bajo "does_not_validate". |
| 0b sigue siendo el puente móvil→desktop | PASS | No hay documentos de 0a que redefinan 0b. |
| Bookmarks son solo onboarding/cold start | PASS | T-0a-002 lo clausura. Invariante 9 de arch-note lo refuerza. |
| Desktop no aparece como observer activo en MVP | PASS | Invariante 1 de arch-note. T-0a-001 lo excluye explícitamente. |
| FS Watcher no aparece en 0a | PASS | Listado como módulo prohibido en arch-note. |
| Pattern Detector, Trust, State Machine no aparecen en 0a | PASS | Listados como módulos prohibidos. Layer prohibida. |
| Panel B no aparece en 0a ni en 0b | PASS | Clausurado en scope-boundaries.md, phase-definition.md y excluido en backlog + arch-note. |
| V1/V2+ no contaminan la ejecución de 0a | PASS | Ningún entregable del ciclo referencia líneas V1/V2+. |

---

## 3. Coherencia Contra Decisions Log (D1–D18)

| Decisión | Área | Estado | Referencia en entregables |
| --- | --- | --- | --- |
| D1 | Privacidad Level 1 | PASS | T-0a-007 y T-0a-002 clausuran contenido completo. Schema cifra URL + título. Dominio en claro. |
| D2 | Episode Detector dual-mode en 0b; Pattern Detector en Fase 2 | PASS | Arch-note diferencia Grouper 0a vs Episode Detector 0b. Módulos prohibidos listados. |
| D3 | Precisión Episode Detector = precise + broad fallback | PASS | No aplica a 0a. Grouper 0a es más simple; la distinción está documentada. |
| D4 | State Machine manda; trust_score es input | PASS | No aplica a 0a. State Machine listada como prohibida. |
| D5 | Slot concentration score | PASS | No aplica a 0a. |
| D6 | Sync MVP = relay cifrado iCloud/Google Drive | PASS | Sync PROHIBIDA en 0a. Sync Layer en capas prohibidas. |
| D7 | LAN en V1; P2P en V2+ | PASS | No aplica a 0a. |
| D8 | Plantillas como baseline; LLM como mejora opcional | PASS | Panel C usa plantillas. T-0a-006 y arch-note lo declaran. LLM no es requisito. |
| D9 | Único observer activo = Share Extension iOS; desktop no observa | PASS | Invariante 1. T-0a-001 y T-0a-002 lo clausuran. iOS Specialist LOCKED. |
| D10 | Fase 0 dividida en 0a y 0b | PASS | OD-001, backlog y arch-note preservan la separación. |
| D11 | macOS + iOS first | PASS | Shell es macOS. iOS no entra en 0a. |
| D12 | Único caso = puente móvil→desktop; bookmarks = onboarding | PASS | T-0a-002, invariante 9 y backlog risks_of_misinterpretation lo clausuran. |
| D13 | Narrativa = detecta y anticipa, sin reglas manuales | PASS | 0a no publica narrativa de producto; es validación interna de formato. |
| D14 | Privacy Dashboard progresivo | PASS | Dashboard prohibido en 0a. |
| D15 | Monetización no se optimiza antes de PMF | PASS | No aplica a 0a. |
| D16 | Schema = INTEGER PRIMARY KEY + UUID indexado | PASS | T-0a-007 lo especifica con el schema exacto. |
| D17 | Pattern Detector completo solo en Fase 2 | PASS | Pattern Detector listado como módulo prohibido. |
| D18 | Fase 0b incluye buffer de sync y escape QR | PASS | No aplica a 0a. Documentado para cuando llegue 0b. |

---

## 4. Coherencia Contra Phase Gates De Fase 0a

Los phase gates de 0a (`operating-system/phase-gates.md`) definen las
siguientes condiciones mínimas de paso:

| Condición mínima de paso | Cubierta por |
| --- | --- |
| el workspace se entiende | T-0a-001, T-0a-005, T-0a-006 + criterios de aceptación |
| la agrupación se entiende | T-0a-004, T-0a-005 + criterios de aceptación |
| el contenedor genera interés | T-0a-001 + criterios de aceptación |
| el equipo distingue claramente 0a de 0b | backlog (does_not_validate), arch-note (tabla diferenciación Grouper vs Episode Detector) |
| bookmarks se describen como bootstrap/onboarding | T-0a-002, backlog risks_of_misinterpretation, invariante 9 de arch-note |

| Condición de no-paso | Protegida por |
| --- | --- |
| el workspace no se entiende | criterios de aceptación bloqueantes en T-0a-001, T-0a-005 |
| la agrupación no genera valor percibido | criterios de aceptación bloqueantes en T-0a-004, T-0a-005 |
| 0a se interpreta como validación de PMF | backlog does_not_validate + phase-definition clausurado |
| el equipo no distingue 0a de 0b | arch-note diferenciación Grouper/Episode Detector + phase-definition |
| bookmarks se reinterpretan como caso núcleo | T-0a-002, R2 del risk register, D12 |

---

## 5. Revisión De Correcciones Documentales

| Corrección | Archivo | Estado | Verificación |
| --- | --- | --- | --- |
| `default_state: LISTENING` → `default_state: ACTIVE` | `agents/09_desktop_tauri_shell_specialist.md` | COMPLETADA | El archivo ahora declara ACTIVE, coherente con la matriz (ACTIVE en 0a, 0b, 1). |
| Panel B añadido a exclusiones de 0a | `project-docs/scope-boundaries.md` | COMPLETADA | La sección "No incluye" de 0a incluye "Panel B del workspace (entra en Fase 1)". |
| Panel B añadido a exclusiones de 0b | `project-docs/scope-boundaries.md` | COMPLETADA | La sección "No incluye" de 0b incluye "Panel B del workspace (entra en Fase 1)". |
| Clausura de ambigüedad Panel B en 0a | `project-docs/phase-definition.md` | COMPLETADA | Nueva sección "Workspace en esta fase" clausura Panel B para 0a. |
| Clausura de ambigüedad Panel B en 0b | `project-docs/phase-definition.md` | COMPLETADA | Nueva sección "Workspace en esta fase" clausura Panel B para 0b y aclara que no invalida el wow moment. |

---

## 6. Hallazgos

### Hallazgo H-001 — Riesgo activo: confusión Grouper 0a vs Episode Detector 0b

Severidad: WATCH (no bloqueante, pero requiere vigilancia activa)

El Grouper básico de 0a (T-0a-004) opera sobre datos similares a los que
procesará el Episode Detector de 0b, y ambos producen agrupaciones de recursos.
Sin la diferenciación documentada, un agente o un desarrollador podría
reutilizar el Grouper de 0a como base del Episode Detector de 0b y colapse
la separación entre fases.

La arch-note incluye una tabla de diferenciación explícita. El riesgo sigue
abierto como R10 del risk register.

Mitigación activa: Phase Guardian debe verificar que ningún entregable de 0b
referencie el Grouper de 0a como "versión inicial del Episode Detector".

### Hallazgo H-002 — Panel B clausurado pero requiere confirmación en futuras sesiones

Severidad: NOTE (informativo)

La clausura de Panel B es correcta y está en tres documentos. Sin embargo,
la spec del producto (`FlowWeaver/flowweaver-product-spec-for-repo.md`) sección 10
describe los tres paneles juntos sin anotación de fase. Cuando se cree el repo
de producto, la spec deberá incluir una nota explícita en la sección de Fase 0b
indicando que Panel B no forma parte del workspace de 0b.

Esta corrección pertenece al repo de producto, no a este repositorio marco.
Se documenta aquí para no perder la trazabilidad.

### Hallazgo H-003 — Métricas cuantitativas de la spec no incorporadas en phase gates

Severidad: NOTE (informativo)

La spec del producto (sección 17) define métricas técnicas y de valor para
el MVP (precisión Episode Detector >60%, ACK <60s, etc.). Los phase gates de
0b en este repositorio definen condiciones de paso cualitativas. Cuando llegue
el ciclo de gobernanza de 0b, el Functional Analyst y el QA Auditor deberán
incorporar estas métricas como condiciones cuantitativas de paso del gate de 0b.

---

## 7. Decisión Del QA Auditor

Estado del primer ciclo operativo: **APPROVED**

- Todos los checklists globales pasan.
- Todas las decisiones D1-D18 relevantes para 0a están cubiertas.
- Todas las correcciones documentales están completadas y verificadas.
- Los phase gates de 0a tienen cobertura suficiente con el backlog producido.
- Los hallazgos son de tipo WATCH y NOTE; ninguno es bloqueante.

El ciclo puede pasar a Handoff Manager para cierre formal.

Siguiente agente recomendado: Handoff Manager → HO-001
