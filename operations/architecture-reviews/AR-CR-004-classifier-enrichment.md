# Revisión Arquitectónica — Classifier Enrichment Capas A y B (CR-004)

```
document_id: AR-CR-004-classifier-enrichment
owner_agent: Technical Architect
phase: 3 (T-3-006 nueva + scope extension de T-3-005)
date: 2026-05-04
status: APROBADO CON CONDICIONES — Capa A aprobada para T-3-006 con
        criterios de aceptación AC-A1..AC-A8; Capa B aprobada como
        scope extension de T-3-005 condicionada a decisión del
        Orchestrator basada en datos de beta. Privacy Guardian debe
        ratificar los inputs de ambas capas (PGR-CR-004) antes de
        que T-3-006 inicie implementación.
precede_a: PGR-CR-004 + handoff del Orchestrator al Functional Analyst
           para actualización de TS-0a-003 y backlog-phase-3.md.
documents_reviewed:
  - operations/change-requests/CR-004-classifier-enrichment.md
  - operations/architecture-notes/AN-classifier-enrichment-options.md
  - operations/task-specs/TS-0a-003-domain-category-classifier.md
  - operations/backlogs/backlog-phase-3.md (T-3-005, T-3-002, T-3-003)
  - Project-docs/decisions-log.md (D1, D4, D8, D17, R12)
  - src-tauri/src/classifier.rs (estado tras commits 1ccaa88, 16e29ef
    y working tree del split entretenimiento → cine + streaming)
  - src-tauri/gen/android/app/src/main/java/com/flowweaver/app/
    ShareIntentActivity.kt (paridad sostenida desde commit 5857eb2)
reference_normativo:
  - Project-docs/decisions-log.md (D1, D4, D8, D17)
  - operations/architecture-reviews/AR-CR-002-mobile-observer.md
    (precedente de scope extension condicionada — AR de un CR similar)
```

---

## Objetivo de Esta Revisión

CR-004 propone dos capas de enriquecimiento al Classifier (T-0a-003):

- **Capa A:** inferencia determinística por TLD + subdominio + keywords
  de path/título, ejecutada **solo** cuando la tabla exacta devuelve
  `otro`. Sin red, sin LLM.
- **Capa B:** ampliar el scope de T-3-005 para autorizar al LLM local
  como enriquecedor opcional del Classifier además de los labels del
  Pattern Detector.

Esta AR responde a las cinco preguntas que el CR-004 dejó abiertas:

1. ¿La Capa A mantiene el contrato público de `classify(url)`?
2. ¿El diccionario de keywords es auditable y mantenible?
3. ¿La función `lookup_category` con 3 pasos nuevos sigue siendo
   O(1) amortizado?
4. ¿La Capa B puede integrarse sin convertirse en dependencia?
5. ¿El scope de T-3-005 puede ampliarse sin reabrir Fase 2?

---

## 1. Contrato público de `classify` — preservado

### Veredicto

**El contrato público de `classify(url) -> Classified` no cambia.**

La estructura actual:

```rust
pub fn classify(url: &str) -> Classified {
    let domain = extract_domain(url);
    let category = lookup_category(&domain).to_string();
    Classified { domain, category }
}
```

permanece idéntica. La extensión ocurre **dentro** de `lookup_category`,
que sigue devolviendo un `&'static str` (categoría). Los consumidores
del Classifier (`Importer`, `Episode Detector`, `Pattern Detector`,
`Trust Scorer`, `Privacy Dashboard`, `ShareIntentActivity` Android)
reciben exactamente el mismo struct.

### Implicación arquitectónica

El cambio es **interno al módulo**. No exige modificación de ningún
otro archivo Rust en `src-tauri/src/`. La paridad Kotlin se mantiene
replicando la lógica en `ShareIntentActivity.kt::classifyDomain`
(constraint vivo desde commits `1986c8d` y `5857eb2`).

**Sin embargo**, dado que Capa A.3 (keyword inference) requiere
tokens del path y del título, el contrato **interno** de
`lookup_category` debe ampliarse:

