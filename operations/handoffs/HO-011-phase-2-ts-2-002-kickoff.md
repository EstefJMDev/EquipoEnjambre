# Standard Handoff

document_id: HO-011
from_agent: Orchestrator
to_agent: Technical Architect
status: ready_for_execution
phase: 2
date: 2026-04-27
cycle: Kickoff Fase 2 — T-2-002 Trust Scorer (drafting de TS)
opens: TS-2-002 (Trust Scorer — spec formal)
depends_on: T-2-001 implementado y aprobado por Technical Architect (AR-2-003, 2026-04-27)
unblocks: implementación de `src-tauri/src/trust_scorer.rs` por Desktop Tauri Shell Specialist tras aprobación de TS-2-002

---

## Objetivo

Producir `operations/task-specs/TS-2-002-trust-scorer.md`: especificación formal e
implementable de `trust_scorer.rs`, el módulo que asigna scores de confianza a
los patrones detectados por T-2-001.

Este HO entrega solo la spec formal — **no** implementación. La implementación
queda diferida a un HO posterior tras aprobación de TS-2-002.

---

## Inputs

- `operations/task-specs/TS-2-001-pattern-detector.md` (contrato de `DetectedPattern`)
- `operations/architecture-reviews/AR-2-003-pattern-detector-review.md` (sección
  "Compatibilidad con T-2-002" confirma que `DetectedPattern` es input suficiente)
- `Project-docs/decisions-log.md` — D4, D5, D8 (no negociables)
- `operations/backlogs/backlog-phase-2.md` — T-2-002 acceptance criteria
- `CLAUDE.md` (FlowWeaver) — sección T-2-002 con el contrato de tipos de salida

---

## Entregable esperado

`operations/task-specs/TS-2-002-trust-scorer.md` con como mínimo los siguientes
siete elementos:

1. **Distinción R12 declarada** — sección explícita y comentario de cabecera
   obligatorio en el módulo Rust:
   ```rust
   // Trust Scorer produce inputs para la State Machine.
   // No toma decisiones de acción (D4).
   // Distinto de pattern_detector.rs (detección) y state_machine.rs (autoridad) — R12.
   ```

2. **Contrato del módulo** — firma pública:
   - Input: `Vec<DetectedPattern>` (no lee SQLCipher directamente)
   - Output: `Vec<TrustScore>` con los campos exactos de CLAUDE.md:
     ```rust
     struct TrustScore {
         pattern_id: Uuid,
         trust_score: f64,         // [0.0, 1.0]
         stability_score: f64,     // [0.0, 1.0] — entropía normalizada (D5)
         recency_weight: f64,
         confidence_tier: ConfidenceTier,  // Low / Medium / High
     }
     ```
   - `TrustConfig` con umbrales `confidence_tier` configurables (no hardcoded)

3. **Restricción D4 explícita** — el módulo **NO** puede exponer
   `recommend_action()`, `should_promote()` ni función equivalente que tome
   decisiones de acción. Las acciones son responsabilidad exclusiva de
   `state_machine.rs` (T-2-003). Trust Scorer solo calcula scores; la State
   Machine consume scores y aplica políticas.

4. **Restricción D5 — `stability_score`** — definir explícitamente la fórmula:
   slot concentration con entropía normalizada, acotada estrictamente en
   [0.0, 1.0]. Plantilla: `H = -Σ wᵢ log wᵢ`, normalizada por `log(N)` (donde N
   es el número de categorías con peso > 0). Caso `N = 1` debe devolver score
   máximo (concentración total). Indicar comportamiento ante categorías vacías.

5. **Algoritmo determinístico (D8)** — `trust_score = f(frequency, recency_weight,
   temporal_coherence)`. El TS debe especificar la fórmula concreta:
   - `recency_weight` = decaimiento exponencial sobre `last_seen` con
     `half_life_days` configurable
   - `temporal_coherence` = derivada de `temporal_window.day_of_week_mask`
     (concentración de bits activos / `popcount`) y consistencia del
     `time_bucket`
   - Combinación: media ponderada o producto, decisión del Technical Architect
   - Sin LLM. Sin aleatoriedad.

6. **Plan de tests con dataset sintético** — mínimo:
   - Test patrón frecuente y reciente → `trust_score` alto, `confidence_tier::High`
   - Test patrón frecuente pero antiguo → `trust_score` reducido por recency
   - Test patrón con categorías muy dispersas → `stability_score` bajo
   - Test patrón con categoría única → `stability_score` máximo (1.0)
   - Test estructural: `trust_score` ∈ [0.0, 1.0] y `stability_score` ∈ [0.0, 1.0]
     para cualquier input válido (D5)
   - Test estructural: el módulo no expone función pública con nombre que sugiera
     acción (`recommend`, `decide`, `promote`, `transition`) — D4

7. **Criterios de aprobación post-implementación** — checklist verificable por
   el Technical Architect antes de desbloquear T-2-003:
   - Comentario de cabecera con D4 y R12 declarados
   - Sin `use crate::state_machine` (no hay aún, pero el módulo no debe
     anticipar acoplamiento)
   - No hay funciones públicas que tomen decisiones de acción
   - `stability_score` acotado en [0.0, 1.0] verificado por test estructural
   - Umbrales de `confidence_tier` configurables vía `TrustConfig`
   - Algoritmo determinístico: dos llamadas con el mismo input producen el
     mismo output
   - Tests nuevos pasan; los 24 tests existentes no tienen regresiones
   - `npx tsc --noEmit` limpio si se añade comando Tauri

---

## Restricciones

- D4: Trust Scorer **no decide acciones**. La State Machine es la única autoridad
- D5: `stability_score` con entropía normalizada en [0.0, 1.0] estricto — sin
  fórmulas alternativas sin change request formal
- D8: baseline determinístico obligatorio sin LLM
- R12: declarar la distinción Pattern Detector / Trust Scorer / State Machine en
  el comentario de cabecera del módulo Rust
- No implementación en este HO — solo la spec formal
- El contrato de `TrustScore` debe ser suficiente para que State Machine (T-2-003)
  consuma scores sin modificaciones de interfaz

---

## Cierre

Entregar TS-2-002 al Orchestrator para revisión. Tras aprobación se activa el
HO posterior (kickoff implementación al Desktop Tauri Shell Specialist). La
implementación de T-2-002 se autoriza únicamente con TS-2-002 firmado.
