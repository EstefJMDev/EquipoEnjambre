# Backlog Funcional — Fase 0a

date: 2026-04-22
owner_agent: Functional Analyst
phase: 0a
status: APPROVED — primer ciclo operativo
referenced_decision: OD-001

---

## Functional Breakdown

phase: 0a
objective: Validar que el formato workspace genera valor.

validates:
- comprensión del contenedor workspace
- utilidad de la agrupación visual de recursos
- claridad del conjunto Panel A + Panel C como espacio de trabajo
- reacción inicial ante recursos agrupados y siguientes pasos sugeridos

does_not_validate:
- product-market fit
- hipótesis núcleo del puente móvil→desktop
- fiabilidad de sync
- aprendizaje del sistema
- confianza progresiva
- wow moment del puente
- Panel B (resumen; entra en Fase 1)

in_scope:
- app desktop Tauri mínima corriendo en macOS
- importación local de bookmarks Safari/Chrome (bootstrap/cold start)
- clasificador por dominio y categoría (reglas determinísticas)
- agrupador básico por similitud de título (heurística simple)
- Panel A: recursos agrupados con título, favicon, dominio, subtema
- Panel C: siguientes pasos generados por plantilla según tipo de contenido
- almacenamiento local cifrado con SQLCipher (D1, D16)

out_of_scope:
- Share Extension iOS
- sync de ningún tipo (iCloud, Google Drive, QR)
- Episode Detector dual-mode (preciso + broad — entra en 0b)
- Panel B (resumen — entra en Fase 1)
- Session Builder
- Pattern Detector
- Trust Scorer
- State Machine
- Explainability Log
- LLM local (ni como mejora; Panel C usa plantillas)
- Privacy Dashboard (mínimo o completo)
- backend propia
- observer activo de ningún tipo
- Accessibility APIs
- FS Watcher
- cualquier funcionalidad de 0b o de fases posteriores

dependencies:
- SQLCipher disponible como motor local (T-0a-007 es prerequisito de todos)
- Bookmark Importer (T-0a-002) como única fuente de recursos en 0a
- Classifier (T-0a-003) como prerequisito del Grouper (T-0a-004)
- Grouper (T-0a-004) como prerequisito de Panel A (T-0a-005) y Panel C (T-0a-006)
- Panel A y Panel C como prerequisitos del Desktop Shell (T-0a-001)

risks_of_misinterpretation:
- tratar el import de bookmarks como caso de uso núcleo en lugar de bootstrap
- confundir el Grouper básico de 0a con el Episode Detector dual-mode de 0b
- creer que una demo exitosa de 0a valida PMF o el puente
- introducir Panel B "para mejorar la demo" anticipando Fase 1
- introducir cualquier red, sync o observer activo
- adelantar Jaccard o similitud semántica del Episode Detector preciso de 0b

---

## Mapa De Dependencias

```
SQLCipher (T-0a-007)
    └── Bookmark Importer (T-0a-002)
            └── Classifier (T-0a-003)
                    └── Grouper (T-0a-004)
                            ├── Panel A (T-0a-005)
                            └── Panel C (T-0a-006)
                                    └── Desktop Shell (T-0a-001)
```

---

## Tareas Y Criterios De Aceptación

---

### T-0a-001 — Desktop Workspace Shell

task_id: T-0a-001
title: Contenedor desktop Tauri mínimo
phase: 0a
owner_agent: Desktop Tauri Shell Specialist

#### Objective
Definir los límites del shell desktop para 0a: qué contiene el contenedor
workspace, qué paneles están activos y qué queda explícitamente prohibido.

#### Documents To Read
- `project-docs/scope-boundaries.md`
- `project-docs/architecture-overview.md`
- `project-docs/module-map.md`
- `operations/architecture-notes/arch-note-phase-0a.md`

#### In Scope
- ventana Tauri 2 corriendo en macOS sin errores
- contenedor que aloja Panel A y Panel C
- almacenamiento local vía SQLCipher
- sin procesos de observación activa en background
- sin red iniciada por la app
- sin Accessibility APIs

