# Task Spec — TS-3-006

document_id: TS-3-006
task_id: T-3-006
title: Classifier Capa A — inferencia determinística (TLD + subdominio + keyword)
phase: 3
produced_by: Technical Architect
status: APPROVED — pendiente de re-auditoría por Privacy Guardian (PGR-T-3-006)
date: 2026-05-04
depends_on:
  - CR-004 (aprobado por Orchestrator vía HO-028, 2026-05-04)
  - AR-CR-004 (Technical Architect, APROBADO CON CONDICIONES)
  - PGR-CR-004 (Privacy Guardian, APROBADO CON CONDICIONES)
  - TS-0a-003 actualizada con sección "Capa A — Inferencia Determinística"
unblocks:
  - implementación de Capa A en `src-tauri/src/classifier.rs` (Rust)
  - sync paritario en `src-tauri/gen/android/.../ShareIntentActivity.kt` (Kotlin)
  - prerequisito de activación de T-3-005 ampliado (Capa B del Classifier)
no_unblocks_in_implementation_until:
  - Privacy Guardian re-audite esta TS y emita PGR-T-3-006 con APROBADO

---

## Distinción Obligatoria — Capa A ≠ Pattern Detector ≠ Episode Detector

**Esta sección debe reproducirse como comentario de cabecera en
`classifier.rs` cuando se implemente Capa A.**

| Dimensión | Capa A del Classifier | `pattern_detector.rs` | `episode_detector.rs` |
|---|---|---|---|
| Propósito | Asignar categoría a un recurso individual cuando la tabla devuelve `otro` | Detectar combinaciones recurrentes en el historial | Detectar grupos coherentes en una sesión activa |
| Temporalidad | Atómica, por recurso, en el momento de la captura | Longitudinal (días/semanas) | Tiempo real sobre la sesión actual |
| Input | `domain`, `path_tokens`, `title_tokens` recibidos en claro upstream del cifrado | Consulta SQLCipher: `domain`, `category`, `captured_at` | `Vec<SessionResource>` en memoria |
| Estado persistido | Ninguno — diccionario estático en código | Sí — patrones detectados se acumulan | Ninguno |
| Algoritmo | Tabla → TLD `ends_with` → subdominio `starts_with` → conteo de keywords | Frecuencia de co-ocurrencia | Jaccard + fallback por categoría |
| Acceso a `title`/`url` | Lee `path_tokens` y `title_tokens` recibidos como parámetros (no descifrados de BD) | **Nunca** — solo `domain`, `category`, `captured_at` | Lee `title` del `SessionResource` (memoria, no BD) |
| Determinismo | Sí — diccionario fijo, mismo input → mismo output | Sí — algoritmo determinístico | Sí — algoritmo determinístico |
| Fase | 3 (T-3-006) | 2 (T-2-001) — cerrado, D17 | 0b — cerrado |
| Conformidad | D1 (operación upstream del cifrado), D8 (sin LLM), R12 (módulo independiente) | D1, D8, D17, R12 | D1, D8, R12 |

**Capa A NO es enriquecimiento del Pattern Detector ni del Episode Detector.**
Cualquier propuesta de fundir lógica de los tres módulos debe bloquearse.

---

## Contrato del Módulo

### Módulo: `src-tauri/src/classifier.rs` (extendido)

```rust
// Capa A — Inferencia Determinística (T-3-006, CR-004).
// Tres pasos nuevos que se ejecutan SOLO cuando la tabla exacta devuelve `otro`.
// Determinístico (D8): mismo input → mismo output. Sin red, sin LLM, sin
// persistencia propia.
// D1 conforme: opera sobre `domain` (en claro), `path_tokens` (derivados de la
// URL recibida en claro upstream del cifrado) y `title_tokens` (derivados del
// título recibido en claro upstream del cifrado). Ningún acceso a campos
// cifrados de SQLCipher.

pub struct Classified {
    pub domain: String,
    pub category: String,
}

/// Contrato público — preservado.
/// `title` opcional para mantener compatibilidad: cuando viene de
/// `import_resource` o `add_capture`, ya está disponible en claro.
pub fn classify(url: &str, title: Option<&str>) -> Classified;

/// Contrato interno — ampliado.
/// Recibe `path_tokens` y `title_tokens` ya tokenizados.
fn lookup_category(
    domain: &str,
    path_tokens: &[&str],
    title_tokens: &[&str],
) -> &'static str;
```

