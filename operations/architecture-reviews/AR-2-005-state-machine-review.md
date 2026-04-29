# Revisión Arquitectónica — State Machine (T-2-003)

document_id: AR-2-005
owner_agent: Technical Architect
phase: 2
date: 2026-04-27
status: APROBADO — sin correcciones; T-2-003 cerrado, T-2-004 desbloqueado (D14)
documents_reviewed:
  - operations/task-specs/TS-2-003-state-machine.md
  - operations/handoffs/HO-013-phase-2-ts-2-003-impl-kickoff.md
  - operations/handoffs/HO-014-phase-2-ts-2-003-impl-close.md
  - src-tauri/src/state_machine.rs (módulo nuevo, 819 líneas)
  - src-tauri/src/lib.rs (`mod state_machine;` registrado en línea 10; tres comandos
    en `invoke_handler!` líneas 75-77)
  - src-tauri/src/commands.rs (líneas 260-324: tres comandos Tauri + helper
    privado `apply_trust_action`)
  - src-tauri/src/storage.rs (delta mínimo: accesor `pub(crate) fn conn()`)
  - src/types.ts (líneas 84-99: bloque T-2-003)
reference_normativo:
  - Project-docs/decisions-log.md (D1, D4, D5, D8, D14, R12)
  - operations/backlogs/backlog-phase-2.md (T-2-003 acceptance criteria)
  - operations/architecture-reviews/AR-2-003-pattern-detector-review.md
  - operations/architecture-reviews/AR-2-004-trust-scorer-review.md
precede_a: Orchestrator → emisión de HO de kickoff de T-2-004 (Privacy Dashboard
  completo) al Desktop Tauri Shell Specialist; D14 queda satisfecho con la
  aprobación de esta AR.

---

## Objetivo De Esta Revisión

Verificar que la implementación de `state_machine.rs` satisface los **14
criterios de aprobación post-implementación** de TS-2-003 §"Criterios de
Aprobación Post-Implementación", validar las **3 desviaciones documentadas**
en HO-014 (todas autorizadas explícitamente por HO-013 o forzadas por los
contratos cerrados de TS-2-001 / TS-2-002), confirmar el cumplimiento de los
constraints **D1, D4, D5 (transitivo), D8, D14 y R12**, y certificar que el
contrato `TrustStateView` + los tres comandos Tauri son input suficiente para
T-2-004 (Privacy Dashboard completo) sin modificación de interfaz.

Datos confirmados por el implementador (HO-014 §"Resultados verificables") y
re-verificados por el revisor en este pase:

- `cargo test` — **45 tests / 44 passed / 0 failed / 1 ignored** (target ≥ 43;
  el ignored es el #4 con justificación documentada que HO-013 §"Test #4"
  acepta explícitamente).
- `npx tsc --noEmit` — salida vacía, limpio.
- Grep recíproco D4 verificado en este pase (ver O.4 abajo).

---

## Resultado Global

**APROBADO sin correcciones.** Los 14 criterios de TS-2-003 están satisfechos
con referencias a líneas concretas. Las 3 desviaciones (D-1 storage no
modificado salvo accesor, D-2 `load_state` defensivo devuelve `(Observing,
0)`, D-3 `detect_patterns` con 2 argumentos) son arquitectónicamente
aceptables y están cada una documentada en código (doc comments / comentarios
inline). El contrato `TrustStateView` (`current_state`, `available_transitions`,
`active_patterns_count`, `last_transition_at`) es estable y consumible por
T-2-004 sin modificación de interfaz.

