# Standard Handoff

document_id: HO-013
from_agent: Orchestrator
to_agent: Desktop Tauri Shell Specialist
status: ready_for_execution
phase: 2
date: 2026-04-27
cycle: Implementación Fase 2 — T-2-003 State Machine (state_machine.rs)
opens: implementación de `src-tauri/src/state_machine.rs` + comandos Tauri + persistencia SQLCipher + tipos TypeScript
depends_on: TS-2-003 firmada por Technical Architect (2026-04-27) y validada por Orchestrator
unblocks: AR-2-005 (revisión arquitectónica post-implementación) y, tras aprobación, T-2-004 (Privacy Dashboard completo) — D14

---

## Objetivo

Implementar `src-tauri/src/state_machine.rs` siguiendo TS-2-003 al pie de la
letra, registrar el módulo en `lib.rs`, añadir la tabla `trust_state` a
`storage.rs` con migración idempotente, exponer los tres comandos Tauri
(`get_trust_state`, `reset_trust_state`, `enable_autonomous_mode`), y añadir los
tipos TypeScript correspondientes en `src/types.ts`. Los **10 tests
obligatorios + 2 recomendados** declarados en TS-2-003 §"Plan de Tests con
Dataset Sintético" deben pasar; los **33 tests previos** (24 de Fase 1 + 9 de
Trust Scorer) **no deben tener regresiones** (target ≥ 43 tests). `npx tsc
--noEmit` debe quedar limpio tras añadir los comandos Tauri.