### Orden de resolución (6 pasos)

```
classify(url, title)
   │
   ▼
extract_domain(url)
extract_path_tokens(url)
tokenize_title(title.unwrap_or(""))
   │
   ▼
lookup_category(domain, path_tokens, title_tokens):
   │
   ├─ exact_lookup(domain)              ── si != "otro" => fin
   ├─ exact_lookup(strip_one_subdomain) ── si != "otro" => fin
   ├─ exact_lookup(strip_two_subdomains)── si != "otro" => fin
   ├─ tld_inference(domain)             ── Capa A.1 — si != "otro" => fin
   ├─ subdomain_inference(domain)       ── Capa A.2 — si != "otro" => fin
   ├─ keyword_inference(path_tokens, title_tokens) ── Capa A.3 — si != "otro" => fin
   └─ "otro"
```

---

## Capa A.1 — TLD Inference

### Función

```rust
fn tld_inference(domain: &str) -> &'static str;
```

### Tabla estática

```rust
const TLD_INFERENCE: &[(&str, &'static str)] = &[
    // Más específico primero — el orden importa por `ends_with`.
    (".gob.es",    "gobierno"),
    (".gov.uk",    "gobierno"),
    (".gov.fr",    "gobierno"),
    (".gov",       "gobierno"),
    (".ac.uk",     "educación"),
    (".ac.jp",     "educación"),
    (".edu.es",    "educación"),
    (".edu",       "educación"),
];
```

### Algoritmo

```rust
fn tld_inference(domain: &str) -> &'static str {
    for (suffix, category) in TLD_INFERENCE {
        if domain.ends_with(suffix) {
            return category;
        }
    }
    "otro"
}
```

**Cota:** ≤ 30 entradas. Mantiene O(1) amortizado.

**Sync Kotlin:** la misma tabla se replica en `ShareIntentActivity.kt`
como `tldInference(d: String): String?` con `endsWith`.

---

## Capa A.2 — Subdomain Inference

### Función

```rust
fn subdomain_inference(domain: &str) -> &'static str;
```

### Tabla estática

```rust
const SUBDOMAIN_INFERENCE: &[(&str, &'static str)] = &[
    ("tienda.",    "comercio"),
    ("shop.",      "comercio"),
    ("store.",     "comercio"),
    ("blog.",      "artículos"),
    ("api.",       "desarrollo"),
    ("developer.", "desarrollo"),
    ("dev.",       "desarrollo"),
    ("docs.",      "educación"),
    ("wiki.",      "educación"),
];
```

### Algoritmo

```rust
fn subdomain_inference(domain: &str) -> &'static str {
    for (prefix, category) in SUBDOMAIN_INFERENCE {
        if domain.starts_with(prefix) {
            return category;
        }
    }
    "otro"
}
```

**Cota:** ≤ 10 entradas.

**Edge case:** `developer.apple.com` ya está en la tabla `exact_lookup`
como "desarrollo". Capa A.2 nunca llega a ejecutarse para ese dominio
porque `exact_lookup(domain)` corta la cadena en el paso 1.

---

## Capa A.3 — Keyword Inference

### Función

```rust
fn keyword_inference(
    path_tokens: &[&str],
    title_tokens: &[&str],
) -> &'static str;
```

### Diccionario estático (mínimo viable)