| # | Criterio TS-2-003 | Resultado | Observación |
|---|---|---|---|
| 1 | `state_machine.rs` registrado alfabéticamente en `lib.rs` entre `session_builder` y `storage` | ✅ | `lib.rs:10`: `mod state_machine;` ubicado correctamente entre `session_builder` (línea 9) y `storage` (línea 11). El listado total de módulos respeta orden alfabético estricto (líneas 1-12). |
| 2 | Comentario de cabecera con D4/D8/D1/D14/R12 + tabla 3×8 | ✅ | `state_machine.rs:1-17`: declara los cinco constraints en líneas 5-6 ("D4, D8, D1, D14") y la mención R12 en línea 4. Tabla comparativa de **tres columnas** (`pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs`) y **ocho dimensiones** (Propósito, Input, Output, Acceso BD, Decide acciones, Persistencia, Estado interno, Determinismo) — verificada línea por línea. |
| 3 | `StateMachineConfig` ortogonal a `TrustConfig` | ✅ | `state_machine.rs:60-77`: cuatro campos (`min_patterns: usize`, `threshold_low: f64`, `threshold_high: f64`, `aggregation: AggregationMode`). Cero reuso de los siete campos de `TrustConfig` (`tier_low_max`, `tier_high_min`, `half_life_days`, `frequency_saturation`, `w_frequency`, `w_recency`, `w_temporal`). Default `(3, 0.4, 0.75, AggregationMode::Max)` coherente con TS-2-003 §"Contrato del Módulo". |
| 4 | Dirección de dependencias D4 — sin imports prohibidos en `state_machine.rs`; sin imports recíprocos en `pattern_detector.rs` / `trust_scorer.rs` | ✅ | `state_machine.rs:19-21`: únicos imports producción son `crate::trust_scorer::TrustScore` (tipo de dato — input puro autorizado por TS-2-003 §"Contrato del Módulo"), `rusqlite::Connection`, `serde`. **Cero** ocurrencias de `use crate::pattern_detector` ni `use crate::trust_scorer::score_patterns`. Grep recíproco confirmado: `pattern_detector.rs` 0 ocurrencias del literal `state_machine`; `trust_scorer.rs` 2 ocurrencias del literal solo en comentarios documentales R12 (líneas 5 y 11), 0 en `use`. Test estructural `test_no_action_api_for_external_modules` (`state_machine.rs:644-681`) blinda los tokens prohibidos. |
| 5 | `Trusted → Autonomous` solo con `EnableAutonomous { confirmed: true }` desde `Trusted` | ✅ | `state_machine.rs:217-229` (rama `EnableAutonomous` de `apply_user_action`): valida `confirmed == true` (devuelve `ConfirmationRequired` en otro caso) y `current == Trusted` (devuelve `InvalidTransitionFromState(current)` en otro caso). Test `test_trusted_to_autonomous_requires_explicit_action` (`state_machine.rs:548-611`) cubre los **cuatro casos** exigidos: sin acción → permanece Trusted, confirmada → Autonomous con `last_transition_at = NOW`, sin confirmar → `ConfirmationRequired`, desde Observing → `InvalidTransitionFromState(Observing)`. Sin path automático: rama `Trusted` del tick automático devuelve `current` (línea 193). |
| 6 | `Learning → Trusted` con doble condición `aggregate > threshold_high && !user_blocked` | ✅ | `state_machine.rs:186-192`: literal `if aggregate > config.threshold_high && !user_blocked(scores)`. Helper `user_blocked()` aislado en líneas 339-341 con TODO(T-2-004) y justificación contractual. La sustitución por la implementación real de T-2-004 será una sola edición mecánica del cuerpo del helper. |
| 7 | Reset → Observing desde cualquier estado con `last_transition_at = now_unix` | ✅ | `state_machine.rs:212-216` (rama `Reset` de `apply_user_action`): `Ok(build_state(Observing, now_unix, active_patterns_count))`. Test `test_reset_from_each_state` (`state_machine.rs:613-642`) itera los cuatro estados origen (Observing/Learning/Trusted/Autonomous) y verifica `current_state == Observing` y `last_transition_at == NOW` en cada caso. |
| 8 | Sin downgrade automático (postura opción b) | ✅ | `state_machine.rs:178-194`: rama `Learning` solo promociona o se mantiene; ramas `Trusted | Autonomous` devuelven `current` en tick automático. Test `test_no_auto_downgrade_from_learning` (`state_machine.rs:795-818`) blinda con tres `TrustScore` con `trust_score = 0.1` (muy por debajo de `threshold_low = 0.4`) y verifica `result.current_state == Learning`. La única vía de bajada es `UserAction::Reset`. |
| 9 | Determinismo bit-exacto (D8) | ✅ | `evaluate_transition` (líneas 158-203) sin RNG, sin `SystemTime::now()` interno, sin LLM. `now_unix` recibido por parámetro. `aggregate_trust` (líneas 292-301) usa `f64::NEG_INFINITY` como centinela y `f64::max` con iteración estable `scores.iter().fold(...)`. Test `test_determinism_bit_exact` (`state_machine.rs:683-717`) verifica `current_state`, `last_transition_at`, `active_patterns_count`, `available_transitions.len()`. |
| 10 | Schema singleton + migración idempotente; sin persistir `trust_score` ni `stability_score` | ✅ | `ensure_schema` (`state_machine.rs:348-364`): `CREATE TABLE IF NOT EXISTS trust_state` con `id INTEGER PRIMARY KEY CHECK (id = 1)`, `current_state TEXT NOT NULL CHECK (... IN ('Observing', 'Learning', 'Trusted', 'Autonomous'))`, `last_transition_at INTEGER NOT NULL`, `updated_at INTEGER NOT NULL`. Inicialización `INSERT OR IGNORE INTO trust_state (id, current_state, last_transition_at, updated_at) VALUES (1, 'Observing', ?1, ?1)` con `now_unix` ligado. **Cero** columnas `trust_score` o `stability_score`. Idempotencia: `CREATE TABLE IF NOT EXISTS` + `INSERT OR IGNORE` ejecutados en cada llamada a comando T-2-003. |
| 11 | Estado inicial `Observing` al primer arranque | ✅ | Test `test_initial_state_is_observing` (`state_machine.rs:470-477`): conexión en memoria → `ensure_schema(&conn, NOW)` → `load_state(&conn)` devuelve `(Observing, NOW)`. Coherente con la decisión de inicializar la fila singleton en `ensure_schema`, no en `load_state`. |
| 12 | Tres comandos Tauri + `TrustStateView` + registro en `invoke_handler!` | ✅ | `commands.rs:266-285`: `get_trust_state(state) -> Result<TrustStateView, String>`, `reset_trust_state(state) -> Result<TrustStateView, String>`, `enable_autonomous_mode(state, confirmed: bool) -> Result<TrustStateView, String>`. Cadena canónica encapsulada en helper privado `apply_trust_action` (líneas 287-324). Registro en `lib.rs:75-77` (los tres comandos en bloque contiguo, tras `clear_all_resources`). `TrustStateView` declarado en `state_machine.rs:130-136` con `impl From<TrustState>` (líneas 138-147). |
| 13 | Tests sin regresiones (target ≥ 43) | ✅ | **45 tests / 44 passed / 0 failed / 1 ignored**. Re-verificado por el revisor en este pase con `cargo test`. Los 33 tests previos (24 de Fase 1 + 9 de Trust Scorer) sin regresión. 12 nuevos en `state_machine.rs` (10 obligatorios + 2 recomendados). El único `ignored` es el #4 con justificación documentada (`#[ignore = "T-2-004 unblocks: requires is_blocked flag on TrustScore (TS-2-002 closed sin él). HO-013 prohíbe modificar trust_scorer.rs en T-2-003."]`). HO-013 §"Test #4" acepta esta alternativa explícitamente. |
| 14 | `npx tsc --noEmit` limpio | ✅ | Re-verificado por el revisor: salida vacía. Bloque T-2-003 en `src/types.ts:84-99` correcto: `TrustStateEnum` (union literal), `Transition` (interface), `TrustStateView` (interface) con campos en `snake_case` coherentes con la serialización Rust. Sin `ConfidenceTier` (correctamente diferido a T-2-004 — coherente con HO-013 §5). |

