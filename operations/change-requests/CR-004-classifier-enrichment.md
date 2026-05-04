# Change Request

request_id: CR-004
owner_agent: Functional Analyst
change_type: Producto restringido (toca TS-0a-003 y la decisión cerrada D8)
date: 2026-05-04
status: PENDIENTE — requiere AR del Technical Architect, PGR del Privacy Guardian
        y aprobación final del Orchestrator
triggered_by: Architecture Note `AN-classifier-enrichment-options.md` (2026-04-30)
              + evidencia de la prueba E2E de 7 días (sesión 2026-04-30 →
              2026-05-04) donde múltiples dominios cayeron en categoría `otro`
              y rompieron la agrupación por episodio.
documents_reviewed:
  - operations/architecture-notes/AN-classifier-enrichment-options.md
  - operations/task-specs/TS-0a-003-domain-category-classifier.md
  - operations/backlogs/backlog-phase-3.md (T-3-005, T-3-002, T-3-003)
  - Project-docs/decisions-log.md (D1, D8, D9, D17)
  - operating-system/change-control.md
  - operating-system/templates/change-request-template.md

---

## Proposed Change

Añadir dos capas de enriquecimiento al Classifier (T-0a-003) sin modificar
el contrato público de `classify(url) -> Classified`. Las dos capas se
introducen como tarea nueva de Fase 3 y como ampliación de scope de
T-3-005 ya existente.

### Capa A — Inferencia determinística (implementable en Fase activa)

Tres pasos nuevos que se ejecutan **solo cuando la tabla exacta devuelve
`otro`**. Ninguno introduce red ni LLM.

1. **TLD inference.** Dominios cuyo TLD coincida con un patrón
   conocido devuelven categoría sin tabla:
   - `.gob.es`, `.gov`, `.gov.uk`, `.gov.fr`, `.eu` administrativo
     → `gobierno`
   - `.edu`, `.ac.uk`, `.edu.es`, `.ac.jp` → `educación`

2. **Subdominio inference.** Prefijos de subdominio reservados:
   - `tienda.*`, `shop.*`, `store.*` → `comercio`
   - `blog.*` → `artículos`
   - `api.*`, `developer.*`, `dev.*` → `desarrollo`
   - `docs.*`, `wiki.*` → `educación` (con desempate posterior si
     dominio raíz está en `desarrollo`)

3. **Path/título keyword inference.** Tokens del path de la URL y del
   título recibido (EXTRA_SUBJECT del Share Intent en mobile, título
   ya presente en el bookmark en desktop — nunca fetch externo) contra
   un diccionario de keywords por categoría. Ejemplos representativos:
   - `{receta, ingredientes, cocinar, plato}` → `cocina`
   - `{partido, gol, liga, futbol, baloncesto}` → `deportes`
   - `{película, serie, episodio, temporada, reseña}` → `entretenimiento`
   - `{ley, decreto, BOE, real-decreto}` → `gobierno`

   Solo opera cuando los pasos previos devolvieron `otro`. Determinístico:
   mismo input → mismo output. Sin red. Sin LLM. Sin persistencia propia.
   El diccionario es estático, versionado en código, auditable por
   inspección directa del módulo `classifier.rs`.

### Capa B — LLM local opcional (Fase 3, condicional)

Ampliar el scope de T-3-005 (actualmente limitado a labels del Pattern
Detector) para autorizar al LLM como **enriquecedor opcional del
Classifier** cuando:

1. Las Capas tabla + A devuelven `otro`,
2. Ollama está disponible localmente, y
3. El usuario tiene el LLM activo en Privacy Dashboard.

El LLM recibe **solo `domain` (en claro) y `path_tokens` ya tokenizados
del path de la URL** — nunca la URL completa, nunca el título cifrado,
nunca campos personales. Su salida es una **sugerencia de categoría**
que el Classifier puede aceptar o ignorar según política. Si Ollama no
está disponible, el sistema devuelve `otro` y el flujo continúa sin
degradación. **D8 sigue siendo no negociable: el LLM nunca es requisito.**

---

## Why It Is Needed

### Evidencia cuantitativa de la prueba E2E (2026-04-30 → 2026-05-04)

Durante la sesión de validación E2E con datos reales:

- 30 recursos capturados desde Android via Share Intent.
- Tras ampliación masiva del Classifier (commits `1ccaa88`, `16e29ef`)
  y el split entretenimiento → cine + streaming (working tree actual),
  24 de 30 recursos quedaron clasificados con categoría útil. 6
  permanecen en `otro`.
- En la sesión `8b53fa62` de 17 recursos, 6 dominios sin entrada en la
  tabla (`milanuncios.com` antes de añadirlo, `share.google` para enlaces
  acortados, dominios de noticias regionales) quedaron en `otro` y
  contaminaron el episodio Broad con label `'other'`.

La inferencia heurística de Capa A hubiera clasificado correctamente
6 de esos 8 recursos solo con keywords de path/título disponibles en
el momento de la captura.

### Evidencia cualitativa

- **Long tail de dominios:** la tabla no escala. La prueba de 7 días
  reveló dominios de cocina, deportes y noticias regionales que no
  estaban en la tabla y cuya inclusión exhaustiva es manual e
  insostenible.
- **Limpieza retroactiva:** el comando temporal `reclassify_all_resources`
  (working tree) demostró que reclasificar la base existente con la
  tabla nueva mejora la calidad, pero los nuevos shares siguen
  llegando a `otro` para dominios no previstos.
- **Contaminación de episodios:** `episode_detector.rs` Broad mode
  agrupa por `category`. Cuando muchos recursos comparten `category =
  "otro"`, el episodio se vuelve ruidoso (label `'other'`, n alto sin
  semántica útil).

---

## Problem It Solves

La hipótesis core de FlowWeaver — *"el workspace anticipa la intención"* —
depende de que la categoría sea correcta. Con `otro` como fallback masivo:

1. El Episode Detector no puede distinguir intenciones distintas:
   todos los recursos no clasificados colapsan en un episodio único
   sin semántica.
2. El Pattern Detector longitudinal recibe señales con baja
   diferenciación (la categoría es la entrada más informativa de
   `domain_signature` y `category_signature`).
3. El Privacy Dashboard muestra una distribución de categorías
   distorsionada — `otro` engulle dominios de naturalezas distintas.

Capa A resuelve el caso de inferencia local determinística (sin coste
en privacidad, sin red, sin LLM). Capa B reserva la posibilidad de
mejora futura con LLM **solo si los datos reales de beta lo justifican**,
manteniendo D8 estricto.

---

## Affected Documents

| Documento | Cambio requerido |
|---|---|
| `operations/task-specs/TS-0a-003-domain-category-classifier.md` | Actualizar §"Qué NO Hace → Exclusiones Explícitas". Las filas "Clasificación por título (sin dominio)" y "Fallback a LLM si dominio no está en tabla" deben matizarse: Capa A autoriza el uso de tokens del path y del título en claro como **input adicional cuando la tabla devuelve `otro`**; el determinismo se preserva (vocabulario estático, no aprendizaje). El fallback a LLM permanece prohibido como requisito (D8), pero se autoriza como **enriquecedor opcional** condicionado a Capa B. |
| `operations/backlogs/backlog-phase-3.md` | Añadir tarea nueva (propuesta: T-3-006) "Classifier Capa A — inferencia determinística". Actualizar T-3-005 para incorporar el scope ampliado al Classifier (Capa B), manteniendo todas las restricciones existentes y añadiendo las del input específico (solo `domain` + `path_tokens`). |
| `Project-docs/decisions-log.md` | D8 mantiene su redacción principal. Añadir nota aclaratoria: *"el LLM como enriquecedor opcional del Classifier (Capa B de CR-004) es conforme con D8 si y solo si el baseline determinístico (tabla + Capa A) sigue produciendo `otro` cuando el LLM no está disponible, sin degradación funcional."* |
| `src-tauri/src/classifier.rs` | Implementación Capa A (TLD + subdominio + keyword) en Fase 3 como T-3-006. NO en este CR. |
| `src-tauri/gen/android/app/src/main/java/com/flowweaver/app/ShareIntentActivity.kt` | Sync paritario de Capa A en Kotlin. NO en este CR. |
| `operations/architecture-notes/AN-classifier-enrichment-options.md` | Cerrar como NOTA INFORMATIVA con referencia cruzada a CR-004 una vez aprobado. |

