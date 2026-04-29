# Task Spec — TS-2-003

document_id: TS-2-003
task_id: T-2-003
title: State Machine — FSM de confianza con autoridad exclusiva (D4)
phase: 2
produced_by: Technical Architect
status: APPROVED
date: 2026-04-27
depends_on: T-2-002 (Trust Scorer implementado y aprobado por AR-2-004)
unblocks: T-2-004 (Privacy Dashboard completo) — D14 lo bloquea hasta tener TrustState contractual

---

## Distinción Obligatoria R12 — Pattern Detector ≠ Trust Scorer ≠ State Machine

**Esta sección debe reproducirse como comentario de cabecera en `state_machine.rs`.**

| Dimensión | `pattern_detector.rs` (T-2-001) | `trust_scorer.rs` (T-2-002) | `state_machine.rs` (este — T-2-003) |
|---|---|---|---|
| Propósito | Detectar combinaciones recurrentes en historial | Asignar `trust_score` y `stability_score` por patrón | Decidir transiciones de estado del sistema |
| Input | Query SQLCipher (`domain`, `category`, `captured_at`) | `&[DetectedPattern]` (en memoria) | `&[TrustScore]` + estado actual + acción de usuario |
| Output | `Vec<DetectedPattern>` | `Vec<TrustScore>` | `TrustState` y transiciones |
| Acceso a SQLCipher | Sí — única query auditada | **No** — input puro vía referencia | **Sí — solo persistir el estado enum + `last_transition_at`** |
| Decide acciones | No | **No (D4)** | **Sí — única autoridad (D4)** |
| Persistencia | Diferida — en memoria (TS-2-001) | En memoria — recalculable on-demand | Sí — persiste `current_state` + `last_transition_at` |
| Estado interno | Recalcula cada llamada | Sin estado — función pura | **Mantiene FSM con persistencia** |
| Determinismo | D8 — sin LLM | D8 — sin LLM, bit-exacto dado mismo input | D8 — transiciones explícitas, bit-exactas dado mismo input |

**No reutilizar `pattern_detector.rs` ni `trust_scorer.rs`.** State Machine es una capa de autoridad pura por encima del Trust Scorer. Compartir tipos utilitarios puros (e.g. helpers de timestamps) es aceptable solo a través de un módulo común si fuera necesario; no es necesario en T-2-003. La State Machine **consume** `TrustScore` por parámetro — nunca al revés (ver §"Restricción D4 — Autoridad Exclusiva").

### Comentario de cabecera obligatorio en el módulo Rust

```rust
// State Machine — Fase 2 (T-2-003)
// Propósito: gestionar la FSM de confianza (Observing → Learning → Trusted → Autonomous).
// La State Machine es la ÚNICA autoridad de transición y de acción (D4).
// Distinto de pattern_detector.rs (detección) y trust_scorer.rs (cálculo de scores) — R12.
// Constraints activos: D4 (autoridad exclusiva), D8 (determinismo sin LLM),
// D1 (sin acceso a url/title transitivo), D14 (T-2-004 depende de este contrato).
//
// State Machine vs Pattern Detector vs Trust Scorer (R12):
// | Dimensión       | pattern_detector.rs    | trust_scorer.rs          | state_machine.rs (este)
// | Propósito       | Detectar combinaciones | Asignar trust/stability  | Decidir transiciones
// | Input           | Query SQLCipher        | &[DetectedPattern]       | &[TrustScore] + estado
// | Output          | Vec<DetectedPattern>   | Vec<TrustScore>          | TrustState
// | Acceso BD       | Sí (única query D1)    | NO — input puro          | Sólo persiste enum + ts
// | Decide acciones | No                     | NO (D4)                  | SÍ — única autoridad (D4)
// | Persistencia    | Diferida (memoria)     | En memoria (recalculable)| Persiste current_state
// | Estado interno  | Sin estado             | Sin estado (fn pura)     | FSM con persistencia
// | Determinismo    | D8                     | D8 — bit-exacto          | D8 — bit-exacto
```

---

## Contrato del Módulo

### Módulo: `src-tauri/src/state_machine.rs`

```rust
use crate::trust_scorer::{ConfidenceTier, TrustScore};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TrustStateEnum {
    Observing,
    Learning,
    Trusted,
    Autonomous,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transition {
    pub from: TrustStateEnum,
    pub to: TrustStateEnum,
    /// `true` para `Trusted → Autonomous` y para cualquier reset.
    /// `false` para promociones automáticas basadas en scores
    /// (`Observing → Learning`, `Learning → Trusted`).
    pub requires_user_action: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrustState {
    pub current_state: TrustStateEnum,
    pub available_transitions: Vec<Transition>,
    pub active_patterns_count: usize,
    pub last_transition_at: i64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AggregationMode {
    /// Toma el `trust_score` máximo del slice. **Default y recomendado.**
    Max,
    /// Toma la mediana — robusto frente a outliers, descartado por simplicidad inicial.
    Median,
    /// Toma el promedio — descartado por sensibilidad a patrones de bajo score.
    Mean,
}

#[derive(Debug, Clone)]
pub struct StateMachineConfig {
    /// Mínimo de patrones presentes en `&[TrustScore]` para abandonar `Observing`.
    pub min_patterns: usize,            // default: 3
    /// Umbral inferior: `Observing → Learning`.
    pub threshold_low: f64,             // default: 0.4
    /// Umbral superior: `Learning → Trusted`.
    pub threshold_high: f64,            // default: 0.75
    /// Política de agregación de `trust_score` sobre el slice.
    pub aggregation: AggregationMode,   // default: Max
}

impl Default for StateMachineConfig {
    fn default() -> Self {
        StateMachineConfig {
            min_patterns: 3,
            threshold_low: 0.4,
            threshold_high: 0.75,
            aggregation: AggregationMode::Max,
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum UserAction {
    /// Reset desde cualquier estado a `Observing`.
    Reset,
    /// Activación explícita de modo autónomo desde `Trusted`.
    /// Requiere `confirmed: true`; en otro caso devuelve
    /// `StateMachineError::ConfirmationRequired`.
    EnableAutonomous { confirmed: bool },
}

#[derive(Debug)]
pub enum StateMachineError {
    /// Configuración inválida (umbrales inconsistentes, min_patterns = 0, etc.).
    InvalidConfig(String),
    /// `EnableAutonomous` invocado sin `confirmed: true`.
    ConfirmationRequired,
    /// `EnableAutonomous` invocado desde un estado distinto de `Trusted`.
    InvalidTransitionFromState(TrustStateEnum),
    /// Error de persistencia en SQLCipher.
    Persistence(rusqlite::Error),
}

impl std::fmt::Display for StateMachineError { /* … */ }
impl std::error::Error for StateMachineError { /* … */ }

impl From<rusqlite::Error> for StateMachineError {
    fn from(e: rusqlite::Error) -> Self {
        StateMachineError::Persistence(e)
    }
}

/// Evalúa si procede una transición de estado dado el conjunto actual de scores,
/// el estado persistido y, opcionalmente, una acción explícita del usuario.
///
/// Función pura: no toca SQLCipher ni el reloj. La persistencia y el reloj son
/// responsabilidad del llamador (`commands.rs`).
///
/// Determinismo (D8): dos llamadas con el mismo
/// `(scores, current, last_transition_at, user_action, now_unix, config)`
/// producen bit-exactamente el mismo `TrustState`.
pub fn evaluate_transition(
    scores: &[TrustScore],
    current: TrustStateEnum,
    last_transition_at: i64,
    user_action: Option<UserAction>,
    now_unix: i64,
    config: &StateMachineConfig,
) -> Result<TrustState, StateMachineError>;

/// Crea (idempotente) la tabla `trust_state` y, si está vacía, inserta la fila
/// inicial `(1, 'Observing', now_unix, now_unix)`.
pub(crate) fn ensure_schema(conn: &Connection, now_unix: i64)
    -> Result<(), StateMachineError>;

/// Lee `(current_state, last_transition_at)` desde `trust_state`.
/// Si la tabla está vacía (no debería tras `ensure_schema`), devuelve
/// `(Observing, now_unix)` por defensiva — la responsabilidad de inicializar
/// la fila es de `ensure_schema`.
pub(crate) fn load_state(conn: &Connection)
    -> Result<(TrustStateEnum, i64), StateMachineError>;

/// Persiste el nuevo estado en `trust_state` (UPSERT sobre `id = 1`).
/// `updated_at` se actualiza siempre; `last_transition_at` se actualiza solo
/// si el estado cambió respecto a la fila previa.
pub(crate) fn save_state(
    conn: &Connection,
    state: TrustStateEnum,
    last_transition_at: i64,
    now_unix: i64,
) -> Result<(), StateMachineError>;
```