#### Out Of Scope
- Panel B
- sync de ningún tipo
- background watcher
- captura activa de cualquier origen

#### Acceptance Criteria
- [ ] el contenedor Tauri corre en macOS sin errores
- [ ] Panel A y Panel C se renderizan dentro del contenedor
- [ ] no se inicia ninguna conexión de red desde la app
- [ ] no se usa ninguna API de observación activa
- [ ] Panel B no existe en esta versión

#### Risks
- que se añada Panel B "para dejarlo preparado" (contaminación de Fase 1)
- que se añada lógica de observación como placeholder (viola D9)
- que se añada un endpoint "temporal" para sync (viola D6)

#### Required Handoff
Al Technical Architect para confirmar que el contrato de módulo es coherente
con `arch-note-phase-0a.md`.

---

### T-0a-002 — Bookmark Importer Retroactive

task_id: T-0a-002
title: Importador local de bookmarks (bootstrap)
phase: 0a
owner_agent: Desktop Tauri Shell Specialist

#### Objective
Definir los límites del importador de bookmarks como mecanismo de bootstrap y
cold start. Dejar explícito que no es un observer activo ni el caso de uso
núcleo del producto.

#### Documents To Read
- `project-docs/scope-boundaries.md`
- `project-docs/decisions-log.md` (D1, D12)
- `project-docs/module-map.md` (Bookmark Importer Retroactive)

#### In Scope
- lectura local de bookmarks desde Safari y/o Chrome
- normalización de cada recurso: URL, título, dominio, categoría
- almacenamiento de recursos normalizados en SQLCipher (cifrado)
- operación de una sola pasada (no monitoring continuo)

#### Out Of Scope
- scraping de contenido completo de páginas (prohibido en D1)
- llamadas a red para enriquecer metadatos
- observación continua de nuevos bookmarks (observer activo — viola D9)
- cualquier rol de "caso de uso núcleo del MVP" (viola D12)

#### Acceptance Criteria
- [ ] los bookmarks se leen desde el filesystem local sin llamadas a red
- [ ] se normalizan URL, título y dominio para cada recurso
- [ ] no se almacena contenido completo de páginas (D1)
- [ ] los datos se cifran en SQLCipher antes de persistir (D1, D16)
- [ ] la importación es una operación discreta, no monitoring continuo (D9)
- [ ] el sistema no presenta los bookmarks como "señales del usuario" en el
  sentido de 0b

#### Risks
- que el importer se reinterprete como el observer de 0b (viola D9)
- que se amplíe para capturar contenido completo (viola D1)
- que se use como argumento de que "bookmarks ya validan el producto" (viola D12)

#### Required Handoff
Al QA Auditor para verificar que la especificación no viola D1 ni D12.

---

### T-0a-003 — Domain/Category Classifier

task_id: T-0a-003
title: Clasificador por dominio y categoría
phase: 0a
owner_agent: Desktop Tauri Shell Specialist (revisión obligatoria: Technical Architect)

#### Objective
Definir el clasificador básico de 0a: reglas determinísticas para asignar
dominio y categoría a cada recurso importado. Distinto del Episode Detector
dual-mode que entra en 0b.

#### Documents To Read
- `project-docs/module-map.md` (Episode Detector Dual-Mode — primera fase: 0b)
- `project-docs/decisions-log.md` (D2, D3)
- `operations/architecture-notes/arch-note-phase-0a.md`

#### In Scope
- asignación de dominio extraído de URL
- asignación de categoría por reglas determinísticas
- operación sobre datos locales únicamente

#### Out Of Scope
- aprendizaje longitudinal (Pattern Detector — Fase 2)
- similitud fina tipo Jaccard o embeddings (pertenece al Episode Detector de 0b)
- llamadas a red o LLM para clasificar
- inferencia de intención del usuario
- ventanas temporales de sesión (Session Builder — 0b)

