# Revisión Arquitectónica — Task Specifications Fase 0a

document_id: AR-0a-001
owner_agent: Technical Architect
phase: 0a
date: 2026-04-22
status: CERRADO — sin bloqueos; corrección menor en TS-0a-007 acusada y aceptada
documents_reviewed:
  - operations/task-specs/TS-0a-001-desktop-workspace-shell.md
  - operations/task-specs/TS-0a-007-sqlcipher-local-storage.md
reference_normativo:
  - operations/architecture-notes/arch-note-phase-0a.md
  - Project-docs/decisions-log.md (D1, D6, D8, D16)
  - Project-docs/risk-register.md (R12)
precede_a: HO-002 (Handoff Manager)

---

## Resultado Global

| Documento | Resultado arquitectónico | Bloqueos | Correcciones |
| --- | --- | --- | --- |
| TS-0a-001 | APROBADO | ninguno | ninguna requerida |
| TS-0a-007 | APROBADO — corrección QA acusada y aceptada | ninguno | ninguna adicional |

---

## A. Revisión Contractual de TS-0a-001

### A.1 Contrato de módulo: Desktop Workspace Shell

El arch-note define el contrato del módulo así:

```
input:  recursos agrupados (del Grouper)
output: ventana Tauri con Panel A + Panel C renderizados
restricciones duras:
  sin conexión de red iniciada por la app
  sin proceso de observación activa
  sin background watcher de ningún tipo
  sin Panel B
  sin Share Extension
  sin sync
```

Verificación punto a punto contra TS-0a-001:

| Atributo del contrato | Requerido por arch-note | Declarado en TS-0a-001 | Coherente |
| --- | --- | --- | --- |
| input: clusters del Grouper | sí | "clusters de recursos provistos por el Grouper (T-0a-004)" | ✅ |
| output: Panel A + Panel C renderizados | sí | criterio de aceptación 2 | ✅ |
| sin conexión de red | sí | criterio de aceptación 4; tabla exclusiones con invariante 2 | ✅ |
| sin observación activa | sí | criterio de aceptación 5; tabla "Prohibido en la UI" | ✅ |
| sin background watcher | sí | tabla "No Incluye" con invariante 1 | ✅ |
| sin Panel B | sí | criterio de aceptación 3; señal de contaminación con fuentes | ✅ |
| sin Share Extension | sí | tabla "No Incluye" con D9 y "iOS Specialist LOCKED" | ✅ |
| sin sync | sí | tabla "No Incluye" con D6 | ✅ |

**Veredicto: contrato alineado sin desviaciones.**

### A.2 Contratos de Panel A y Panel C

El arch-note define:

```
Panel A
  input:  clusters del Grouper
  output: lista visual de recursos agrupados [título, favicon, dominio, subtema]
  sin resumen de contenido (Panel B), sin red, sin LLM

Panel C
  input:  clusters + tipo de contenido (del Classifier)
  output: checklist 3-5 acciones por plantilla
  baseline por plantilla sin LLM; sin dependencia de Panel B
```

TS-0a-001 aloja Panel A y Panel C como componentes externos (T-0a-005 y T-0a-006
respectivamente) y no sobrescribe sus contratos. El shell es el contenedor, no el
componente: no asume responsabilidad sobre el renderizado interno de Panel A ni de
Panel C. Este límite de responsabilidad es correcto y coherente con la separación
de contratos del arch-note.

**Veredicto: responsabilidades del shell correctamente delimitadas frente a Panel A y Panel C.**

### A.3 Límites de Fase 0a

TS-0a-001 respeta los límites de fase mediante:

1. Tabla "No Incluye" con primera fase permitida y regla que bloquea para cada
   elemento excluido — patrón consistente con arch-note.
2. Tabla "Prohibido en la UI de 0a" con motivación normativa por fila.
3. Sección "Señales de Contaminación de Fase" que cubre todos los vectores
   de contaminación identificados en el arch-note y añade el criterio de
   bloqueo para placeholders de Panel B, que el arch-note no explicita pero
   que es coherente con la invariante 5.

No se detecta ningún elemento in-scope de 0a omitido ni ningún elemento de
fases posteriores introducido.

