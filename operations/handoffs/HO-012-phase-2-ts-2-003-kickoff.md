# Standard Handoff

document_id: HO-012
from_agent: Orchestrator
to_agent: Technical Architect
status: ready_for_execution
phase: 2
date: 2026-04-27
cycle: Kickoff Fase 2 — T-2-003 State Machine (drafting de TS)
opens: TS-2-003 (State Machine — spec formal)
depends_on: T-2-002 implementado y aprobado por Technical Architect (AR-2-004, 2026-04-27)
unblocks: implementación de `src-tauri/src/state_machine.rs` por Desktop Tauri Shell Specialist tras aprobación de TS-2-003

---

## Objetivo

Producir `operations/task-specs/TS-2-003-state-machine.md`: especificación formal
e implementable de `state_machine.rs`, el módulo que gestiona la máquina de
estados de confianza (`Observing → Learning → Trusted → Autonomous`) y
constituye la **única autoridad** del sistema para transiciones de acción (D4).

Este HO entrega solo la spec formal — **no** implementación. La implementación
queda diferida a un HO posterior tras aprobación de TS-2-003 por el Orchestrator
y el Technical Architect.

---

## Inputs

- `operations/task-specs/TS-2-002-trust-scorer.md` (contrato de `TrustScore` —
  input directo de la State Machine)
- `operations/architecture-reviews/AR-2-004-trust-scorer-review.md` (sección
  "Compatibilidad con T-2-003", líneas ~130-156: confirma que `TrustScore` es
  input suficiente y declara la nota arquitectónica sobre ortogonalidad de
  umbrales `StateMachineConfig` vs `TrustConfig`)
- `operations/handoffs/HO-011-phase-2-ts-2-002-kickoff.md` (estructura y tono de
  referencia)
- `Project-docs/decisions-log.md` — D4, D8, D14, R12 (no negociables)
- `operations/backlogs/backlog-phase-2.md` — T-2-003 acceptance criteria
  (líneas ~347-428)
- `CLAUDE.md` (FlowWeaver) — sección "T-2-003 — State Machine
  (`state_machine.rs`)" con el contrato de tipos, estados, transiciones y
  umbrales

---

## Entregable esperado

`operations/task-specs/TS-2-003-state-machine.md` con como mínimo los
siguientes diez elementos:

1. **Distinción R12 declarada** — sección explícita reproduciendo la tabla
   comparativa de tres columnas Pattern Detector / Trust Scorer / State Machine
   (mismo patrón que TS-2-002 §"Distinción Obligatoria R12"), con las
   dimensiones: Propósito, Input, Output, Acceso a SQLCipher, Decide acciones,
   Persistencia, Estado interno, Determinismo. Comentario de cabecera
   obligatorio en el módulo Rust:
   ```rust
   // State Machine — Fase 2 (T-2-003)
   // Propósito: gestionar la FSM de confianza (Observing → Learning → Trusted → Autonomous).
   // La State Machine es la ÚNICA autoridad de transición y de acción (D4).
   // Distinto de pattern_detector.rs (detección) y trust_scorer.rs (cálculo de scores) — R12.
   // Constraints activos: D4 (autoridad exclusiva), D8 (determinismo sin LLM),
   // D1 (sin acceso a url/title transitivo), D14 (T-2-004 depende de este contrato).
   ```

2. **Contrato del módulo** — firma pública con los tipos exactos de CLAUDE.md:
   ```rust
   pub enum TrustStateEnum {
       Observing,
       Learning,
       Trusted,
       Autonomous,
   }

   pub struct Transition {
       pub from: TrustStateEnum,
       pub to: TrustStateEnum,
       pub requires_user_action: bool,  // true para Trusted → Autonomous y para Reset
   }

   pub struct TrustState {
       pub current_state: TrustStateEnum,
       pub available_transitions: Vec<Transition>,
       pub active_patterns_count: usize,
       pub last_transition_at: i64,
   }
   ```
   - Input de `evaluate_transition`: `&[TrustScore]` + estado persistido +
     (opcionalmente) acción explícita del usuario + `now_unix: i64`
   - Output: `TrustState` actualizado (con persistencia del enum + timestamp)
   - `StateMachineConfig` con `Default` para los umbrales (ver punto 5)
   - Tipo `StateMachineError` con variantes para configuración inválida e
     transiciones no permitidas