#### Acceptance Criteria
- [ ] cada recurso importado recibe un dominio y una categoría
- [ ] la clasificación es determinística (mismo input produce mismo output)
- [ ] no requiere red ni LLM
- [ ] no implica aprendizaje ni memoria longitudinal
- [ ] el documento deja explícito que este clasificador NO es el Episode Detector

#### Risks
- que se confunda con el Episode Detector de 0b (R10 del risk register)
- que se añada similitud semántica con LLM "porque es trivial de añadir" (D8)

#### Required Handoff
Al Technical Architect para validar límite de módulo y diferenciación con
Episode Detector.

---

### T-0a-004 — Basic Similarity Grouper

task_id: T-0a-004
title: Agrupador básico por similitud de título
phase: 0a
owner_agent: Desktop Tauri Shell Specialist (revisión obligatoria: Technical Architect)

#### Objective
Definir el agrupador básico de 0a que produce clusters para Panel A. Dejar
explícita la diferencia con el Episode Detector dual-mode de 0b.

#### Documents To Read
- `project-docs/decisions-log.md` (D2, D3)
- `project-docs/module-map.md` (Episode Detector Dual-Mode — primera fase: 0b)
- `operations/architecture-notes/arch-note-phase-0a.md`

#### In Scope
- agrupación por dominio + categoría compartida (output del Classifier)
- sub-agrupación por similitud básica de título (heurística simple)
- operación sobre datos locales del Importer

#### Out Of Scope
- Jaccard similarity del Episode Detector preciso (pertenece a 0b, D3)
- clustering semántico con embeddings o LLM
- detección de episodios reales con ventana temporal (Session Builder — 0b)
- límites temporales de sesión de ningún tipo

#### Acceptance Criteria
- [ ] los recursos se agrupan por dominio y categoría
- [ ] la sub-agrupación produce clusters visibles y comprensibles en Panel A
- [ ] el grouper no depende de red ni de LLM
- [ ] el documento diferencia explícitamente este grouper del Episode Detector
- [ ] no se implementa lógica de ventana temporal de ningún tipo

#### Risks
- que el Grouper de 0a se confunda con el Episode Detector de 0b (R10)
- que se añada Jaccard "porque es un detalle técnico menor" (adelanto de 0b)

#### Required Handoff
Al QA Auditor para verificar diferenciación documentada con Episode Detector.

---

### T-0a-005 — Panel A

task_id: T-0a-005
title: Panel A — Recursos agrupados
phase: 0a
owner_agent: Desktop Tauri Shell Specialist

#### Objective
Definir el contrato de Panel A para 0a: qué muestra, con qué datos y qué
queda prohibido.

#### Documents To Read
- `project-docs/scope-boundaries.md`
- `project-docs/architecture-overview.md` (Workspace Layer)
- `operations/architecture-notes/arch-note-phase-0a.md`

#### In Scope
- lista de recursos agrupados por subtema
- por cada recurso: título real, favicon, dominio, agrupación visible
- organización visual que permita entender el contenido de la sesión

#### Out Of Scope
- resumen de los recursos (Panel B — Fase 1)
- siguientes pasos (Panel C — componente separado)
- generación con LLM de ningún tipo
- datos que requieran conexión de red

#### Acceptance Criteria
- [ ] Panel A muestra los recursos agrupados por subtema
- [ ] cada recurso muestra título, dominio y agrupación
- [ ] Panel A no incluye resumen ni bullets de contenido (eso es Panel B, Fase 1)
- [ ] Panel A no requiere red ni LLM para renderizarse
- [ ] Panel A se distingue visualmente de Panel C

#### Risks
- que se mezcle Panel A con elementos de Panel B (contaminación de Fase 1)
- que se añadan bullets de resumen "como mejora de UX" de 0a

#### Required Handoff
Al Functional Analyst para confirmar que Panel A satisface la hipótesis de
comprensión del workspace en 0a.