```rust
const KEYWORD_INFERENCE: &[(&'static str, &[&'static str])] = &[
    ("cocina", &[
        "receta", "recetas", "ingredientes", "cocinar", "plato",
        "horno", "guiso", "postre", "tapa", "menu",
    ]),
    ("deportes", &[
        "partido", "gol", "liga", "futbol", "baloncesto",
        "tenis", "formula1", "motogp", "marcador", "resultado",
    ]),
    ("entretenimiento", &[
        "pelicula", "peliculas", "serie", "series", "episodio",
        "temporada", "capitulo", "reparto", "estreno", "sinopsis",
    ]),
    ("gobierno", &[
        "ley", "decreto", "boe", "resolucion",
        "tramite", "expediente", "boja", "doe",
    ]),
    ("salud", &[
        "sintoma", "tratamiento", "consulta", "clinica",
        "diagnostico", "farmacia", "vacuna",
    ]),
];
```

**Cota dura:** suma total ≤ 200 entradas a través de todas las
categorías.

### Algoritmo

```rust
fn keyword_inference(
    path_tokens: &[&str],
    title_tokens: &[&str],
) -> &'static str {
    let mut scores: Vec<(&str, usize)> = Vec::new();
    for (category, keywords) in KEYWORD_INFERENCE {
        let count = path_tokens.iter().chain(title_tokens.iter())
            .filter(|t| keywords.contains(t))
            .map(|t| *t)
            .collect::<std::collections::HashSet<_>>()
            .len();   // tokens distintos coincidentes
        if count > 0 {
            scores.push((category, count));
        }
    }
    if scores.is_empty() {
        return "otro";
    }
    scores.sort_by(|a, b| b.1.cmp(&a.1));
    let (best_cat, best_count) = scores[0];
    if best_count < 2 {
        return "otro";   // umbral mínimo: 2 tokens distintos coincidentes
    }
    if scores.len() >= 2 && scores[0].1 == scores[1].1 {
        return "otro";   // empate => fallback determinístico
    }
    best_cat
}
```

**Reglas de decisión (declaradas — no ajustables sin nuevo CR):**

- **Umbral mínimo:** count ≥ 2 tokens distintos coincidentes con la
  misma categoría. Un único keyword no basta.
- **Margen mínimo:** la categoría ganadora debe tener al menos un
  count estrictamente mayor que la segunda. Empate → `otro`.
- **Tokens distintos:** un mismo token contado dos veces (en path y
  en título) cuenta como 1, no como 2 (`HashSet`).

### Tokenización

#### `extract_path_tokens`

Idéntica a `episode_detector.rs::extract_url_tokens` — reutilizable
directamente. Si reutilizar implica exportar la función, el
implementador convierte `extract_url_tokens` en `pub(crate)` o la
duplica en `classifier.rs` con test de paridad.

```rust
pub(crate) fn extract_path_tokens(url: &str) -> Vec<String>;
```

Filtros:
- separadores: `/ ? & = #`
- longitud mínima por token: 3
- exclusión: `www`, `com`, `html`, `php`, `htm`, `asp`, `aspx`, `jsp`,
  `org`, `net`
- exclusión de prefijos: `utm_`, `fbclid`, `gclid`
- exclusión de tokens numéricos puros

#### `tokenize_title`

Idéntica a `episode_detector.rs::tokenize`. Stopwords ES + EN, longitud
mínima 3, filtrado de números puros, lowercase. **Tras CR-004 también
filtra TLDs** (`com`, `net`, `org`, `www`, `edu`, `gov`, `io`, `app`,
`dev` — alineado con commit `f509697` H-004).

```rust
pub(crate) fn tokenize_title(title: &str) -> Vec<String>;
```

---

## Cambios en consumidores de `classify`

### `src-tauri/src/commands.rs`

| Función | Cambio |
|---|---|
| `import_resource` | Llamar `classify(&input.url, Some(&input.title))` en vez de `classify(&input.url)`. |
| `add_capture` | Llamar `classify(&url, if title.is_empty() { None } else { Some(&title) })`. |
| `import_bookmarks_html` (vía `importer::import_html_content`) | Verificar que el importer pasa el título cuando lo extrae del HTML. |

### `src-tauri/src/importer.rs`

Pasar `Some(&title)` a `classify` en cada bookmark importado.