### Justificación: firma de `evaluate_transition`

1. **Función pura.** La función no abre la BD ni lee el reloj — todos los inputs vienen por parámetro. Esto la hace trivialmente testeable sin mocking, replica el patrón de `score_patterns` (TS-2-002) y refuerza D8 (determinismo bit-exacto).
2. **`current` y `last_transition_at` por parámetro.** El llamador (`commands.rs`) carga el estado persistido vía `load_state(conn)`, invoca `evaluate_transition`, y persiste el resultado vía `save_state(conn, …)`. La FSM nunca toca la BD durante el cálculo.
3. **`user_action: Option<UserAction>`.** Los tres casos de uso son: (a) tick automático sin acción de usuario (`None`); (b) reset (`Some(Reset)`); (c) activación de autónomo (`Some(EnableAutonomous { confirmed })`). Modelarlo como `Option<enum>` es la representación canónica en Rust y permite a la FSM distinguir transiciones automáticas (sólo promociones) de transiciones manuales (sólo reset y `Trusted → Autonomous`).
4. **`now_unix: i64` explícito.** Mismo patrón que TS-2-002 — testabilidad sin mocking del reloj y composabilidad con la cadena `commands.rs`.

### Justificación: visibilidad de `load_state` / `save_state` / `ensure_schema`

Las tres funciones de persistencia se exponen como **`pub(crate)`** (no `pub`):

- `commands.rs` las invoca como parte de la cadena Tauri — necesita acceso desde el mismo crate.
- Ningún otro módulo (`pattern_detector`, `trust_scorer`, frontend) debe persistir directamente — la unión `evaluate_transition` + `save_state` es responsabilidad exclusiva del llamador `commands.rs`.
- `pub(crate)` cumple ambas: visible para `commands.rs`, oculto para consumidores externos al crate (la propia compilación bloquea cualquier acoplamiento futuro indebido).

### Campos prohibidos en tipos públicos (D1 transitivo)

- Ningún tipo público (`TrustStateEnum`, `Transition`, `TrustState`, `StateMachineConfig`, `UserAction`, `StateMachineError`) puede contener un campo de tipo `String` o equivalente que represente `url` o `title`.
- Ningún campo de los structs públicos puede llamarse `url`, `title`, `link`, `href`, `bookmark_url`, `page_title` o variantes — auditable por inspección textual.
- Las únicas cadenas presentes en el contrato son `pattern_id` (UUID v4) heredado de `TrustScore` (ya validado en AR-2-004) y los discriminantes serializados de `TrustStateEnum` (`"Observing" | "Learning" | "Trusted" | "Autonomous"`).
- Ninguna función pública del módulo puede tener nombre que sugiera consulta directa a Pattern Detector o Trust Scorer (e.g. `query_patterns`, `fetch_scores`) — la State Machine consume `&[TrustScore]` por parámetro y nunca invoca a esos módulos por sí misma (ver §"Restricción D4").

---

## Restricción D4 — Autoridad Exclusiva

**Regla bloqueante de aceptación.** La State Machine es la **única** autoridad del sistema para transiciones de estado y para autorizar acciones automatizadas.

### a) State Machine como única autoridad

- **Sólo `state_machine.rs`** decide si el sistema pasa de `Observing` a `Learning`, de `Learning` a `Trusted` o vuelve a `Observing` por reset.
- **Sólo el usuario**, mediante `UserAction::EnableAutonomous { confirmed: true }`, autoriza la transición a `Autonomous`. La State Machine valida la acción; el resto del sistema la respeta.
- Trust Scorer **no** invoca transiciones — solo aporta `Vec<TrustScore>` como input.
- Privacy Dashboard (T-2-004) **no** dispara transiciones automáticas — solo expone botones que se traducen en `UserAction::Reset` o `UserAction::EnableAutonomous` vía los comandos Tauri definidos en §"Comandos Tauri".

### b) Forbidden imports recíprocos (auditable por grep)

| Restricción | Verificación |
|---|---|
| `trust_scorer.rs` **no** debe contener `use crate::state_machine` ni cualquier import del módulo. | Grep manual en revisión arquitectónica — confirmar cero ocurrencias del literal `state_machine` en `trust_scorer.rs` salvo el comentario documental R12. |
| `pattern_detector.rs` **no** debe contener `use crate::state_machine` ni cualquier import del módulo. | Mismo grep — cero ocurrencias salvo comentario documental. |
| `state_machine.rs` **no** debe contener `use crate::pattern_detector` directo. | El State Machine consume `TrustScore` (que a su vez referencia `pattern_id` por `String`), no `DetectedPattern`. La cadena la compone `commands.rs`. |

La dirección de dependencia correcta es estricta:

```
commands.rs
  ├─→ pattern_detector::detect_patterns(conn, …)         // produce Vec<DetectedPattern>
  ├─→ trust_scorer::score_patterns(&patterns, …)         // produce Vec<TrustScore>
  └─→ state_machine::evaluate_transition(&scores, …)     // produce TrustState
        └─→ state_machine::save_state(conn, …)            // persiste enum + ts
```

Ninguna flecha vuelve hacia atrás. State Machine consume `TrustScore` por parámetro — nunca llama a `score_patterns` ni a `detect_patterns`.

### c) Cadena de invocación canónica

Toda invocación de la cadena (e.g. cuando T-2-004 solicita `get_trust_state`) sigue exactamente este orden, materializado en `commands.rs`:

```rust
// Pseudocódigo simplificado del comando Tauri get_trust_state
pub async fn get_trust_state(state: State<'_, DbState>) -> Result<TrustStateView, String> {
    let now_unix = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64;
    let conn = state.0.lock().unwrap().conn();
    state_machine::ensure_schema(conn, now_unix)?;
    let (current, last_ts) = state_machine::load_state(conn)?;
    let patterns = pattern_detector::detect_patterns(conn, &PatternConfig::default(), now_unix)?;
    let scores = trust_scorer::score_patterns(&patterns, &TrustConfig::default(), now_unix)?;
    let new_state = state_machine::evaluate_transition(
        &scores, current, last_ts, None /* tick automático */, now_unix,
        &StateMachineConfig::default()
    )?;
    state_machine::save_state(conn, new_state.current_state, new_state.last_transition_at, now_unix)?;
    Ok(TrustStateView::from(new_state))
}
```

`commands.rs` es el **único** sitio donde se compone la cadena. Ningún módulo intermedio invoca al siguiente.

### d) Test estructural recomendado

Replicar el patrón de TS-2-002 §"Test Estructural D4" — `include_str!` + split por `#[cfg(test)]` para evitar falsos positivos en literales de test:

```rust
#[test]
fn test_no_action_api_for_external_modules() {
    const SRC: &str = include_str!("state_machine.rs");
    // Inspeccionar sólo la sección de producción para evitar self-detección
    // de los literales prohibidos del propio array.
    let public_section = SRC
        .split("#[cfg(test)]")
        .next()
        .expect("module always has a non-test prefix");

    // 1) No exponer funciones que permitan a Trust Scorer/Pattern Detector
    //    forzar transiciones desde fuera.
    let forbidden_pub = [
        "pub fn force_transition",
        "pub fn promote_to",
        "pub fn set_state(",
        "pub fn override_state",
    ];
    for token in forbidden_pub {
        assert!(!public_section.contains(token),
            "D4 violation: forbidden public API '{token}' present");
    }

    // 2) No importar `pattern_detector` ni invocar a `score_patterns` desde aquí.
    assert!(!public_section.contains("use crate::pattern_detector"),
        "D4 violation: state_machine must not import pattern_detector directly");
    assert!(!public_section.contains("score_patterns("),
        "D4 violation: state_machine must not invoke trust_scorer::score_patterns");
    assert!(!public_section.contains("detect_patterns("),
        "D4 violation: state_machine must not invoke pattern_detector::detect_patterns");
}
```

Adicionalmente, la revisión arquitectónica (AR-2-005) verificará por grep que ni `pattern_detector.rs` ni `trust_scorer.rs` contienen `use crate::state_machine` (test recíproco, fuera del alcance del archivo bajo test).

---

## Reglas de Transición Exactas

Las cuatro transiciones permitidas, con condiciones literales y postura tomada en cada decisión abierta del HO-012.

### `Observing → Learning`

**Condición:** `scores.len() >= config.min_patterns && trust_score_aggregate(scores) > config.threshold_low`.

**Postura sobre agregación de `trust_score_aggregate`** — `AggregationMode::Max` (default).

Justificación:

- **Semánticamente correcta.** El sistema abandona `Observing` cuando "ha encontrado al menos un patrón fiable" — un único patrón con `trust_score > threshold_low` es suficiente. Esto coincide con la intuición operativa de que la observación tiene rendimiento decreciente: en cuanto el primer patrón cruza el umbral, no tiene sentido seguir en estado de pura observación.
- **Robusta frente a baja cardinalidad.** En las primeras semanas de uso, `scores.len()` es pequeño y los scores son ruidosos. El máximo es estable; el promedio sería arrastrado a la baja por patrones marginales y la mediana exigiría más muestras para estabilizarse.
- **Configurable.** `AggregationMode` se expone en `StateMachineConfig`. Si Fase 3 detecta abuso (e.g. un solo patrón espurio promocionando demasiado pronto), se puede cambiar a `Median` o `Mean` por configuración sin alterar la firma pública. Las variantes `Median` y `Mean` se declaran en el enum como reservadas pero **no se implementan** en T-2-003 (la implementación devuelve `StateMachineError::InvalidConfig` si se selecciona una agregación distinta de `Max`, dejando el contrato listo para extensión sin compromiso de calibración prematura).

**Marca de transición:** `last_transition_at = now_unix` cuando se aplica.

### `Learning → Trusted`

**Condición:** `trust_score_aggregate(scores) > config.threshold_high && !user_blocked(scores)`.

**Postura sobre `user_blocked`** — flag por patrón, evaluado como **"alguno de los patrones contribuyentes está bloqueado"**.

Justificación contractual y diferimiento a T-2-004:

- El `block_pattern` / `unblock_pattern` de T-2-004 actúa **por patrón** (cada patrón se bloquea individualmente desde el Privacy Dashboard). Un flag global de bloqueo no encaja con la UX descrita en CLAUDE.md §"T-2-004".
- Para T-2-003, `user_blocked(scores)` se evalúa contractualmente como:
  ```
  user_blocked(scores) = scores.iter().any(|s| s.is_blocked())
  ```
  donde `is_blocked()` es el flag por patrón derivado del estado persistente del bloqueo.
- **Diferimiento explícito a T-2-004.** El flag `is_blocked` no existe aún en `TrustScore` (TS-2-002 cerrado sin él) ni en una tabla auxiliar. T-2-004 implementará el mecanismo de bloqueo (`block_pattern` Tauri + tabla `pattern_blocks` o equivalente) y propagará el flag.
- **Contrato para T-2-003:** la State Machine debe consumir el flag desde una de dos fuentes — la decisión final la toma T-2-004 dentro del rango siguiente:
  1. Campo `is_blocked: bool` añadido a `TrustScore` (cambio menor a TS-2-002 vía addendum).
  2. Tabla `pattern_blocks(pattern_id TEXT PRIMARY KEY)` consultada por `commands.rs` antes de invocar `evaluate_transition`, que filtra/marca los `TrustScore` correspondientes.
- **Comportamiento intermedio (durante el sprint de T-2-003):** la State Machine recibe el flag por parámetro implícito en `TrustScore` (asumiendo que será incorporado). Mientras T-2-004 no exista, la implementación de `evaluate_transition` trata todos los patrones como `is_blocked = false` por defecto, preservando el comportamiento contractual sin bloquear el avance de T-2-003. La revisión arquitectónica de T-2-003 (AR-2-005) verificará explícitamente que el contrato `user_blocked(scores)` está cableado al sitio correcto pero puede devolver `false` por defecto hasta que T-2-004 entregue el flag.

**Marca de transición:** `last_transition_at = now_unix`.

### `Trusted → Autonomous`

**Condición:** `user_action == Some(UserAction::EnableAutonomous { confirmed: true })`.

Detalle:

- Sin `user_action` (`None`) o con `Some(Reset)`, **no transiciona** aunque los scores sean máximos. Devuelve el `TrustState` actual.
- Con `Some(EnableAutonomous { confirmed: false })`, devuelve `Err(StateMachineError::ConfirmationRequired)`.
- Con `Some(EnableAutonomous { confirmed: true })` desde un estado **distinto** de `Trusted`, devuelve `Err(StateMachineError::InvalidTransitionFromState(current))`.
- Con `Some(EnableAutonomous { confirmed: true })` desde `Trusted`, transiciona a `Autonomous` y marca `last_transition_at = now_unix`.

**No existe ningún path automático a `Autonomous`** — coherente con D4 estricto.

### `Cualquier estado → Observing` (reset)

**Condición:** `user_action == Some(UserAction::Reset)`.

Detalle:

- El reset es válido desde **cualquier** estado, incluido `Observing` (en cuyo caso el efecto es solo refrescar `last_transition_at`).
- `last_transition_at = now_unix` siempre.
- `active_patterns_count` se recalcula desde `scores.len()` — la State Machine **no** vacía la tabla de patrones; el reset es de la FSM, no del histórico longitudinal. Si el usuario quiere borrar patrones, eso se hace por el comando `block_pattern` de T-2-004 o por `clear_all_resources` ya existente.
- **Hook de explicabilidad.** Cada reset debe poder loggearse en un futuro `Explainability Log` (módulo de Fase 3). T-2-003 declara el hook conceptual pero **no implementa** el log — la implementación se difiere a Fase 3 sin compromiso de schema en T-2-003.

### Postura sobre downgrade automático — opción (b): solo reset manual

El HO-012 §4 exige una decisión explícita entre dos opciones:

- (a) `trust_score` cayendo bajo `threshold_low` revierte automáticamente `Learning → Observing`.
- (b) Solo se permite reset manual por el usuario.

**Decisión: opción (b).**

