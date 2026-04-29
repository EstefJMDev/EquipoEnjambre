# Revisión Arquitectónica — Trust Scorer (T-2-002)

document_id: AR-2-004
owner_agent: Technical Architect
phase: 2
date: 2026-04-27
status: APROBADO — sin correcciones; T-2-002 cerrado, T-2-003 desbloqueado
documents_reviewed:
  - operations/task-specs/TS-2-002-trust-scorer.md
  - src-tauri/src/trust_scorer.rs (módulo nuevo, 429 líneas)
  - src-tauri/src/lib.rs (`mod trust_scorer;` registrado en línea 11)
reference_normativo:
  - Project-docs/decisions-log.md (D1, D4, D5, D8, R12)
  - operations/backlogs/backlog-phase-2.md (T-2-002 acceptance criteria)
  - operations/handoffs/HO-011-phase-2-ts-2-002-kickoff.md
precede_a: Orchestrator → emisión de HO-012 (kickoff drafting de TS-2-003 — State Machine)

---

## Objetivo De Esta Revisión

Verificar que la implementación de `trust_scorer.rs` satisface los 12 criterios de
aprobación post-implementación de TS-2-002 (líneas 438-452) y confirmar que el
contrato público (`TrustScore`) es input suficiente para alimentar a la State
Machine (T-2-003) sin modificaciones de interfaz. Adicionalmente confirmar el
cumplimiento de los constraints D1, D4, D5, D8 y R12, y la ausencia de
acoplamiento anticipado con `state_machine.rs` (módulo aún inexistente).

Datos confirmados por el implementador (Desktop Tauri Shell Specialist):
- `cargo test` — 33/33 OK (24 previos + 9 nuevos del trust_scorer, sin regresiones)
- `npx tsc --noEmit` limpio

---

## Resultado Global

**APROBADO sin correcciones.** Los 12 criterios están satisfechos. El contrato
de `TrustScore` es directamente consumible por `state_machine.rs` (T-2-003) sin
modificaciones de interfaz.