---

### T-0a-006 — Panel C

task_id: T-0a-006
title: Panel C — Siguientes pasos
phase: 0a
owner_agent: Desktop Tauri Shell Specialist

#### Objective
Definir el contrato de Panel C para 0a: checklist de siguientes pasos
generado por plantilla según el tipo de contenido. LLM es mejora opcional,
no requisito (D8).

#### Documents To Read
- `project-docs/scope-boundaries.md`
- `project-docs/decisions-log.md` (D8)
- `operations/architecture-notes/arch-note-phase-0a.md`

#### In Scope
- checklist de 3 a 5 acciones por plantilla
- generación basada en tipo de contenido del Classifier
- baseline siempre funcionando sin LLM (D8)

#### Out Of Scope
- generación con LLM como requisito (D8 lo prohíbe como dependencia)
- personalización avanzada del usuario
- memoria de acciones previas
- aprendizaje longitudinal

#### Acceptance Criteria
- [ ] Panel C muestra 3 a 5 acciones sugeridas para el tipo de contenido
- [ ] las acciones se generan por plantilla sin LLM (D8 baseline)
- [ ] las plantillas cubren los tipos de contenido presentes en la demo de 0a
- [ ] Panel C funciona sin red y sin LLM
- [ ] Panel C no depende de Panel B

#### Risks
- que se añada dependencia de LLM "para mejorar las sugerencias" (viola D8)
- que Panel C se vacíe porque las plantillas parecen genéricas sin LLM

#### Required Handoff
Al QA Auditor para verificar que el baseline de plantillas es suficiente y
que LLM no se ha convertido en dependencia.

---

### T-0a-007 — Local Encrypted Storage

task_id: T-0a-007
title: Almacenamiento local cifrado — SQLCipher
phase: 0a
owner_agent: Technical Architect

#### Objective
Definir el contrato de almacenamiento local para 0a: qué se almacena, cómo
se cifra y qué tablas quedan prohibidas hasta fases posteriores.

#### Documents To Read
- `project-docs/decisions-log.md` (D1, D16)
- `project-docs/module-map.md`
- `project-docs/architecture-overview.md`

#### In Scope
- SQLCipher sobre SQLite
- schema mínimo de 0a: tabla `resources` con URL, título, dominio, categoría
- INTEGER PRIMARY KEY + UUID indexado (D16)
- cifrado de URLs, títulos y metadatos (D1, Privacy Level 1)
- dominio puede mantenerse en claro (D1)

#### Out Of Scope
- almacenamiento de contenido completo de páginas (prohibido en D1)
- sincronización con iCloud o Google Drive (0b)
- tablas de sesiones o episodios (0b)
- tablas de patrones o trust score (Fase 2)
- schema completo "preparado para fases futuras"

#### Acceptance Criteria
- [ ] los recursos se almacenan cifrados en SQLCipher
- [ ] el schema usa INTEGER PRIMARY KEY + UUID indexado (D16)
- [ ] no se almacena contenido completo de páginas (D1)
- [ ] el dominio puede mantenerse en claro (D1)
- [ ] el schema de 0a no incluye tablas de 0b ni de fases posteriores
- [ ] la retención de datos cubre el período de la demo de 0a sin configuración
  adicional

#### Risks
- que se cree el schema completo "para ahorrar trabajo en 0b" (contaminación)
- que se almacene contenido completo por conveniencia de la demo (viola D1)

#### Required Handoff
Al QA Auditor para verificar cumplimiento de D1 y D16.

---

## Hipótesis Que 0a Debe Validar (Gate De Salida)

Antes de pasar el gate de 0a, debe existir evidencia de que:

- el equipo entiende el formato workspace
- la agrupación visual genera interés en observadores externos
- el contenedor workspace hace comprensible la intención de trabajo
- el equipo distingue claramente 0a de 0b
- los bookmarks siguen siendo descritos como bootstrap y no como caso núcleo
