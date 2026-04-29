# Task Spec — TS-2-002

document_id: TS-2-002
task_id: T-2-002
title: Trust Scorer — score determinístico por patrón
phase: 2
produced_by: Technical Architect
status: APPROVED
date: 2026-04-27
depends_on: T-2-001 (Pattern Detector implementado y aprobado por AR-2-003)
unblocks: T-2-003 (State Machine) tras aprobación de la implementación de trust_scorer.rs

---

## Distinción Obligatoria R12 — Trust Scorer ≠ Pattern Detector ≠ State Machine

**Esta sección debe reproducirse como comentario de cabecera en `trust_scorer.rs`.**

| Dimensión | `pattern_detector.rs` (T-2-001) | `trust_scorer.rs` (este — T-2-002) | `state_machine.rs` (T-2-003) |
|---|---|---|---|
| Propósito | Detectar combinaciones recurrentes en historial | Asignar `trust_score` y `stability_score` por patrón | Decidir transiciones de estado del sistema |
| Input | Query SQLCipher (`domain`, `category`, `captured_at`) | `&[DetectedPattern]` (en memoria) | `&[TrustScore]` + estado actual + acción de usuario |
| Output | `Vec<DetectedPattern>` | `Vec<TrustScore>` | `TrustState` y transiciones |
| Acceso a SQLCipher | Sí — única query auditada | **No** — input puro vía referencia | Sí — solo persistir el estado enum |
| Decide acciones | No | **No (D4)** | **Sí — única autoridad (D4)** |
| Persistencia | Diferida — en memoria (TS-2-001) | En memoria — recalculable on-demand | Sí — persiste `current_state` |
| Estado interno | Recalcula cada llamada | Sin estado — función pura | Mantiene FSM con persistencia |
| Determinismo | D8 — sin LLM | D8 — sin LLM, bit-exacto dado mismo input | Determinístico, transiciones explícitas |

**No reutilizar `pattern_detector.rs` ni anticipar acoplamiento con `state_machine.rs`** (este último no existe aún). Trust Scorer es una capa de cálculo pura entre detección y autoridad. Compartir tipos utilitarios puros (e.g. helpers de timestamps) es aceptable solo a través de un módulo común si fuera necesario; no es necesario en T-2-002.

### Comentario de cabecera obligatorio en el módulo Rust

```rust
// Trust Scorer — Fase 2 (T-2-002)
// Propósito: calcular trust_score y stability_score por patrón detectado.
// Trust Scorer produce inputs para la State Machine.
// No toma decisiones de acción (D4).
// Distinto de pattern_detector.rs (detección) y state_machine.rs (autoridad) — R12.
// Constraints activos: D1 (sin acceso a url/title), D4 (sin API de acción),
// D5 (stability_score con entropía normalizada en [0.0, 1.0] estricto),
// D8 (baseline determinístico sin LLM).
```

---

## Contrato del Módulo

### Módulo: `src-tauri/src/trust_scorer.rs`

```rust
use crate::pattern_detector::DetectedPattern;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone)]
pub struct TrustConfig {
    /// Umbral inferior: por encima de este `trust_score` el tier sale de Low.
    pub tier_low_max: f64,        // default: 0.4
    /// Umbral superior: por encima de este `trust_score` el tier es High.
    pub tier_high_min: f64,       // default: 0.75

    /// Vida media (en días) del decaimiento exponencial sobre `last_seen`.
    pub half_life_days: f64,      // default: 14.0

    /// Saturación lineal de `frequency`. Por encima de este valor,
    /// `frequency_factor = 1.0`.
    pub frequency_saturation: f64, // default: 12.0

    /// Pesos de combinación para `trust_score`. Suma debe ser 1.0.
    pub w_frequency: f64,         // default: 0.5
    pub w_recency: f64,           // default: 0.3
    pub w_temporal: f64,          // default: 0.2
}

impl Default for TrustConfig {
    fn default() -> Self {
        TrustConfig {
            tier_low_max: 0.4,
            tier_high_min: 0.75,
            half_life_days: 14.0,
            frequency_saturation: 12.0,
            w_frequency: 0.5,
            w_recency: 0.3,
            w_temporal: 0.2,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConfidenceTier {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrustScore {
    pub pattern_id: String,         // referencia 1:1 al DetectedPattern.pattern_id (UUID v4)
    pub trust_score: f64,           // [0.0, 1.0]
    pub stability_score: f64,       // [0.0, 1.0] — entropía normalizada (D5)
    pub recency_weight: f64,        // [0.0, 1.0] — decaimiento exponencial respecto a now
    pub confidence_tier: ConfidenceTier,
}

#[derive(Debug)]
pub enum TrustScorerError {
    InvalidConfig(String),
}

impl std::fmt::Display for TrustScorerError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TrustScorerError::InvalidConfig(m) => write!(f, "invalid trust config: {m}"),
        }
    }
}

impl std::error::Error for TrustScorerError {}

/// Calcula scores de confianza para un conjunto de patrones detectados.
///
/// `now_unix` se pasa explícitamente para garantizar testabilidad determinística
/// (D8): dos llamadas con el mismo `patterns`, mismo `config` y mismo `now_unix`
/// deben producir bit-exactamente el mismo `Vec<TrustScore>`.
///
/// El módulo no accede a SQLCipher ni a `url`/`title` (D1).
/// El módulo no decide acciones — solo calcula scores (D4).
pub fn score_patterns(
    patterns: &[DetectedPattern],
    config: &TrustConfig,
    now_unix: i64,
) -> Result<Vec<TrustScore>, TrustScorerError>;
```