```rust
// Antes (estado actual):
fn lookup_category(domain: &str) -> &'static str

// Después (Capa A):
fn lookup_category(
    domain: &str,
    path_tokens: &[&str],  // tokens del path de la URL
    title_tokens: &[&str], // tokens del título recibido en claro
) -> &'static str
```

`classify` se actualiza para extraer los tokens antes de invocar:

```rust
pub fn classify(url: &str, title: Option<&str>) -> Classified {
    let domain = extract_domain(url);
    let path_tokens = extract_path_tokens(url);
    let title_tokens = title.map(tokenize).unwrap_or_default();
    let category = lookup_category(&domain, &path_tokens, &title_tokens).to_string();
    Classified { domain, category }
}
```

**El parámetro `title` es opcional.** Permite mantener compatibilidad
hacia atrás con `import_resource` (que ya tiene `title`) y con
`add_capture` (idem). Si `title` es `None`, Capa A.3 opera solo con
`path_tokens` (Android Share Intent puede enviar título; bookmarks de
desktop también lo tienen).

### Alternativa rechazada

Pasar `url` completa a `lookup_category` y dejar que sea esa función
quien tokenice. **Rechazada:** rompe la separación de
responsabilidades que `extract_domain` ya estableció.

---

## 2. Diccionario de keywords — auditable y mantenible

### Veredicto

**El diccionario debe declararse como dato estático versionado en
código**, no como configuración externa. Esto preserva D8 (sin
aprendizaje implícito), D1 (auditoría por lectura del módulo) y
permite que el compilador rechace duplicaciones (igual que la tabla
exact_lookup actual).

### Estructura aprobada

```rust
// classifier.rs
const KEYWORD_INFERENCE: &[(&str, &[&str])] = &[
    ("cocina", &[
        "receta", "ingredientes", "cocinar", "plato", "horno",
        "guiso", "postre", "tapa", "menu",
    ]),
    ("deportes", &[
        "partido", "gol", "liga", "futbol", "baloncesto",
        "tenis", "formula", "motogp", "marcador",
    ]),
    ("entretenimiento", &[
        "pelicula", "serie", "episodio", "temporada", "capitulo",
        "reparto", "estreno", "sinopsis",
    ]),
    ("gobierno", &[
        "ley", "decreto", "boe", "real-decreto", "resolucion",
        "tramite", "sede", "expediente",
    ]),
    // ... mínimo viable: 5 categorías × 8-10 keywords cada una
];
```

### Auditoría requerida

- **Privacy Guardian** (PGR-CR-004) verifica que ningún keyword
  permite reconstrucción inversa de `title` cifrado: el diccionario
  opera sobre **tokens recibidos en claro** (path en URL o
  EXTRA_SUBJECT del Share Intent). El diccionario es público; el
  título no se reidentifica desde la categoría inferida.
- **QA Auditor** verifica con test estructural que la suma del
  diccionario no excede las 200 entradas (cota dura para mantener
  legibilidad y O(1) amortizado).
- **Functional Analyst** documenta en TS-0a-003 (sección Capa A) el
  proceso de añadir keywords nuevos: PR + test + revisión, no
  configuración runtime.

### Determinismo

El diccionario es **estático en código**. No se carga de archivo, no
se aprende de uso, no se externaliza a configuración del usuario. La
clasificación sigue siendo determinística: mismo input → misma salida
en cualquier ejecución, en cualquier dispositivo.

---

## 3. Complejidad — O(1) amortizado preservado

### Pasos de `lookup_category` ampliada

| # | Paso | Operación | Coste |
|---|---|---|---|
| 1 | `exact_lookup(domain)` | Match en tabla estática (compilador convierte a tabla hash o jump table) | O(1) |
| 2 | `exact_lookup(strip_one_subdomain)` | idem | O(1) |
| 3 | `exact_lookup(strip_two_subdomains)` | idem | O(1) |
| 4 | **NUEVO — Capa A.1** `tld_inference(domain)` | Match en lista de TLD (≤ 30 entradas) | O(1) amortizado (lista pequeña con `ends_with`) |
| 5 | **NUEVO — Capa A.2** `subdomain_inference(domain)` | Match en lista de prefijos (≤ 10 entradas) con `starts_with` | O(1) |
| 6 | **NUEVO — Capa A.3** `keyword_inference(path_tokens, title_tokens)` | Para cada (categoría, keywords): contar matches. Cota dura: 5 categorías × 10 keywords = 50 comparaciones por token; cota de tokens: ≤ 30 por URL+título | O(1) amortizado (cotas duras) |
| 7 | Fallback `"otro"` | Constante | O(1) |

