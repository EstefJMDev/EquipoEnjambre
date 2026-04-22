# Especificación Operativa — T-0a-007

owner_agent: Technical Architect
document_id: TS-0a-007
task_id: T-0a-007
phase: 0a
date: 2026-04-22
status: DRAFT — pendiente de revisión por QA Auditor
referenced_backlog: operations/backlogs/backlog-phase-0a.md
referenced_arch_note: operations/architecture-notes/arch-note-phase-0a.md
referenced_decisions: D1 (Privacidad Nivel 1), D16 (Schema BD)
required_review: QA Auditor (cumplimiento de D1 y D16)

---

## Propósito En Fase 0a

SQLCipher es la única capa de persistencia de datos en Fase 0a. Existe porque:

1. Los bookmarks importados (T-0a-002) deben persistir entre sesiones de
   la demo sin perder estado.
2. D1 (Privacidad Nivel 1) exige que URLs y títulos estén cifrados en reposo
   desde el primer momento, no a partir de una fase posterior.
3. Sin persistencia cifrada no hay workspace reproducible para la demo de 0a.

La existencia de SQLCipher en 0a no amplía el scope de la fase. Resuelve
el prerrequisito técnico mínimo para que los datos de la demo sean persistentes
y estén protegidos desde el inicio.

---

## Por Qué Se Establece Ya En Esta Fase

Si el almacenamiento no es cifrado desde 0a, se viola D1 desde el primer ciclo
operativo. Corregirlo en 0b implicaría migración de datos y reescritura del
Importer, generando deuda técnica innecesaria y un momento de regresión de
privacidad documentable. D1 no es opcional ni aplazable.

SQLCipher se elige sobre otras opciones porque:
- es SQLite con cifrado AES integrado, sin infraestructura adicional
- no requiere red ni backend propia (compatible con D6 que prohíbe backend
  propia en MVP)
- es coherente con el entorno desktop macOS de Tauri 2
- está especificado sin ambigüedad en el backlog y en la arch-note de 0a

---

## Qué Datos De 0a Puede Albergar

### Tabla `resources` — única tabla autorizada en 0a

```sql
CREATE TABLE IF NOT EXISTS resources (
  id       INTEGER PRIMARY KEY,
  uuid     TEXT    NOT NULL,
  url      TEXT    NOT NULL,
  title    TEXT    NOT NULL,
  domain   TEXT    NOT NULL,
  category TEXT    NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_resources_uuid ON resources(uuid);
```

| Campo | Tipo | Cifrado | Justificación |
| --- | --- | --- | --- |
| `id` | INTEGER PRIMARY KEY | no | clave técnica; D16 |
| `uuid` | TEXT NOT NULL UNIQUE | no | identificador portable; D16 |
| `url` | TEXT NOT NULL | sí | información sensible de navegación (D1) |
| `title` | TEXT NOT NULL | sí | puede revelar intención del usuario (D1) |
| `domain` | TEXT NOT NULL | no | nivel de abstracción aceptado por D1 |
| `category` | TEXT NOT NULL | no | derivado del dominio por el Classifier; no revela contenido |

El dominio se mantiene en claro porque D1 define el nivel de abstracción:
dominio (p.ej. `github.com`) no constituye contenido sensible de navegación.
La categoría tampoco: es la salida determinística del Classifier (T-0a-003)
sobre el dominio.

---

## Qué Datos NO Deben Aparecer En 0a

### Prohibido en 0a porque pertenece a 0b

| Dato / Tabla | Motivo |
| --- | --- |
| Tabla `sessions` o `episodes` | el Session Builder es de 0b |
| Campos de timestamp de captura activa | la captura activa (Share Extension) es de 0b |
| Payload cifrado de sync relay | el relay iCloud/Google Drive es de 0b (D6) |
| Campos de ACK o idempotencia de sync | pertenecen al protocolo de sync de 0b |
| Tabla o campo para el buffer de sync | D18: buffer de sync es de 0b |

### Prohibido en 0a porque pertenece a Fase 1

| Dato / Tabla | Motivo |
| --- | --- |
| Tabla para recursos de `~/Downloads` | el FS Watcher entra en Fase 1 (D9) |
| Campos de tipo_de_archivo para FS Watcher | idem |

### Prohibido en 0a porque pertenece a Fase 2

| Dato / Tabla | Motivo |
| --- | --- |
| Tabla `patterns` o `pattern_signals` | D2, D17: Pattern Detector es Fase 2 |
| Campo `trust_score` | D4: Trust Scorer es Fase 2 |
| Tabla `state_transitions` | D4: State Machine es Fase 2 |
| Tabla `explainability_log` | D14: Explainability Log es Fase 2 |

### Prohibido permanentemente (D1)

| Dato | Motivo |
| --- | --- |
| Campo `content_body` o cualquier variante | contenido completo de páginas; D1 lo prohíbe explícitamente |
| Texto completo de páginas en cualquier forma | idem |

**Regla operativa**: cualquier propuesta de añadir tabla o campo de fases
futuras —incluso "para ahorrar trabajo en 0b"— debe bloquearse y escalarse
al Phase Guardian.