---

## Observaciones De Diseño Relevantes

### O.1 — Helper `apply_trust_action` privado en `commands.rs`

Los tres comandos Tauri delegan en un helper privado
`apply_trust_action(state, user_action: Option<UserAction>)`
(`commands.rs:287-324`) que materializa la cadena canónica de TS-2-003
§"Cadena de invocación canónica" en una sola implementación. Esto evita
triplicar el bloque `ensure_schema → load_state → detect_patterns →
score_patterns → evaluate_transition → save_state` y mantiene un único punto
de auditoría D4.

Decisión arquitectónicamente correcta: refuerza simultáneamente D4 (la cadena
existe **exclusivamente** dentro de `commands.rs`, no se filtra a otros
módulos), reduce superficie de error en mantenimiento, y deja el contrato
público (`get_trust_state`, `reset_trust_state`, `enable_autonomous_mode`)
intacto frente a refactorizaciones internas.

### O.2 — `TrustStateView` como wrapper estable

`TrustStateView` (`state_machine.rs:130-136`) es estructuralmente idéntico a
`TrustState` y se construye vía `impl From<TrustState>` (líneas 138-147). El
doc comment en línea 126-129 declara explícitamente la motivación: "preserva
la libertad de ampliar `TrustState` con campos internos en el futuro sin
romper la superficie consumida por T-2-004". Patrón coherente con el
desacoplamiento entre representación interna (`TrustState`, posiblemente con
campos `pub(crate)` futuros) y contrato externo (`TrustStateView`,
serializable y estable).

Para T-2-004: importar y consumir `TrustStateView` directamente; nunca
asumir igualdad estructural con `TrustState` por construcción actual.

### O.3 — `available_transitions_from(Observing)` incluye `Observing → Observing`

`state_machine.rs:244-255` declara dos transiciones desde `Observing`:
- `Observing → Learning` con `requires_user_action: false` (promoción
  automática);
- `Observing → Observing` con `requires_user_action: true`.