**Conclusión:** la latencia añadida por recurso clasificado es
≤ 1500 comparaciones de string corto (50 keywords × 30 tokens). En
arquitectura Rust, esto está en el orden de microsegundos —
despreciable comparado con AES-GCM cifrado de `import_resource`
(≥ 100 µs).

### Tests de regresión exigidos

AC-A4 (sección 6) impone benchmark de regresión: `cargo bench`
debe mostrar que `classify` con Capa A activa no excede en > 30 µs
la versión sin Capa A para 1000 URLs típicas. Si lo excede,
revisión inmediata del diccionario.

---

## 4. Capa B — integrable sin convertirse en dependencia

### Veredicto

**Aprobado como scope extension de T-3-005 con las mismas restricciones
de condicionalidad ya vigentes.**

T-3-005 sigue marcada `[CONDICIONAL]` en `backlog-phase-3.md` con la
nota:

> Solo puede activarse si los datos de beta de T-3-002 y T-3-003
> demuestran que el baseline determinístico es insuficiente, Y el
> Orchestrator emite decisión explícita.

CR-004 amplía el scope de T-3-005 sin tocar esos prerequisitos. La
restricción D8 (el sistema debe arrancar y funcionar sin LLM) queda
explícita en el AC de T-3-005:

> el sistema arranca y funciona con el baseline sin errores ni
> degradación de funcionalidades core cuando Ollama no está disponible.

Para Capa B aplicada al Classifier, esto significa:

```rust
fn lookup_category(domain, path_tokens, title_tokens) -> &str {
    let baseline = baseline_lookup(domain, path_tokens, title_tokens);
    if baseline != "otro" {
        return baseline;
    }
    if !ollama_available() || !user_enabled_llm_in_dashboard() {
        return "otro";
    }
    let suggested = llm_classify(domain, path_tokens);
    accept_or_reject_suggestion(suggested).unwrap_or("otro")
}
```

### Input del LLM — declaración exacta

Como Technical Architect, declaro que el input del LLM **debe ser
únicamente**:

- `domain: &str` — en claro (D1 lo autoriza)
- `path_tokens: &[&str]` — tokens del path de la URL, ya tokenizados
  con la misma función `extract_path_tokens` que Capa A.3

El input **no puede contener**:

- la URL completa (revela el path con todos sus parámetros)
- el título (`title`) — está cifrado en SQLCipher cuando viene de
  bookmarks; en captura Share Intent llega en claro pero **el
  Classifier es upstream del cifrado**, así que técnicamente está
  disponible. La política aquí es **conservadora**: el título no
  va al LLM. La Capa A.3 ya lo usa internamente como heurística;
  la Capa B se ciñe a domain + path tokens.

Privacy Guardian (PGR-CR-004) ratifica esta declaración.

### Degradación graceful

AC-B5: con Ollama detenido, `cargo test` pasa al 100%. Con Ollama
arrancando lento (> 1 s), el Classifier devuelve `otro` y no bloquea
el `import_resource`. Implementación recomendada: timeout 200 ms a la
llamada del LLM; si excede, fallback a `otro` sin error.

---

## 5. Scope extension de T-3-005 sin reabrir Fase 2

### Veredicto

**Aprobado.** T-3-005 está en backlog-phase-3.md, fase 3, condicional.
Ampliar su scope al Classifier no toca:

- `pattern_detector.rs` (D17 — cerrado en Fase 2)
- `trust_scorer.rs` (idem)
- `state_machine.rs` (idem; D4 — autoridad de transición exclusiva)
- `episode_detector.rs` (R12 — separado del Pattern Detector)

Capa B opera **antes** del fallback `otro` dentro del Classifier.
Su salida (categoría) entra al schema de SQLCipher como cualquier
otra categoría, vía `Importer`. No introduce campos nuevos en
`storage::resources`.