**Justificación primera — coherencia con D4.** D4 establece que la State Machine es la única autoridad de transición y que las acciones de elevación de privilegios requieren input explícito. La simetría conceptual con `Trusted → Autonomous` es directa: si subir requiere acción explícita del usuario en el escalón final, bajar también debería respetar autoridad explícita en lugar de oscilar por ruido en los scores. Un downgrade automático introduce una dimensión de "decisión por umbral" que rompe la narrativa "el sistema sólo sube cuando confía y sólo baja cuando el usuario lo pide".

**Justificación segunda — coste operativo del downgrade automático.** Los `trust_score` derivan de `frequency`, `recency_weight` y `temporal_coherence`, todos factores que pueden fluctuar día a día (un fin de semana sin uso baja el `recency_weight` significativamente con `half_life_days = 14`). Si `Learning ↔ Observing` se permitiera por umbral, el sistema oscilaría: el usuario vería el estado cambiar sin haber hecho nada, lo que rompe la narrativa de progresividad. El coste de UX (confusión, pérdida de confianza en el sistema) supera el beneficio teórico de "auto-corrección".

**Hook de change request.** Si Fase 3 detecta abuso del estado `Trusted` por scores degradados (e.g. un usuario que dejó de usar el sistema durante 60 días sigue en `Trusted` con scores ya bajos), se puede proponer un addendum a esta TS introduciendo un downgrade configurable bajo flag `enable_auto_downgrade: bool` en `StateMachineConfig`. Hasta entonces, la única vía de bajada es `UserAction::Reset` por decisión consciente del usuario desde el Privacy Dashboard.

**Implicación concreta:** no se implementa la transición `Learning → Observing` por scores bajos en T-2-003. No hay test obligatorio de downgrade automático (ver §"Plan de Tests"). No se expone comando Tauri adicional para downgrade.

---

## Umbrales Configurables — `StateMachineConfig`

Estructura completa con campos exactos y defaults:

```rust
pub struct StateMachineConfig {
    pub min_patterns: usize,            // Default = 3
    pub threshold_low: f64,             // Default = 0.4
    pub threshold_high: f64,            // Default = 0.75
    pub aggregation: AggregationMode,   // Default = Max
}
```

**Validación de configuración** (`evaluate_transition` devuelve `StateMachineError::InvalidConfig` si):

- `min_patterns == 0` (sin patrones no tiene sentido evaluar).
- `threshold_low >= threshold_high` (umbrales inconsistentes).
- `threshold_low < 0.0 || threshold_low > 1.0` (fuera de rango de `trust_score`).
- `threshold_high < 0.0 || threshold_high > 1.0` (idem).
- `aggregation != AggregationMode::Max` en T-2-003 (variantes `Median`/`Mean` declaradas pero no implementadas — devuelve `InvalidConfig` con mensaje "aggregation mode not implemented in T-2-003 baseline").

### Ortogonalidad con `TrustConfig`

**Nota arquitectónica heredada de AR-2-004 §"Compatibilidad con T-2-003".** Los umbrales de `StateMachineConfig` y los de `TrustConfig` (Trust Scorer) son **ortogonales por diseño** — gobiernan dos dimensiones distintas y nunca deben unificarse sin change request formal.

| Aspecto | `StateMachineConfig` (este — T-2-003) | `TrustConfig` (T-2-002) |
|---|---|---|
| Qué gobierna | Promoción de estado del **sistema** (Observing/Learning/Trusted) | Etiqueta descriptiva de **cada patrón** (Low/Medium/High tier) |
| Naturaleza | Decisión de FSM con autoridad (D4) | Cálculo descriptivo, sin autoridad de acción |
| Campos | `min_patterns`, `threshold_low`, `threshold_high` | `tier_low_max`, `tier_high_min`, `half_life_days`, `frequency_saturation`, `w_*` |
| Consumidor | `evaluate_transition` (FSM) | `score_patterns` (cálculo) |
| Granularidad | Global del sistema | Por patrón individual |
| Responsable de cambios | Technical Architect — Fase 3 podrá calibrar | Technical Architect — Fase 3 podrá calibrar |

**Prohibición explícita:** ningún sprint futuro debe unificar `threshold_low` con `tier_low_max` ni `threshold_high` con `tier_high_min`. Aunque numéricamente los defaults coincidan (0.4 y 0.75 respectivamente), su semántica es distinta: los `tier_*` etiquetan patrones individuales para visualización; los `threshold_*` autorizan transiciones del sistema entero. Una calibración futura puede hacerlos divergir (e.g. `threshold_high = 0.85` para ser más conservador en la promoción a `Trusted` que en la asignación de `tier = High`).

Una unificación requiere:
1. Change Request formal aprobado por Orchestrator.
2. Demostración de que la nueva semántica unificada no rompe D4 (los tiers no pueden adquirir autoridad de acción).
3. Auditoría de tests existentes para confirmar que ningún test confunde los dos conceptos.

---

## Determinismo (D8)

**Sin LLM, sin RNG, sin `SystemTime::now()` interno.**

Garantías:

- `evaluate_transition` no invoca `SystemTime::now()`, `rand::*`, ni ningún generador no determinístico — `now_unix` se pasa por parámetro (mismo patrón que TS-2-002).
- Iteración estable sobre `&[TrustScore]` en orden de entrada — el cálculo del `trust_score_aggregate` (máximo) es asociativo y commutativo sobre `f64`, pero internamente se itera con `scores.iter().fold(f64::NEG_INFINITY, f64::max)` para garantizar determinismo bit-exacto incluso ante NaN (si entrara un NaN, `f64::max` lo descartaría preservando el máximo finito; igualmente, los tests sintéticos no producen NaN).
- Resultado bit-exacto reproducible: dos invocaciones con el mismo `(scores, current, last_transition_at, user_action, now_unix, config)` producen el mismo `TrustState` bit a bit (campo `last_transition_at` incluido — depende sólo de `now_unix` y de si la rama de transición se aplicó).
- Las funciones de persistencia (`save_state`, `load_state`) son IO y por tanto no son "puras", pero tampoco reordenan ni transforman datos — el round-trip es identidad: lo que entra sale igual.

**Test obligatorio:** `test_determinism_bit_exact` verifica con `to_bits()` la igualdad de los `f64` derivados (no hay `f64` directamente en `TrustState`, pero sí `last_transition_at: i64` y enums comparables por igualdad estructural).

---

## Persistencia en SQLCipher

### Schema mínimo

Tabla nueva `trust_state` — singleton (máximo una fila, identificada por `id = 1`):

```sql
CREATE TABLE IF NOT EXISTS trust_state (
    id                 INTEGER PRIMARY KEY CHECK (id = 1),
    current_state      TEXT    NOT NULL CHECK (current_state IN
                              ('Observing', 'Learning', 'Trusted', 'Autonomous')),
    last_transition_at INTEGER NOT NULL,
    updated_at         INTEGER NOT NULL
);
```

Justificación de cada elección:

- **`id INTEGER PRIMARY KEY CHECK (id = 1)`.** Singleton estricto — la tabla nunca tendrá más de una fila. El `CHECK` blinda contra inserciones accidentales con `id != 1`. Coherente con D16 (INTEGER PRIMARY KEY) sin necesidad de UUID porque no hay multiplicidad.
- **`current_state TEXT`.** Serialización de `TrustStateEnum` como string discriminante. Más legible que `INTEGER` (un dump directo de la BD muestra `'Observing'` en lugar de `0`). El `CHECK` blinda contra valores fuera del enum si una migración futura introduce un quinto estado y hay desincronización.
- **`last_transition_at INTEGER`.** Unix timestamp en segundos — formato consistente con `captured_at` (storage.rs) y con `now_unix` de los módulos de Fase 2.
- **`updated_at INTEGER`.** Timestamp del último write (sea o no transición). Sirve para diagnóstico — `last_transition_at` puede ser viejo si el sistema lleva tiempo en el mismo estado, pero `updated_at` muestra cuándo se evaluó por última vez. **No expuesto en `TrustState`** — solo metadato de BD.