La segunda parece tautológica pero es semánticamente correcta: representa la
acción "Reset" disponible incluso desde Observing (idempotente — refuerza
`last_transition_at = now_unix`). Permite a T-2-004 mostrar siempre el botón
"Resetear confianza" sin inspeccionar el estado actual. La asimetría con la
ausencia de un análogo en estados terminales se justifica por el comportamiento
contractual de `UserAction::Reset` (definido como "desde cualquier estado a
Observing", sin discriminación de origen).

Decisión menor pero coherente con la UX del Privacy Dashboard.

### O.4 — Verificación recíproca D4 (grep negativo)

Re-verificado por el revisor (Grep + lectura directa) durante esta AR:

```
state_machine en pattern_detector.rs: 0 ocurrencias.
state_machine en trust_scorer.rs   : 2 ocurrencias, ambas en comentarios
                                     documentales R12 (líneas 5 y 11).
                                     0 ocurrencias en `use` o invocaciones.
```

Y dentro de `state_machine.rs` (sección de producción, antes del primer
`#[cfg(test)]`):

```
use crate::pattern_detector       : 0 ocurrencias.
use crate::trust_scorer::score_p* : 0 ocurrencias.
score_patterns(                   : 0 ocurrencias.
detect_patterns(                  : 0 ocurrencias.
```

El único `use crate::trust_scorer::TrustScore` (línea 19) consume el tipo de
dato como **input puro** — autorizado por TS-2-003 §"Contrato del Módulo" y
por AR-2-004 §"Compatibilidad con T-2-003" donde se declaró que `TrustScore`
es input suficiente.

El test estructural `test_no_action_api_for_external_modules`
(`state_machine.rs:644-681`) blinda los mismos tokens dentro del módulo,
duplicando la garantía vía `include_str!` + split por `#[cfg(test)]`. Patrón
ya validado en AR-2-004 §O.3 para `trust_scorer.rs`; reaplicado correctamente
aquí.

### O.5 — `save_state` con UPSERT y preservación de `last_transition_at`

`save_state` (`state_machine.rs:398-430`) implementa la lógica de TS-2-003
§"Persistencia → save_state": si el estado **no cambió** respecto a la fila
previa, ejecuta solo `UPDATE trust_state SET updated_at = ?1 WHERE id = 1`
(actualiza únicamente `updated_at`); si el estado **cambió**, ejecuta `INSERT
... ON CONFLICT(id) DO UPDATE SET ...` con los tres campos sincronizados.

Esto preserva la propiedad contractual exigida en TS-2-003: `last_transition_at`
sólo se actualiza cuando hay transición efectiva. Coherente con el comentario
de `evaluate_transition` (`state_machine.rs:196`):
`let new_last_ts = if next == current { last_transition_at } else { now_unix };`

Decisión correcta y verificada por `test_persistence_round_trip`
(`state_machine.rs:719-732`).

### O.6 — `load_state` defensivo con `(Observing, 0)` (D-2 documentada)

Ver §"Verificación de Desviaciones — D-2" abajo.

### O.7 — Sobrecumplimiento de tests (12 vs 10 mínimos)

TS-2-003 exige 10 tests obligatorios; HO-013 §"Test #4" acepta uno
`#[ignore]` con justificación. La implementación incluye los **10
obligatorios + 2 recomendados** (`test_observing_blocked_when_below_min_patterns`,
`test_no_auto_downgrade_from_learning`), totalizando 12 tests propios del
módulo de los cuales 11 ejecutan y 1 está `#[ignore]` con justificación.

Decisión arquitectónicamente positiva (paralela a la observada en AR-2-004
§O.1): blinda más superficies sin coste operativo. Conviene registrarlo para
que futuras revisiones no asuman que el mínimo es 12.

---

## Verificación de Desviaciones Documentadas

HO-014 §"Desviaciones documentadas" declara tres desviaciones menores. Cada
una se verifica aquí contra los textos normativos (TS-2-003, HO-013, AR-2-003,
AR-2-004) y se confirma su aceptabilidad arquitectónica.

### D-1 — `storage.rs` no modificado (salvo accesor `pub(crate) fn conn()`)

**Hechos:** el delta en `storage.rs` (verificado por `git diff` en este pase)
es la adición de un único método público de módulo:

```rust
/// Read-only access to the underlying connection. Used by modules that
/// need to issue their own SELECTs (e.g. pattern_detector).
pub(crate) fn conn(&self) -> &Connection {
    &self.conn
}
```

La creación e inicialización de la tabla `trust_state` se encapsula
**completamente** en `state_machine::ensure_schema` (líneas 348-364) y se
invoca desde `commands.rs::apply_trust_action` (línea 298) antes de cada uso.

**Conformidad con HO-013:** HO-013 §3 "Decisión operativa de integración"
declara textualmente: "Ambas ubicaciones son aceptables siempre que la
idempotencia se preserve y la tabla se cree antes del primer `load_state`." y
recomienda exactamente la elección tomada: "mantener `ensure_schema` en
`state_machine.rs` (módulo dueño del schema) y llamarlo desde `commands.rs` en
cada comando que toque la State Machine".

**Conformidad con TS-2-003:** TS-2-003 §"Cadena de invocación canónica" lista
`ensure_schema` como paso 2 del pseudocódigo, antes de `load_state`. La
implementación lo respeta (`commands.rs:298-299`).

**Idempotencia:** `CREATE TABLE IF NOT EXISTS` + `INSERT OR IGNORE` se
ejecutan en cada llamada a un comando Tauri T-2-003. Las bases de datos
pre-T-2-003 (sin la tabla) reciben la creación; las que ya tienen la tabla
con la fila singleton reciben no-op.

**Veredicto:** desviación aceptada. El accesor `pub(crate) fn conn()` es una
adición mínima coherente con el patrón ya usado por `pattern_detector` y
estrictamente más restrictiva que `pub` (visibilidad limitada al crate).

### D-2 — `load_state` defensivo devuelve `(Observing, 0)`

**Hechos:** ante `rusqlite::Error::QueryReturnedNoRows` (caso defensivo
inalcanzable en uso normal), `load_state` (`state_machine.rs:374-392`)
devuelve `(TrustStateEnum::Observing, 0)` en lugar de `(Observing, now_unix)`.

**Razón documentada en código** (doc comment líneas 366-373): "Devolvemos `0`
(no `now_unix`) porque la firma no recibe el reloj y mantener la función
libre de `SystemTime::now()` preserva D8 transitivamente; la responsabilidad
de inicializar la fila con `now_unix` es de `ensure_schema`."

**Conformidad con TS-2-003:** TS-2-003 §"Contrato del Módulo" declara la firma
`pub(crate) fn load_state(conn: &Connection) -> Result<(TrustStateEnum, i64),
StateMachineError>` — sin parámetro `now_unix`. Modificar la firma para
aceptar `now_unix` rompería el contrato declarado y exigiría addendum a
TS-2-003.

**Conformidad con D8:** la elección preserva D8 (sin `SystemTime::now()`
interno en `load_state`). Pasar `now_unix` desde `commands.rs` también
preservaría D8, pero rompería el contrato.

**Inalcanzabilidad práctica:** `commands.rs::apply_trust_action` siempre
invoca `ensure_schema` antes de `load_state` (líneas 298-299). El test
`test_initial_state_is_observing` (`state_machine.rs:470-477`) verifica que
tras `ensure_schema` con `NOW`, `load_state` devuelve `(Observing, NOW)` —
nunca `0`. La rama defensiva existe solo para evitar un crash en caso de
inversión accidental del orden de llamada en código futuro.

**Veredicto:** desviación aceptada. Es una decisión defensiva conservadora
que preserva el contrato y la propiedad D8. La asimetría
"`ensure_schema` inicializa con `now_unix`, pero `load_state` defensivo
devuelve 0" se documenta en el doc comment y no afecta ningún flujo
observable.

### D-3 — `pattern_detector::detect_patterns` invocado con 2 argumentos

**Hechos:** `commands.rs::apply_trust_action` (línea 303) llama
`pattern_detector::detect_patterns(conn, &PatternConfig::default())` con dos
argumentos. El pseudocódigo de TS-2-003 §"Cadena de invocación canónica"
(línea 262) ilustra la cadena con tres argumentos
`detect_patterns(conn, &PatternConfig::default(), now_unix)`.

**Razón documentada en código** (`commands.rs:300-302`):
```rust
// pattern_detector::detect_patterns(conn, &PatternConfig) — firma sin
// now_unix (TS-2-001 cerrado así); coexiste con score_patterns que sí lo
// recibe explícitamente.
```

**Conformidad con AR-2-003 / HO-013:** TS-2-001 cerró la firma de
`detect_patterns` con dos parámetros (`pattern_detector.rs:123-126` —
`detect_patterns(conn: &Connection, config: &PatternConfig)`). El módulo
usa `SystemTime::now()` internamente, lo cual fue aceptado en AR-2-003.
HO-013 §"Restricciones específicas" prohíbe modificar `pattern_detector.rs`:
"su contrato está cerrado por TS-2-001 / TS-2-002 y aprobado por AR-2-003 /
AR-2-004".

**Naturaleza del pseudocódigo TS-2-003:** ilustrativo, no normativo respecto
a la firma exacta de un módulo cuyo contrato ya estaba cerrado. La cadena
canónica conceptual (`detect_patterns → score_patterns → evaluate_transition`)
se preserva; lo único que difiere es la firma de un único parámetro de un
módulo previamente aprobado.

**Impacto sobre constraints:**
- **D4:** la cadena `detect_patterns → score_patterns → evaluate_transition`
  se compone exclusivamente en `commands.rs` (única superficie autorizada),
  sin imports cruzados ni invocaciones recíprocas. Verificado por grep en
  O.4. Sin afectación.
- **D8 de la State Machine:** el determinismo de `state_machine.rs` se
  preserva bit-a-bit. El no-determinismo introducido por `SystemTime::now()`
  interno de `pattern_detector` ya estaba aceptado en AR-2-003 y no se
  propaga al output de `state_machine::evaluate_transition` (que recibe
  `now_unix` por parámetro). Sin afectación.
- **D1:** sin afectación (la firma no toca campos sensibles).

**Veredicto:** desviación aceptada. El pseudocódigo de TS-2-003 era
ilustrativo y la firma real del módulo ya cerrado es la fuente de verdad.
La discrepancia se documenta en el comentario inline del call site, lo cual
permitirá a futuras auditorías reconciliar pseudocódigo y código sin
reconstrucción.

---

## Constraints D1 / D4 / D5 / D8 / D14 / R12 — Verificación final

| Constraint | Verificación | Estado |
|---|---|---|
| **D1** — sin `url`/`title` en claro | El módulo no accede a SQLCipher para leer recursos. Schema `trust_state` solo contiene `id`, `current_state`, `last_transition_at`, `updated_at`. Ningún struct público (`TrustState`, `TrustStateView`, `Transition`, `StateMachineConfig`, `UserAction`, `StateMachineError`) contiene `url`, `title`, `link`, `href`, `bookmark_url` ni variantes. Inspección textual confirma cero ocurrencias en el módulo. La cadena `detect_patterns → score_patterns` (en `commands.rs::apply_trust_action`) opera sobre tipos cuyas auditorías previas (AR-2-003 y AR-2-004) ya certificaron ausencia de `url`/`title`. | ✅ |
| **D4** — autoridad exclusiva de la State Machine | Única superficie pública decisional: `evaluate_transition`. Sin métodos `recommend_*`, `force_*`, `promote_*`, `should_*`, `apply_action`, `decide_*`. Dirección de dependencias correcta (ver O.4): cero imports prohibidos en `state_machine.rs`; cero imports recíprocos en `pattern_detector.rs` / `trust_scorer.rs`. Test estructural `test_no_action_api_for_external_modules` blinda los tokens prohibidos. Cadena canónica encapsulada exclusivamente en `commands.rs::apply_trust_action`. | ✅ |
| **D5** — transitivo (no aplica) | La State Machine no calcula `stability_score`. Consume `trust_score` y `confidence_tier` por referencia (campos de `TrustScore`) y no recalcula nada de TS-2-002. Sin lógica de entropía ni slot concentration en este módulo. | ✅ (transitivo) |
| **D8** — determinismo bit-exacto | `evaluate_transition` (líneas 158-203): sin RNG, sin `SystemTime::now()` interno, sin LLM. `now_unix` por parámetro. Iteración estable en `aggregate_trust` con `f64::NEG_INFINITY` como centinela y `f64::max`. `load_state` defensivo devuelve `0` en lugar de invocar el reloj (preserva D8 transitivamente — D-2 documentada). Test `test_determinism_bit_exact` verifica con cuatro campos. | ✅ |
| **D14** — Privacy Dashboard bloquea cierre Fase 2 | Contrato `TrustStateView` (líneas 130-136) estable y consumible por T-2-004 sin modificación. Tres comandos Tauri completos y registrados (`get_trust_state`, `reset_trust_state`, `enable_autonomous_mode`). Tipos TypeScript (`TrustStateEnum`, `Transition`, `TrustStateView`) en `src/types.ts:84-99`. T-2-004 puede consumir el contrato sin edición de `state_machine.rs`. | ✅ |
| **R12** — distinción de módulos | Comentario de cabecera con tabla 3×8 reproducida textualmente (líneas 1-17). Sin imports cruzados productivos (línea 19 importa solo el tipo `TrustScore` por contrato; línea 456 importa `ConfidenceTier` solo en el bloque de tests). El módulo no reutiliza algoritmos de `pattern_detector` ni de `trust_scorer`; solo consume sus tipos como input. | ✅ |

---

## Compatibilidad con T-2-004 (Privacy Dashboard completo)

T-2-004 expandirá `PrivacyDashboard.tsx` con tres secciones nuevas (patrones,
estado de confianza, FS Watcher si implementado) y dependerá del contrato
declarado por T-2-003. Verifico campo a campo que `TrustStateView` y los tres
comandos Tauri proveen los inputs necesarios:

| Necesidad de T-2-004 | Superficie consumida | Cómo se usa |
|---|---|---|
| Mostrar el estado actual ("Observando", "Aprendiendo", "Confiando", "Autónomo") | `TrustStateView.current_state: TrustStateEnum` | Switch sobre las cuatro variantes; etiqueta UI traducible. |
| Mostrar tiempo en estado | `TrustStateView.last_transition_at: number` (Unix seconds) | Diff frente a `Date.now() / 1000`; formateo "hace X días/horas". |
| Mostrar conteo de patrones activos | `TrustStateView.active_patterns_count: number` | Render directo (e.g. "Patrones activos: 5"). |
| Habilitar/deshabilitar el botón "Activar preparación automática" según estado | `TrustStateView.current_state === 'Trusted'` y/o inspección de `available_transitions` | Botón visible y habilitado solo cuando `current_state === 'Trusted'`; al pulsar mostrar diálogo de confirmación; al confirmar invocar `enable_autonomous_mode(confirmed: true)`. |
| Resetear confianza desde cualquier estado | comando `reset_trust_state` | Botón siempre visible en la sección "Estado de confianza"; al pulsar invoca el comando y refresca la vista con la respuesta. |
| Refrescar el estado al abrir el dashboard | comando `get_trust_state` | Al montar el componente; el comando recompone la cadena canónica (detect → score → evaluate → save) y devuelve el estado actualizado. |
| Manejar errores de confirmación | error string `"confirmation required"` desde `enable_autonomous_mode(confirmed: false)` | Frontend muestra mensaje de error y solicita confirmación explícita antes de re-invocar con `confirmed: true`. |
| Manejar errores de transición inválida | error string `"invalid transition from <state>"` desde `enable_autonomous_mode(...)` | Frontend muestra mensaje informativo (no debería ocurrir en flujo normal porque el botón está gated por `current_state === 'Trusted'`). |

**Confirmación explícita:** `TrustStateView` y los tres comandos Tauri son
inputs suficientes para T-2-004. **No se requieren modificaciones** de
`state_machine.rs`, `commands.rs` ni `src/types.ts` para soportar el Privacy
Dashboard completo dentro del scope de TS-2-003.

**Pendientes para T-2-004 (no afectan AR-2-005):** la sección "Patrones
detectados" del dashboard requerirá nuevos comandos Tauri (`get_detected_patterns`,
`block_pattern`, `unblock_pattern`) y un nuevo tipo `PatternSummary` en
`src/types.ts`. Estos no son scope de T-2-003 — son responsabilidad de
T-2-004. La materialización del flag `is_blocked` (vía addendum a TS-2-002 o
tabla auxiliar `pattern_blocks`) decidida en T-2-004 también activará el
test #4 (`test_learning_to_trusted_blocked_when_user_blocked`) actualmente
`#[ignore]`; HO de cierre de T-2-004 deberá reportar la reactivación.