### Constraint anti-creep

T-3-005 con scope ampliado **no puede** invocar al LLM dentro de
ningún módulo cerrado de Fase 2. La interacción del Classifier con
el LLM es local al Classifier; el resto del pipeline no sabe que
el LLM existe. Esto preserva R12 (Pattern Detector ≠ Episode
Detector ≠ Classifier — flujos paralelos sin contaminación).

### Coordinación con T-3-006 (nueva)

T-3-006 es **prerequisito de Capa B**. La secuencia obligatoria:

```
T-3-006 (Capa A) implementada y verificada
       │
       ▼
T-3-005 (Capa B) activada por decisión del Orchestrator
        con datos de beta
       │
       ▼
LLM enriquece solo cuando Capa A devuelve "otro"
```

Sin Capa A, Capa B intentaría clasificar **demasiados** dominios y
el LLM se convertiría en dependencia de hecho. La condición de
activación de Capa B es: "Capa A está implementada y los datos de
beta muestran que la categoría `otro` sigue siendo no despreciable
(p.ej. > 10% de capturas) tras Capa A".

---

## 6. Criterios de Aceptación

### Capa A — T-3-006 (nueva tarea Fase 3)

| # | Criterio | Verificable |
|---|---|---|
| AC-A1 | El contrato público `classify(url, title) -> Classified` se preserva. Los consumidores del Classifier (`import_resource`, `add_capture`, etc.) no requieren modificación más allá de pasar el `title` cuando lo tienen. | Inspección de cabecera + `cargo check` desktop sin errores fuera de `classifier.rs`. |
| AC-A2 | `lookup_category` ejecuta en orden: exact (3 niveles) → tld_inference → subdomain_inference → keyword_inference → "otro". Cualquier paso que devuelve categoría distinta de `otro` corta la cadena. | Test unitario con 12 casos cubriendo cada uno de los 6 caminos de retorno. |
| AC-A3 | El diccionario de keywords es estático en código (no externo, no aprendido), declarado como `&[(&str, &[&str])]`. Cota dura: ≤ 200 entradas totales. | Inspección + test estructural de cota. |
| AC-A4 | `cargo bench` muestra que `classify` con Capa A activa no excede en > 30 µs la versión actual para 1000 URLs típicas. | Benchmark con criterios fijos. |
| AC-A5 | Determinismo: el mismo input produce el mismo output en cualquier ejecución. Sin estado interno mutable, sin acceso a archivos, sin red. | Test estructural: ausencia de `std::fs`, `std::net`, `std::sync::Mutex` en `classifier.rs`. |
| AC-A6 | Sync paritario en Kotlin: `ShareIntentActivity.kt::classifyDomain` implementa los mismos 3 pasos (TLD + subdominio + keyword) con el mismo diccionario. Tabla de paridad documentada. | Diff de los keywords + test de paridad opcional (script que compara dominios y categorías esperadas en ambos lados). |
| AC-A7 | Privacy Guardian (PGR-CR-004) ha emitido revisión APROBADA verificando que los inputs de Capa A.3 son solo `path_tokens` y `title_tokens` recibidos en claro. | Documento PGR-CR-004 con status APROBADO. |
| AC-A8 | `cargo test` desktop pasa al 100% sin regresiones. `npx tsc --noEmit` limpio. | CI verde. |

### Capa B — scope extension de T-3-005 (cuando Orchestrator la active)