---

## Phase Impact

### Capa A — Implementable en Fase 3 como tarea nueva (T-3-006)

- **No bloquea ningún entregable existente de Fase 2.** Los módulos
  `pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs` y
  `PrivacyDashboard.tsx` están cerrados (D17) y no se tocan.
- **No reabre Fase 2.** El Classifier es un módulo de catálogo
  (TS-0a-003) cuyo crecimiento de tabla siempre fue evolutivo. Capa A
  añade tres pasos antes del fallback `otro` sin modificar el contrato
  público.
- **No interfiere con T-3-001/T-3-002/T-3-003.** Capa A puede
  desarrollarse en paralelo a la infraestructura de beta y a la
  telemetría. Su salida (categorías más diferenciadas) **mejora** la
  calidad de los datos de telemetría sin cambiar el schema declarado
  en T-3-002.

### Capa B — Parte de T-3-005 (ya en backlog) con scope ampliado

- T-3-005 sigue siendo **CONDICIONAL**. Se activa solo si el
  Orchestrator emite decisión explícita basada en datos de beta.
- Capa B se añade al scope de T-3-005 sin cambiar sus prerequisitos
  ni su categoría de condicionalidad.
- D8 permanece no negociable: el sistema debe arrancar y funcionar
  con `cargo test` al 100% sin Ollama presente.

### Compatibilidad con gates de fase