### Justificación: `now_unix` explícito

Pasar `now_unix: i64` explícitamente (en lugar de leer `SystemTime::now()` internamente) habilita:

1. **Tests reproducibles** — los tests fijan `now_unix` al timestamp de referencia del dataset sintético sin necesidad de mocking del reloj.
2. **Determinismo bit-exacto** — el mismo input produce el mismo output siempre, pre-condición de D8.
3. **Composabilidad** — el llamador (`commands.rs`) controla el reloj y puede sincronizar varias llamadas a `now`.

Trade-off aceptado: el llamador tiene la responsabilidad de pasar un timestamp consistente. Esto es trivial (`SystemTime::now()` se invoca una vez en `commands.rs`) y se considera mejor práctica que el efecto secundario oculto.

---

## Restricción D4 — Sin API de Acción

**Regla bloqueante de aceptación.** El módulo `trust_scorer.rs` **no puede exponer** ningún elemento público (función, método, tipo, trait, macro) cuyo nombre sugiera o realice una decisión de acción. Lista explícita de prohibiciones:

| Substring prohibido en nombres públicos | Justificación |
|---|---|
| `recommend` | Recomendar es decidir — autoridad de State Machine |
| `decide` | Decisión explícita — D4 |
| `promote` | Cambiar de tier es transición — D4 |
| `transition` | Transiciones son potestad de la FSM |
| `apply_action` / `apply` | Aplicar implica ejecutar política |
| `should_*` (e.g. `should_promote`, `should_trust`) | Forma estructural de decisión |

Trust Scorer **solo calcula y devuelve** `TrustScore`. La interpretación (¿es suficiente para promover este patrón a Trusted?) corresponde exclusivamente a `state_machine.rs` (T-2-003).

**Test estructural obligatorio (`test_no_action_decision_api`):** verifica por inspección textual del archivo `trust_scorer.rs` que ningún nombre público contiene los substrings prohibidos. Implementación recomendada: leer el propio archivo fuente con `include_str!` y comprobar ausencia de los tokens en la sección pública. Alternativa aceptable: lista enumerada de los símbolos públicos del módulo declarada en el test.

**Forbidden imports anticipados:** el módulo no debe contener `use crate::state_machine::*` ni cualquier otro símbolo de `state_machine` (que no existe aún). Trust Scorer no anticipa acoplamiento.

---

## Restricción D5 — Fórmula de `stability_score`

`stability_score` mide la concentración de la `category_signature` del patrón mediante entropía de Shannon normalizada. Cuanto más concentrada (una sola categoría dominante), mayor el score.

### Fórmula exacta

Sea `category_signature = [(c₁, w₁), (c₂, w₂), …, (cₙ, wₙ)]` con `wᵢ > 0` y `Σ wᵢ = 1` (garantizado por construcción en `pattern_detector::build_pattern`).