| # | Criterio | Verificable |
|---|---|---|
| AC-B1 | Capa B solo se invoca si Capa A devolvió `otro`, Ollama está disponible localmente Y el usuario tiene LLM activo en Privacy Dashboard. | Test unitario con mocks de los 3 estados. |
| AC-B2 | El input del LLM es exclusivamente `domain` + `path_tokens`. La URL completa, el título y cualquier otro campo no llegan al LLM. | Test estructural sobre la función `llm_classify`: solo dos argumentos del tipo declarado. |
| AC-B3 | Timeout 200 ms a la llamada del LLM; si excede, fallback a `otro` sin error. | Test de timeout simulado. |
| AC-B4 | El Privacy Dashboard incluye sección "Modelo local — clasificador" visible al usuario cuando Capa B está activa, con control de desactivación. | Inspección de `PrivacyDashboard.tsx` + test de toggle. |
| AC-B5 | `cargo test` pasa con Ollama disponible Y sin él. Sin él, el Classifier devuelve `otro` para los casos que Capa B habría enriquecido — sin errores, sin degradación de funcionalidades core. | Dos invocaciones de `cargo test` en CI: uno con `OLLAMA_HOST` configurado, otro sin él. |
| AC-B6 | El modelo usado está declarado en configuración (versión, tamaño, origen). El usuario puede verificar qué modelo procesa sus datos en Privacy Dashboard. | UI de Privacy Dashboard. |
| AC-B7 | Privacy Guardian (PGR-CR-004) ha ratificado el input exacto del LLM y el flujo de Capa B. | Documento PGR-CR-004 con sección dedicada a Capa B. |

---

## 7. Riesgos Conocidos

| ID | Riesgo | Prob. | Impacto | Mitigación | Owner |
|---|---|---|---|---|---|
| R-A1 | El implementador infla el diccionario con keywords poco discriminativos. | Media | Bajo | TS-0a-003 declara mínimo viable y proceso de PR + test para añadir entradas. | Functional Analyst |
| R-A2 | Capa A.3 clasifica incorrectamente recursos cuyo path contiene keywords ambiguas (p.ej. "barcelona" puede ser deportes o viajes). | Media | Bajo | Política: si keyword_inference devuelve empate, el Classifier retorna `otro`. AC-A2 lo valida. | Implementador |
| R-A3 | Paridad Rust ↔ Kotlin se rompe en futuras ampliaciones de keywords. | Media | Medio | AC-A6 + script de diff opcional en CI. | Implementador + QA Auditor |
| R-A4 | Capa A introduce regresión de latencia. | Baja | Medio | AC-A4 (benchmark). | Implementador |
| R-B1 | El LLM se convierte en dependencia implícita por mal diseño de la degradación. | Media | Alto | AC-B5 (cargo test sin Ollama) + revisión del Technical Architect en TS de T-3-005 ampliada. | Technical Architect |
| R-B2 | El input del LLM se amplía indebidamente más allá de domain + path_tokens. | Baja | Alto | AC-B2 (test estructural). PGR-CR-004 audita el flujo. | Privacy Guardian |
| R-B3 | El LLM produce sugerencias inestables (no-determinístico) que confunden al Pattern Detector aguas abajo. | Media | Medio | Política: las sugerencias del LLM son aceptadas solo si encajan con el set fijo de categorías existente. Sugerencias fuera de set → `otro`. | Implementador |
| R-B4 | Prompt injection desde el path de la URL controlado por atacante. | Baja | Alto | Tokenizar el path y filtrar por longitud y alfabeto antes de pasarlo al LLM. AC-B2 limita el input. | Implementador |

---

## 8. Decisiones Operativas

### 8.1 — Numeración de la tarea nueva

T-3-006 — Classifier Capa A — inferencia determinística. Posición en el
backlog: tras T-3-005 y antes del cierre del backlog. Ver actualización
del Functional Analyst en commit subsiguiente.

### 8.2 — Activación de Capa B

Capa B se activa solo cuando se cumplen **simultáneamente**:

1. T-3-006 implementada y verificada (Capa A operativa).
2. Datos de beta (T-3-002, T-3-003) muestran que `otro` sigue siendo
   no despreciable (cota propuesta: > 10 % de capturas con `otro`
   tras Capa A).
3. Orchestrator emite OD explícita autorizando T-3-005 con scope
   ampliado.

Sin estas tres condiciones, Capa B **no existe como tarea activa**.

### 8.3 — Coordinación con T-3-002 (telemetría)

Capa A mejorará la diferenciación de categorías en la telemetría sin
cambiar el schema declarado en backlog-phase-3.md §T-3-002. Las
métricas de `sugerencia_emitida`, `sugerencia_aceptada` y
`transicion_estado` siguen operando exclusivamente sobre `domain` y
`category`. Capa B no introduce nuevos eventos.