| # | Criterio TS-2-002 | Resultado | Observación |
|---|---|---|---|
| 1 | `trust_scorer.rs` existe como módulo independiente registrado en `lib.rs` | ✅ | Archivo de 429 líneas en `src-tauri/src/trust_scorer.rs`. `mod trust_scorer;` declarado en `lib.rs` línea 11, alfabéticamente entre `storage` y los módulos condicionales. |
| 2 | Comentario de cabecera con D4, D5, D8, R12 y tabla comparativa Trust Scorer / Pattern Detector / State Machine | ✅ | Líneas 1-18: declara propósito, los cuatro constraints (D1, D4, D5, D8 — D1 incluido por exigencia transversal), y tabla comparativa de tres columnas con ocho dimensiones (Propósito, Input, Output, Acceso BD, Decide acciones, Persistencia, Estado interno). Reproduce la sección R12 obligatoria de TS-2-002 §1. |
| 3 | Sin `use crate::state_machine::*` ni cualquier import de `state_machine` | ✅ | Únicos imports del módulo (líneas 20-21): `use crate::pattern_detector::DetectedPattern;` y `use serde::{Deserialize, Serialize};`. Grep manual confirma cero ocurrencias del literal `state_machine` en código (solo aparece en comentario de cabecera como referencia documental R12). |
| 4 | Sin funciones públicas con substrings prohibidos (D4) | ✅ | Inspección manual de las API `pub`: `score_patterns` (única función pública), `TrustConfig`, `ConfidenceTier`, `TrustScore`, `TrustScorerError` y sus impls de `Default`/`Display`/`Error`. Ninguna contiene `recommend`, `decide`, `promote`, `transition`, `apply_action`, `apply(`, ni `should_`. Test estructural `test_no_action_decision_api` (líneas 345-368) lo blinda mediante `include_str!` + split por `#[cfg(test)]` — ver O.3. |
| 5 | `stability_score` acotado en [0.0, 1.0] verificado por `test_scores_in_range` | ✅ | Implementación en `compute_stability_score` (líneas 174-191) aplica clamp final `raw.max(0.0).min(1.0)` (línea 190). Test `test_scores_in_range` (líneas 308-342) ejerce 4×3×4×6 = 288 patrones con frecuencias, antigüedades, máscaras DOW y signatures de 1 a 6 categorías; verifica los tres rangos `[0.0, 1.0]` (`trust_score`, `stability_score`, `recency_weight`). |
| 6 | Caso `N == 1` devuelve `stability_score = 1.0` exacto | ✅ | Línea 184-186: rama `if n == 1 { return 1.0; }` antes del cálculo de entropía — evita división por cero (`H_max = log₂(1) = 0`) y asegura el valor exacto sin imprecisión flotante. Test `test_pattern_single_category_max_stability` (líneas 292-305) verifica con `assert_eq!(scores[0].stability_score, 1.0)`. |
| 7 | Umbrales `tier_low_max`, `tier_high_min`, `half_life_days`, `frequency_saturation`, pesos `w_*` configurables vía `TrustConfig` con `Default` | ✅ | `TrustConfig` (líneas 25-34) declara los siete campos exigidos. `impl Default` (líneas 36-48) provee los valores prescritos (0.4 / 0.75 / 14.0 / 12.0 / 0.5 / 0.3 / 0.2). Test `test_confidence_tier_thresholds_configurable` (líneas 405-428) demuestra que la asignación de `confidence_tier` cambia con `TrustConfig` distintos sobre el mismo patrón. |
| 8 | Determinismo: dos llamadas con mismo `(patterns, config, now_unix)` producen output bit-exacto | ✅ | Sin RNG, sin `SystemTime::now()` interno, sin IO. `now_unix` se pasa por parámetro. Iteración estable `patterns.iter().map(...)` (líneas 95-98) preserva orden de entrada. Test `test_determinism_bit_exact` (líneas 371-395) verifica con `to_bits()` los tres campos `f64` y comparación directa de `pattern_id` y `confidence_tier`. |
| 9 | `score_patterns` valida `TrustConfig` con `TrustScorerError::InvalidConfig` | ✅ | `validate_config` (líneas 102-128) cubre las cuatro validaciones exigidas: suma de pesos con tolerancia `WEIGHTS_TOLERANCE = 1e-6`, `tier_low_max >= tier_high_min`, `half_life_days <= 0.0`, `frequency_saturation <= 0.0`. Mensajes de error descriptivos e impl de `Display`/`Error`. Test `test_invalid_config_weights` (líneas 398-402) ejerce el camino de error. |
| 10 | Sin acceso a SQLCipher (sin `use rusqlite`, sin `Connection`, sin queries) | ✅ | Grep manual: cero ocurrencias de `rusqlite`, `Connection`, `SELECT`, `INSERT`, `UPDATE` en el archivo. El módulo solo recibe `&[DetectedPattern]` por referencia; refuerza simultáneamente D1, D4 y R12 (TS-2-002 §"Acceso a Datos"). |
| 11 | Los 6 tests obligatorios pasan; los 24 tests existentes no tienen regresiones | ✅ | Confirmado 33/33 OK (24 previos + 9 nuevos). Los seis obligatorios están presentes: `test_pattern_frequent_recent_high_score`, `test_pattern_frequent_old_lower_score`, `test_pattern_dispersed_categories_low_stability`, `test_pattern_single_category_max_stability`, `test_scores_in_range`, `test_no_action_decision_api`. Tres adicionales recomendados también incluidos — ver O.1. |
| 12 | `npx tsc --noEmit` limpio si se añade comando Tauri; contrato `TrustScore` coherente con inputs esperados por T-2-003 | ✅ | `npx tsc --noEmit` limpio (no se añadió comando Tauri en este sprint, coherente con persistencia diferida — ver O.5). Compatibilidad campo a campo con T-2-003 verificada en sección "Compatibilidad con T-2-003" abajo. |

---

## Observaciones De Diseño Relevantes

### O.1 — Sobrecumplimiento de tests (9 vs 6 mínimos)

TS-2-002 exige seis tests obligatorios y permite tres adicionales recomendados.
La implementación incluye los nueve. Los tres opcionales —
`test_determinism_bit_exact` (con verificación `to_bits()` para garantía de
igualdad bit-exacta de `f64`), `test_invalid_config_weights`,
`test_confidence_tier_thresholds_configurable` — están todos presentes.

Decisión arquitectónicamente positiva: blinda más superficies sin coste
operativo. Conviene registrarlo para que futuras revisiones no asuman que el
mínimo es nueve.

### O.2 — `WEIGHTS_TOLERANCE = 1e-6` constante de módulo

TS-2-002 §"Combinación lineal" prescribe la validación
`(w_frequency + w_recency + w_temporal - 1.0).abs() > 1e-6`. La implementación
materializa `1e-6` como constante de módulo `WEIGHTS_TOLERANCE` (línea 23) en
lugar de literal en línea — facilita auditoría y reuso si el test estructural
quisiera referirla.