```text
N = número de categorías con wᵢ > 0
H = -Σᵢ wᵢ · log₂(wᵢ)              (entropía de Shannon, base 2)
H_max = log₂(N)                     (entropía máxima posible para N categorías)

stability_score = 1.0 - (H / H_max) si N >= 2
stability_score = 1.0               si N == 1     (concentración total)
stability_score = 0.0               si N == 0     (caso degenerado — sin categorías)
```

### Casos límite

| Caso | N | Comportamiento | Razón |
|---|---|---|---|
| Categoría única | 1 | `stability_score = 1.0` (devolver sin calcular) | `H = 0`, `H_max = log₂(1) = 0` ⇒ división por cero. Convención: concentración total. |
| Sin categorías | 0 | `stability_score = 0.0` | Patrón degenerado. No debería ocurrir si `pattern_detector` valida, pero el scorer es defensivo. |
| Distribución uniforme | N | `stability_score = 0.0` | `H = log₂(N) = H_max` ⇒ `1 - 1 = 0` (dispersión máxima). |

### Clamp final

Por imprecisión de coma flotante (e.g. suma de pesos = 0.9999999), el resultado podría caer ligeramente fuera de [0, 1]. Se aplica clamp explícito:

```rust
let stability_score = ((1.0 - h / h_max).max(0.0)).min(1.0);
```

**Garantía:** `stability_score ∈ [0.0, 1.0]` estricto. Test estructural lo blinda.

---

## Algoritmo Determinístico (D8) — Fórmula de `trust_score`

Tres factores combinados linealmente. Todos los factores acotados en [0.0, 1.0] antes de combinarse.

### Factor 1 — `frequency_factor` (saturación lineal)

```text
frequency_factor = min(frequency as f64 / config.frequency_saturation, 1.0)
```

A partir de `config.frequency_saturation` ocurrencias, el factor se satura a `1.0`. Default `12.0`: aproximadamente cuatro semanas de un patrón con tres apariciones por semana saturan el factor.

### Factor 2 — `recency_weight` (decaimiento exponencial)

```text
days_elapsed   = (now_unix - last_seen) as f64 / 86400.0
recency_weight = 0.5_f64.powf(days_elapsed / config.half_life_days)
```

Si `now_unix < last_seen` (timestamp futuro, no debería ocurrir), `days_elapsed` puede ser negativo. Por seguridad: clamp `recency_weight = recency_weight.min(1.0).max(0.0)`.

Default `half_life_days = 14.0`: tras 14 días sin nuevas ocurrencias, el peso cae a `0.5`; tras 28 días, a `0.25`; tras 42 días, a `0.125`.

`recency_weight` se expone tal cual en el campo del mismo nombre de `TrustScore` (no se compone con la combinación lineal antes — el llamador puede inspeccionar el factor crudo).

### Factor 3 — `temporal_coherence` (concentración de día de la semana)

A partir de `temporal_window.day_of_week_mask: u8` (bitmask, bit 0 = lunes … bit 6 = domingo). Sea `popcount` el número de días activos.

```text
si popcount == 0:  temporal_coherence = 0.0   (máscara inválida — defensivo)
si popcount >= 1:  temporal_coherence = 1.0 - (popcount - 1) as f64 / 6.0
```

Justificación: un patrón confinado a un solo día de la semana es máximamente coherente (`1.0`). Un patrón que abarca los siete días no tiene coherencia semanal (`0.0`). Lineal en el medio.

`time_bucket` no entra en la fórmula porque ya está fijado por construcción de `DetectedPattern` (cada patrón tiene un único `time_bucket` — la varianza interna de bucket no existe). Si en el futuro `temporal_window` se extiende para incluir varios buckets, `temporal_coherence` se redefine por addendum.

### Combinación lineal

```text
trust_raw = config.w_frequency * frequency_factor
          + config.w_recency   * recency_weight
          + config.w_temporal  * temporal_coherence

trust_score = trust_raw.max(0.0).min(1.0)   (clamp defensivo)
```

Pesos por defecto: `w_frequency = 0.5`, `w_recency = 0.3`, `w_temporal = 0.2`. Suma `= 1.0`.

**Validación de configuración:** `score_patterns` devuelve `TrustScorerError::InvalidConfig` si:

- `(w_frequency + w_recency + w_temporal - 1.0).abs() > 1e-6`
- `tier_low_max >= tier_high_min`
- `half_life_days <= 0.0`
- `frequency_saturation <= 0.0`

### Por qué combinación lineal y no producto / media geométrica