3. **Restricción D4 — autoridad explícita** — sección dedicada que declare:
   - La State Machine es la **única** autoridad para transiciones de estado y
     decisiones de acción.
   - Trust Scorer **no** invoca transiciones; Privacy Dashboard tampoco las
     dispara automáticamente más allá de las acciones explícitas del usuario
     (reset, activar autonomía).
   - El llamador de `evaluate_transition` es `commands.rs`, después de la
     cadena `pattern_detector::detect_patterns → trust_scorer::score_patterns`.
   - **Forbidden imports recíprocos:** `trust_scorer.rs` y `pattern_detector.rs`
     **no** deben importar `state_machine` (auditable mediante grep en la
     revisión arquitectónica). La dirección de dependencia correcta es:
     `state_machine` consume `TrustScore` por parámetro — nunca al revés.
   - Test estructural recomendado: inspección textual del archivo confirmando
     que la API pública no expone funciones que permitan a Trust Scorer o
     Pattern Detector forzar transiciones (replicar el patrón
     `test_no_action_decision_api` de TS-2-002 §"Restricción D4").

4. **Reglas de transición exactas** — fijadas literal desde CLAUDE.md y
   backlog T-2-003:
   - `Observing → Learning`: `pattern_count >= MIN_PATTERNS && trust_score >
     THRESHOLD_LOW`. Especificar si `trust_score` se evalúa como máximo,
     mediana o promedio del slice (decisión del Technical Architect, debe
     quedar argumentada).
   - `Learning → Trusted`: `trust_score > THRESHOLD_HIGH && !user_blocked`.
     `user_blocked` debe estar definido como flag por patrón (alimentado desde
     T-2-004 vía `block_pattern`) o flag global — el Technical Architect
     decide y lo justifica.
   - `Trusted → Autonomous`: **solo** por acción explícita del usuario; nunca
     automática aunque los scores sean máximos. Confirmación explícita exigida
     desde la UI (T-2-004) — la TS debe declarar el contrato del comando Tauri
     que recibe esta acción y exigir un flag de confirmación de usuario.
   - `Cualquier estado → Observing`: acción de reset del usuario
     (`reset_trust_state`). Debe restablecer `last_transition_at` y limpiar el
     contador de patrones activos según política definida.
   - **Transiciones inversas (downgrade automático)** — decisión obligatoria
     del Technical Architect: la TS debe argumentar y fijar si:
     - (a) `trust_score` cayendo bajo `THRESHOLD_LOW` revierte automáticamente
       `Learning → Observing`, o
     - (b) solo se permite reset manual por el usuario (precedente: D4 favorece
       autoridad explícita).
     Sostenibilidad operativa puede justificar (a); coherencia estricta con D4
     puede justificar (b). El Technical Architect debe **tomar postura** —
     "queda abierto" no es aceptable.

5. **Umbrales configurables** — `StateMachineConfig` con `Default`:
   ```rust
   pub struct StateMachineConfig {
       pub min_patterns: usize,        // MIN_PATTERNS
       pub threshold_low: f64,         // THRESHOLD_LOW para Observing → Learning
       pub threshold_high: f64,        // THRESHOLD_HIGH para Learning → Trusted
       // + cualesquiera flags de política de downgrade automático según punto 4
   }
   ```
   **Nota arquitectónica heredada de AR-2-004:** estos umbrales son
   **ortogonales** a `tier_low_max` / `tier_high_min` de `TrustConfig`. No
   reutilizar nombres ni valores: los tiers descriptivos del Trust Scorer y los
   thresholds de transición de la State Machine son conceptos distintos por D4
   (uno gobierna la etiqueta de cada patrón, el otro la promoción de estado del
   sistema). La TS debe declarar esta distinción explícitamente y prohibir que
   un sprint futuro los unifique sin change request formal.