### Migración idempotente

```rust
pub(crate) fn ensure_schema(conn: &Connection, now_unix: i64)
    -> Result<(), StateMachineError>
{
    conn.execute_batch("
        CREATE TABLE IF NOT EXISTS trust_state (
            id                 INTEGER PRIMARY KEY CHECK (id = 1),
            current_state      TEXT    NOT NULL CHECK (current_state IN
                                      ('Observing', 'Learning', 'Trusted', 'Autonomous')),
            last_transition_at INTEGER NOT NULL,
            updated_at         INTEGER NOT NULL
        );
    ")?;
    // Inserción idempotente del estado inicial — INSERT OR IGNORE evita
    // sobreescribir si la fila ya existe.
    conn.execute(
        "INSERT OR IGNORE INTO trust_state (id, current_state, last_transition_at, updated_at)
         VALUES (1, 'Observing', ?1, ?1)",
        rusqlite::params![now_unix],
    )?;
    Ok(())
}
```

Garantías:

- **Idempotente.** `CREATE TABLE IF NOT EXISTS` no falla si la tabla ya existe. `INSERT OR IGNORE` no falla si la fila singleton ya existe.
- **Inicialización por defecto.** Al primer arranque (tabla recién creada), inserta `(1, 'Observing', now_unix, now_unix)`. Subsecuentes arranques no la tocan.
- **Sin schema_version.** No se introduce versión de schema porque la tabla es nueva en T-2-003 y no convive con versiones previas. Una futura migración (e.g. añadir columna `notes` para Explainability Log) usaría `ALTER TABLE … ADD COLUMN … DEFAULT …` siguiendo el mismo patrón ya usado en `storage.rs` línea 95.

### Comportamiento al primer arranque

1. La aplicación arranca por primera vez tras instalar la versión que incluye T-2-003.
2. `commands.rs` (o `setup_db()` en `lib.rs`) invoca `state_machine::ensure_schema(conn, now_unix)`.
3. La tabla `trust_state` se crea y se inserta `(1, 'Observing', now_unix, now_unix)`.
4. La primera invocación de `get_trust_state` lee `(Observing, now_unix)` y procede.

**Si el sistema arranca con patrones ya detectados** (e.g. un usuario que actualizó desde Fase 1 con histórico): el estado inicial sigue siendo `Observing`. La primera invocación de `evaluate_transition` puede promocionar inmediatamente a `Learning` si los scores cumplen las condiciones — no hay penalty artificial por "ser nuevo".

### Prohibiciones explícitas

- **Nunca persistir `trust_score` ni `stability_score`.** Estos valores se recalculan on-demand desde `Vec<DetectedPattern>` (decisión heredada de TS-2-002 §"Decisión de Persistencia"). T-2-003 no introduce tabla `trust_scores` ni similar.
- **Nunca persistir `url` ni `title` ni `pattern_id` en `trust_state`** (D1 transitivo). El singleton sólo contiene el enum del estado y dos timestamps. La asociación entre transición y patrón concreto que la justificó (auditoría) es trabajo de Fase 3 (Explainability Log).
- **Nunca exponer el `Connection` desde `state_machine.rs`** — todas las funciones de persistencia reciben `&Connection` por parámetro y devuelven después de cerrar el statement.

---

## Comandos Tauri

Tres comandos nuevos en `commands.rs`, todos retornando `TrustStateView` para el frontend:

### `get_trust_state`

```rust
#[tauri::command]
pub async fn get_trust_state(state: State<'_, DbState>) -> Result<TrustStateView, String>
```

Comportamiento:

1. Obtiene `now_unix` desde `SystemTime::now()`.
2. Carga estado actual: `state_machine::ensure_schema(conn, now_unix)?; let (current, last_ts) = state_machine::load_state(conn)?;`.
3. Computa cadena: `pattern_detector::detect_patterns(...)` → `trust_scorer::score_patterns(...)`.
4. Evalúa transición sin acción de usuario: `state_machine::evaluate_transition(&scores, current, last_ts, None, now_unix, &cfg)?`.
5. Persiste: `state_machine::save_state(conn, new_state.current_state, new_state.last_transition_at, now_unix)?`.
6. Devuelve `TrustStateView::from(new_state)`.

Este comando es **idempotente** desde el punto de vista del usuario — invocarlo dos veces seguidas con el mismo conjunto de patrones produce el mismo `TrustStateView`. La invocación puede promocionar el estado si los scores cumplen umbrales (es la única vía de promoción automática).

### `reset_trust_state`

```rust
#[tauri::command]
pub async fn reset_trust_state(state: State<'_, DbState>) -> Result<TrustStateView, String>
```

Comportamiento:

1. `now_unix` desde `SystemTime::now()`.
2. Carga estado y cadena (igual que `get_trust_state`).
3. Evalúa con `Some(UserAction::Reset)`: `state_machine::evaluate_transition(&scores, current, last_ts, Some(UserAction::Reset), now_unix, &cfg)?`.
4. Persiste y devuelve.

Resultado: el estado vuelve a `Observing` desde cualquier estado actual, con `last_transition_at = now_unix`.

### `enable_autonomous_mode`

```rust
#[tauri::command]
pub async fn enable_autonomous_mode(
    state: State<'_, DbState>,
    confirmed: bool,
) -> Result<TrustStateView, String>
```

Comportamiento:

1. `now_unix` desde `SystemTime::now()`.
2. Carga estado y cadena.
3. Evalúa con `Some(UserAction::EnableAutonomous { confirmed })`.
4. Si `confirmed == false`, propaga `StateMachineError::ConfirmationRequired` como string al frontend (`"confirmation required"` o equivalente).
5. Si `current_state != Trusted`, propaga `StateMachineError::InvalidTransitionFromState(...)` — el frontend muestra mensaje "solo desde Trusted".
6. Si todo válido, persiste `Autonomous` y devuelve.

El frontend (T-2-004) **debe** invocar este comando con `confirmed: true` solo tras mostrar un diálogo de confirmación explícita al usuario describiendo qué implica activar el modo autónomo. La implementación de ese diálogo es responsabilidad de T-2-004.

### Comandos NO expuestos

- **No** existe `force_state_to(state)` ni similar — D4 prohíbe override directo.
- **No** existe comando para downgrade automático — decisión §"Reglas de Transición" opción (b).
- **No** existe `get_trust_score(pattern_id)` desde `state_machine` — los scores los expone (si fuera necesario en el futuro) `trust_scorer.rs` o `commands.rs::get_trust_scores`. Mantener la separación de responsabilidades.

### `TrustStateView` — tipo expuesto al frontend

```rust
#[derive(Debug, Serialize)]
pub struct TrustStateView {
    pub current_state: TrustStateEnum,           // serializado como string
    pub available_transitions: Vec<Transition>,
    pub active_patterns_count: usize,
    pub last_transition_at: i64,
}

impl From<TrustState> for TrustStateView {
    fn from(s: TrustState) -> Self {
        TrustStateView {
            current_state: s.current_state,
            available_transitions: s.available_transitions,
            active_patterns_count: s.active_patterns_count,
            last_transition_at: s.last_transition_at,
        }
    }
}
```

**Decisión:** `TrustStateView` es **idéntico** a `TrustState` (sin filtrado adicional). No hay campos sensibles que ocultar — la State Machine no maneja `url` ni `title` (D1 transitivo cumplido por construcción) y todos los campos públicos son seguros para el frontend. La existencia del wrapper se justifica por:

- **Estabilidad de API.** Si en el futuro `TrustState` añade campos internos (e.g. `_recompute_at: i64` para diagnóstico), `TrustStateView` puede mantener su forma actual sin breaking change para el frontend.
- **Serialización explícita.** `TrustStateView` con `#[derive(Serialize)]` sólo, mientras que `TrustState` deriva también `Deserialize` (necesario para tests). Separar serialización de deserialización es buena práctica en Tauri.

El frontend importará el tipo desde `src/types.ts` con la siguiente forma TypeScript (T-2-004 lo confirma como parte de su propio contrato):

```typescript
export type TrustStateEnum = 'Observing' | 'Learning' | 'Trusted' | 'Autonomous';

export interface Transition {
  from: TrustStateEnum;
  to: TrustStateEnum;
  requires_user_action: boolean;
}

export interface TrustStateView {
  current_state: TrustStateEnum;
  available_transitions: Transition[];
  active_patterns_count: number;
  last_transition_at: number;
}
```

---

## Plan de Tests con Dataset Sintético

### Helpers requeridos

Tests construyen `TrustScore` directamente (sin invocar al scorer). Helper sugerido:

```rust
fn score(pattern_id: &str, trust: f64, tier: ConfidenceTier) -> TrustScore {
    TrustScore {
        pattern_id: pattern_id.into(),
        trust_score: trust,
        stability_score: 1.0,           // valor arbitrario — no afecta a la FSM
        recency_weight: 1.0,            // valor arbitrario — no afecta a la FSM
        confidence_tier: tier,
    }
}
```

Helper de BD en memoria para tests de persistencia:

```rust
fn in_memory_conn() -> Connection {
    let conn = Connection::open_in_memory().expect("open memory");
    state_machine::ensure_schema(&conn, NOW).expect("schema");
    conn
}
```

### Tests obligatorios (10 mínimos)

```rust
#[test]
fn test_initial_state_is_observing() {
    // Sin estado persistido previo, ensure_schema + load_state ⇒ Observing.
    let conn = Connection::open_in_memory().unwrap();
    state_machine::ensure_schema(&conn, NOW).unwrap();
    let (state, ts) = state_machine::load_state(&conn).unwrap();
    assert_eq!(state, TrustStateEnum::Observing);
    assert_eq!(ts, NOW);
}

#[test]
fn test_observing_to_learning_on_threshold() {
    // 3 scores con trust = 0.5 (> 0.4 = threshold_low), pattern_count = 3 (>= 3).
    let scores = vec![
        score("p1", 0.5, ConfidenceTier::Medium),
        score("p2", 0.5, ConfidenceTier::Medium),
        score("p3", 0.5, ConfidenceTier::Medium),
    ];
    let result = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Observing, NOW - 1000, None, NOW,
        &StateMachineConfig::default(),
    ).unwrap();
    assert_eq!(result.current_state, TrustStateEnum::Learning);
    assert_eq!(result.last_transition_at, NOW);
}

#[test]
fn test_learning_to_trusted_on_high_threshold() {
    // 3 scores con trust = 0.8 (> 0.75 = threshold_high), no bloqueados.
    let scores = vec![
        score("p1", 0.8, ConfidenceTier::High),
        score("p2", 0.8, ConfidenceTier::High),
        score("p3", 0.8, ConfidenceTier::High),
    ];
    let result = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Learning, NOW - 1000, None, NOW,
        &StateMachineConfig::default(),
    ).unwrap();
    assert_eq!(result.current_state, TrustStateEnum::Trusted);
}

#[test]
fn test_learning_to_trusted_blocked_when_user_blocked() {
    // 3 scores con trust = 0.9 — pero el contrato user_blocked debe bloquear.
    // Mientras T-2-004 no exista, este test asume el cableado inicial donde
    // user_blocked devuelve false; por tanto este test se materializa cuando
    // el flag is_blocked existe en TrustScore o tabla auxiliar.
    // Implementación inicial: marcar TODO con #[ignore] si el cableado no
    // está disponible, y activarlo en T-2-004.
    // Alternativa preferida: añadir campo `is_blocked: bool` con default
    // false a TrustScore vía addendum a TS-2-002, y este test pasa is_blocked
    // = true en uno de los tres scores. Asserts: result.current_state ==
    // Learning (no transiciona).
}

#[test]
fn test_trusted_to_autonomous_requires_explicit_action() {
    let scores = vec![
        score("p1", 1.0, ConfidenceTier::High),
        score("p2", 1.0, ConfidenceTier::High),
        score("p3", 1.0, ConfidenceTier::High),
    ];
    // Sin acción ⇒ se queda en Trusted aunque scores sean máximos.
    let no_action = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Trusted, NOW - 1000, None, NOW,
        &StateMachineConfig::default(),
    ).unwrap();
    assert_eq!(no_action.current_state, TrustStateEnum::Trusted);

    // Con acción confirmada ⇒ transiciona a Autonomous.
    let confirmed = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Trusted, NOW - 1000,
        Some(UserAction::EnableAutonomous { confirmed: true }), NOW,
        &StateMachineConfig::default(),
    ).unwrap();
    assert_eq!(confirmed.current_state, TrustStateEnum::Autonomous);
    assert_eq!(confirmed.last_transition_at, NOW);

    // Sin confirmación ⇒ error.
    let unconfirmed = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Trusted, NOW - 1000,
        Some(UserAction::EnableAutonomous { confirmed: false }), NOW,
        &StateMachineConfig::default(),
    );
    assert!(matches!(unconfirmed, Err(StateMachineError::ConfirmationRequired)));

    // Desde estado distinto de Trusted ⇒ error.
    let from_observing = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Observing, NOW - 1000,
        Some(UserAction::EnableAutonomous { confirmed: true }), NOW,
        &StateMachineConfig::default(),
    );
    assert!(matches!(
        from_observing,
        Err(StateMachineError::InvalidTransitionFromState(TrustStateEnum::Observing))
    ));
}

#[test]
fn test_reset_from_each_state() {
    let scores = vec![
        score("p1", 0.9, ConfidenceTier::High),
        score("p2", 0.9, ConfidenceTier::High),
        score("p3", 0.9, ConfidenceTier::High),
    ];
    for from in [
        TrustStateEnum::Observing,
        TrustStateEnum::Learning,
        TrustStateEnum::Trusted,
        TrustStateEnum::Autonomous,
    ] {
        let r = state_machine::evaluate_transition(
            &scores, from, NOW - 1000, Some(UserAction::Reset), NOW,
            &StateMachineConfig::default(),
        ).unwrap();
        assert_eq!(r.current_state, TrustStateEnum::Observing,
            "reset from {:?} should land on Observing", from);
        assert_eq!(r.last_transition_at, NOW);
    }
}

#[test]
fn test_no_action_api_for_external_modules() {
    // Test estructural — ver §"Restricción D4 — Autoridad Exclusiva" (d).
    const SRC: &str = include_str!("state_machine.rs");
    let public_section = SRC
        .split("#[cfg(test)]")
        .next()
        .expect("module always has a non-test prefix");

    let forbidden_pub = [
        "pub fn force_transition",
        "pub fn promote_to",
        "pub fn set_state(",
        "pub fn override_state",
    ];
    for token in forbidden_pub {
        assert!(!public_section.contains(token),
            "D4 violation: forbidden public API '{token}' present");
    }

    assert!(!public_section.contains("use crate::pattern_detector"),
        "D4 violation: state_machine must not import pattern_detector");
    assert!(!public_section.contains("score_patterns("),
        "D4 violation: state_machine must not invoke score_patterns");
    assert!(!public_section.contains("detect_patterns("),
        "D4 violation: state_machine must not invoke detect_patterns");
}

#[test]
fn test_determinism_bit_exact() {
    let scores = vec![
        score("p1", 0.6, ConfidenceTier::Medium),
        score("p2", 0.7, ConfidenceTier::Medium),
        score("p3", 0.8, ConfidenceTier::High),
    ];
    let cfg = StateMachineConfig::default();
    let r1 = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Observing, NOW - 1000, None, NOW, &cfg).unwrap();
    let r2 = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Observing, NOW - 1000, None, NOW, &cfg).unwrap();
    assert_eq!(r1.current_state, r2.current_state);
    assert_eq!(r1.last_transition_at, r2.last_transition_at);
    assert_eq!(r1.active_patterns_count, r2.active_patterns_count);
    assert_eq!(r1.available_transitions.len(), r2.available_transitions.len());
}

#[test]
fn test_persistence_round_trip() {
    let conn = Connection::open_in_memory().unwrap();
    state_machine::ensure_schema(&conn, NOW).unwrap();

    // Estado inicial es Observing.
    let (s0, _ts0) = state_machine::load_state(&conn).unwrap();
    assert_eq!(s0, TrustStateEnum::Observing);

    // Guardar Trusted.
    state_machine::save_state(&conn, TrustStateEnum::Trusted, NOW + 100, NOW + 100).unwrap();

    // Releer.
    let (s1, ts1) = state_machine::load_state(&conn).unwrap();
    assert_eq!(s1, TrustStateEnum::Trusted);
    assert_eq!(ts1, NOW + 100);
}

#[test]
fn test_invalid_config() {
    let scores = vec![score("p1", 0.5, ConfidenceTier::Medium)];

    // threshold_low >= threshold_high
    let bad = StateMachineConfig {
        min_patterns: 3,
        threshold_low: 0.8,
        threshold_high: 0.5,
        aggregation: AggregationMode::Max,
    };
    let r = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Observing, 0, None, NOW, &bad);
    assert!(matches!(r, Err(StateMachineError::InvalidConfig(_))));

    // min_patterns == 0
    let bad = StateMachineConfig {
        min_patterns: 0,
        threshold_low: 0.4,
        threshold_high: 0.75,
        aggregation: AggregationMode::Max,
    };
    let r = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Observing, 0, None, NOW, &bad);
    assert!(matches!(r, Err(StateMachineError::InvalidConfig(_))));

    // aggregation distinto de Max (Median/Mean no implementadas en T-2-003)
    let bad = StateMachineConfig {
        aggregation: AggregationMode::Median,
        ..StateMachineConfig::default()
    };
    let r = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Observing, 0, None, NOW, &bad);
    assert!(matches!(r, Err(StateMachineError::InvalidConfig(_))));
}
```