### 8.4 — Anti-objetivos reafirmados

Los anti-objetivos de AN-classifier-enrichment-options.md se
mantienen:

- NO introducir LLM obligatorio (D8).
- NO scrapear contenido completo de páginas.
- NO crear dependencia de servicio externo distinto del LLM local.
- NO almacenar metadata más allá de lo que D1 permite.

---

## 9. Correcciones Previas a Implementación

Ninguna corrección al código existente. Las condiciones de esta AR
son:

1. Privacy Guardian emite PGR-CR-004 ratificando los inputs de
   Capa A.3 y Capa B.
2. Orchestrator aprueba CR-004 (CR + AR + PGR) y emite handoff al
   Functional Analyst para actualizar TS-0a-003 y backlog-phase-3.md.
3. Functional Analyst actualiza TS-0a-003 (sección Capa A nueva;
   exclusiones matizadas) y backlog-phase-3.md (T-3-006 nueva;
   T-3-005 con scope ampliado).
4. Tras esos commits, Technical Architect emite TS de T-3-006 con
   los AC-A1..AC-A8 desglosados en pasos ejecutables.
5. Implementación de T-3-006 puede comenzar tras aprobación de la
   TS por Privacy Guardian.

---

## 10. Siguiente Agente Responsable

1. **Privacy Guardian** — emitir PGR-CR-004 verificando inputs de
   Capa A.3 (path_tokens, title_tokens en claro) y Capa B (solo
   domain + path_tokens al LLM).
2. **Orchestrator** — aprobar CR + AR + PGR y emitir handoff al
   Functional Analyst.
3. **Functional Analyst** — actualizar TS-0a-003 y
   backlog-phase-3.md según CR-004 + AR-CR-004 + PGR-CR-004.

La implementación queda bloqueada hasta que TS de T-3-006 esté
aprobada y los datos de beta justifiquen la activación de Capa B.

---

## Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Revisado | operations/change-requests/CR-004-classifier-enrichment.md | LEÍDO |
| Revisado | operations/architecture-notes/AN-classifier-enrichment-options.md | LEÍDO |
| Revisado | operations/task-specs/TS-0a-003-domain-category-classifier.md | LEÍDO |
| Revisado | operations/backlogs/backlog-phase-3.md | LEÍDO — T-3-005 condicional, T-3-002 schema declarado |
| Revisado | Project-docs/decisions-log.md | LEÍDO — D1, D4, D8, D17 vigentes |
| Revisado | src-tauri/src/classifier.rs | LEÍDO — estructura `lookup_category` documentada |
| Revisado | operations/architecture-reviews/AR-CR-002-mobile-observer.md | REFERENCIA de formato y estilo |
| Creado | operations/architecture-reviews/AR-CR-004-classifier-enrichment.md | este documento |

---

## Firma

```
approved_by: Technical Architect
approval_date: 2026-05-04
status_detail: |
  APROBADO CON CONDICIONES. Capa A aprobada para implementación en Fase 3
  como T-3-006 con criterios AC-A1..AC-A8 emitidos. Capa B aprobada como
  scope extension de T-3-005 condicionada a que (1) T-3-006 esté
  implementada y verificada, (2) los datos de beta muestren que `otro`
  sigue siendo no despreciable tras Capa A, y (3) el Orchestrator emita
  OD explícita autorizándola. El contrato público `classify(url, title)
  -> Classified` se preserva; el contrato interno de `lookup_category`
  se amplía para aceptar `path_tokens` y `title_tokens`. El diccionario
  de keywords es estático en código, ≤ 200 entradas, auditable por
  inspección. La paridad Rust ↔ Kotlin se mantiene como constraint vivo.
  D8 no negociable: Capa B debe degradarse sin error si Ollama no está
  disponible (AC-B5). El input del LLM se restringe a `domain` +
  `path_tokens` — nunca URL completa ni título. PGR-CR-004 debe
  ratificar los inputs de ambas capas antes de que T-3-006 comience
  implementación. 8 criterios para Capa A + 7 criterios para Capa B
  emitidos. 8 riesgos conocidos con mitigaciones declaradas.
```