- **Gate de Fase 3** (backlog-phase-3.md §"Hipótesis Que Fase 3 Debe
  Validar"): la calidad del Classifier es prerequisito implícito de
  las métricas de aceptación de sugerencias. Capa A mejora ese
  prerequisito. No introduce nuevo bloqueo.

---

## Architectural Impact

### Capa A

El Classifier sigue siendo determinístico (D8 conforme). La función
interna `lookup_category` añade dos pasos nuevos antes del fallback
`otro`:

```
domain → exact_lookup(domain)        // tabla actual
       → exact_lookup(strip_one_subdomain)
       → exact_lookup(strip_two_subdomains)
       → tld_inference(domain)        // Capa A.1 — nuevo
       → subdomain_inference(domain)  // Capa A.2 — nuevo
       → keyword_inference(path_tokens, title_tokens)  // Capa A.3 — nuevo
       → "otro"                       // fallback
```

El contrato público `classify(url) -> Classified` **no cambia**.
El tipo `Classified { domain, category }` no se altera. Los
consumidores (`Importer`, `Episode Detector`, `Pattern Detector`,
`Trust Scorer`, `Privacy Dashboard`) reciben el mismo struct.

Los pasos Capa A son O(1) amortizado: cada uno consulta tablas
estáticas indexadas por hash del prefijo o del token. La latencia
añadida por recurso clasificado es despreciable comparada con las
operaciones de cifrado AES de `import_resource`.

### Capa B

El LLM opera como **capa adicional opcional después de Capa A**, antes
del fallback final `otro`:

```
... Capa A devuelve "otro"
    → si Ollama disponible Y LLM activo en Privacy Dashboard:
        llm_classify(domain, path_tokens) -> sugerencia
    → si la sugerencia no encaja: "otro"
```

D4 no aplica: el Classifier no toma decisiones de acción; solo
asigna una etiqueta. La autoridad de transición sigue exclusivamente
en `state_machine.rs`.

### Sync paritario Rust ↔ Kotlin

Tanto Capa A como Capa B deben replicarse en
`ShareIntentActivity.kt::classifyDomain` para mantener paridad entre
desktop y Android (constraint sostenido por commits `1986c8d` y
`5857eb2`). Capa B en Kotlin es opcional en Fase 3 — Ollama corre
en desktop; Android puede limitarse a Capa A determinística.

---

## Scope Creep Risk

### Capa A — BAJO

- Es una extensión del módulo existente sin cambio de contrato.
- El diccionario de keywords debe estar acotado y auditado por
  Privacy Guardian para verificar que ningún keyword opera sobre
  campos cifrados.
- Riesgo de mal uso: un implementador podría inflar el diccionario
  con keywords poco discriminativos. Mitigación: la TS de T-3-006
  declarará un mínimo viable (5 categorías × 8-10 keywords) y las
  ampliaciones requerirán justificación en commit.

### Capa B — MEDIO

- El LLM no debe convertirse en dependencia implícita del flujo.
  Mitigación: el AC explícito de T-3-005 ya exige que `cargo test`
  pase tanto con Ollama disponible como sin él.
- Privacy Guardian debe auditar qué tokens exactos recibe el modelo.
  Mitigación: declarar en la TS los campos exactos del input del
  LLM (solo `domain` + `path_tokens`) y emitir test de auditoría.
- Riesgo de prompt injection si el path contiene contenido
  controlado por el atacante. Mitigación: tokenizar y filtrar el
  path por longitud y alfabeto antes de pasarlo al LLM.

---

## Alternatives Rejected

| Alternativa | Razón de rechazo |
|---|---|
| Fetch ligero de headers (HEAD + og:tags) — Opción 3b de AN-classifier-enrichment-options | Impacto MEDIO en D1 (la IP del dispositivo se revela al servidor); requiere consentimiento explícito; depende de red. Rechazada como **primera opción**. Puede reconsiderarse en V1 con CR independiente. |
| oEmbed APIs — Opción 3c de AN-classifier-enrichment-options | Solo cubre dominios populares con soporte oEmbed; requiere red; latencia 1–5 s por captura. Útil pero no resuelve la long tail. Puede combinarse con Capa A en el futuro pero no es el paso prioritario. |
| Ampliar tabla indefinidamente (estado actual) | Escalabilidad nula, mantenimiento manual insostenible. La prueba de 7 días mostró que la tabla necesita inferencia para cubrir la long tail. Esta alternativa es exactamente lo que se reemplaza. |
| LLM como capa única sin Capa A | Viola D8: el LLM se convertiría en requisito de hecho para una clasificación útil. Rechazada permanentemente. |
| Aprendizaje longitudinal de categorías por uso | Viola D17 (Pattern Detector cerrado en Fase 2 — no debe contaminarse con clasificación). Rechazada permanentemente. |

---

## Recommendation

**Aprobar Capa A para implementación en Fase 3 como T-3-006.**

**Aprobar scope extension de T-3-005 para Capa B**, con activación
condicional a decisión explícita del Orchestrador con datos reales
de beta (mismas condiciones que T-3-005 ya tiene en
backlog-phase-3.md §T-3-005).

Ambas capas requieren revisión de Privacy Guardian antes de
implementar. La AR del Technical Architect debe declarar
formalmente los criterios de aceptación que la TS nueva (o la
actualización de TS-0a-003) deberá satisfacer.

---

## Required Reviewers

| Reviewer | Razón |
|---|---|
| Technical Architect | Contrato arquitectónico de `classify`; D8; verificación de que `lookup_category` con 3 pasos sigue siendo O(1) amortizado; ampliación de scope de T-3-005 sin reabrir Fase 2. |
| Privacy Guardian | D1: verificar que keywords de Capa A operan exclusivamente sobre `domain` (en claro) + `path` (en claro) + `title` recibido en claro por Share Intent (no descifrado de SQLCipher). Capa B: input exacto del LLM (solo `domain` + `path_tokens`). |
| Phase Guardian | Scope: verificar que la tarea nueva T-3-006 no contamina ningún módulo cerrado de Fase 2 (Pattern Detector, Trust Scorer, State Machine — D17). |

---

## Final Decision

PENDIENTE — Orchestrador post-revisión de AR-CR-004 (Technical
Architect) y PGR-CR-004 (Privacy Guardian).

---

## Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Leído | operations/architecture-notes/AN-classifier-enrichment-options.md | Inventario base de opciones (3a–3d) |
| Leído | operations/task-specs/TS-0a-003-domain-category-classifier.md | Exclusiones explícitas a actualizar |
| Leído | operations/backlogs/backlog-phase-3.md | T-3-005 a ampliar; T-3-006 a añadir |
| Leído | Project-docs/decisions-log.md | D1, D8, D17 — restricciones activas |
| Leído | operating-system/change-control.md | Flujo de aprobación |
| Leído | operating-system/templates/change-request-template.md | Estructura de este documento |
| Creado | operations/change-requests/CR-004-classifier-enrichment.md | este documento |