`WEIGHTS_TOLERANCE` no se expone en `TrustConfig`, lo cual es coherente con la
TS (no figura como parámetro en el contrato) pero queda como candidato a
parametrizar si Fase 3 introduce calibración de los pesos. Aceptable como está.

### O.3 — Test estructural D4 con split por `#[cfg(test)]`

`test_no_action_decision_api` (líneas 345-368) inspecciona el archivo fuente vía
`include_str!("trust_scorer.rs")` y limita la inspección a la **sección de
producción** mediante `SRC.split("#[cfg(test)]").next()`. Esto evita un falso
positivo: el array de literales prohibidos (`"pub fn recommend"`, etc.) vive
dentro del propio test, y sin la división el test detectaría sus propias
literales y fallaría siempre.

Implementación robusta: el split por `#[cfg(test)]` no produce ambigüedad porque
el módulo solo tiene un bloque de tests (líneas 193-429) y ese atributo no
aparece en ningún otro sitio del archivo. Si en el futuro se añadieran bloques
adicionales `#[cfg(test)]` (e.g. helpers compartidos), el split seguiría tomando
correctamente la sección anterior al primero.

Comentario explicativo en líneas 347-348 documenta el razonamiento — futuras
auditorías no necesitarán reconstruir la intención.

### O.4 — Ordenación de output preserva orden de input

`score_patterns` itera con `patterns.iter().map(...).collect()` (líneas 95-98) —
no hay ordenamiento interno. El output `Vec<TrustScore>` mantiene el orden del
input. Esto refuerza el determinismo (D8) más allá de la igualdad bit-exacta:
también garantiza estabilidad estructural del orden, propiedad útil para
correlación 1:1 con `Vec<DetectedPattern>` por índice (además del `pattern_id`
explícito).