---

## Ítems pendientes heredados (sin cambios respecto a HO-014)

Reproducidos para trazabilidad. Ninguno bloquea esta AR; todos se delegan
correctamente a T-2-004 o Fase 3.

- **`is_blocked` en `TrustScore`:** materialización diferida a T-2-004. Helper
  `user_blocked()` aislado en `state_machine.rs:339-341` con `TODO(T-2-004)`.
  Test #4 `#[ignore]` con justificación. Confirmado en HO-014 §"Ítems
  pendientes" y verificado en código.
- **`AggregationMode::Median` y `AggregationMode::Mean`:** variantes
  reservadas; `validate_config` (`state_machine.rs:323-327`) devuelve
  `InvalidConfig("aggregation mode not implemented in T-2-003 baseline")`.
  Test `test_invalid_config` blinda los cuatro casos
  (`threshold_low >= threshold_high`, `min_patterns == 0`,
  `aggregation = Median`, `aggregation = Mean`). Sin compromiso de
  implementación en T-2-003.
- **Hook de Explainability Log:** TS-2-003 §"Cualquier estado → Observing
  (reset)" declara el hook conceptual; la implementación se difiere a Fase 3
  sin compromiso de schema en T-2-003.
- **Política de downgrade automático:** postura opción (b) confirmada
  (`test_no_auto_downgrade_from_learning`). Hook de change request para
  Fase 3 declarado en TS-2-003 §"Hook de change request".