Este HO es el **primer HO de implementación formal** de la cadena Fase 2 y
materializa la cláusula §"Cierre" de HO-012 ("Tras aprobación se activa el HO
posterior — kickoff implementación al Desktop Tauri Shell Specialist") y
TS-2-003 §"Handoffs Requeridos Post-Implementación". La implementación queda
autorizada únicamente porque TS-2-003 está firmada por Technical Architect y
validada por Orchestrator.

---

## Inputs

Lectura obligatoria antes de empezar la implementación:

- `operations/task-specs/TS-2-003-state-machine.md` — la spec completa,
  especialmente:
  - §"Distinción Obligatoria R12" (cabecera del módulo y tabla comparativa de
    tres columnas con ocho dimensiones).
  - §"Contrato del Módulo" (firma exacta de tipos públicos y de
    `evaluate_transition`, visibilidad `pub(crate)` de `ensure_schema` /
    `load_state` / `save_state`).
  - §"Restricción D4 — Autoridad Exclusiva" (cadena de invocación canónica,
    forbidden imports recíprocos, test estructural con `include_str!` + split
    por `#[cfg(test)]`).
  - §"Reglas de Transición Exactas" (cuatro transiciones con condiciones
    literales y las tres posturas tomadas por TS-2-003).
  - §"Persistencia en SQLCipher" (schema exacto, migración idempotente,
    comportamiento al primer arranque, prohibiciones explícitas).
  - §"Comandos Tauri" (firmas, comportamiento, `TrustStateView`).
  - §"Plan de Tests con Dataset Sintético" (10 tests obligatorios + 2
    recomendados, helpers requeridos).
  - §"Criterios de Aprobación Post-Implementación" (los 14 ítems que verificará
    AR-2-005).
- `operations/architecture-reviews/AR-2-004-trust-scorer-review.md` — modelo de
  qué se verificará en AR-2-005 (criterios, observaciones, compatibilidad
  campo-a-campo, verificación de constraints final).
- `operations/handoffs/HO-012-phase-2-ts-2-003-kickoff.md` — referencia del HO
  predecesor que activó el drafting de TS-2-003.
- `Project-docs/decisions-log.md` — D1, D4, D8, D14, R12 (no negociables;
  reiterados en §"Restricciones" abajo).
- `CLAUDE.md` (FlowWeaver) — sección "T-2-003 — State Machine
  (`state_machine.rs`)".
- Código existente en FlowWeaver (solo lectura, para confirmar superficie de
  integración):
  - `src-tauri/src/lib.rs` — actualmente declara `mod trust_scorer;` en línea
    11. Se debe añadir `mod state_machine;` en orden alfabético entre
    `session_builder` (línea 9) y `storage` (línea 10).
  - `src-tauri/src/trust_scorer.rs` — contrato de `TrustScore` y
    `ConfidenceTier` que se consumirá por referencia.
  - `src-tauri/src/storage.rs` — patrón existente de migraciones SQLCipher
    (`CREATE TABLE IF NOT EXISTS` + `ALTER TABLE … ADD COLUMN` idempotente,
    líneas 72-98); `ensure_schema` debe seguir este patrón.
  - `src-tauri/src/commands.rs` — patrón existente de comandos Tauri (uso de
    `State<'_, DbState>`, retorno de `Result<T, String>`, lock del mutex). Los
    tres comandos nuevos deben seguir este patrón.
  - `src/types.ts` — actualmente sin `TrustStateView` ni `TrustStateEnum`. Se
    deben añadir respetando exactamente la serialización Rust de los
    structs/enums.

---

## Entregable esperado

Lista granular y verificable de los seis cambios exigidos:

### 1. Nuevo archivo `src-tauri/src/state_machine.rs`

Contiene en orden:

a. **Comentario de cabecera obligatorio** — reproducción literal del bloque de
   TS-2-003 §"Distinción Obligatoria R12" → "Comentario de cabecera obligatorio
   en el módulo Rust", incluyendo:
   - Las cuatro líneas de propósito y constraints (`D4`, `D8`, `D1`, `D14`,
     `R12`).
   - La tabla comparativa de **tres columnas** (`pattern_detector.rs`,
     `trust_scorer.rs`, `state_machine.rs`) y **ocho dimensiones** (Propósito,
     Input, Output, Acceso BD, Decide acciones, Persistencia, Estado interno,
     Determinismo).
   - La línea final indicando "este (el actual) — D4" para la columna
     `state_machine.rs`.

b. **Tipos públicos** con las derivaciones exactas de TS-2-003 §"Contrato del
   Módulo":
   - `TrustStateEnum` con cuatro variantes (`Observing`, `Learning`, `Trusted`,
     `Autonomous`) y derivaciones `Debug, Clone, Copy, PartialEq, Eq, Serialize,
     Deserialize`.
   - `Transition` con campos `from`, `to`, `requires_user_action: bool`.
   - `TrustState` con cuatro campos públicos (`current_state`,
     `available_transitions`, `active_patterns_count`, `last_transition_at`).
   - `AggregationMode` con tres variantes (`Max`, `Median`, `Mean`).
   - `StateMachineConfig` con cuatro campos (`min_patterns`, `threshold_low`,
     `threshold_high`, `aggregation`) y `impl Default` con valores
     `(3, 0.4, 0.75, AggregationMode::Max)`.
   - `UserAction` enum con dos variantes (`Reset`,
     `EnableAutonomous { confirmed: bool }`).
   - `StateMachineError` enum con cuatro variantes (`InvalidConfig(String)`,
     `ConfirmationRequired`, `InvalidTransitionFromState(TrustStateEnum)`,
     `Persistence(rusqlite::Error)`).
   - `impl Display` y `impl std::error::Error` para `StateMachineError`.
   - `impl From<rusqlite::Error> for StateMachineError`.

c. **Función pública `evaluate_transition`** con la firma exacta de TS-2-003
   §"Contrato del Módulo":
   ```rust
   pub fn evaluate_transition(
       scores: &[TrustScore],
       current: TrustStateEnum,
       last_transition_at: i64,
       user_action: Option<UserAction>,
       now_unix: i64,
       config: &StateMachineConfig,
   ) -> Result<TrustState, StateMachineError>
   ```
   Comportamiento exacto definido por las cuatro reglas de §"Reglas de
   Transición Exactas":
   - Validación de configuración primero (devuelve `InvalidConfig` por
     `min_patterns == 0`, `threshold_low >= threshold_high`,
     `threshold_low/high` fuera de [0.0, 1.0], o `aggregation != Max`).
   - Acciones de usuario tienen prioridad sobre tick automático
     (`Some(Reset)` → siempre `Observing`; `Some(EnableAutonomous { confirmed
     })` → validar `confirmed` y `current == Trusted`).
   - Tick automático (`None`) sólo aplica promociones (`Observing → Learning`,
     `Learning → Trusted`); nunca downgrade — postura **opción (b)** de
     TS-2-003 §"Postura sobre downgrade automático".
   - `last_transition_at` se actualiza solo cuando hay transición efectiva; se
     preserva el valor de entrada cuando el estado no cambia.

d. **Funciones `pub(crate)` de persistencia** según TS-2-003 §"Contrato del
   Módulo" (visibilidad estricta `pub(crate)`, **no `pub`**):
   - `ensure_schema(conn, now_unix)` — `CREATE TABLE IF NOT EXISTS` +
     `INSERT OR IGNORE` con valores `(1, 'Observing', now_unix, now_unix)`.
   - `load_state(conn)` — devuelve `(TrustStateEnum, i64)`; defensiva ante
     tabla vacía devolviendo `(Observing, now_unix)` (responsabilidad de
     inicializar es de `ensure_schema`, pero load defensivo evita un crash si
     el orden se invierte por accidente; declarar el comportamiento en doc
     comment).
   - `save_state(conn, state, last_transition_at, now_unix)` — UPSERT sobre
     `id = 1`; `updated_at` se actualiza siempre, `last_transition_at` solo si
     el estado cambió respecto a la fila previa.

e. **Helper privado `user_blocked(scores) -> bool`** — postura tomada por
   TS-2-003 §"Reglas de Transición — `Learning → Trusted`":
   ```rust
   /// TODO(T-2-004): cuando el flag `is_blocked` exista en `TrustScore` o en
   /// una tabla auxiliar `pattern_blocks`, sustituir por
   /// `scores.iter().any(|s| s.is_blocked())`. Materialización diferida a
   /// T-2-004; durante el sprint T-2-003 devuelve `false` por defecto sin
   /// bloquear el avance contractual.
   fn user_blocked(_scores: &[TrustScore]) -> bool {
       false
   }
   ```
   El helper debe estar **claramente aislado y marcado** para que su
   sustitución por la implementación real de T-2-004 sea una sola edición
   mecánica. AR-2-005 verificará el aislamiento.

f. **Bloque `#[cfg(test)] mod tests`** con los **10 tests obligatorios**
   (TS-2-003 §"Plan de Tests" → "Tests obligatorios (10 mínimos)"):
   1. `test_initial_state_is_observing`
   2. `test_observing_to_learning_on_threshold`
   3. `test_learning_to_trusted_on_high_threshold`
   4. `test_learning_to_trusted_blocked_when_user_blocked` — implementación
      pragmática durante el sprint: marcar `#[ignore]` con motivo documentado
      ("activado en T-2-004 cuando `is_blocked` esté disponible") **o**
      implementar el wiring temporal pasando un flag por TrustScore con
      addendum a TS-2-002. Decidir y dejar constancia textual del modo
      elegido en el cuerpo del test. AR-2-005 acepta cualquiera de las dos
      alternativas siempre que el test exista nombrado.
   5. `test_trusted_to_autonomous_requires_explicit_action` (cubre los cuatro
      casos: sin acción, confirmada, sin confirmar, desde estado distinto de
      Trusted).
   6. `test_reset_from_each_state` (Observing/Learning/Trusted/Autonomous →
      Observing).
   7. `test_no_action_api_for_external_modules` — test estructural exacto de
      TS-2-003 §"Restricción D4 — Autoridad Exclusiva" (d): `include_str!` +
      split por `#[cfg(test)]` + array de tokens prohibidos + grep negativo
      de `use crate::pattern_detector`, `score_patterns(`, `detect_patterns(`.
   8. `test_determinism_bit_exact` (mismos inputs → mismo output;
      `last_transition_at`, `current_state`, `active_patterns_count`,
      `available_transitions.len()`).
   9. `test_persistence_round_trip` (BD en memoria; `ensure_schema` →
      `load_state` → `save_state` → `load_state`).
   10. `test_invalid_config` (cubre los tres casos:
       `threshold_low >= threshold_high`, `min_patterns == 0`, `aggregation
       != Max`).

   **Más los 2 tests recomendados** (TS-2-003 §"Tests recomendados
   adicionales"):
   - `test_observing_blocked_when_below_min_patterns` (`scores.len() < 3` con
     trust = 1.0 ⇒ se queda en Observing).
   - `test_no_auto_downgrade_from_learning` (postura opción (b): scores bajos
     no degradan automáticamente Learning → Observing).

   El módulo debe contener **un solo bloque `#[cfg(test)]`** para que el split
   del test estructural funcione tal como está definido (consistente con
   `trust_scorer.rs` — ver AR-2-004 §O.3).

### 2. Modificación `src-tauri/src/lib.rs`

Añadir `mod state_machine;` en **orden alfabético** entre `session_builder`
(línea 9) y `storage` (línea 10). El listado quedará así (líneas 1-12 tras la
edición):

```
mod classifier;
mod commands;
mod crypto;
mod episode_detector;
mod grouper;
mod importer;
mod pattern_detector;
mod raw_event;
mod session_builder;
mod state_machine;
mod storage;
mod trust_scorer;
```

### 3. Modificación `src-tauri/src/storage.rs`

Añadir migración idempotente para la tabla `trust_state` siguiendo el patrón
existente en `Db::migrate()` (líneas 72-98). El esquema **literal** definido
por TS-2-003 §"Persistencia en SQLCipher → Schema mínimo" es:

```sql
CREATE TABLE IF NOT EXISTS trust_state (
    id                 INTEGER PRIMARY KEY CHECK (id = 1),
    current_state      TEXT    NOT NULL CHECK (current_state IN
                              ('Observing', 'Learning', 'Trusted', 'Autonomous')),
    last_transition_at INTEGER NOT NULL,
    updated_at         INTEGER NOT NULL
);
```

La migración debe ejecutar `CREATE TABLE IF NOT EXISTS` + `INSERT OR IGNORE
INTO trust_state (id, current_state, last_transition_at, updated_at) VALUES
(1, 'Observing', ?1, ?1)` con `now_unix` como parámetro de bind, replicando el
patrón de `ensure_schema` propuesto en TS-2-003 §"Migración idempotente".

**Decisión operativa de integración:** la responsabilidad de invocar la
migración es del módulo `state_machine` vía su `ensure_schema(conn, now_unix)`,
llamado desde `commands.rs` antes de cada uso. No es necesario tocar
`Db::migrate()` para insertar el código del schema dentro de `storage.rs` si
prefieres mantener la migración encapsulada en `state_machine.rs`. Ambas
ubicaciones son aceptables siempre que la idempotencia se preserve y la tabla
se cree antes del primer `load_state`. **Recomendación:** mantener
`ensure_schema` en `state_machine.rs` (módulo dueño del schema) y llamarlo
desde `commands.rs` en cada comando que toque la State Machine — coherente con
TS-2-003 §"Cadena de invocación canónica" (paso 2 del pseudocódigo).

### 4. Modificación `src-tauri/src/commands.rs`

Añadir tres nuevos comandos Tauri siguiendo TS-2-003 §"Comandos Tauri" y el
patrón existente del archivo:

a. **`get_trust_state(state: State<'_, DbState>) -> Result<TrustStateView,
   String>`** — cadena canónica:
   1. `now_unix` desde `SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64`.
   2. Lock del mutex de `DbState`; obtener `&Connection`.
   3. `state_machine::ensure_schema(conn, now_unix)?`.
   4. `let (current, last_ts) = state_machine::load_state(conn)?`.
   5. `let patterns = pattern_detector::detect_patterns(conn,
      &PatternConfig::default(), now_unix)?`.
   6. `let scores = trust_scorer::score_patterns(&patterns,
      &TrustConfig::default(), now_unix)?`.
   7. `let new_state = state_machine::evaluate_transition(&scores, current,
      last_ts, None, now_unix, &StateMachineConfig::default())?`.
   8. `state_machine::save_state(conn, new_state.current_state,
      new_state.last_transition_at, now_unix)?`.
   9. `Ok(TrustStateView::from(new_state))`.

   La cadena se materializa **exclusivamente** aquí. La State Machine no
   invoca `detect_patterns` ni `score_patterns` por sí misma (D4). AR-2-005
   verificará por grep recíproco que `state_machine.rs` no contiene
   `use crate::pattern_detector` ni invocaciones a `score_patterns(`.

b. **`reset_trust_state(state: State<'_, DbState>) -> Result<TrustStateView,
   String>`** — idéntico a `get_trust_state` excepto que invoca
   `evaluate_transition` con `Some(UserAction::Reset)` en el sexto argumento.
   Resultado: estado → `Observing` desde cualquier estado actual.

c. **`enable_autonomous_mode(state: State<'_, DbState>, confirmed: bool) ->
   Result<TrustStateView, String>`** — idéntico excepto que invoca con
   `Some(UserAction::EnableAutonomous { confirmed })`. Propaga
   `StateMachineError::ConfirmationRequired` y
   `StateMachineError::InvalidTransitionFromState(...)` como `String` al
   frontend con mensajes descriptivos (`"confirmation required"`,
   `"invalid transition from <state>"`, etc.).

**Registrar los tres comandos** en el `invoke_handler!` de `lib.rs` (líneas
61-79 actuales), añadiéndolos en orden lógico (sugerencia: tras
`commands::clear_all_resources` y antes de los comandos mobile/relay).

**Imports nuevos requeridos en `commands.rs`:** añadir
`pattern_detector::{self, PatternConfig}`, `state_machine::{self,
StateMachineConfig, UserAction, TrustStateView}`, `trust_scorer::{self,
TrustConfig}` al bloque `use crate::{ … }`. Verificar que los nombres de tipos
existen en sus módulos respectivos antes de importar (si `PatternConfig` o
`TrustConfig` no son `pub`, ajustar visibilidad o usar valores por defecto
inline).

### 5. Modificación `src/types.ts`

Añadir los tipos consumidos por T-2-004. Los nombres y campos deben coincidir
**exactamente** con la serialización Rust (orden, nombres, casing
`snake_case` de Rust → `snake_case` en TypeScript también para consistencia
con el resto del archivo, e.g. `current_state`, `last_transition_at`,
`active_patterns_count` ya en `snake_case`):

```typescript
// ── Phase 2 — Trust State (T-2-003) ──────────────────────────────────────────

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

Si `ConfidenceTier` aún no está exportado en `types.ts` y T-2-004 lo va a
necesitar, **no lo añadas en T-2-003** — su materialización es responsabilidad
de T-2-004 cuando consuma `PatternSummary`/`TrustScore` desde la UI. T-2-003
solo expone `TrustStateView` y sus dependencias inmediatas (`TrustStateEnum`,
`Transition`).

### 6. Verificación final

Ejecutar y reportar el resultado de los siguientes comandos:

```bash
cd src-tauri && cargo test
```
- **Target:** ≥ 43 tests pasando (33 previos + 10 obligatorios + 2
  recomendados; el test #4 puede estar `#[ignore]` con justificación).
- Reportar conteo exacto: `running N tests … test result: ok. M passed; K
  failed; I ignored`.

```bash
npx tsc --noEmit
```
- Salida limpia (sin errores) tras la adición de los tres comandos Tauri y
  los tipos en `src/types.ts`.

Documentar en el handoff de cierre:
- Conteo exacto de tests `passed / failed / ignored`.
- Estado de `npx tsc --noEmit`.
- Líneas finales del archivo `state_machine.rs`.
- Cualquier desviación de TS-2-003 con justificación (idealmente cero).
- Confirmación línea-por-línea de los **14 criterios** de TS-2-003 §"Criterios
  de Aprobación Post-Implementación" — referenciar líneas concretas del
  código que satisfacen cada criterio.

---

## Restricciones

Reiteración explícita de los constraints no negociables aplicables a T-2-003:

### D1 — sin `url`/`title` (transitivo)

- Ningún campo persistido en la tabla `trust_state` puede contener `url` ni
  `title` — el schema solo tiene `id`, `current_state`, `last_transition_at`,
  `updated_at`.
- Ningún campo de los structs públicos (`TrustState`, `TrustStateView`,
  `Transition`, `StateMachineConfig`, `UserAction`, `StateMachineError`) puede
  llamarse `url`, `title`, `link`, `href`, `bookmark_url`, `page_title` o
  variantes — auditable por inspección textual.
- La State Machine **no** accede a SQLCipher para leer recursos; consume
  `&[TrustScore]` por parámetro (cuyos campos ya fueron auditados en AR-2-004
  como libres de `url`/`title`).

### D4 — autoridad exclusiva de la State Machine

- Única autoridad de transición y de acción del sistema. Trust Scorer y
  Pattern Detector **no** invocan transiciones.
- **Forbidden imports en `state_machine.rs`** (auditable por grep en AR-2-005):
  - `use crate::pattern_detector` — prohibido.
  - `use crate::trust_scorer::score_patterns` — prohibido.
  - Llamadas a `score_patterns(` o `detect_patterns(` desde dentro del módulo
    — prohibidas.
- **Forbidden imports recíprocos** (verificación cruzada por grep en AR-2-005,
  fuera del archivo bajo test): ni `pattern_detector.rs` ni `trust_scorer.rs`
  pueden contener `use crate::state_machine` salvo el comentario documental
  R12.
- La cadena `detect_patterns → score_patterns → evaluate_transition` se
  compone **exclusivamente** en `commands.rs`. El test estructural
  `test_no_action_api_for_external_modules` blinda los tokens prohibidos en la
  API pública.

### D8 — determinismo bit-exacto

- Sin RNG. Sin `SystemTime::now()` interno en `evaluate_transition`. Sin LLM.
  `now_unix` se pasa por parámetro como en TS-2-002.
- Iteración estable sobre `&[TrustScore]` en orden de entrada. Cálculo del
  `trust_score_aggregate` con `scores.iter().fold(f64::NEG_INFINITY,
  f64::max)` para garantía bit-exacta ante NaN (TS-2-003 §"Determinismo (D8)"
  línea 450).
- Test `test_determinism_bit_exact` lo verifica con comparación exacta de
  `current_state`, `last_transition_at`, `active_patterns_count` y
  `available_transitions.len()`.

### D5 — transitivo (no aplica a State Machine)

- La State Machine **no** calcula `stability_score`. Consume `trust_score` y
  `confidence_tier` por referencia y no recalcula nada de TS-2-002.
- No introducir lógica de entropía ni de slot concentration en este módulo.

### D14 — Privacy Dashboard bloquea cierre Fase 2

- T-2-004 (Privacy Dashboard completo) depende del contrato exacto de
  `TrustStateView` definido en este sprint. No modificar ese contrato sin
  coordinación con T-2-004.
- Los tres comandos Tauri (`get_trust_state`, `reset_trust_state`,
  `enable_autonomous_mode`) son el contrato completo que T-2-004 consume.
- Los tipos TypeScript añadidos en `src/types.ts` son la única superficie que
  T-2-004 importará; deben ser estables.

### R12 — distinción de módulos

- Comentario de cabecera obligatorio con la **tabla de tres columnas y ocho
  dimensiones** reproducida desde TS-2-003 §"Distinción Obligatoria R12".
- `state_machine.rs` ≠ `pattern_detector.rs` ≠ `trust_scorer.rs`. No heredar
  algoritmos ni reutilizar código de los otros módulos salvo el consumo de
  los tipos `TrustScore` / `ConfidenceTier` por parámetro (no por
  reimplementación).

### Restricciones específicas de T-2-003 (posturas tomadas en TS-2-003)

- **No implementar `is_blocked` real en `TrustScore`** — T-2-002 está cerrado
  sin el flag. Usar el helper privado `user_blocked()` que devuelve `false`
  por defecto, marcado con `TODO(T-2-004)`. El test #4
  (`test_learning_to_trusted_blocked_when_user_blocked`) puede quedar
  `#[ignore]` con justificación documentada o usar wiring temporal — ambas
  alternativas son aceptables. AR-2-005 verificará que el placeholder está
  aislado y su sustitución es mecánica.
- **No implementar variantes `Median` ni `Mean`** de `AggregationMode` —
  declarar las variantes en el enum (necesarias para la firma) pero la
  validación de `evaluate_transition` debe devolver
  `StateMachineError::InvalidConfig("aggregation mode not implemented in
  T-2-003 baseline")` si se selecciona una distinta de `Max`. Test
  `test_invalid_config` cubre este caso.
- **No implementar downgrade automático** — postura opción (b) de TS-2-003
  §"Postura sobre downgrade automático". Scores bajos **no** degradan
  `Learning → Observing`. Test `test_no_auto_downgrade_from_learning`
  (recomendado) lo blinda. La única vía de bajada es `UserAction::Reset`.
- **No modificar `trust_scorer.rs` ni `pattern_detector.rs`** — su contrato
  está cerrado por TS-2-001 / TS-2-002 y aprobado por AR-2-003 / AR-2-004.
  Cualquier necesidad de modificación debe escalarse al Orchestrator antes de
  proceder.
- **No exponer `Connection` desde `state_machine.rs`** — todas las funciones
  de persistencia reciben `&Connection` por parámetro y devuelven después de
  cerrar el statement.
- **No persistir `trust_score` ni `stability_score`** en SQLCipher — se
  recalculan on-demand desde `Vec<DetectedPattern>` (decisión heredada de
  TS-2-002 §"Decisión de Persistencia").

---

## Cierre

Tras completar la implementación, el Desktop Tauri Shell Specialist debe
**emitir handoff de cierre al Technical Architect** solicitando emisión de
`AR-2-005-state-machine-review.md` (revisión arquitectónica
post-implementación). AR-2-005 verificará los **14 criterios** de TS-2-003
§"Criterios de Aprobación Post-Implementación":

1. `state_machine.rs` existe como módulo independiente registrado en `lib.rs`
   en orden alfabético (entre `session_builder` y `storage`).
2. Comentario de cabecera con D4, D8, D1, D14 y R12 declarados explícitamente,
   y tabla comparativa de tres columnas y ocho dimensiones reproducida
   textualmente.
3. Distinción explícita de umbrales `StateMachineConfig` vs `TrustConfig` —
   sin reutilización de nombres ni valores.
4. Dirección de dependencias correcta — sin `use crate::pattern_detector` ni
   `use crate::trust_scorer::score_patterns` en `state_machine.rs`. Sin
   imports recíprocos desde `trust_scorer.rs` ni `pattern_detector.rs`
   (verificable por grep).
5. Transición a `Autonomous` solo posible mediante `UserAction::EnableAutonomous
   { confirmed: true }` desde `Trusted`; sin path automático.
6. Transición `Learning → Trusted` con doble condición `trust_score_aggregate
   > threshold_high && !user_blocked`; cableado de `user_blocked` declarado
   contractualmente.
7. `reset_trust_state` devuelve a `Observing` desde cualquier estado con
   `last_transition_at = now_unix`.
8. **Sin downgrade automático** — `Learning → Observing` solo por
   `UserAction::Reset`; test `test_no_auto_downgrade_from_learning` lo blinda.
9. Determinismo bit-exacto — test `test_determinism_bit_exact` verifica.
10. Persistencia: tabla `trust_state` singleton con CHECK enum + migración
    idempotente; nunca persiste `trust_score` ni `stability_score`.
11. Estado inicial al primer arranque: `Observing`; test
    `test_initial_state_is_observing` verifica.
12. Tres comandos Tauri implementados (`get_trust_state`, `reset_trust_state`,
    `enable_autonomous_mode(confirmed: bool)`); `TrustStateView` exportado.
13. Tests pasando sin regresiones (target ≥ 43); `cargo test` limpio.
14. `npx tsc --noEmit` limpio tras añadir comandos y tipos.

**Solo tras aprobación de AR-2-005 se desbloquea T-2-004** (Privacy Dashboard
completo — D14 lo bloquea hasta tener `TrustState` contractual implementado y
verificado).

El implementador debe reportar al cierre los siguientes datos verificables:

- Número exacto de tests pasados (formato `M passed; K failed; I ignored`;
  target ≥ 43 con `failed = 0`).
- Estado de `npx tsc --noEmit` (limpio o lista de errores).
- Cualquier desviación de TS-2-003 con justificación explícita (idealmente
  cero; el Orchestrator validará cualquier desviación antes de pasar a
  AR-2-005).
- Líneas totales del archivo `state_machine.rs` final.
- Confirmación línea-por-línea de los 14 criterios de aprobación con
  referencias a líneas concretas del código (e.g. "Criterio #4 — sin imports
  prohibidos: verificado en líneas 20-22 del módulo, donde solo se importan
  `crate::trust_scorer::{ConfidenceTier, TrustScore}`, `rusqlite::Connection`
  y `serde`").

La implementación de T-2-003 queda autorizada únicamente con TS-2-003 firmada
por Technical Architect (2026-04-27) y validada por Orchestrator. Cualquier
ambigüedad encontrada durante la implementación se escala al Orchestrator
**antes** de tomar decisiones que puedan apartarse de la spec. El
implementador no introduce posturas nuevas — TS-2-003 ya tomó las tres
posturas exigidas (agregación = Max, downgrade = opción b, user_blocked =
flag por patrón con materialización diferida) y son contractualmente
vinculantes.