**Estos cambios son mecánicos y no alteran ningún contrato externo.**

---

## Sync Paritario Rust ↔ Kotlin

### Función Kotlin equivalente

```kotlin
// ShareIntentActivity.kt — Capa A (T-3-006)
private fun classifyDomain(domain: String, pathTokens: List<String>,
                            titleTokens: List<String>): String {
    val d = domain.lowercase()
    return exactLookup(d)
        ?: exactLookup(stripOneSubdomain(d))
        ?: exactLookup(stripTwoSubdomains(d))
        ?: tldInference(d)
        ?: subdomainInference(d)
        ?: keywordInference(pathTokens, titleTokens)
        ?: "otro"
}
```

Las tablas `TLD_INFERENCE`, `SUBDOMAIN_INFERENCE` y `KEYWORD_INFERENCE`
en Kotlin **deben contener exactamente los mismos pares (clave →
categoría)** que las constantes Rust. Una divergencia rompe la
paridad y la categoría enviada por el relay no coincidiría con la que
el desktop derivaría sobre el mismo dominio.

### Verificación de paridad

Test estructural (sugerido como AC-A6 ejecutable):

```bash
# Script de auditoría — opcional en CI
diff <(grep -oE '"\w+\." *(=>|->) *"\w+"' classifier.rs | sort) \
     <(grep -oE '"\w+\." *(=>|->) *"\w+"' ShareIntentActivity.kt | sort)
```

---

## Acceptance Criteria

| # | Criterio | Verificable |
|---|---|---|
| AC-A1 | Contrato público `classify(url: &str, title: Option<&str>) -> Classified` preservado. Los call sites se actualizan para pasar `title` cuando lo tienen. `cargo check` desktop verde. | `grep classify\\b src/` muestra todas las llamadas con dos args. CI verde. |
| AC-A2 | `lookup_category` ejecuta los 6 pasos en orden. Cualquier paso != `otro` corta la cadena. | Test unitario con 12 casos: 1 por cada uno de los 6 caminos de retorno × 2 variantes (con y sin `title`). |
| AC-A3 | Diccionario estático ≤ 200 entradas totales. Las constantes están declaradas como `&[(&str, &[&str])]` sin estado mutable. | Test estructural con `count_keywords()` que falla si > 200. |
| AC-A4 | `cargo bench` muestra que `classify` con Capa A no excede en > 30 µs la versión actual para 1000 URLs típicas. | Benchmark en `src-tauri/benches/classify_bench.rs` con baseline registrado. |
| AC-A5 | Determinismo: ningún `std::fs`, `std::net`, `std::sync::Mutex`, `std::cell` en `classifier.rs`. Sin estado interno mutable. | Test estructural con `include_str!` + `contains`. |
| AC-A6 | Sync paritario en Kotlin: las tres tablas tienen los mismos pares (clave → categoría) que en Rust. | Diff de las tablas + test de paridad opcional en CI. |
| AC-A7 | Privacy Guardian re-audita esta TS y emite PGR-T-3-006 verificando que los inputs de Capa A.3 son `path_tokens` (en claro) y `title_tokens` (en claro), nunca campos cifrados. | Documento PGR-T-3-006 con APROBADO antes de implementar. |
| AC-A8 | `cargo test` desktop al 100% sin regresiones + `npx tsc --noEmit` limpio. | CI verde. |

### Casos de test obligatorios (AC-A2 desglosado)