6. **Determinismo (D8)** — sección dedicada:
   - Sin LLM, sin RNG.
   - Dada la misma `(scores, current_state, user_action, now_unix)`, dos
     invocaciones producen el mismo `TrustState` bit-exacto.
   - Sin `SystemTime::now()` interno; los timestamps se pasan por parámetro
     (mismo patrón que TS-2-002 §"Justificación: `now_unix` explícito").
   - Iteración estable sobre `&[TrustScore]` en orden de entrada.

7. **Persistencia en SQLCipher** — sección dedicada:
   - Solo se persiste `current_state` (enum serializable a `TEXT` o `INTEGER`)
     y `last_transition_at: i64`.
   - **Nunca** persistir `trust_score` ni `stability_score` — los valores se
     recalculan desde patrones (coherente con la decisión TS-2-002
     §"Decisión de Persistencia").
   - El Technical Architect debe especificar:
     - Schema mínimo: tabla nueva (`trust_state`) o extensión a una existente,
       con columnas exactas y tipos.
     - Migración: cómo se introduce el schema sin romper la BD existente
       (idempotencia obligatoria — la migración debe poder ejecutarse varias
       veces sin error).
     - Comportamiento al primer arranque: si no hay registro previo, el
       estado inicial es `Observing` y `last_transition_at = now_unix`.
   - Ningún campo persistido puede contener `url` ni `title` (D1 transitivo).

8. **Comandos Tauri exigidos** — sección dedicada:
   - `get_trust_state` (lectura): devuelve `TrustState` actual al frontend
     (consumido por T-2-004).
   - `reset_trust_state` (acción usuario): transición → `Observing` desde
     cualquier estado.
   - Comando para activar autonomía explícita desde Trusted (la TS define el
     nombre — sugerencia coherente con D4 y T-2-004: `enable_autonomous_mode`
     o equivalente). Debe exigir un parámetro de confirmación explícita
     (`confirmed: bool`) y devolver error si no se proporciona o si el estado
     actual no es `Trusted`.
   - Si el Technical Architect decide downgrade automático en el punto 4 (a),
     debe especificar si se expone un comando adicional o si la lógica
     ocurre internamente en `evaluate_transition`.

9. **Plan de tests con dataset sintético** — mínimo (replica la estructura de
   TS-2-002 §"Plan de Tests"):
   - `test_initial_state_is_observing` — primer arranque sin estado persistido
     → `Observing`.
   - `test_observing_to_learning_on_threshold` — cumplimiento de
     `pattern_count >= MIN_PATTERNS && trust_score > THRESHOLD_LOW` → transición
     correcta.
   - `test_learning_to_trusted_on_high_threshold` — cumplimiento de
     `trust_score > THRESHOLD_HIGH && !user_blocked` → transición correcta.
   - `test_learning_to_trusted_blocked_when_user_blocked` — con
     `user_blocked == true`, no transiciona aunque scores sean máximos.
   - `test_trusted_to_autonomous_requires_explicit_action` — sin acción
     explícita del usuario, no transiciona aunque scores sean máximos; con
     acción explícita y confirmación, transiciona correctamente.
   - `test_reset_from_each_state` — reset desde `Observing`, `Learning`,
     `Trusted`, `Autonomous` → todos vuelven a `Observing` con
     `last_transition_at` actualizado.
   - `test_no_action_api_for_external_modules` — test estructural: la API
     pública no expone funciones que permitan a Trust Scorer o Pattern Detector
     forzar transiciones (D4). Inspección textual con `include_str!` y
     verificación de ausencia de exports peligrosos.
   - `test_determinism_bit_exact` — dos invocaciones de `evaluate_transition`
     con el mismo `(scores, current_state, user_action, now_unix)` producen el
     mismo `TrustState` bit-exacto.
   - `test_persistence_round_trip` — estado se guarda y se restaura
     correctamente tras reinicio simulado (escribir a SQLCipher en memoria,
     reabrir, leer).
   - Si el Technical Architect decide downgrade automático (4.a):
     `test_learning_to_observing_on_score_drop` — `trust_score` cae bajo
     `THRESHOLD_LOW` → revierte a `Observing`.