Decisión coherente con la cláusula de TS-2-002 §"Determinismo bit-exacto"
("Iteración sobre `&[DetectedPattern]` en orden de entrada — el output preserva
el orden del input").

### O.5 — Persistencia diferida (decisión TS-2-002)

TS-2-002 §"Decisión de Persistencia" decidió mantener los `TrustScore` en
memoria, recalculables on-demand desde `Vec<DetectedPattern>`. La implementación
lo respeta: no hay schema nuevo en SQLCipher, no hay migración añadida, y no se
expone comando Tauri en este sprint. La integración con `commands.rs` (cadena
`detect_patterns → score_patterns`) se materializará cuando T-2-003 establezca
qué subset de información necesita la State Machine para persistir.

Coherente con la simetría TS-2-001 ↔ TS-2-002 (ambos difieren persistencia
hasta que el consumidor estabilice contrato). No requiere acción en esta
revisión.

---

## Compatibilidad con T-2-003 (State Machine)

State Machine (T-2-003) consumirá `&[TrustScore]` para decidir transiciones de
`Observing → Learning → Trusted` (CLAUDE.md sección T-2-003). Verifico
campo a campo que `TrustScore` proporciona los inputs necesarios:

| Necesidad de State Machine | Campo de TrustScore | Cómo se usa |
|---|---|---|
| Comparación contra `THRESHOLD_LOW` para `Observing → Learning` | `trust_score: f64` | Comparación numérica directa contra umbral configurable de `StateMachineConfig`. |
| Comparación contra `THRESHOLD_HIGH` para `Learning → Trusted` | `trust_score: f64` | Misma fuente; State Machine define `THRESHOLD_HIGH` independientemente del `tier_high_min` de Trust Scorer (los dos umbrales son ortogonales — uno gobierna tiers descriptivos, el otro transiciones de FSM). |
| Tier gating opcional en política de transición | `confidence_tier: ConfidenceTier` | Enum `Low | Medium | High` directamente comparable. La State Machine puede usarlo como gate redundante (e.g. exigir `tier == High` además de `trust_score > THRESHOLD_HIGH`) o ignorarlo. |
| Conteo de patrones activos (`MIN_PATTERNS`) | longitud de `&[TrustScore]` | `slice.len()` o filtrado por `trust_score > THRESHOLD_LOW` antes del conteo, según política. |
| Correlación 1:1 con `DetectedPattern` para auditoría / explicabilidad | `pattern_id: String` (UUID v4) | Clave estable que permite a State Machine asociar una decisión con el patrón concreto que la justificó (sin abrir auditoría completa, que es trabajo de Fase 3). |
| Información secundaria sobre concentración del patrón | `stability_score: f64` | Disponible si la política de transición desea ponderar contra dispersión de categorías; la TS de T-2-003 decidirá si se usa. |
| Decaimiento temporal explícito | `recency_weight: f64` | Expuesto crudo (no compuesto en `trust_score` antes), permite a State Machine inspeccionar el factor por separado si lo requiere. |

**Confirmación explícita:** `TrustScore` es input suficiente para
`state_machine.rs`. No se requieren modificaciones de interfaz en T-2-002 para
soportar T-2-003. Los siete campos disponibles cubren todas las necesidades
declaradas de la State Machine en CLAUDE.md y en el backlog.

Nota para el drafting de TS-2-003: los umbrales `MIN_PATTERNS`,
`THRESHOLD_LOW`, `THRESHOLD_HIGH` deben vivir en `StateMachineConfig` y son
**distintos** de `tier_low_max` / `tier_high_min` de `TrustConfig`. No reutilizar
los nombres ni los valores — son ortogonales por diseño (D4: tiers descriptivos
vs transiciones de autoridad).

---

## Constraints D1 / D4 / D5 / D8 / R12 — Verificación final

| Constraint | Verificación | Estado |
|---|---|---|
| **D1** — solo `domain`/`category` accesibles en claro | El módulo recibe `&[DetectedPattern]` (cuyo contenido fue auditado en AR-2-003 como libre de `url`/`title`). No accede a SQLCipher. `TrustScore` no contiene `url` ni `title`. Cero menciones de esos campos en el código. | ✅ |
| **D4** — autoridad de la State Machine | Sin API de acción. Única función pública: `score_patterns`. Ningún nombre público contiene los seis substrings prohibidos. Test estructural blinda nombres. Sin imports de `state_machine`. | ✅ |
| **D5** — `stability_score` con entropía normalizada en [0.0, 1.0] estricto | Fórmula exacta de TS-2-002 implementada en `compute_stability_score` (líneas 174-191): `1 - H/H_max` para N≥2, `1.0` para N=1, `0.0` para N=0. Clamp final `raw.max(0.0).min(1.0)`. Test `test_scores_in_range` verifica con 288 patrones sintéticos. | ✅ |
| **D8** — baseline determinístico sin LLM | Algoritmo puramente aritmético (saturación lineal, exponencial decay con `0.5_f64.powf`, popcount, entropía Shannon, combinación lineal). Sin RNG, sin `SystemTime::now()` interno, sin IO. Test `test_determinism_bit_exact` verifica igualdad `to_bits()`. | ✅ |
| **R12** — Trust Scorer ≠ Pattern Detector ≠ State Machine | Comentario de cabecera con tabla comparativa de 3 columnas y 8 dimensiones. Sin imports de `state_machine` (que no existe). Único import desde `pattern_detector` es el tipo `DetectedPattern` consumido como input puro — no hay reutilización de algoritmos ni código de detección. | ✅ |

---

## Correcciones

**Ninguna.** Implementación apta para producción dentro del scope de Fase 2.

---

## Siguiente Agente Responsable

**Orchestrator** — emisión de `HO-012-phase-2-ts-2-003-kickoff.md` solicitando
al Technical Architect el drafting de `TS-2-003-state-machine.md`.

La implementación de `state_machine.rs` queda autorizada únicamente tras la
aprobación de TS-2-003 por el Orchestrator y el Technical Architect.

---

## Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Revisado | src-tauri/src/trust_scorer.rs (429 líneas) | APROBADO |
| Revisado | src-tauri/src/lib.rs (`mod trust_scorer;` línea 11) | APROBADO |
| Cerrado | T-2-002 (Trust Scorer implementación) | COMPLETADO |
| Desbloqueado | T-2-003 (State Machine — pendiente TS) | LISTO PARA SPEC |
| Creado | operations/architecture-reviews/AR-2-004-trust-scorer-review.md | este documento |

---

## Firma

approved_by: Technical Architect
approval_date: 2026-04-27
notes: Implementación de trust_scorer.rs satisface los 12 criterios de aprobación de TS-2-002 sin observaciones bloqueantes. Constraints D1, D4, D5, D8 y R12 verificados. TrustScore confirmado como input suficiente para State Machine (T-2-003) sin modificaciones de interfaz. Sobrecumplimiento de tests (9 vs 6 obligatorios), test estructural D4 implementado de forma robusta mediante split por `#[cfg(test)]`. Persistencia diferida sigue siendo correcta arquitectónicamente; se decidirá esquema en TS-2-003 o addendum. Se autoriza al Orchestrator la emisión de HO-012 para drafting de TS-2-003 (State Machine).