| # | URL | Title | Categoría esperada | Camino |
|---|---|---|---|---|
| T1 | `https://github.com/foo/bar` | `repo` | `desarrollo` | exact_lookup |
| T2 | `https://mail.google.com/x` | None | `productividad` | strip_one_subdomain |
| T3 | `https://es.elpais.com/` | None | `noticias` | strip_one_subdomain |
| T4 | `https://sede.juntadeandalucia.es/tramite/x` | `Trámite` | `gobierno` | tld_inference (`.es` no aplica; debería ser `.gob.es` o subdomain `sede.`) — caso de borde, validar con TS de implementación |
| T5 | `https://shop.misitio.io/` | None | `comercio` | subdomain_inference |
| T6 | `https://api.misitio.com/` | None | `desarrollo` | subdomain_inference |
| T7 | `https://desconocido.com/recetas/tarta-queso` | `Receta tarta de queso ingredientes` | `cocina` | keyword_inference (count ≥ 2) |
| T8 | `https://desconocido.com/futbol/liga` | `Partido liga gol resumen` | `deportes` | keyword_inference |
| T9 | `https://desconocido.com/abc` | `Hola mundo` | `otro` | fallback (sin coincidencias) |
| T10 | `https://desconocido.com/receta-futbol` | None | `otro` | empate keyword_inference (1 token cada categoría → empate) |
| T11 | `https://github.com/x` (con título "receta cocinar plato") | `receta cocinar plato` | `desarrollo` | exact_lookup gana sobre keyword |
| T12 | `https://desconocido.com/x` con `title=None` y `path_tokens=[]` | None | `otro` | path vacío + title None |

### Tests adicionales para Capa A.3

| # | Caso | Verificable |
|---|---|---|
| K1 | Un único keyword coincidente → `otro` (umbral mínimo 2). | `keyword_inference(&["receta"], &[])` == `"otro"`. |
| K2 | 2 keywords distintos misma categoría → categoría. | `keyword_inference(&["receta", "ingredientes"], &[])` == `"cocina"`. |
| K3 | Empate 2-vs-2 entre dos categorías → `otro`. | Test con 2 tokens cocina y 2 tokens deportes. |
| K4 | Token duplicado entre path y title cuenta 1. | `keyword_inference(&["receta"], &["receta"])` == `"otro"` (count=1). |

---

## Riesgos

| ID | Riesgo | Prob. | Impacto | Mitigación | Owner |
|---|---|---|---|---|---|
| R-A1 | Implementador infla el diccionario con keywords poco discriminativos. | Media | Bajo | TS-0a-003 §"Capa A" declara mínimo viable y proceso de PR + revisión por Privacy Guardian (PG-A4). | Implementador + Privacy Guardian |
| R-A2 | Capa A.3 clasifica incorrectamente recursos cuyo path contiene keywords ambiguas. | Media | Bajo | Política de empate → `otro`. AC-A2 + K3 lo validan. | Implementador |
| R-A3 | Paridad Rust ↔ Kotlin se rompe en futuras ampliaciones. | Media | Medio | AC-A6 + script de diff opcional en CI. | Implementador + QA Auditor |
| R-A4 | Capa A introduce regresión de latencia. | Baja | Medio | AC-A4 (benchmark). | Implementador |
| R-A5 | Diccionario incluye keywords con potencial de identificación personal. | Baja | Alto | PG-A2 (PGR-CR-004 §3) — exclusión de nombres propios, marcas asociadas a identidad y términos médicos específicos. Auditoría del Privacy Guardian. | Privacy Guardian |
| R-A6 | El implementador toca `episode_detector.rs` o `pattern_detector.rs` para "compartir tokenización". | Media | Alto | Reutilización autorizada solo vía `pub(crate)` de las funciones existentes en `episode_detector.rs`. Modificación de `pattern_detector.rs` queda PROHIBIDA (D17). | QA Auditor |
| R-A7 | Capa A.3 procesa el `title` recibido en claro y se interpreta como violación de D1 por inspección superficial. | Media | Bajo | Documentar explícitamente en cabecera de `classifier.rs` y en `tokenize_title`: el Classifier opera upstream del cifrado; los tokens nunca se descifran de SQLCipher. | Privacy Guardian (re-auditoría) |

---

## Out of Scope (declarado)

- **Capa B (LLM como enriquecedor opcional)** — pertenece a T-3-005
  con scope ampliado, condicional a OD del Orchestrator.
- **Modificación de `pattern_detector.rs`, `trust_scorer.rs`,
  `state_machine.rs`** — D17 (cerrados en Fase 2).
