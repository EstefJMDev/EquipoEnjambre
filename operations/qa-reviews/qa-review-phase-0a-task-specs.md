# QA Review — Task Specifications Fase 0a

document_id: QA-REVIEW-0a-002
reviewer_agent: QA Auditor
phase: 0a
date: 2026-04-22
status: CERRADO — sin bloqueos; corrección menor aplicada
documents_reviewed:
  - operations/task-specs/TS-0a-001-desktop-workspace-shell.md
  - operations/task-specs/TS-0a-007-sqlcipher-local-storage.md
references_checked:
  - operations/architecture-notes/arch-note-phase-0a.md
  - operating-system/phase-gates.md
  - Project-docs/scope-boundaries.md
  - Project-docs/phase-definition.md
  - Project-docs/decisions-log.md (D1, D6, D8, D16)
  - Project-docs/risk-register.md (R11, R12)

---

## Resultado Global

| Documento | Resultado | Bloqueos | Correcciones aplicadas |
| --- | --- | --- | --- |
| TS-0a-001 | APROBADO | ninguno | ninguna |
| TS-0a-007 | APROBADO con corrección menor | ninguno | 1 — inversión de dirección de flujo |

---

## 1. Revisión de TS-0a-001 — Desktop Workspace Shell

### 1.1 Coherencia con Fase 0a

PASS. El documento delimita el shell a Panel A + Panel C. No introduce Panel B,
sync, observer activo ni Episode Detector. La sección "Qué NO valida" usa lenguaje
de exclusión explícita coherente con la hipótesis de 0a definida en phase-definition:
validar el formato workspace, no PMF.

### 1.2 Coherencia con arch-note-phase-0a.md

PASS. Contrato del módulo Desktop Workspace Shell alineado punto a punto:

| Atributo del contrato | arch-note | TS-0a-001 | Estado |
| --- | --- | --- | --- |
| input | recursos agrupados del Grouper | clusters de T-0a-004 | ✅ |
| output | ventana Tauri con Panel A + Panel C | Panel A y Panel C renderizados | ✅ |
| sin red | sí | criterio de aceptación explícito | ✅ |
| sin observer activo | sí | criterio de aceptación explícito | ✅ |
| sin background watcher | sí | listado en "No Incluye" | ✅ |
| sin Panel B | sí | criterio de aceptación y señal de contaminación | ✅ |
| sin Share Extension | sí | listado en "No Incluye" | ✅ |
| sin sync | sí | listado en "No Incluye" con D6 | ✅ |

Dependencias declaradas (T-0a-007, T-0a-004, T-0a-005, T-0a-006, T-0a-002)
coinciden con los módulos activos del arch-note. Ninguna dependencia apunta a un
módulo prohibido en 0a.

### 1.3 Coherencia con phase-gates.md

