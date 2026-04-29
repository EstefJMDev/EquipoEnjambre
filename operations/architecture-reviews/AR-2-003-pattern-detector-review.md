# Revisión Arquitectónica — Pattern Detector (T-2-001)

document_id: AR-2-003
owner_agent: Technical Architect
phase: 2
date: 2026-04-27
status: APROBADO — sin correcciones; T-2-001 cerrado, T-2-002 desbloqueado
documents_reviewed:
  - operations/task-specs/TS-2-001-pattern-detector.md
  - src-tauri/src/pattern_detector.rs (módulo nuevo, 421 líneas)
  - src-tauri/src/storage.rs (método pub(crate) `conn()` añadido)
  - src-tauri/src/lib.rs (`mod pattern_detector;` registrado en línea 7)
reference_normativo:
  - Project-docs/decisions-log.md (D1, D8, D17, R12)
  - operations/backlogs/backlog-phase-2.md (T-2-001 acceptance criteria)
  - operations/handoffs/HO-010-phase-2-ts-2-001-kickoff.md
precede_a: Technical Architect → drafting de TS-2-002 (Trust Scorer)

---

## Objetivo De Esta Revisión

Verificar que la implementación de `pattern_detector.rs` satisface los 8 criterios
de aprobación post-implementación de TS-2-001 (líneas 273-284) y que el contrato
público (`DetectedPattern`) es suficiente para alimentar Trust Scorer (T-2-002)
sin modificaciones de interfaz. Adicionalmente confirmar el cumplimiento de los
constraints D1, D8, D17 y R12.

Datos confirmados por el implementador (Desktop Tauri Shell Specialist):
- `cargo test` — 24/24 OK (19 previos + 5 nuevos sin regresiones)
- `npx tsc --noEmit` limpio

---

## Resultado Global

**APROBADO sin correcciones.** Los 8 criterios están satisfechos.

| # | Criterio TS-2-001 | Resultado | Observación |
|---|---|---|---|
| 1 | `pattern_detector.rs` independiente, sin `use crate::episode_detector` (R12) | ✅ | grep confirma: las únicas dos menciones a `episode_detector` están en el comentario de cabecera (referencia documental). No hay `use`, `mod` ni llamadas. |
| 2 | Comentario de cabecera con tabla R12 | ✅ | Líneas 1-16 incluyen propósito, constraints aplicables (D1/D8/D17) y la tabla comparativa de seis dimensiones (Propósito, Temporalidad, Input, Estado persistido, Acceso a title, Algoritmo). |
| 3 | Ninguna query SQLCipher contiene `url` ni `title` (D1) | ✅ | Única query del módulo: `RESOURCES_QUERY` (líneas 33-36) — `SELECT domain, category, captured_at FROM resources WHERE captured_at >= ?1`. Test `test_no_url_or_title_in_query` (líneas 402-405) lo verifica estructuralmente. Las menciones a `url`/`title` en el archivo aparecen solo en (a) comentario de cabecera con la prohibición, (b) helper de tests `insert_at` que satisface la firma de `NewResource` con valores cifrados ficticios, (c) nombre del test estructural. Ninguna alcanza la capa de queries reales del detector. |
| 4 | `PatternConfig.min_frequency` parámetro, no constante | ✅ | Líneas 39-43: `min_frequency`, `lookback_days` y `time_bucket_boundaries` son campos del struct, con `Default` (3 / 30 / [12, 18]) en líneas 45-53. La función `detect_patterns` recibe `&PatternConfig`. |
| 5 | `DetectedPattern` con los 8 campos requeridos | ✅ | Líneas 80-90: `pattern_id` (String UUID), `label`, `category_signature: Vec<CategoryWeight>`, `domain_signature: Vec<DomainWeight>`, `temporal_window: TemporalWindow`, `frequency: usize`, `first_seen: i64`, `last_seen: i64`. Coincide con el contrato declarado en TS-2-001 líneas 87-97. |
| 6 | 5 tests nuevos pasan; sin regresiones | ✅ | Confirmado 24/24 OK. Los cinco tests requeridos están presentes: `test_detect_known_pattern_development_morning`, `test_detect_known_pattern_media_afternoon`, `test_below_min_frequency_not_detected`, `test_no_url_or_title_in_query`, `test_pattern_id_is_uuid`. |
| 7 | `npx tsc --noEmit` limpio | ✅ | Confirmado por el implementador. No se ha añadido comando Tauri en este sprint (consistente con la decisión de persistencia diferida — ver sección de observaciones). |
| 8 | Contrato `DetectedPattern` coherente con inputs de T-2-002 | ✅ | Ver sección "Compatibilidad con T-2-002" abajo. Todos los campos necesarios para `trust_score`, `stability_score`, `recency_weight` y `confidence_tier` están presentes y son determinísticamente derivables. |

