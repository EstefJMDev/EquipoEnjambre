# Standard Handoff

document_id: HO-010
from_agent: Orchestrator
to_agent: Technical Architect
status: ready_for_execution
phase: 2
date: 2026-04-27
cycle: Kickoff Fase 2 — T-2-001 Pattern Detector
opens: TS-2-001 (Pattern Detector — spec formal)
depends_on: T-2-000 no bloquea conceptualmente (paralelo autorizado por backlog-phase-2.md)
unblocks: implementación de pattern_detector.rs por Desktop Tauri Shell Specialist

---

## Objetivo

Producir `TS-2-001-pattern-detector.md`: especificación formal e implementable de
`pattern_detector.rs`, el módulo de detección de patrones longitudinales sobre
domain/category.

Esta tarea puede especificarse en paralelo con T-2-000. La implementación de
Pattern Detector no depende de FS Watcher — son cadenas independientes en el
mapa de dependencias de Fase 2.

---

## Inputs

- `operations/backlogs/backlog-phase-2.md` — T-2-001 in_scope (líneas 187-274):
  contiene in_scope, out_scope, acceptance_criteria y risks ya aprobados por el
  Technical Architect en AR-2-001
- `Project-docs/decisions-log.md` — D1, D8, D17, R12 (no negociables)
- `operations/orchestration-decisions/OD-004-phase-2-activation.md`
- `operations/architecture-reviews/AR-2-001*.md`
- `src-tauri/src/episode_detector.rs` — referencia de la distinción R12 (Pattern
  Detector ≠ Episode Detector); el TS debe declarar esta separación explícitamente

---

## Entregable esperado

`operations/task-specs/TS-2-001-pattern-detector.md` con como mínimo:

1. **Distinción R12 declarada** — sección explícita: Pattern Detector vs Episode
   Detector (longitudinal vs sesión; persiste estado vs no persiste; opera sobre
   historial completo vs sesión activa). Obligatorio en cabecera del módulo Rust.
2. **Contrato de módulo** — firma pública de `pattern_detector.rs`:
   - función `detect_patterns(db: &Connection, config: PatternConfig) -> Vec<DetectedPattern>`
   - tipo `DetectedPattern` con todos los campos del backlog (pattern_id, label,
     category_signature, domain_signature, temporal_window, frequency,
     first_seen, last_seen)
   - tipo `PatternConfig` con al menos `min_frequency: usize` como parámetro
     (no hardcoded — backlog línea 228)
3. **Acceso a datos** — queries SQLCipher permitidas: solo domain, category,
   captured_at. Prohibición explícita de url y title (D1). Indicar el nombre de la
   tabla y los campos exactos.
4. **Algoritmo baseline** — descripción determinística del algoritmo de
   co-ocurrencia: ventanas temporales (time_of_day_bucket: mañana/tarde/noche),
   day_of_week_mask (bitmask 0–6), lógica de frecuencia mínima. Sin LLM como
   requisito (D8); si se declara como mejora opcional, con sección explícita separada.
5. **Persistencia** — decisión sobre si los patrones detectados se guardan en
   SQLCipher en este sprint o permanecen en memoria hasta que T-2-002 valide la
   estructura. El Technical Architect decide y lo documenta aquí.
6. **Plan de tests** — dataset sintético con N recursos con patrones conocidos y
   resultados esperados de `detect_patterns()`. Mínimo: un test con patrón positivo
   esperado y un test con datos insuficientes (menos de min_frequency).
7. **Criterios de aprobación** — qué debe verificar el Technical Architect en
   la revisión post-implementación antes de desbloquear T-2-002.

---

## Restricciones

- D1: queries sobre domain, category, captured_at únicamente — nunca url ni title
- D8: baseline determinístico obligatorio sin LLM; el LLM opcional debe declararse
  como sección separada si el Technical Architect lo incluye
- D17: Pattern Detector completo en Fase 2 — no se puede dividir entre fases ni
  implementar "a medias"
- R12 WATCH: la distinción Pattern Detector ≠ Episode Detector debe declararse en
  el TS (sección explícita) y en el comentario de cabecera del módulo Rust
- No implementación en este HO — solo la spec formal
- El contrato de `DetectedPattern` debe ser suficiente para que Trust Scorer (T-2-002)
  lo consuma sin modificaciones de interfaz

---

## Cierre

Entregar TS-2-001 al Orchestrator para revisión. Tras aprobación se activa HO-011
(kickoff implementación al Desktop Tauri Shell Specialist).