---

## Riesgos conocidos heredados (sin cambios)

| ID | Riesgo | Mitigación verificada |
|---|---|---|
| RK-2-003-1 | `is_blocked` no existe aún | Helper `user_blocked()` aislado, devuelve `false` por defecto, marcado con `TODO(T-2-004)`. Verificado en `state_machine.rs:331-341`. |
| RK-2-003-2 | Política de downgrade (opción b) — usuarios atrapados en `Trusted` | Hook de change request declarado para Fase 3 (TS-2-003 §"Hook de change request"). El path de salida actual es `UserAction::Reset` desde el frontend. |
| RK-2-003-3 | `AggregationMode` con variantes reservadas | `validate_config` devuelve `InvalidConfig` para `Median`/`Mean` con mensaje explícito. Verificado en `state_machine.rs:323-327` y test `test_invalid_config`. |
| RK-2-003-4 | Schema en bases pre-T-2-003 | `ensure_schema` invocado en cada comando Tauri T-2-003 desde `commands.rs::apply_trust_action` (línea 298). Idempotencia preservada por `CREATE TABLE IF NOT EXISTS` + `INSERT OR IGNORE`. |
| RK-2-003-5 | Comentario R12 podría diluirse | Reproducido textualmente en `state_machine.rs:1-17` (verificado por inspección directa). Tabla 3×8 íntegra. |