PASS. El último criterio de aceptación ("un observador externo entiende la
organización del workspace sin explicación previa") reproduce exactamente la
condición mínima del gate de salida de 0a. La nota que aclara que este criterio
requiere demo real y no es verificable automáticamente es coherente con la lógica
del gate: el gate no pasa por completitud documental sino por evidencia suficiente.

### 1.4 Coherencia con scope-boundaries.md

PASS. Todos los elementos in-scope de 0a están reflejados. Panel B listado en
"No Incluye" con primera fase permitida = Fase 1, consistente con scope-boundaries.

### 1.5 Coherencia con phase-definition.md

PASS. El workspace de TS-0a-001 tiene Panel A y Panel C únicamente, idéntico a
lo definido en phase-definition para 0a. La prohibición de Panel B está explícita
y cita las fuentes normativas correctas.

### 1.6 Coherencia con decisiones D1, D6, D8, D16

| Decisión | Verificación en TS-0a-001 | Estado |
| --- | --- | --- |
| D1 — Privacidad Nivel 1 | "lectura de datos desde SQLCipher" delega el cumplimiento a TS-0a-007; no introduce campos ni narrativa que viole D1 | ✅ |
| D6 — Sync MVP | Sync excluida con referencia explícita a D6 en tabla "No Incluye" | ✅ |
| D8 — LLM no requisito | "LLM local como requisito | nunca como requisito | D8" en tabla "No Incluye" | ✅ |
| D16 — Schema BD | TS-0a-001 no define schema; delega correctamente a TS-0a-007 | ✅ |

### 1.7 Ausencia de contaminación de fase

PASS.

| Control | Resultado |
| --- | --- |
| Panel B ausente | ✅ — tabla "No Incluye" + criterio de aceptación + señal de contaminación |
| Sync ausente | ✅ — D6 referenciado |
| Observer desktop ausente | ✅ — D9 referenciado; "desktop no observa" explícito |
| Episode Detector real ausente | ✅ — tabla "Qué NO valida" |
| Trabajo de 0b ausente | ✅ — Share Extension, Session Builder, sync: todos excluidos con primera fase permitida |
| Especificación de proyecto marco, no implementación | ✅ — nota de gobernanza explícita |

### 1.8 Contención de R12

PASS. TS-0a-001 incluye en "Señales de Contaminación de Fase":

> "el Grouper podría usar el Episode Detector de 0b" → ESCALAR — R12 activo

El riesgo R12 está correctamente etiquetado con el ID canónico y la acción es
la correcta (escalar, no solo bloquear, porque es un riesgo de confusión
documental activa).

---

## 2. Revisión de TS-0a-007 — SQLCipher Local Storage

### 2.1 Coherencia con Fase 0a

PASS. El documento justifica la presencia de SQLCipher en 0a por tres razones
operativas concretas (persistencia entre sesiones, D1 no aplazable, workspace
reproducible para demo). La justificación no amplía el scope: aclara por qué el
módulo existe en esta fase sin introducir funcionalidad de fases posteriores.

### 2.2 Coherencia con arch-note-phase-0a.md

PASS. Schema idéntico:

| Campo | arch-note | TS-0a-007 | Estado |
| --- | --- | --- | --- |
| id INTEGER PRIMARY KEY | sí | sí | ✅ |
| uuid TEXT NOT NULL (indexado) | sí | sí + CREATE UNIQUE INDEX | ✅ |
| url TEXT NOT NULL (cifrado) | sí | sí | ✅ |
| title TEXT NOT NULL (cifrado) | sí | sí | ✅ |
| domain TEXT NOT NULL (en claro) | sí | sí | ✅ |
| category TEXT NOT NULL | sí | sí | ✅ |
| sin tablas de sesiones/episodios/patrones/trust | sí | tablas prohibidas listadas explícitamente | ✅ |

### 2.3 Coherencia con phase-gates.md

PASS. El gate de 0a no incluye criterios directos sobre el storage, pero el
cumplimiento de D1 (privacidad en reposo desde el inicio) es prerrequisito
implícito para cualquier demo con datos reales. TS-0a-007 lo satisface.

### 2.4 Coherencia con scope-boundaries.md

PASS. SQLCipher está in-scope en 0a. La exclusión de sync payload, sessions,
pattern data y trust data coincide con los elementos out-of-scope de scope-boundaries.

### 2.5 Coherencia con phase-definition.md

PASS. Ningún campo ni tabla introduce elementos de fases posteriores. Las
secciones "Prohibido en 0a porque pertenece a 0b / Fase 1 / Fase 2" trazan
exactamente las fronteras de phase-definition.

### 2.6 Coherencia con decisiones D1, D6, D8, D16

| Decisión | Verificación en TS-0a-007 | Estado |
| --- | --- | --- |
| D1 | URL y título cifrados; dominio y categoría en claro; justificación normativa por campo | ✅ |
| D6 | "El relay de sync usará este storage en 0b. El schema de 0a debe ser compatible sin adelantarlo" — sin campos de relay en 0a | ✅ |
| D8 | "El Classifier que alimenta `category` no puede usar LLM como requisito. Si lo usa como mejora, no debe bloquear el INSERT" | ✅ |
| D16 | INTEGER PRIMARY KEY + UUID indexado con CREATE UNIQUE INDEX | ✅ |

### 2.7 Ausencia de tablas de fases futuras

PASS.

| Control | Resultado |
| --- | --- |
| Sin tabla `sessions` / `episodes` | ✅ — listado como prohibido con trazabilidad a D10 |
| Sin payload de sync | ✅ — prohibido; trazabilidad a D6 |
| Sin tabla `patterns` / `pattern_signals` | ✅ — prohibido; trazabilidad a D2, D17 |
| Sin `trust_score` | ✅ — prohibido; trazabilidad a D4 |
| Sin `state_transitions` | ✅ — prohibido; trazabilidad a D4 |
| Sin `explainability_log` | ✅ — prohibido; trazabilidad a D14 |
| Sin `content_body` | ✅ — prohibido permanentemente; D1 |
| Sin schema "preparado para el futuro" | ✅ — regla operativa explícita contra tablas vacías |

### 2.8 Contención de R12

PASS parcial — sin violación activa. TS-0a-007 es un contrato de storage; R12
aplica principalmente a documentos que describen el Grouper. El documento no
introduce lenguaje que confunda el Grouper de 0a con el Episode Detector. La
sección "Prohibido en 0a" excluye correctamente las tablas propias del Session
Builder y del Episode Detector.

### 2.9 Especificación de proyecto marco

PASS. Nota de gobernanza explícita: "Esta especificación no autoriza
implementación en el repo de producto."

---

## 3. Corrección Aplicada

### Error: inversión de dirección de flujo en criterio de aceptación de TS-0a-007

**Ubicación**: criterios de aceptación, último ítem (línea 171-172 antes de la corrección)

**Texto original**:
> el módulo pasa datos al Bookmark Importer (T-0a-002) y al Grouper (T-0a-004)
> sin violaciones de los contratos de módulo definidos en arch-note

**Problema**: La dirección declarada es inversa a la del arch-note.
Según el arch-note, el Bookmark Importer almacena recursos EN SQLCipher
(Importer → SQLCipher). SQLCipher no pasa datos al Importer; el Importer escribe
en SQLCipher. SQLCipher sí sirve datos al Grouper.

**Texto corregido**:
> el módulo recibe datos del Bookmark Importer (T-0a-002) y los sirve al
> Grouper (T-0a-004) sin violaciones de los contratos de módulo definidos en
> arch-note

**Impacto**: Menor. No afecta el schema ni los contratos de D1 o D16. Sí afecta
la claridad del contrato de integración y podría generar confusión en la
implementación si el criterio se traslada sin corrección al repo de producto.

**Acción tomada**: Corrección aplicada directamente en TS-0a-007. No requiere
revisión adicional del Technical Architect para este ítem aislado.

---

## 4. Hallazgos Generales

| Tipo | Descripción | Acción |
| --- | --- | --- |
| PASS | TS-0a-001: coherencia completa con todos los documentos de referencia | ninguna |
| PASS | TS-0a-007: schema mínimo, D1 y D16 cumplidos, sin tablas de fases futuras | ninguna |
| CORRECCIÓN MENOR | TS-0a-007: inversión de dirección de flujo en último criterio de aceptación | aplicada |
| OBSERVACIÓN | R12 no se menciona explícitamente en TS-0a-007 | aceptable — R12 aplica al Grouper, no al storage |

No se encontraron contradicciones bloqueantes, señales de contaminación de fase,
referencias a riesgos con IDs no canónicos ni texto de implementación de producto.

---

## 5. Bloqueos

**Ninguno.**

Ambos documentos pueden avanzar al siguiente paso del handoff definido en su
sección "Handoff Esperado".

---

## 6. Siguiente Agente Responsable

**Technical Architect**

Razón: TS-0a-001 tiene pendiente la revisión del Technical Architect ("confirma
coherencia con arch-note-phase-0a.md, en especial los contratos de módulo de
Desktop Workspace Shell y de Panel A y Panel C"). Esta revisión está prevista
en el handoff de TS-0a-001 y no puede ser sustituida por la revisión QA.

TS-0a-007 ya fue producida por el Technical Architect. La corrección menor
aplicada no requiere un ciclo completo de revisión, pero el Technical Architect
debe acusar recibo antes de que el Handoff Manager cierre el ciclo.

Después del Technical Architect: **Handoff Manager** para cerrar el ciclo de
especificación cuando todos los TS de 0a estén revisados.

---

## 7. Trazabilidad De Entregable

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado | operations/task-specs/TS-0a-001-desktop-workspace-shell.md | APROBADO |
| Revisado y corregido | operations/task-specs/TS-0a-007-sqlcipher-local-storage.md | APROBADO con corrección menor |
| Creado | operations/qa-reviews/qa-review-phase-0a-task-specs.md | este documento |