- **Lineal:** un factor cero no aniquila el score (un patrón muy frecuente y reciente pero disperso semanalmente sigue puntuando alto). Coherente con la intuición de que la coherencia temporal es deseable pero no necesaria.
- **Producto / media geométrica:** un solo factor en cero cancela todo. Demasiado severo para Fase 2; descartable como mejora calibrable en Fase 3.

Si la calibración en Fase 3 sugiere mayor severidad, la fórmula puede reformularse mediante addendum sin alterar la firma pública.

### Asignación de `confidence_tier`

```text
si trust_score < config.tier_low_max:           ConfidenceTier::Low
sino si trust_score < config.tier_high_min:     ConfidenceTier::Medium
sino:                                            ConfidenceTier::High
```

Defaults: `Low` si `< 0.4`; `Medium` si `[0.4, 0.75)`; `High` si `>= 0.75`. Configurables vía `TrustConfig` (D17 / acceptance criteria del backlog: "umbrales de confidence_tier configurables, no hardcoded").

### Determinismo bit-exacto

- Sin LLM. Sin RNG. Sin lectura de `SystemTime::now()` interna.
- Iteración sobre `&[DetectedPattern]` en orden de entrada — el output preserva el orden del input (no hay reordenamiento interno).
- Operaciones de coma flotante en orden estable (mismo input ⇒ misma secuencia de operaciones ⇒ mismo resultado bit-exacto en una misma plataforma).

---

## Acceso a Datos

**Trust Scorer no accede a SQLCipher.** Recibe `&[DetectedPattern]` por referencia. Esto refuerza tres constraints simultáneamente:

| Constraint | Cumplimiento |
|---|---|
| D1 — sin acceso a `url`/`title` | `DetectedPattern` no contiene esos campos (verificado en AR-2-003). El scorer es input-puro. |
| D4 — sin autoridad de acción | Sin acceso a estado persistido, no puede mutar nada. |
| R12 — independencia de módulos | El scorer no conoce el origen de los `DetectedPattern` ni su próximo consumidor. |

Cualquier futura optimización que persista `TrustScore` en SQLCipher debe especificarse en TS-2-003 o como addendum (ver "Decisión de Persistencia" abajo).

---

## Decisión de Persistencia (Technical Architect)

**Decisión: los `TrustScore` se calculan on-demand desde `Vec<DetectedPattern>` y se mantienen en memoria. No se persisten en SQLCipher en T-2-002.**

Justificación:

1. **Coherencia con TS-2-001.** Pattern Detector difirió la persistencia de `DetectedPattern` por la misma razón estructural: el contrato del consumidor (T-2-002) debía validar que la información era suficiente antes de comprometer un esquema de tabla. La misma lógica aplica a T-2-002 → T-2-003: hasta que la State Machine confirme qué subset de scores necesita (probablemente solo el último valor por patrón), persistir prematuramente acopla esquema con interfaz no estabilizada.
2. **Recalcular es barato.** `score_patterns` es O(P · K) donde P = número de patrones y K = tamaño promedio de `category_signature`. Para los volúmenes esperados de Fase 2 (decenas a bajas centenas de patrones, K < 10) el cálculo es despreciable comparado con la query de patrones a SQLCipher.
3. **Determinismo refuerza la estrategia.** Dado que `score_patterns` es determinístico bit-exacto, recalcular nunca produce inconsistencias.

Implicación concreta:

- `commands.rs` invocará `pattern_detector::detect_patterns(...)` seguido de `trust_scorer::score_patterns(...)` cuando el frontend solicite el estado.
- No se añade tabla `trust_scores` ni migración en T-2-002.
- T-2-003 (State Machine) sí persiste su `current_state` enum en SQLCipher (eso es decisión de TS-2-003). Si T-2-003 determina que necesita persistir scores históricos para auditoría de transiciones, lo especificará como addendum a esta TS o en TS-2-003.

---

## LLM Como Mejora Opcional (no requerido — D8)

Si en una iteración futura se añade calibración de pesos (`w_frequency`, `w_recency`, `w_temporal`) o ajuste de umbrales (`tier_low_max`, `tier_high_min`) mediante un modelo local, debe:

1. Declararse en una TS separada o como addendum a esta TS.
2. No modificar la firma de `score_patterns()` — el LLM solo influye en la generación de `TrustConfig`, no en el cálculo.
3. El baseline determinístico debe seguir funcionando con `TrustConfig::default()` si el LLM no está disponible.

**Esta TS no requiere ni activa LLM.**

---

## Plan de Tests

### Helpers requeridos

Tests sintéticos construyen `DetectedPattern` directamente (sin invocar al detector ni a SQLCipher). Helper sugerido:

```rust
fn pattern(
    pattern_id: &str,
    cats: &[(&str, f64)],
    domains: &[(&str, f64)],
    bucket: TimeBucket,
    dow_mask: u8,
    frequency: usize,
    first_seen: i64,
    last_seen: i64,
) -> DetectedPattern { ... }
```

### Tests requeridos (mínimo 6)

```rust
#[test]
fn test_pattern_frequent_recent_high_score() {
    // frequency = 10, last_seen = NOW, day_of_week_mask = 0b0000_0001 (un solo día)
    // Esperado: trust_score > 0.7, confidence_tier = High,
    //           recency_weight ≈ 1.0
}

#[test]
fn test_pattern_frequent_old_lower_score() {
    // frequency = 10, last_seen = NOW - 60 días (half_life_days = 14)
    // Esperado: recency_weight < 0.1 (60/14 ≈ 4.28 vidas medias ⇒ 0.5^4.28 ≈ 0.051),
    //           trust_score reducido respecto a un patrón equivalente reciente,
    //           confidence_tier degradado.
}

#[test]
fn test_pattern_dispersed_categories_low_stability() {
    // category_signature = 4 categorías con weights ≈ 0.25 cada una
    // H ≈ 2.0, H_max = log2(4) = 2.0 ⇒ stability_score ≈ 0.0
    // Tolerancia: stability_score < 0.05
}

#[test]
fn test_pattern_single_category_max_stability() {
    // category_signature = [("development", 1.0)]
    // Esperado: stability_score == 1.0 exacto (rama N==1, sin cálculo)
}

#[test]
fn test_scores_in_range() {
    // Para un conjunto variado de patrones (frequency 1..50, last_seen variable,
    // dow_mask variable, signatures de 1..6 categorías):
    // assert para cada TrustScore: 0.0 <= trust_score <= 1.0
    //                              0.0 <= stability_score <= 1.0
    //                              0.0 <= recency_weight <= 1.0
    // (D5 + clamp defensivo)
}

#[test]
fn test_no_action_decision_api() {
    // Test estructural: lee el archivo trust_scorer.rs vía include_str! y
    // verifica que no contiene ninguno de los substrings prohibidos como
    // declaración pública (`pub fn recommend`, `pub fn decide`, `pub fn promote`,
    // `pub fn transition`, `pub fn apply_action`, `pub fn should_`).
    // Implementación recomendada:
    //   const SRC: &str = include_str!("../trust_scorer.rs");
    //   for forbidden in ["pub fn recommend", "pub fn decide", "pub fn promote",
    //                     "pub fn transition", "pub fn apply_action",
    //                     "pub fn should_"] {
    //       assert!(!SRC.contains(forbidden), "D4 violation: {forbidden}");
    //   }
}
```

### Tests adicionales recomendados (no obligatorios pero deseables)

```rust
#[test]
fn test_determinism_bit_exact() {
    // Llamar score_patterns dos veces con el mismo input + mismo now_unix.
    // Comparar Vec<TrustScore> campo a campo: deben ser idénticos.
}

#[test]
fn test_invalid_config_weights() {
    // TrustConfig con w_frequency + w_recency + w_temporal = 0.7
    // Esperado: Err(TrustScorerError::InvalidConfig(_))
}

#[test]
fn test_confidence_tier_thresholds_configurable() {
    // Construir un patrón cuyo trust_score conocido sea ≈ 0.5.
    // Con tier_low_max = 0.6 ⇒ Low; con tier_low_max = 0.3 y tier_high_min = 0.8 ⇒ Medium.
}
```

### Garantía de no regresión

Los **24 tests existentes** (19 de Fase 1 + 5 de Pattern Detector) deben seguir pasando sin modificación. Total esperado tras T-2-002: **30 tests** mínimo (24 previos + 6 nuevos obligatorios).

---

## Criterios de Aprobación Post-Implementación

El Technical Architect verificará antes de desbloquear T-2-003:

- [ ] `trust_scorer.rs` existe como módulo independiente registrado en `lib.rs`.
- [ ] Comentario de cabecera incluye declaración de D4, D5, D8 y R12, y la tabla comparativa Trust Scorer / Pattern Detector / State Machine.
- [ ] El módulo no contiene `use crate::state_machine::*` ni cualquier import de `state_machine` (no existe aún; sin acoplamiento anticipado).
- [ ] No hay funciones públicas con nombres que contengan `recommend`, `decide`, `promote`, `transition`, `apply_action` ni `should_` (D4). Verificado por `test_no_action_decision_api`.
- [ ] `stability_score` acotado en [0.0, 1.0] verificado por `test_scores_in_range`.
- [ ] Caso `N == 1` devuelve `stability_score = 1.0` exacto, verificado por `test_pattern_single_category_max_stability`.
- [ ] Umbrales `tier_low_max`, `tier_high_min`, `half_life_days`, `frequency_saturation`, pesos `w_*` configurables vía `TrustConfig` con `Default`.
- [ ] Algoritmo determinístico: dos llamadas con el mismo `(patterns, config, now_unix)` producen el mismo output bit-exacto (verificable por `test_determinism_bit_exact` si se incluye, o por inspección de la firma sin RNG/IO).
- [ ] `score_patterns` valida `TrustConfig` y devuelve `TrustScorerError::InvalidConfig` si los pesos no suman 1.0 o si los umbrales son inconsistentes.
- [ ] El módulo no accede a SQLCipher (sin `use rusqlite`, sin `Connection`, sin queries).
- [ ] Los 6 tests nuevos obligatorios pasan; los 24 tests existentes no tienen regresiones (`cargo test`).
- [ ] `npx tsc --noEmit` limpio si se añade comando Tauri (e.g. `get_trust_scores` en `commands.rs`).
- [ ] El contrato de `TrustScore` es coherente con los inputs esperados por T-2-003 (State Machine consumirá `&[TrustScore]` para evaluar transiciones).

---

## Restricciones Declaradas Explícitamente

| Constraint | Cómo aplica en TS-2-002 |
|---|---|
| **D1** — solo `domain`/`category` accesibles en claro | Trust Scorer recibe `&[DetectedPattern]` y `DetectedPattern` no contiene `url` ni `title` (confirmado en AR-2-003). El scorer es input-seguro por construcción. |
| **D4** — autoridad de la State Machine | Sin API de acción. Lista de prohibiciones explícita. Test estructural blindando los nombres públicos. |
| **D5** — `stability_score` con entropía normalizada en [0.0, 1.0] | Fórmula fijada arriba (sección "Restricción D5"). Casos límite definidos. Clamp defensivo. Test estructural. |
| **D8** — baseline determinístico sin LLM | Sin RNG, sin LLM, sin IO. `now_unix` explícito. Iteración estable sobre `&[DetectedPattern]`. |
| **R12** — Trust Scorer ≠ Pattern Detector ≠ State Machine | Tabla comparativa de tres columnas en cabecera del módulo. Sin imports cruzados. Sin reutilización de código no utilitario. |

---

## Handoffs Requeridos Post-Implementación

1. **Technical Architect** — revisión arquitectónica (`AR-2-004-trust-scorer-review.md`):
   - Verificar los 12 criterios de aprobación post-implementación.
   - Confirmar que el contrato de `TrustScore` es suficiente para alimentar T-2-003 (State Machine) sin modificaciones de interfaz.
   - Verificar ausencia de acoplamiento con `state_machine.rs` (que no existe aún).
2. Tras aprobación del Technical Architect → emisión del HO de kickoff de T-2-003 (drafting de TS-2-003 — State Machine).

La implementación de `trust_scorer.rs` queda autorizada al **Desktop Tauri Shell Specialist** únicamente con TS-2-002 firmado por Technical Architect y aprobado por Orchestrator.

---

## Firma

approved_by: Technical Architect
approval_date: 2026-04-27
notes: Spec conforme a HO-011 y constraints D1/D4/D5/D8/R12. Contrato de TrustScore considerado suficiente para que State Machine (T-2-003) consuma scores sin modificaciones de interfaz. Persistencia diferida a TS-2-003 — los scores se calculan on-demand desde DetectedPattern, en memoria.