---

## Correcciones

**Ninguna.** Implementación apta para producción dentro del scope de Fase 2.

Las tres desviaciones documentadas (D-1, D-2, D-3) son arquitectónicamente
aceptables, todas autorizadas por HO-013 o forzadas por contratos cerrados de
TS-2-001 / TS-2-002. Cada una está documentada en código (doc comments o
comentarios inline) para futuras auditorías.

---

## Siguiente Agente Responsable

**Orchestrator** — emisión de `HO-015-phase-2-ts-2-004-kickoff.md` solicitando
al Technical Architect el drafting de `TS-2-004-privacy-dashboard.md` (o
nombre equivalente) que materialice el Privacy Dashboard completo según
CLAUDE.md §"T-2-004 — Privacy Dashboard completo" y backlog de Fase 2.

D14 queda formalmente desbloqueado con esta aprobación: T-2-004 puede entrar
en ciclo de spec drafting.

T-2-003 queda **cerrado**. La cadena de tareas activas en Fase 2 pasa a:

```
T-2-001  Pattern Detector              ✅ CERRADO (AR-2-003)
T-2-002  Trust Scorer                  ✅ CERRADO (AR-2-004)
T-2-003  State Machine                 ✅ CERRADO (AR-2-005 — este documento)
T-2-004  Privacy Dashboard completo    → SPEC DRAFTING (próximo HO)
T-2-000  FS Watcher                    → APROBADO; implementación autorizada
                                          en paralelo a T-2-004
```

