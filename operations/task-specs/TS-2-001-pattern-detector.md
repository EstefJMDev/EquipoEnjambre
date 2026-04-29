# Task Spec — TS-2-001

document_id: TS-2-001
task_id: T-2-001
title: Pattern Detector — detección de patrones longitudinales
phase: 2
produced_by: Technical Architect
status: APPROVED
date: 2026-04-27
depends_on: ninguno (paralelo a T-2-000 autorizado por backlog-phase-2.md)
unblocks: T-2-002 (Trust Scorer) tras aprobación de implementación

---

## Distinción Obligatoria R12 — Pattern Detector ≠ Episode Detector

**Esta sección debe reproducirse como comentario de cabecera en `pattern_detector.rs`.**

| Dimensión | `episode_detector.rs` | `pattern_detector.rs` |
|---|---|---|
| Propósito | Detectar grupos coherentes dentro de una sesión activa | Detectar combinaciones recurrentes a lo largo del tiempo |
| Temporalidad | Opera en tiempo real sobre la sesión actual | Opera sobre el historial completo en SQLCipher |
| Input | `Vec<SessionResource>` (en memoria, sesión viva) | Consulta a SQLCipher: `domain`, `category`, `captured_at` |
| Estado persistido | Ninguno — no persiste (comentario explícito en código) | Sí — patrones detectados se mantienen entre sesiones |
| Algoritmo | Similitud Jaccard sobre title tokens (precise) + fallback por category (broad) | Frecuencia de co-ocurrencia (domain, category) en ventanas temporales |
| Acceso a title/url | Lee `title` de `SessionResource` (campo en memoria, no en BD) | **Nunca** — solo `domain`, `category`, `captured_at` (D1) |
| Ciclo de vida | Se recalcula en cada sesión, sin estado previo | Acumula historial; cada ejecución refina los patrones existentes |

**No reutilizar `episode_detector.rs` como base.** Compartir funciones utilitarias puras (e.g. normalización de timestamps) es aceptable, pero el módulo semánticamente debe ser independiente.

---

## Contrato del Módulo

### Módulo: `src-tauri/src/pattern_detector.rs`

```rust
// Pattern Detector — Fase 2 (T-2-001)
// Propósito: detección de patrones longitudinales sobre domain/category.
// Distinción R12: este módulo opera sobre historial completo en SQLCipher
// (días/semanas), no sobre sesiones activas. Ver episode_detector.rs para
// detección de sesión. Ambos módulos son independientes semánticamente.
// Constraints activos: D1 (solo domain/category), D8 (sin LLM requerido),
// D17 (módulo completo en Fase 2, no dividir entre fases).

pub struct PatternConfig {
    pub min_frequency: usize,          // mínimo de ocurrencias para considerar un patrón
    pub lookback_days: u32,            // ventana histórica a analizar (default: 30)
    pub time_bucket_boundaries: [u32; 2], // horas de corte [morning_end, afternoon_end] (default: [12, 18])
}

impl Default for PatternConfig {
    fn default() -> Self {
        PatternConfig {
            min_frequency: 3,
            lookback_days: 30,
            time_bucket_boundaries: [12, 18],
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TimeBucket {
    Morning,    // 00:00–boundary[0]
    Afternoon,  // boundary[0]–boundary[1]
    Evening,    // boundary[1]–23:59
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryWeight {
    pub category: String,
    pub weight: f64,   // fracción del total de ocurrencias del patrón [0.0–1.0]
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DomainWeight {
    pub domain: String,
    pub weight: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemporalWindow {
    pub time_bucket: TimeBucket,
    pub day_of_week_mask: u8,  // bitmask: bit 0 = lunes, bit 6 = domingo
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectedPattern {
    pub pattern_id: String,             // UUID v4
    pub label: String,                  // derivado de dominant_category + time_bucket (sin LLM)
    pub category_signature: Vec<CategoryWeight>,
    pub domain_signature: Vec<DomainWeight>,
    pub temporal_window: TemporalWindow,
    pub frequency: usize,               // número de sesiones en que apareció este patrón
    pub first_seen: i64,                // Unix timestamp (segundos)
    pub last_seen: i64,
}

/// Analiza el historial en SQLCipher y devuelve patrones recurrentes.
/// Solo accede a: domain, category, captured_at.
/// No accede a url ni title bajo ninguna circunstancia (D1).
pub fn detect_patterns(
    conn: &rusqlite::Connection,
    config: &PatternConfig,
) -> Result<Vec<DetectedPattern>, PatternDetectorError>;
```