---

## Límites De Privacidad — Nivel 1 (D1)

| Dato | Tratamiento | Justificación normativa |
| --- | --- | --- |
| URL completa | CIFRADO en reposo | revela historial de navegación; D1 |
| Título de la página | CIFRADO en reposo | puede revelar intención del usuario; D1 |
| Dominio (e.g. `github.com`) | EN CLARO | nivel de abstracción aceptado por D1 |
| Categoría asignada por el Classifier | EN CLARO | derivado del dominio; no revela contenido |
| UUID interno | EN CLARO | identificador técnico; no revela contenido |
| Clave de cifrado de SQLCipher | LOCAL — nunca transmitida | cualquier transmisión viola D6 e invariante 2 |

Nota sobre auditabilidad: D14 define un Privacy Dashboard para 0b (mínimo) y
Fase 2 (completo). El schema de 0a debe ser compatible con un futuro audit
trail sin requerirlo todavía. La tabla `resources` de 0a satisface este
requisito: todos los campos son introspectables por el usuario si se habilita
la visualización en fases posteriores.

---

## Exclusiones Explícitas Con Trazabilidad De Fase

| Elemento | Primera fase | Regla |
| --- | --- | --- |
| Tabla `sessions` | 0b | Session Builder (D10) |
| Sync payload y relay | 0b | D6 |
| Privacy Dashboard vinculado al storage | 0b (mínimo) | D14 |
| Tabla `patterns` | Fase 2 | D2, D17 |
| Trust score | Fase 2 | D4 |
| State machine storage | Fase 2 | D4 |
| Explainability log | Fase 2 | D14 |
| Content body | nunca | D1 |
| Schema "preparado para el futuro" con tablas vacías | prohibido | principio de schema mínimo de 0a |

---

## Criterios De Aceptación

- [ ] SQLCipher sobre SQLite está operativo en macOS sin dependencias externas
  de red ni de servicio
- [ ] la tabla `resources` existe con el schema exacto definido en este documento
- [ ] el índice UUID está creado y es UNIQUE
- [ ] URLs y títulos se almacenan cifrados en reposo (D1)
- [ ] el dominio y la categoría se almacenan en claro (D1 — nivel de abstracción
  aceptado)
- [ ] el schema no contiene tablas de 0b, Fase 1 ni Fase 2
- [ ] los datos persisten entre sesiones de la app sin pérdida
- [ ] no existe campo `content_body` ni equivalente (D1)
- [ ] la clave de cifrado es local; no se transmite a ningún servicio externo
  (invariante 2 de arch-note)
- [ ] el módulo recibe datos del Bookmark Importer (T-0a-002) y los sirve al
  Grouper (T-0a-004) sin violaciones de los contratos de módulo definidos en
  arch-note

---

## Riesgos De Contaminación

| Riesgo | Señal de activación | Acción |
| --- | --- | --- |
| Schema "preparado para el futuro" | aparece tabla de sesiones, patrones o sync | BLOQUEAR; escalar al Phase Guardian |
| Contenido completo de páginas | campo `content`, `body` o equivalente en el schema | BLOQUEAR; viola D1 |
| Clave de cifrado transmitida | cualquier llamada de red durante setup de SQLCipher | BLOQUEAR; viola D6 e invariante 2 de arch-note |
| LLM invocado antes del INSERT | el Classifier llama a LLM para enriquecer antes de persistir | ADVERTIR; viola D8 baseline |
| Tabla vacía reservada para 0b | tabla con nombre `sessions`, `sync_queue`, etc. sin datos | BLOQUEAR; contamina fase |

---

## Relación Con Decisiones Cerradas

| Decisión | Impacto directo en este módulo |
| --- | --- |
| D1 | Define qué se cifra (URL, título) y qué no (dominio, categoría). No negociable. |
| D16 | Fija INTEGER PRIMARY KEY + UUID indexado como estructura canónica. No negociable. |
| D6 | El relay de sync usará este storage en 0b. El schema de 0a debe ser compatible sin adelantarlo: no añadir campos de relay en 0a. |
| D8 | El Classifier que alimenta `category` no puede usar LLM como requisito. Si lo usa como mejora, no debe bloquear el INSERT. |
| D14 | El schema de 0a debe permitir un futuro audit trail (Privacy Dashboard de 0b y Fase 2) sin necesidad de rediseñarlo. |

---

## Handoff Esperado

1. Technical Architect produce este documento (completado).
2. QA Auditor revisa cumplimiento de D1 y D16 contra este schema.
3. QA Auditor confirma que no hay tablas de fases futuras.
4. Desktop Tauri Shell Specialist recibe confirmación del contrato de storage
   para alinear T-0a-001 (el shell lee de SQLCipher).
5. Phase Guardian vigila que ningún entregable posterior añada tablas fuera
   del schema mínimo de 0a sin OD previa.

---

## Nota De Gobernanza

Esta especificación no autoriza implementación en el repo de producto.
Define el contrato de datos que la implementación debe respetar.

El schema aquí definido es el schema MÍNIMO y COMPLETO de 0a.
Cualquier adición requiere una Orchestration Decision (OD) previa.