**Veredicto: límites de Fase 0a correctamente implementados.**

### A.4 Separación entre Grouper 0a y Episode Detector 0b (R12)

TS-0a-001 mantiene la separación en tres niveles:

**Nivel léxico**: El documento usa exclusivamente "Grouper" y "T-0a-004" para
referirse al módulo de agrupación. No aparecen los términos "Episode Detector",
"detector", "dual-mode", "Jaccard" ni "ventana temporal" en ningún contexto del
shell.

**Nivel funcional**: La tabla "Qué NO valida" declara explícitamente:
`que el Episode Detector entrega valor | ese módulo no existe en 0a`. Esta
declaración es operativamente correcta y arquitectónicamente necesaria para
desambiguar el scope.

**Nivel de señal de contaminación**: La señal de R12 está presente y usa el
ID canónico correcto:
`"el Grouper podría usar el Episode Detector de 0b" → ESCALAR — R12 activo`

La acción asignada es ESCALAR (no solo BLOQUEAR), lo cual es correcto porque
R12 es un riesgo de confusión documental que el Phase Guardian debe gestionar,
no solo rechazar.

**Veredicto: R12 correctamente contenido. Separación Grouper 0a / Episode Detector 0b operativa.**

---

## B. Acuse de Recibo Arquitectónico de TS-0a-007

### B.1 Corrección aplicada por QA Auditor

La revisión QA (QA-REVIEW-0a-002) corrigió el último criterio de aceptación
de TS-0a-007:

**Antes**: `el módulo pasa datos al Bookmark Importer (T-0a-002) y al Grouper (T-0a-004)`
**Después**: `el módulo recibe datos del Bookmark Importer (T-0a-002) y los sirve al Grouper (T-0a-004)`

**Verificación arquitectónica de la corrección:**

El flujo real en Fase 0a es:

```
Bookmark Importer (T-0a-002)
  → escribe recursos clasificados EN SQLCipher (T-0a-007)

SQLCipher (T-0a-007)
  → sirve recursos clasificados AL Grouper (T-0a-004)

Grouper (T-0a-004)
  → produce clusters HACIA el Shell (T-0a-001)

Shell (T-0a-001)
  → renderiza Panel A y Panel C
```

Coherencia del flujo con el arch-note:

| Contrato arch-note | Dirección correcta | Corrección aplicada | Coherente |
| --- | --- | --- | --- |
| Importer output: "almacenados en SQLCipher" | Importer → SQLCipher | "recibe datos del Importer" | ✅ |
| Grouper input: "recursos clasificados" | SQLCipher → Grouper | "los sirve al Grouper" | ✅ |
| Shell input: "recursos agrupados del Grouper" | Grouper → Shell | fuera del criterio corregido; intacto en TS-0a-001 | ✅ |

La corrección es arquitectónicamente válida. El texto anterior invertía la
dirección del flujo con el Bookmark Importer, lo que podía generar confusión
en la fase de implementación si el criterio se trasladaba sin revisión al repo
de producto.

**Veredicto: corrección aceptada. TS-0a-007 es arquitectónicamente coherente con el flujo de 0a.**

### B.2 Separación de responsabilidades

| Módulo | Responsabilidad en 0a | Separación correcta |
| --- | --- | --- |
| Bookmark Importer (T-0a-002) | normalizar y clasificar recursos; escribir en SQLCipher | ✅ — no accede a la UI ni a la lógica del Grouper |
| SQLCipher (T-0a-007) | persistencia cifrada local; servir recursos al Grouper | ✅ — no agrega ni clasifica; no transmite |
| Grouper (T-0a-004) | leer recursos clasificados; producir clusters; entregar al Shell | ✅ — no persiste; no observa; no es el Episode Detector |
| Shell (T-0a-001) | contener Panel A + Panel C; leer del Grouper; sin red | ✅ — no persiste directamente; no clasifica |

No se detecta solapamiento de responsabilidades entre módulos ni acoplamiento
indebido entre capas.

### B.3 Cumplimiento de D1, D6, D8 y D16