### Generación de `label` sin LLM (baseline D8)

```
label = "{dominant_category} ({time_bucket_es})"
```

Ejemplos: `"research (mañana)"`, `"productivity (tarde)"`, `"media (noche)"`.

`dominant_category` = la categoría con mayor `weight` en `category_signature`.

---

## Acceso a Datos SQLCipher

### Query permitida (única):

```sql
SELECT domain, category, captured_at
FROM resources
WHERE captured_at >= ?1
ORDER BY captured_at ASC
```

Parámetro `?1`: `NOW - lookback_days * 86400` (Unix timestamp).

### Campos prohibidos (D1):

`url`, `title` — **nunca deben aparecer en ninguna query ni en ningún campo de
`DetectedPattern`**. Si en el futuro se añaden campos a la tabla `resources`, el
módulo debe revisar explícitamente que no accede a campos no autorizados.

---

## Algoritmo Baseline Determinístico

### Paso 1 — Agrupar por sesión temporal

Agrupar recursos consecutivos donde la diferencia entre `captured_at` sucesivos
es ≤ 30 minutos. Cada grupo = una "sesión de captura".

### Paso 2 — Etiquetar cada sesión

Para cada sesión, derivar:
- `time_bucket`: según la hora del primer recurso de la sesión y `time_bucket_boundaries`
- `day_of_week`: día de la semana del primer recurso (0 = lunes)
- `category_set`: conjunto de `category` únicos en la sesión
- `domain_set`: conjunto de `domain` únicos en la sesión

### Paso 3 — Detectar co-ocurrencias recurrentes

Para cada combinación única de `(category_set, time_bucket)`:
- contar cuántas sesiones contienen esa combinación → `frequency`
- si `frequency >= config.min_frequency`: candidato a patrón
- `day_of_week_mask`: OR acumulativo de los días de todas las sesiones que
  contienen la combinación

### Paso 4 — Construir `DetectedPattern`

Para cada candidato:
- `pattern_id`: UUID v4 generado en el momento de detección
- `category_signature`: cada categoría única + su peso = ocurrencias_categoría / total_ocurrencias_patrón
- `domain_signature`: ídem para dominios
- `temporal_window`: `time_bucket` + `day_of_week_mask`
- `first_seen` / `last_seen`: timestamps del primer y último recurso de las sesiones que forman el patrón

### Paso 5 — Filtrar solapamientos

Si dos patrones comparten >80% de `category_signature`, conservar el de mayor
`frequency`. (Evita duplicados en patrones muy similares.)

### Complejidad esperada

O(N log N) sobre N recursos — no requiere infraestructura adicional. Adecuado
para el tamaño de datos esperado en Fase 2 (cientos a pocos miles de recursos).

---

## LLM como Mejora Opcional (no requerido — D8)

Si en una iteración futura se añade generación de etiquetas con LLM local
(Ollama), debe:
1. Declararse explícitamente en una TS separada o como addendum a esta
2. No modificar la firma de `detect_patterns()` — el LLM solo enriquece `label`
3. El baseline determinístico debe seguir funcionando si el LLM no está disponible

**Esta TS no requiere ni activa LLM.**

---

## Decisión de Persistencia (Technical Architect)

**Decisión: los patrones detectados permanecen en memoria para T-2-001.**

Justificación: el esquema de tabla para `detected_patterns` en SQLCipher debe
validarse contra los inputs esperados por Trust Scorer (T-2-002) antes de
commitear la migración. Persistir prematuramente acopla el esquema antes de
que T-2-002 confirme que `DetectedPattern` es suficiente.