---

## Observaciones De Diseño Relevantes

### O.1 — Solapamiento por Jaccard de categorías (paso 5 del algoritmo)

TS-2-001 (líneas 174-176) prescribe "si dos patrones comparten >80% de
`category_signature`, conservar el de mayor frequency". La implementación
(función `category_overlap`, líneas 302-312) materializa esta regla mediante
**índice de Jaccard sobre el conjunto de categorías** (`|A ∩ B| / |A ∪ B|`),
con `OVERLAP_THRESHOLD = 0.8` (línea 29).

Decisión arquitectónicamente correcta: Jaccard es la métrica canónica para
solapamiento de conjuntos discretos y elimina la ambigüedad de "comparten >80%"
(que podría leerse de varias formas). Determinístico (D8). El umbral está
declarado como constante de módulo, no escondido — auditable.

Nota: `OVERLAP_THRESHOLD` no se expone vía `PatternConfig`. Es aceptable para
T-2-001 (no figura en los criterios como parámetro obligatorio), pero queda como
candidato a parametrizar si la calibración futura lo requiere.

### O.2 — Derivación manual de day_of_week sin chrono

`derive_day_of_week_bit` (líneas 234-237) calcula el día de la semana mediante
aritmética modular sobre Unix epoch (días desde 1970-01-01, que cae en jueves;
offset = 3 para alinear lunes = bit 0). Evita dependencia adicional de `chrono`,
es determinístico, y los tests (`ts_at` helper líneas 351-354) verifican que la
semántica es correcta para lunes (bit 0) y miércoles (bit 2).

Trade-off explícito: no maneja zonas horarias — opera en UTC. Para Fase 2 es
aceptable; si Fase 3 introduce localización por zona horaria del usuario, este
helper deberá reemplazarse o envolverse, sin afectar al contrato público.

### O.3 — Persistencia diferida (decisión TS-2-001)

TS-2-001 (líneas 197-211) decidió mantener los patrones en memoria hasta que
T-2-002 valide el contrato. La implementación lo respeta: no hay schema nuevo
en SQLCipher, no hay migración añadida, y `detect_patterns()` se invoca on-demand
desde `commands.rs` (cuando se exponga). La persistencia se especificará en
TS-2-002 o como addendum.

Coherente con la decisión arquitectónica. No requiere acción en esta revisión.

### O.4 — Acceso `pub(crate) fn conn()` en storage.rs

`storage.rs` (líneas 288-292) añade `pub(crate) fn conn(&self) -> &Connection`
para que `pattern_detector.rs` pueda emitir su propio `SELECT`. Visibilidad
restringida al crate (no expuesta como API pública del módulo). Aceptable: el
detector requiere su query especializada y duplicar la abstracción de `Db` para
una sola query sería sobreingeniería. Cualquier módulo que use este accessor
queda sujeto a auditoría D1 igual que `pattern_detector.rs`.

### O.5 — Manejo de errores con tipo propio

`PatternDetectorError` (líneas 92-119) envuelve `rusqlite::Error` y
`std::time::SystemTimeError` con `From` impls e `impl Display + Error`.
Limpio, no propaga `unwrap()` en el camino crítico. Adecuado.

### O.6 — Ordenación determinística de signatures

`category_signature` y `domain_signature` se ordenan por peso descendente con
desempate alfabético (líneas 262-265, 271-274). Garantiza que el `dominant_category`
y, por extensión, el `label` son reproducibles dado el mismo input. Refuerza D8.

---

## Compatibilidad con T-2-002 (Trust Scorer)

Trust Scorer recibirá `Vec<DetectedPattern>` y debe producir `TrustScore` con
campos `trust_score`, `stability_score`, `recency_weight`, `confidence_tier`
(CLAUDE.md sección T-2-002). Verifico que cada campo es derivable:

| Campo de TrustScore | Derivable de DetectedPattern | Cómo |
|---|---|---|
| `trust_score = f(frequency, recency_weight, temporal_coherence)` | ✅ | `frequency` directo; `recency_weight` desde `last_seen`; `temporal_coherence` desde `temporal_window.day_of_week_mask` (concentración de bits) y consistencia de `time_bucket`. |
| `stability_score` (entropía normalizada de slot concentration, D5) | ✅ | `category_signature: Vec<CategoryWeight>` con pesos en [0,1] que suman 1 — input directo para `H = -Σ wᵢ log wᵢ`, normalizable contra `log(N)` para acotar a [0,1]. |
| `recency_weight` | ✅ | `last_seen: i64` permite calcular decaimiento exponencial respecto a `now`. |
| `confidence_tier` (Low/Medium/High) | ✅ | Derivable de `trust_score` aplicando los umbrales configurables que TS-2-002 deberá especificar. |
| `pattern_id` (correlación 1:1) | ✅ | `pattern_id: String` (UUID v4) — clave estable para asociar `TrustScore` ↔ `DetectedPattern`. |

**Confirmación explícita:** `DetectedPattern` es input suficiente para
`trust_scorer.rs`. No se requieren modificaciones de interfaz en T-2-001 para
soportar T-2-002.

Nota para el drafting de TS-2-002: el constraint D4 obliga a que Trust Scorer
no exponga `recommend_action()` ni similar — solo cálculo de scores. La firma
sugerida es `pub fn score_patterns(patterns: &[DetectedPattern], config: &TrustConfig) -> Vec<TrustScore>`.

---

## Constraints D1 / D8 / D17 / R12 — Verificación final

| Constraint | Verificación | Estado |
|---|---|---|
| **D1** — solo `domain`/`category`/`captured_at` | Única query `RESOURCES_QUERY` cumple. `DetectedPattern` no contiene `url` ni `title`. Test estructural lo blinda. | ✅ |
| **D8** — baseline determinístico sin LLM | Algoritmo puramente combinatorio (agrupación por gap, conteo, Jaccard). `label` se genera con `format!` sobre `dominant_category + time_bucket_es`. No hay dependencia de modelo. | ✅ |
| **D17** — Pattern Detector completo en Fase 2 | Los 5 pasos del algoritmo (sesiones → etiquetado → co-ocurrencia → construcción → filtro de solapamientos) están implementados. La persistencia diferida está autorizada por TS-2-001 y no constituye división del módulo. | ✅ |
| **R12** — `pattern_detector.rs` ≠ `episode_detector.rs` | Sin `use crate::episode_detector`. Comentario de cabecera con tabla comparativa. Algoritmos distintos (co-ocurrencia longitudinal vs Jaccard de tokens en sesión). | ✅ |

---

## Correcciones

**Ninguna.** Implementación apta para producción dentro del scope de Fase 2.

---

## Siguiente Agente Responsable

**Technical Architect** — drafting de `TS-2-002-trust-scorer.md` (sesión separada,
activada por HO-011 que se emite en paralelo a esta AR).

La implementación de `trust_scorer.rs` queda autorizada únicamente tras la
aprobación de TS-2-002 por el Orchestrator y Technical Architect.

---

## Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Revisado | src-tauri/src/pattern_detector.rs | APROBADO |
| Revisado | src-tauri/src/storage.rs (método conn) | APROBADO |
| Revisado | src-tauri/src/lib.rs (mod pattern_detector) | APROBADO |
| Cerrado | T-2-001 (Pattern Detector implementación) | COMPLETADO |
| Desbloqueado | T-2-002 (Trust Scorer — pendiente TS) | LISTO PARA SPEC |
| Creado | operations/architecture-reviews/AR-2-003-pattern-detector-review.md | este documento |

---

## Firma

approved_by: Technical Architect
approval_date: 2026-04-27
notes: Implementación de pattern_detector.rs satisface los 8 criterios de aprobación de TS-2-001 sin observaciones bloqueantes. Constraints D1, D8, D17 y R12 verificados. DetectedPattern confirmado como input suficiente para Trust Scorer (T-2-002). Persistencia diferida sigue siendo correcta arquitectónicamente; se decidirá esquema en TS-2-002 o addendum. Se autoriza la emisión de HO-011 para drafting de TS-2-002.