| Decisión | Requerimiento | Estado en TS-0a-007 corregido |
| --- | --- | --- |
| D1 | URL y título cifrados en reposo; dominio y categoría en claro | ✅ — verificado campo a campo; justificación normativa por fila |
| D6 | sin campos de sync relay en schema de 0a; schema compatible sin adelantarlo | ✅ — tabla de prohibiciones con trazabilidad a D6; nota explícita en sección de decisiones |
| D8 | Classifier no puede usar LLM como requisito; si lo usa no debe bloquear el INSERT | ✅ — riesgo de contaminación LLM incluido con señal "ADVERTIR" y trazabilidad a D8 |
| D16 | INTEGER PRIMARY KEY + UUID indexado | ✅ — schema y CREATE UNIQUE INDEX confirman D16; campo a campo coherente |

### B.4 Ausencia de estructuras de 0b, Fase 1 y Fase 2

Verificación exhaustiva:

| Estructura prohibida | Pertenece a | Ausente en TS-0a-007 | Trazabilidad |
| --- | --- | --- | --- |
| Tabla `sessions` / `episodes` | 0b | ✅ | D10 |
| Payload de sync relay | 0b | ✅ | D6 |
| Campos ACK / idempotencia | 0b | ✅ | D18 |
| Buffer de sync | 0b | ✅ | D18 |
| Tabla para `~/Downloads` / FS Watcher | Fase 1 | ✅ | D9 |
| Tabla `patterns` / `pattern_signals` | Fase 2 | ✅ | D2, D17 |
| Campo `trust_score` | Fase 2 | ✅ | D4 |
| Tabla `state_transitions` | Fase 2 | ✅ | D4 |
| Tabla `explainability_log` | Fase 2 | ✅ | D14 |
| Campo `content_body` o equivalente | nunca | ✅ | D1 |
| Tabla vacía "reservada para el futuro" | prohibida | ✅ | principio schema mínimo |

**Veredicto: schema de 0a es mínimo y completo. Sin estructuras anticipatorias de fases futuras.**

---

## Hallazgos

| Tipo | Documento | Descripción |
| --- | --- | --- |
| PASS | TS-0a-001 | Contrato de módulo alineado con arch-note punto a punto |
| PASS | TS-0a-001 | Panel A y Panel C alojados sin sobreescritura de contratos |
| PASS | TS-0a-001 | R12 contenido con ID canónico y acción correcta (ESCALAR) |
| PASS | TS-0a-001 | Límites de Fase 0a implementados con trazabilidad normativa completa |
| ACUSE | TS-0a-007 | Corrección de inversión de flujo aplicada por QA Auditor: válida y aceptada |
| PASS | TS-0a-007 | D1, D6, D8 y D16 verificados; sin desviaciones |
| PASS | TS-0a-007 | Schema mínimo confirmado; cero estructuras de fases futuras |
| PASS | TS-0a-007 | Separación de responsabilidades entre Importer / SQLCipher / Grouper / Shell correcta |

---

## Bloqueos

**Ninguno.**

Ambas especificaciones están arquitectónicamente coherentes con el arch-note
y con el marco normativo de Fase 0a. No se requieren correcciones adicionales.

---

## Siguiente Agente Responsable

**Handoff Manager**

**Objetivo**: producir **HO-002** para cerrar el ciclo de especificación de
TS-0a-001 y TS-0a-007 y abrir el siguiente ciclo de tareas de 0a.

**Insumos disponibles para HO-002:**

| Entregable | Estado | Referencia |
| --- | --- | --- |
| TS-0a-001 | APROBADO — QA y arquitectura confirmados | operations/task-specs/TS-0a-001-desktop-workspace-shell.md |
| TS-0a-007 | APROBADO — corrección aplicada; QA y arquitectura confirmados | operations/task-specs/TS-0a-007-sqlcipher-local-storage.md |
| QA-REVIEW-0a-002 | CERRADO | operations/qa-reviews/qa-review-phase-0a-task-specs.md |
| AR-0a-001 | CERRADO | operations/architecture-reviews/AR-0a-001-task-specs-review.md |

HO-002 debe registrar el cierre de este ciclo de especificación e identificar
qué tareas del backlog de 0a quedan pendientes de especificación (TS-0a-002
al TS-0a-006) para que el siguiente ciclo pueda comenzar.