Implicación: `detect_patterns()` se llama desde `commands.rs` cuando el frontend
solicita el estado; no hay caché entre reinicios hasta que T-2-002 esté aprobado.

La persistencia en SQLCipher se especificará en TS-2-002 o como addendum si
el Technical Architect lo determina tras revisar el contrato de T-2-002.

---

## Plan de Tests

### Dataset sintético

```
resources (25 entradas, captured_at en UTC Unix):

Sesión A — lunes mañana (3 veces, semanas 1/2/3):
  domain: "github.com",  category: "development", captured_at: lunes 09:15
  domain: "docs.rs",     category: "development", captured_at: lunes 09:30
  domain: "crates.io",   category: "development", captured_at: lunes 09:45

Sesión B — miércoles tarde (3 veces, semanas 1/2/3):
  domain: "youtube.com", category: "media",       captured_at: miércoles 15:10
  domain: "spotify.com", category: "media",       captured_at: miércoles 15:20

Sesión C — única (no debe superar min_frequency=3):
  domain: "nytimes.com", category: "news",        captured_at: viernes 20:00
```

### Tests requeridos

```rust
#[test]
fn test_detect_known_pattern_development_morning() {
    // Dataset sintético con Sesión A × 3
    // Esperado: patrón con label "development (mañana)",
    //           frequency >= 3, day_of_week_mask con bit 0 activo (lunes)
}

#[test]
fn test_detect_known_pattern_media_afternoon() {
    // Dataset sintético con Sesión B × 3
    // Esperado: patrón con label "media (tarde)",
    //           frequency >= 3, day_of_week_mask con bit 2 activo (miércoles)
}

#[test]
fn test_below_min_frequency_not_detected() {
    // Dataset sintético con Sesión C × 1
    // Esperado: Vec vacío (frequency < min_frequency=3)
}

#[test]
fn test_no_url_or_title_in_query() {
    // Verificación estructural: inspect the SQL strings used in detect_patterns()
    // Ninguna query debe contener "url" ni "title"
}

#[test]
fn test_pattern_id_is_uuid() {
    // Todos los pattern_id en el resultado son UUID v4 válidos
}
```

Los 14 tests de cargo test existentes deben pasar sin regresiones.

---

## Criterios de Aprobación Post-Implementación

El Technical Architect revisará:

- [ ] `pattern_detector.rs` existe como módulo independiente y no tiene `use crate::episode_detector` en ninguna línea (R12)
- [ ] El comentario de cabecera del módulo incluye la distinción R12 con la tabla Pattern Detector vs Episode Detector
- [ ] Ninguna query SQLCipher en el módulo contiene `url` ni `title` (D1)
- [ ] `PatternConfig.min_frequency` es un parámetro — no hay constante hardcoded equivalente
- [ ] `DetectedPattern` incluye los 8 campos requeridos: `pattern_id`, `label`, `category_signature`, `domain_signature`, `temporal_window`, `frequency`, `first_seen`, `last_seen`
- [ ] Los 5 tests nuevos pasan y los 14 tests existentes no tienen regresiones (`cargo test`)
- [ ] `npx tsc --noEmit` limpio si se añade comando Tauri
- [ ] El contrato de `DetectedPattern` es coherente con los inputs esperados por T-2-002 (Trust Scorer recibirá `Vec<DetectedPattern>`)

---

## Handoffs Requeridos Post-Implementación

1. **Technical Architect** — revisión del contrato `DetectedPattern` contra inputs de T-2-002 y verificación de que ninguna query accede a campos prohibidos
2. Tras aprobación del Technical Architect → **HO-011** kickoff implementación desbloquea T-2-002

---

## Firma

approved_by: Technical Architect
approval_date: 2026-04-27
notes: Spec conforme a backlog-phase-2.md (T-2-001), HO-010 y constraints D1/D8/D17/R12. Persistencia diferida a T-2-002 por decisión de Technical Architect. Contrato de DetectedPattern considerado suficiente para que Trust Scorer lo consuma sin modificaciones de interfaz.