---

## Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Revisado | `src-tauri/src/state_machine.rs` (819 líneas) | APROBADO |
| Revisado | `src-tauri/src/lib.rs` (`mod state_machine;` línea 10; tres comandos en `invoke_handler!` líneas 75-77) | APROBADO |
| Revisado | `src-tauri/src/commands.rs` (líneas 260-324) | APROBADO |
| Revisado | `src-tauri/src/storage.rs` (delta: accesor `pub(crate) fn conn()`) | APROBADO |
| Revisado | `src/types.ts` (líneas 84-99: bloque T-2-003) | APROBADO |
| Cerrado | T-2-003 (State Machine — implementación) | COMPLETADO |
| Desbloqueado | T-2-004 (Privacy Dashboard completo — D14) | LISTO PARA SPEC |
| Creado | `operations/architecture-reviews/AR-2-005-state-machine-review.md` | este documento |

---

## Firma

approved_by: Technical Architect
approval_date: 2026-04-27
notes: Implementación de state_machine.rs (819 líneas) satisface los 14 criterios de aprobación de TS-2-003 sin observaciones bloqueantes. Las tres desviaciones documentadas en HO-014 (D-1 storage no modificado salvo accesor `pub(crate) fn conn()`, D-2 `load_state` defensivo devuelve `(Observing, 0)`, D-3 `detect_patterns` con dos argumentos) son arquitectónicamente aceptables: D-1 está explícitamente autorizada por HO-013 §3 y es la opción recomendada; D-2 preserva el contrato declarado de TS-2-003 §"Contrato del Módulo" y la propiedad D8 transitiva; D-3 respeta el cierre de TS-2-001 (firma cerrada con dos parámetros). Constraints D1, D4, D5 (transitivo), D8, D14 y R12 verificados. Tests: 45 ejecutados, 44 passed / 0 failed / 1 ignored (target ≥ 43). El único `ignored` (test #4 `test_learning_to_trusted_blocked_when_user_blocked`) tiene justificación documentada y será reactivado en T-2-004 cuando se materialice `is_blocked`. TypeScript: limpio (`npx tsc --noEmit` sin output). Contrato `TrustStateView` confirmado como input suficiente para T-2-004 sin modificación de interfaz. Sobrecumplimiento de tests (12 vs 10 obligatorios). Verificación recíproca D4 por grep negativo: cero `use crate::state_machine` en `pattern_detector.rs` y `trust_scorer.rs` (salvo dos comentarios documentales R12 en `trust_scorer.rs:5,11` que son esperados); cero `use crate::pattern_detector` y cero `score_patterns(`/`detect_patterns(` en la sección de producción de `state_machine.rs`. Se autoriza al Orchestrator la emisión de HO de kickoff de T-2-004 (drafting de spec por Technical Architect). D14 desbloqueado.