- **Modificación de `episode_detector.rs`** — solo se autoriza
  exportar funciones existentes con `pub(crate)`. Cambios de algoritmo
  prohibidos.
- **Aprendizaje automático del diccionario** — viola D8 y PG-A1.
- **Persistencia del diccionario en SQLCipher o config externa** —
  el diccionario es estático en código.
- **Llamadas a red para enriquecer la categoría** — viola la
  invariante 2 del arch-note de Fase 0a y D8.
- **Capa A para sistemas de archivos del FS Watcher** — Capa A es
  exclusiva del Classifier de URL/dominio. El FS Watcher (T-2-000)
  tiene su propia clasificación y no se toca.

---

## Plan de Implementación

### Fase de implementación 1 — Rust

1. Refactor de `classify` para añadir `title: Option<&str>`. Actualizar
   call sites en `commands.rs` e `importer.rs`. Verificar con `cargo
   check`.
2. Añadir `extract_path_tokens` (reutilizar `episode_detector.rs::
   extract_url_tokens` exportado como `pub(crate)`) y `tokenize_title`
   (reutilizar `episode_detector.rs::tokenize`).
3. Implementar `tld_inference` con su tabla estática.
4. Implementar `subdomain_inference` con su tabla estática.
5. Implementar `keyword_inference` con el diccionario mínimo viable.
6. Modificar `lookup_category` para incorporar los 3 pasos nuevos en el
   orden declarado.
7. Añadir tests unitarios T1..T12 + K1..K4.
8. Añadir benchmark `classify_bench.rs`.
9. Verificar `cargo test` + `cargo bench` + `npx tsc --noEmit`.

### Fase de implementación 2 — Kotlin

10. Replicar `tldInference`, `subdomainInference`, `keywordInference`
    en `ShareIntentActivity.kt` con las **mismas tablas exactas**.
11. Modificar `classifyDomain` para integrar los 3 pasos nuevos.
12. Verificar paridad con script de diff (opcional en CI).

### Fase de implementación 3 — Verificación

13. QA Auditor verifica AC-A1..AC-A8.
14. Privacy Guardian verifica que `tokenize_title` no descifra ningún
    campo de SQLCipher (auditoría de los call sites).
15. Commit final con mensaje `feat(classifier-capa-a): T-3-006
    inferencia determinística TLD + subdominio + keyword`.

---

## Required Handoff

1. **Privacy Guardian** — re-auditar esta TS y emitir
   `operations/architecture-reviews/PGR-T-3-006-classifier-capa-a.md`
   verificando los 5 controles PG-A1..PG-A5 + R-A7.
2. **Desktop Tauri Shell Specialist** — implementación Rust siguiendo
   el plan de implementación. Implementación bloqueada hasta PGR-T-3-006
   APROBADO.
3. **Android Share Intent Specialist** — implementación Kotlin paralela
   con paridad estricta de las tres tablas.
4. **QA Auditor** — verificación de AC-A1..AC-A8 sobre el código
   antes de merge.

---

## Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Referenciado | operations/change-requests/CR-004-classifier-enrichment.md | APROBADO 2026-05-04 |
| Referenciado | operations/architecture-reviews/AR-CR-004-classifier-enrichment.md | APROBADO CON CONDICIONES 2026-05-04 |
| Referenciado | operations/architecture-reviews/PGR-CR-004-classifier-enrichment.md | APROBADO CON CONDICIONES 2026-05-04 |
| Referenciado | operations/handoffs/HO-028-cr-004-classifier-enrichment-approval.md | ready_for_execution 2026-05-04 |
| Referenciado | operations/task-specs/TS-0a-003-domain-category-classifier.md | actualizado 2026-05-04 (commit 1789bdf) |
| Referenciado | operations/backlogs/backlog-phase-3.md | actualizado 2026-05-04 (commit b40428b) |
| Pendiente | operations/architecture-reviews/PGR-T-3-006-classifier-capa-a.md | re-auditoría del Privacy Guardian |
| Creado | operations/task-specs/TS-3-006-classifier-capa-a.md | este documento |