### Tests recomendados adicionales (no obligatorios)

```rust
#[test]
fn test_observing_blocked_when_below_min_patterns() {
    // 2 scores (< 3 = min_patterns), aunque sean trust = 1.0 ⇒ se queda en Observing.
    let scores = vec![
        score("p1", 1.0, ConfidenceTier::High),
        score("p2", 1.0, ConfidenceTier::High),
    ];
    let r = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Observing, NOW - 1000, None, NOW,
        &StateMachineConfig::default(),
    ).unwrap();
    assert_eq!(r.current_state, TrustStateEnum::Observing);
}

#[test]
fn test_no_auto_downgrade_from_learning() {
    // Postura §"Reglas de Transición" opción (b): scores bajos no degradan
    // automáticamente Learning → Observing.
    let scores = vec![
        score("p1", 0.1, ConfidenceTier::Low),
        score("p2", 0.1, ConfidenceTier::Low),
        score("p3", 0.1, ConfidenceTier::Low),
    ];
    let r = state_machine::evaluate_transition(
        &scores, TrustStateEnum::Learning, NOW - 1000, None, NOW,
        &StateMachineConfig::default(),
    ).unwrap();
    assert_eq!(r.current_state, TrustStateEnum::Learning,
        "scores bajos no deben degradar automáticamente — opción (b)");
}
```

### Garantía de no regresión

Los **33 tests existentes** (24 de Fase 1 + 9 de Trust Scorer) deben seguir pasando sin modificación. Total esperado tras T-2-003: **≥ 43 tests** (33 previos + 10 nuevos obligatorios + opcionales).

---

## Riesgos Conocidos

| ID | Riesgo | Mitigación |
|---|---|---|
| RK-2-003-1 | El flag `is_blocked` no existe aún en `TrustScore`; el contrato `user_blocked(scores)` queda cableado pero devuelve `false` por defecto hasta T-2-004. | Documentado explícitamente en §"Reglas de Transición" → `Learning → Trusted`. AR-2-005 verificará el cableado correcto. T-2-004 cierra el círculo añadiendo el flag (vía addendum a TS-2-002 o tabla auxiliar). |
| RK-2-003-2 | Política de downgrade automático (opción b) puede generar usuarios atrapados en `Trusted` con scores ya degradados (e.g. usuarios inactivos por 60 días). | Hook de change request declarado en §"Postura sobre downgrade automático". Fase 3 podrá calibrar con datos reales y proponer un flag opcional `enable_auto_downgrade` sin romper compatibilidad. |
| RK-2-003-3 | `AggregationMode` declara variantes `Median` y `Mean` no implementadas en T-2-003 — un consumidor podría intentar usarlas. | Validación en `evaluate_transition` devuelve `InvalidConfig` para variantes no implementadas, con mensaje explícito "aggregation mode not implemented in T-2-003 baseline". El test `test_invalid_config` lo blinda. |
| RK-2-003-4 | El cambio de schema (nueva tabla `trust_state`) podría no aplicarse en bases de datos pre-T-2-003. | `ensure_schema` se invoca al arranque desde `setup_db()` o desde el primer comando Tauri que toque la State Machine — `CREATE TABLE IF NOT EXISTS` es idempotente. La AR-2-005 verificará que el setup-path está activo. |
| RK-2-003-5 | El comentario de cabecera R12 podría diluirse con el tiempo. | Se exige textualmente como parte del criterio de aprobación post-implementación (ver §"Criterios de Aprobación"). AR-2-005 lo verifica por inspección. |

---

## Cadena de Dependencias Clara

```
                     ┌────────────────────────────────────────────┐
                     │                commands.rs                 │
                     │      (compone la cadena — D4 explícito)    │
                     └────────┬─────────────┬──────────────┬──────┘
                              │             │              │
                              ▼             ▼              ▼
           ┌──────────────────────┐  ┌─────────────┐  ┌───────────────────┐
           │ pattern_detector     │  │ trust_scorer│  │ state_machine     │
           │ ::detect_patterns    │  │::score_     │  │ ::evaluate_       │
           │  (lee SQLCipher)     │  │  patterns   │  │  transition       │
           │                      │  │             │  │                   │
           │  → Vec<DetectedPattern│ │  → Vec<     │  │  → TrustState     │
           │                      │  │   TrustScore│  │                   │
           └──────────────────────┘  └─────────────┘  └────────┬──────────┘
                                                                │
                                                                ▼
                                                  ┌─────────────────────────┐
                                                  │ state_machine::         │
                                                  │  save_state(conn, …)    │
                                                  │  (persiste enum + ts)   │
                                                  └─────────────────────────┘
```

**Sin flechas hacia atrás.** `state_machine` no importa `pattern_detector` ni invoca `score_patterns`. La cadena la compone exclusivamente `commands.rs`.

---

## LLM Como Mejora Opcional (no requerido — D8)

Si en una iteración futura se introduce ajuste de umbrales (`threshold_low`, `threshold_high`, `min_patterns`) mediante un modelo local que aprenda de la calidad de transiciones percibida por el usuario:

1. Debe declararse en una TS separada o como addendum a esta TS.
2. **No** modificar la firma de `evaluate_transition` — el LLM solo influye en la generación de `StateMachineConfig`, no en el cálculo de transiciones.
3. El baseline determinístico debe seguir funcionando con `StateMachineConfig::default()` si el LLM no está disponible.
4. La autoridad de la transición sigue siendo de la State Machine — el LLM **no** decide transiciones, solo calibra umbrales como parámetros.

**Esta TS no requiere ni activa LLM.**

---

## Restricciones Declaradas Explícitamente

| Constraint | Cómo aplica en TS-2-003 |
|---|---|
| **D1** — solo `domain`/`category` accesibles en claro | State Machine consume `&[TrustScore]` (cuyos campos no contienen `url` ni `title`, validado en AR-2-004) y persiste sólo enum + timestamps. Ningún campo de `TrustState`, `TrustStateView`, `Transition`, `StateMachineConfig` ni `UserAction` puede contener `url` o `title`. La tabla `trust_state` no tiene columnas con esos campos. |
| **D4** — autoridad exclusiva de la State Machine | Sección dedicada §"Restricción D4 — Autoridad Exclusiva" con cuatro subsecciones. Lista de prohibiciones explícita. Test estructural con `include_str!` + split por `#[cfg(test)]`. Forbidden imports recíprocos auditables por grep. Cadena de invocación canónica documentada. |
| **D8** — baseline determinístico sin LLM | `evaluate_transition` sin RNG, sin LLM, sin `SystemTime::now()` interno. `now_unix` explícito. Iteración estable sobre `&[TrustScore]`. Test `test_determinism_bit_exact` lo blinda. |
| **D14** — Privacy Dashboard completo bloqueante de Fase 2 | El contrato `TrustStateView` definido en §"Comandos Tauri" es directamente consumible por T-2-004 sin modificaciones de interfaz. Los tres comandos Tauri (`get_trust_state`, `reset_trust_state`, `enable_autonomous_mode`) son el contrato completo que T-2-004 requiere. |
| **R12** — State Machine ≠ Pattern Detector ≠ Trust Scorer | Tabla comparativa de tres columnas en cabecera del módulo. Sin imports cruzados. Sin reutilización de código no utilitario. Comentario de cabecera obligatorio reproducido textualmente. |

---

## Criterios de Aprobación Post-Implementación

El Technical Architect verificará antes de desbloquear T-2-004 (Privacy Dashboard completo):

- [ ] `state_machine.rs` existe como módulo independiente registrado en `lib.rs` (línea alfabéticamente coherente, e.g. tras `session_builder` y antes de `storage`).
- [ ] Comentario de cabecera con D4, D8, D1, D14 y R12 declarados explícitamente, y tabla comparativa de tres columnas (Pattern Detector / Trust Scorer / State Machine) con ocho dimensiones reproducida textualmente.
- [ ] Distinción explícita de umbrales `StateMachineConfig` (`min_patterns`, `threshold_low`, `threshold_high`, `aggregation`) vs `TrustConfig` (`tier_low_max`, `tier_high_min`, `half_life_days`, `frequency_saturation`, `w_*`) — sin reutilización de nombres ni valores.
- [ ] La dirección de dependencias es correcta: la State Machine consume `&[TrustScore]` por parámetro — **no** llama directamente a `score_patterns` ni a `detect_patterns`. Sin `use crate::pattern_detector` ni `use crate::trust_scorer::score_patterns` en `state_machine.rs`. Sin imports recíprocos desde `trust_scorer.rs` ni `pattern_detector.rs` hacia `state_machine` (verificable por grep en AR-2-005).
- [ ] La transición a `Autonomous` solo es posible mediante `UserAction::EnableAutonomous { confirmed: true }` desde estado `Trusted`; no hay path de transición automática a `Autonomous`. Sin confirmación devuelve `ConfirmationRequired`; desde otro estado devuelve `InvalidTransitionFromState`.
- [ ] La transición `Learning → Trusted` requiere doble condición: `trust_score_aggregate > threshold_high && !user_blocked` (D4). Cableado de `user_blocked` declarado contractualmente, aunque el flag concreto se materialice en T-2-004.
- [ ] `reset_trust_state` devuelve el sistema a `Observing` desde cualquier estado, con `last_transition_at = now_unix`.
- [ ] **No existe downgrade automático.** `Learning → Observing` solo ocurre por `UserAction::Reset`. Test `test_no_auto_downgrade_from_learning` lo blinda.
- [ ] Algoritmo determinístico: dos llamadas con mismo input producen mismo output bit-exacto, sin RNG, sin `SystemTime::now()` interno. Test `test_determinism_bit_exact` lo verifica.
- [ ] Persistencia en SQLCipher: tabla `trust_state` singleton con `id INTEGER PRIMARY KEY CHECK (id = 1)`, `current_state TEXT NOT NULL CHECK (...)`, `last_transition_at INTEGER NOT NULL`, `updated_at INTEGER NOT NULL`. Migración idempotente verificada (`CREATE TABLE IF NOT EXISTS` + `INSERT OR IGNORE`). Nunca persiste `trust_score` ni `stability_score`.
- [ ] Estado inicial al primer arranque: `Observing`. Test `test_initial_state_is_observing` lo verifica.
- [ ] Comandos Tauri implementados: `get_trust_state`, `reset_trust_state`, `enable_autonomous_mode(confirmed: bool)`. `TrustStateView` exportado con tipos coherentes para `src/types.ts`.
- [ ] Tests pasando sin regresiones (target ≥ 43 tests = 33 previos + 10 nuevos obligatorios). `cargo test` limpio.
- [ ] `npx tsc --noEmit` limpio tras añadir comandos Tauri (`get_trust_state`, `reset_trust_state`, `enable_autonomous_mode` consumibles desde T-2-004).

---

## Handoffs Requeridos Post-Implementación

1. **Technical Architect** — revisión arquitectónica (`AR-2-005-state-machine-review.md`):
   - Verificar los 14 criterios de aprobación post-implementación.
   - Confirmar que el contrato de `TrustStateView` es suficiente para que T-2-004 lo consuma sin modificaciones de interfaz.
   - Verificar grep recíproco en `pattern_detector.rs` y `trust_scorer.rs` confirmando ausencia de `use crate::state_machine`.
   - Verificar que la cadena `commands.rs` se materializa exclusivamente en `commands.rs` y no en módulos intermedios.
2. Tras aprobación del Technical Architect → emisión del HO de kickoff de T-2-004 (Privacy Dashboard completo).

La implementación de `state_machine.rs` queda autorizada al **Desktop Tauri Shell Specialist** únicamente con TS-2-003 firmado por Technical Architect y aprobado por Orchestrator.

---

## Firma

approved_by: Technical Architect
approval_date: 2026-04-27
notes: Spec conforme a HO-012 y constraints D1/D4/D8/D14/R12. Contrato de TrustState/TrustStateView considerado suficiente para que Privacy Dashboard (T-2-004) consuma estado y transiciones sin modificaciones de interfaz. Posturas tomadas explícitamente: (1) agregación de trust_score = Max por defecto, configurable vía AggregationMode (Median/Mean reservadas pero no implementadas en T-2-003); (2) downgrade automático = opción (b) — solo reset manual, hook de change request declarado para Fase 3 si emerge abuso; (3) user_blocked = flag por patrón con cableado declarado y materialización diferida a T-2-004. Persistencia: tabla trust_state singleton con CHECK (id = 1), CREATE TABLE IF NOT EXISTS + INSERT OR IGNORE para idempotencia. Sin downgrade automático, sin LLM, sin RNG, sin SystemTime::now() interno. Tests obligatorios = 10 (más 2 recomendados); target post-implementación ≥ 43 tests. Riesgos conocidos documentados en §"Riesgos Conocidos" con mitigaciones explícitas.