10. **Criterios de aprobación post-implementación** — checklist verificable
    por Technical Architect antes de desbloquear T-2-004 (Privacy Dashboard
    completo). Mínimo:
    - [ ] `state_machine.rs` existe como módulo independiente registrado en
          `lib.rs`.
    - [ ] Comentario de cabecera con D4, D8 y R12 declarados explícitamente,
          y tabla comparativa de tres columnas
          (Pattern Detector / Trust Scorer / State Machine).
    - [ ] Distinción explícita de umbrales `StateMachineConfig`
          (`min_patterns`, `threshold_low`, `threshold_high`) vs
          `TrustConfig` (`tier_low_max`, `tier_high_min`) — sin reutilización
          de nombres ni valores.
    - [ ] La dirección de dependencias es correcta: la State Machine consume
          `&[TrustScore]` por parámetro — **no** llama directamente a
          `score_patterns` ni a `detect_patterns`. Sin imports recíprocos
          desde `trust_scorer` ni `pattern_detector` hacia `state_machine`.
    - [ ] La transición a `Autonomous` solo es posible mediante acción
          explícita del usuario con flag de confirmación; no hay path de
          transición automática a `Autonomous`.
    - [ ] La transición `Learning → Trusted` requiere doble condición:
          `trust_score > THRESHOLD_HIGH && !user_blocked` (D4).
    - [ ] `reset_trust_state` devuelve el sistema a `Observing` desde
          cualquier estado.
    - [ ] Algoritmo determinístico: dos llamadas con mismo input producen
          mismo output bit-exacto, sin RNG, sin `SystemTime::now()` interno.
    - [ ] Persistencia en SQLCipher: solo `current_state` enum y
          `last_transition_at`. Nunca `trust_score` ni `stability_score`.
          Migración idempotente verificada.
    - [ ] Estado inicial al primer arranque: `Observing`.
    - [ ] Comandos Tauri implementados: `get_trust_state`,
          `reset_trust_state`, comando explícito de activación de autonomía
          (con confirmación obligatoria).
    - [ ] Tests pasando sin regresiones (target ≥ 33 tests previos + nuevos
          obligatorios del plan de tests).
    - [ ] `npx tsc --noEmit` limpio tras añadir comandos Tauri
          (`get_trust_state` y `reset_trust_state` consumibles desde T-2-004).

---

## Restricciones

- **D4** — única autoridad de acción es la State Machine. Reiterar prohibición
  de que `trust_scorer.rs` o `pattern_detector.rs` importen `state_machine`.
  La dirección de dependencia es estricta: State Machine consume `&[TrustScore]`
  por parámetro; no se permite acoplamiento inverso.
- **D8** — baseline determinístico obligatorio sin LLM. Sin RNG, sin
  `SystemTime::now()` interno, `now_unix` por parámetro.
- **R12** — declarar la distinción Pattern Detector / Trust Scorer / State
  Machine en el comentario de cabecera del módulo Rust replicando el patrón de
  tabla de TS-2-002 §"Distinción Obligatoria R12".
- **D14** — T-2-004 (Privacy Dashboard completo) bloquea cierre de Fase 2 y
  depende de T-2-003. El contrato de `TrustState` definido en esta TS debe ser
  suficiente para que T-2-004 lo consuma sin modificaciones de interfaz.
- **D1** transitivo — ningún campo persistido en SQLCipher ni expuesto en los
  comandos Tauri puede contener `url` ni `title`. La State Machine no accede
  a esos campos directa ni indirectamente.
- **No implementación** en este HO — solo la spec formal. La implementación de
  `state_machine.rs` queda diferida a un HO posterior tras aprobación de
  TS-2-003.
- El contrato `TrustState` debe ser suficiente para que el Privacy Dashboard
  (T-2-004) consuma estado y transiciones disponibles sin modificaciones de
  interfaz.

---

## Cierre

Entregar TS-2-003 al Orchestrator para revisión. Tras aprobación se activa el
HO posterior (kickoff implementación al Desktop Tauri Shell Specialist). La
implementación de T-2-003 se autoriza únicamente con TS-2-003 firmado por
Technical Architect y validado por Orchestrator.
