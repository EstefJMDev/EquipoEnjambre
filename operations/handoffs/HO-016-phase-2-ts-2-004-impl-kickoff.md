# Standard Handoff

document_id: HO-016
from_agent: Orchestrator
to_agent: Desktop Tauri Shell Specialist
status: ready_for_execution
phase: 2
date: 2026-04-27
cycle: Implementación T-2-004 — Privacy Dashboard completo
opens: implementación de TS-2-004 (`operations/task-specs/TS-2-004-privacy-dashboard.md`, firmada por Technical Architect 2026-04-27, validada por Orchestrator 2026-04-27)
depends_on: TS-2-004 firmada y validada; T-2-001 implementado y aprobado (AR-2-003); T-2-003 implementado y aprobado (AR-2-005); contratos `DetectedPattern`, `TrustScore`, `TrustStateView` estables y consumibles sin modificación.
unblocks: AR-2-006 (revisión arquitectónica post-implementación) → cierre lógico de Fase 2 satisfaciendo D14 (Privacy Dashboard completo es prerequisito bloqueante de Fase 3). FS Watcher (`fs_watcher.rs`) se implementa en paralelo y se integra al dashboard mediante HO-FW-PD futuro sin reabrir TS-2-004.

---

## Objetivo

Implementar T-2-004 según TS-2-004 firmada. La implementación abarca cinco
ejes coordinados:

1. **Backend Rust** — módulo nuevo `pattern_blocks.rs` con schema y API
   `pub(crate)`; tres comandos Tauri nuevos en `commands.rs`; edición de
   `state_machine::evaluate_transition` y `apply_trust_action` para
   externalizar `user_blocked` (decisión arquitectónica de TS-2-004 §"Edición
   Mecánica"); registro de módulo y comandos en `lib.rs`.
2. **TypeScript** — cinco tipos nuevos en `src/types.ts` (`CategorySignatureItem`,
   `DomainSignatureItem`, `TimeBucket`, `TemporalWindowView`, `PatternSummary`).
3. **Frontend React** — modificación de `PrivacyDashboard.tsx` (contenedor) y
   tres subcomponentes nuevos (`PatternsSection.tsx`, `TrustStateSection.tsx`,
   `PrivacyDashboardNeverSeen.tsx`).
4. **Tests Rust** — 4 tests nuevos en `pattern_blocks::tests`, 1 test
   estructural D1 en `commands::tests`, reactivación del test
   `test_learning_to_trusted_blocked_when_user_blocked` (eliminar `#[ignore]`
   y actualizar firma), edición mecánica de los 11 tests previos que invocan
   `evaluate_transition` para añadir `false` como último parámetro.
5. **Verificaciones** — `cargo test` con ≥ 49 tests / 0 failed / 0 ignored,
   `npx tsc --noEmit` limpio, handoff a Privacy Guardian con cuatro archivos
   del dashboard + cinco capturas de pantalla.

La implementación queda **estrictamente acotada** a TS-2-004. Cualquier
ambigüedad o necesidad de desviación se escala al Orchestrator antes de
proceder.

---

## Inputs

Lectura obligatoria antes de cualquier edición:

### Spec autoritativa
- **TS-2-004:** `operations/task-specs/TS-2-004-privacy-dashboard.md` (firmada
  por Technical Architect 2026-04-27, validada por Orchestrator 2026-04-27).
  La spec es la **única fuente de verdad** para esta implementación. Todos
  los contratos (tipos, comandos, schema, JSX) están declarados con shape
  exacto y deben implementarse literalmente.

### Contratos heredados (no modificar)
- **TS-2-001:** `operations/task-specs/TS-2-001-pattern-detector.md` —
  `DetectedPattern`, `pattern_detector::detect_patterns(conn, &PatternConfig)`.
- **TS-2-002:** `operations/task-specs/TS-2-002-trust-scorer.md` — `TrustScore`
  permanece idéntico al cierre de AR-2-004. **No reabrir.**
- **TS-2-003:** `operations/task-specs/TS-2-003-state-machine.md` —
  `TrustStateView`, `TrustStateEnum`, `Transition`, los tres comandos
  (`get_trust_state`, `reset_trust_state`, `enable_autonomous_mode`).
  **Consumir sin modificación.** La única excepción es el cambio de firma
  documentado de `evaluate_transition` declarado en TS-2-004 §"Edición
  Mecánica" (parámetro `user_blocked_pre: bool`).

### Revisiones arquitectónicas
- **AR-2-003 / AR-2-004 / AR-2-005:** cierres de TS-2-001 / TS-2-002 /
  TS-2-003. Cualquier consumo de los contratos cerrados debe respetar la
  superficie blindada en estas revisiones.

### Decisiones cerradas
- **`project-docs/decisions-log.md`** — D1 (transversal absoluto: sin
  `url`/`title`), D4 (T-2-004 no introduce nueva autoridad de transición),
  D8 (determinismo), D14 (T-2-004 cierra el gate), R12 (T-2-004 no introduce
  lógica de detección).

### CLAUDE.md (FlowWeaver)
- Sección §"T-2-004 — Privacy Dashboard completo" describe scope a alto
  nivel. **TS-2-004 prevalece** sobre CLAUDE.md ante cualquier discrepancia.

### Código existente (anclas verificadas)
- `src-tauri/src/state_machine.rs:339-341` — placeholder actual de
  `user_blocked()`. Será **eliminado** según TS-2-004 §"Edición Mecánica".
- `src-tauri/src/state_machine.rs:519-546` — test
  `test_learning_to_trusted_blocked_when_user_blocked` con `#[ignore]`.
  Será **reactivado** con la firma actualizada según TS-2-004 §"Edición
  Mecánica" + criterios 8-9.
- `src-tauri/src/lib.rs:1-13` — declaraciones de módulos en orden
  alfabético. `mod pattern_blocks;` se inserta entre línea 7
  (`mod pattern_detector;`) y línea 8 (`mod raw_event;`).
- `src-tauri/src/lib.rs` `invoke_handler!` (líneas ~70-83) — los tres
  comandos T-2-004 (`get_detected_patterns`, `block_pattern`,
  `unblock_pattern`) se añaden tras `commands::enable_autonomous_mode`
  manteniendo orden lógico declarado en TS-2-004 §"Contratos de Comandos
  Tauri Nuevos".
- `src/types.ts:84-99` — bloque T-2-003. El bloque T-2-004 se añade
  inmediatamente después.
- `src/components/PrivacyDashboard.tsx` — estado actual (Fase 0b — solo
  sección "Recursos"). Se modifica según TS-2-004 §"Estructura del
  Componente".

### Comandos de verificación
```bash
cd src-tauri && cargo test          # ≥ 49 tests / 0 failed / 0 ignored
npx tsc --noEmit                    # limpio
```

---

## Entregables esperados

### 1. Módulo nuevo `src-tauri/src/pattern_blocks.rs`

Estructura exacta declarada en TS-2-004 §"Persistencia: tabla `pattern_blocks`":

- Comentario de cabecera obligatorio (D1, D4, D8, R12) — copiar literal de
  TS-2-004 §"Módulo nuevo".
- Schema:
  ```sql
  CREATE TABLE IF NOT EXISTS pattern_blocks (
      pattern_id TEXT PRIMARY KEY,
      blocked_at INTEGER NOT NULL
  );
  ```
- API `pub(crate)`:
  - `ensure_schema(conn: &Connection) -> Result<(), rusqlite::Error>`
  - `block(conn: &Connection, pattern_id: &str, now_unix: i64) -> Result<(), rusqlite::Error>` (`INSERT OR IGNORE`)
  - `unblock(conn: &Connection, pattern_id: &str) -> Result<(), rusqlite::Error>` (`DELETE WHERE pattern_id = ?`)
  - `list_blocked(conn: &Connection) -> Result<HashSet<String>, rusqlite::Error>`
  - `is_blocked(conn: &Connection, pattern_id: &str) -> Result<bool, rusqlite::Error>`
- Visibilidad estricta `pub(crate)` (mismo principio que `state_machine`).
- Tests internos (`#[cfg(test)] mod tests`):
  - `test_block_unblock_round_trip`
  - `test_block_idempotent`
  - `test_unblock_idempotent`
  - `test_list_blocked_returns_set`

### 2. Registro en `src-tauri/src/lib.rs`

- `mod pattern_blocks;` insertado en orden alfabético entre línea 7
  (`mod pattern_detector;`) y línea 8 (`mod raw_event;`).
- Tres comandos nuevos añadidos al `invoke_handler!` tras
  `commands::enable_autonomous_mode`, en el orden:
  ```rust
  commands::get_detected_patterns,
  commands::block_pattern,
  commands::unblock_pattern,
  ```

### 3. Tres comandos Tauri nuevos en `src-tauri/src/commands.rs`

Firmas exactas:
```rust
#[tauri::command]
pub fn get_detected_patterns(state: State<'_, DbState>) -> Result<Vec<PatternSummary>, String>;

#[tauri::command]
pub fn block_pattern(state: State<'_, DbState>, pattern_id: String) -> Result<(), String>;

#[tauri::command]
pub fn unblock_pattern(state: State<'_, DbState>, pattern_id: String) -> Result<(), String>;
```

Comportamiento exacto en TS-2-004 §"Contratos de Comandos Tauri Nuevos":

- `get_detected_patterns`: lock mutex → `ensure_schema` → `detect_patterns`
  con `PatternConfig::default()` → `list_blocked` → proyectar a
  `Vec<PatternSummary>` con `is_blocked` resuelto → ordenar por `last_seen`
  desc, desempate por `pattern_id` asc.
- `block_pattern` / `unblock_pattern`: idempotentes vía `INSERT OR IGNORE` /
  `DELETE`.

Definición del struct `PatternSummary` en Rust con `#[derive(Serialize)]`
coherente con el shape de `src/types.ts` (camelCase ↔ snake_case manejado
por serde).

**Restricción D4 estricta:** ninguno de los tres comandos invoca
`evaluate_transition`, `score_patterns`, ni mutaciones de `state_machine`.

### 4. Edición de `src-tauri/src/state_machine.rs`

Según TS-2-004 §"Edición Mecánica de `state_machine::user_blocked()`":

- **Eliminar** el helper privado `user_blocked()` (líneas 339-341 actuales).
  TS-2-004 lo externaliza; no se mantiene placeholder.
- **Modificar la firma de `evaluate_transition`** añadiendo
  `user_blocked_pre: bool` como último parámetro:
  ```rust
  pub fn evaluate_transition(
      scores: &[TrustScore],
      current: TrustStateEnum,
      last_transition_at: i64,
      user_action: Option<UserAction>,
      now_unix: i64,
      config: &StateMachineConfig,
      user_blocked_pre: bool,
  ) -> Result<TrustState, StateMachineError>
  ```
- **Reemplazar** dentro del cuerpo de `evaluate_transition` cualquier
  invocación al helper eliminado por consultas al parámetro
  `user_blocked_pre`. La transición `Learning → Trusted` se inhibe cuando
  `user_blocked_pre == true`.
- **Reactivar** el test `test_learning_to_trusted_blocked_when_user_blocked`
  en líneas 519-546:
  - Eliminar la línea `#[ignore = "..."]`.
  - Actualizar la llamada a `evaluate_transition` para pasar `true` como
    último argumento.
  - La aserción permanece: `result.current_state == TrustStateEnum::Learning`.
- **Edición mecánica de los 11 tests activos previos** que invocan
  `evaluate_transition`: añadir `false` como último argumento. Localizables
  por `cargo build` (la firma cambiada provocará errores de compilación
  precisos en cada caller hasta corregirlos).

### 5. Edición de `src-tauri/src/commands.rs::apply_trust_action`

Precomputar `user_blocked_pre` antes de invocar `evaluate_transition` según
TS-2-004 §"Edición Mecánica":

```rust
let blocked_ids = pattern_blocks::list_blocked(conn).map_err(|e| e.to_string())?;
let user_blocked_pre = scores.iter().any(|s| blocked_ids.contains(&s.pattern_id));
let new_state = state_machine::evaluate_transition(
    &scores, current, last_ts, user_action, now_unix,
    &StateMachineConfig::default(), user_blocked_pre,
)?;
```

`pattern_blocks::ensure_schema(conn)` debe haberse invocado antes (en el
arranque de la app o en la primera invocación). Si la spec implícita ya
ejecuta `ensure_schema` en cada comando T-2-004, no añadir invocaciones
duplicadas — preservar el patrón establecido.

### 6. Test estructural D1 en `src-tauri/src/commands.rs`

Test exacto declarado en TS-2-004 §"Verificación Doble (i)":

```rust
#[test]
fn test_no_url_or_title_in_dashboard_components() {
    const FILES: &[&str] = &[
        include_str!("../../src/components/PrivacyDashboard.tsx"),
        include_str!("../../src/components/PatternsSection.tsx"),
        include_str!("../../src/components/TrustStateSection.tsx"),
        include_str!("../../src/components/PrivacyDashboardNeverSeen.tsx"),
    ];
    let forbidden = [
        "resource.url", "resource.title",
        ".bookmark_url", ".page_title",
        "p.url", "p.title",
        "view.url", "view.title",
    ];
    for src in FILES {
        for token in forbidden {
            assert!(
                !src.contains(token),
                "D1 violation: token '{token}' present in dashboard component"
            );
        }
    }
}
```

Ubicación recomendada: dentro del módulo `tests` de `commands.rs` si existe,
o como módulo de tests de integración separado bajo `src-tauri/src/`. Mantener
coherencia con el patrón de tests estructurales D4 ya presentes en el suite.

### 7. Tipos TypeScript nuevos en `src/types.ts`

Añadir tras el bloque T-2-003 (línea 99 actual). Shape literal de TS-2-004
§"Contrato de Tipos TypeScript":

```typescript
// ── Phase 2 — Privacy Dashboard (T-2-004) ────────────────────────────────────

export interface CategorySignatureItem {
  category: string;
  weight: number;
}

export interface DomainSignatureItem {
  domain: string;
  weight: number;
}

export type TimeBucket = 'Morning' | 'Afternoon' | 'Evening';

export interface TemporalWindowView {
  time_bucket: TimeBucket;
  day_of_week_mask: number;
}

export interface PatternSummary {
  pattern_id: string;
  label: string;
  category_signature: CategorySignatureItem[];
  domain_signature: DomainSignatureItem[];
  temporal_window: TemporalWindowView;
  frequency: number;
  last_seen: number;
  is_blocked: boolean;
}
```

**No reabrir** `TrustStateEnum`, `Transition`, `TrustStateView` (cerrados en
AR-2-005).

### 8. Modificación de `src/components/PrivacyDashboard.tsx`

Según TS-2-004 §"Contenedor: `src/components/PrivacyDashboard.tsx`":

- Imports nuevos:
  ```typescript
  import { PatternsSection } from "./PatternsSection";
  import { TrustStateSection } from "./TrustStateSection";
  import { PrivacyDashboardNeverSeen } from "./PrivacyDashboardNeverSeen";
  ```
- Estructura del JSX dentro del panel cuando `open === true`: copiar literal
  del bloque `<div className="privacy-dashboard__panel">` declarado en
  TS-2-004.
- Sección "Recursos" preservada **sin churn funcional**: solo se envuelve
  en `<section aria-labelledby="pd-recursos">` y se le añade el `<h4>`. El
  botón "Eliminar todos los datos" preserva su comportamiento actual.

### 9. Subcomponentes nuevos en `src/components/`

Tres archivos con código literal de TS-2-004 (copiar exactamente, sin
parafrasear):

- **`PatternsSection.tsx`** — TS-2-004 §"Subcomponente: `src/components/PatternsSection.tsx`".
  Incluye los helpers privados `formatTemporalWindow` y `formatRelative`.
  Cap visual de 5 badges + "+N más" sin tooltip detallado.
- **`TrustStateSection.tsx`** — TS-2-004 §"Subcomponente: `src/components/TrustStateSection.tsx`".
  Modal de confirmación obligatorio antes de
  `enable_autonomous_mode(confirmed: true)` con texto literal declarado.
  El botón "Activar preparación automática" solo aparece cuando
  `view.current_state === "Trusted"`.
- **`PrivacyDashboardNeverSeen.tsx`** — TS-2-004 §"Subcomponente:
  `src/components/PrivacyDashboardNeverSeen.tsx`". **Texto literal — no
  parafrasear.** El bloque `<ul>` y la nota final son contractuales (D1).

**Restricción D1 vinculante:** ninguno de los tres subcomponentes accede a
campos `url`, `title`, `bookmark_url`, `page_title`, `link`, `href`. Las
únicas menciones permitidas son **textuales explicativas** en
`PrivacyDashboardNeverSeen.tsx` (auditable por inspección directa y por el
test estructural §6).

---

## Plan de implementación recomendado (orden de menor riesgo)

El orden no es prescriptivo, pero esta secuencia minimiza compilaciones rotas:

1. **Módulo `pattern_blocks.rs`** + tests internos (1-4). `cargo test` debe
   pasar añadiendo 4 tests nuevos sin afectar los 45 actuales.
2. **Registro `mod pattern_blocks;` en `lib.rs`** línea 7→8.
3. **Edición de `state_machine.rs`:** eliminar helper, modificar firma de
   `evaluate_transition`, reactivar test #4, ajustar 11 tests previos a
   `false` como último arg. `cargo test` debe pasar con 45 + 4 = 49 tests
   (no failed, no ignored).
4. **Edición de `commands.rs::apply_trust_action`:** precomputar
   `user_blocked_pre`. `cargo test` sigue verde.
5. **Tres comandos nuevos en `commands.rs`** (`get_detected_patterns`,
   `block_pattern`, `unblock_pattern`) + struct `PatternSummary` en Rust.
   Registro en `invoke_handler!` de `lib.rs`.
6. **Test estructural D1** en `commands.rs` (test #5 nuevo). `cargo test`
   debe pasar con ≥ 50 tests (45 base + 4 pattern_blocks + 1 D1) y 0
   ignored. Nota: el test D1 fallará en este punto porque los archivos JSX
   no existen aún — implementar tras los archivos JSX, o usar `Path::exists`
   guard temporal **NO**: TS-2-004 declara el shape exacto del test sin
   guard. Implementar los archivos JSX antes del test D1, o implementar el
   test D1 **después** de los archivos en el orden 5→7-9→6.
7. **Tipos TypeScript nuevos** en `src/types.ts`. `npx tsc --noEmit` limpio.
8. **Subcomponentes nuevos** (`PatternsSection.tsx`, `TrustStateSection.tsx`,
   `PrivacyDashboardNeverSeen.tsx`). `npx tsc --noEmit` limpio.
9. **Modificación de `PrivacyDashboard.tsx`** para componer los subcomponentes.
   `npx tsc --noEmit` limpio.
10. **Test estructural D1** (paso 6 reordenado): ahora los `include_str!`
    encuentran los archivos. `cargo test` ≥ 50 tests / 0 failed / 0 ignored.
11. **Verificación funcional manual** del dashboard en el shell desktop
    (ver criterios externos abajo).

---

## Restricciones

### D1 — sin `url`/`title` (transversal absoluto)

- Ningún campo, tooltip, `aria-label`, atributo `title`, mensaje de error
  ni log puede contener `url` ni `title` en accesos a campos. Las menciones
  textuales explicativas en `PrivacyDashboardNeverSeen.tsx` son
  contractualmente correctas y **deben permanecer literales**.
- El test estructural §6 es la red automatizada; el handoff a Privacy
  Guardian es la red humana. Ambos son obligatorios.

### D4 — autoridad exclusiva (transitivo)

- Los tres comandos nuevos NO invocan `evaluate_transition` ni mutan
  `state_machine`. La consulta de bloqueo se hace en
  `apply_trust_action` antes de invocar `evaluate_transition`.
- El frontend NO infiere transiciones. Toda mutación pasa por comando.

### D8 — determinismo (transitivo)

- `get_detected_patterns` ordena por `last_seen` desc, desempate por
  `pattern_id` asc. **Verificable** por test si se considera necesario
  (no obligatorio según TS-2-004 §"Plan de Tests").
- `evaluate_transition` permanece pura: no abre `Connection`, no usa reloj,
  determinística bit-a-bit dado el mismo input (incluyendo
  `user_blocked_pre`).

### D14 — Privacy Dashboard completo bloquea cierre Fase 2

- T-2-004 cierra D14 con tres secciones (Recursos / Patrones / Estado) +
  bloque "Qué no veo nunca". La sección FS Watcher es **out-of-scope** en
  T-2-004 (TS-2-004 §"Decisiones del Technical Architect §4"). No
  implementar la sección FS Watcher en este HO.

### R12 — distinción transitiva

- `pattern_blocks.rs` distinto de `pattern_detector.rs`, `trust_scorer.rs`,
  `state_machine.rs`. Comentario de cabecera obligatorio (D1, D4, D8, R12).
- Los tres subcomponentes son **presentación**, no detección. Cualquier
  filtro/agrupación adicional vive en backend.

### Restricciones específicas T-2-004

- **No reabrir contratos cerrados** de TS-2-001 (`DetectedPattern`),
  TS-2-002 (`TrustScore`), TS-2-003 (`TrustStateEnum`, `Transition`,
  `TrustStateView`). Cualquier necesidad detectada se escala al
  Orchestrator antes de proceder.
- **Desviación declarada autorizada:** modificación de la firma de
  `state_machine::evaluate_transition` añadiendo `user_blocked_pre: bool`
  y eliminación del helper privado `user_blocked()`. AR-2-006 validará
  esta desviación según TS-2-004 §"Edición Mecánica".
- **No introducir telemetría:** ningún `fetch`, ningún POST a externos,
  ningún logger remoto. Frontend puro.
- **No introducir Vitest** salvo decisión explícita del implementador
  (TS-2-004 §"Plan de Tests" lo declara opcional, no bloqueante para
  AR-2-006). Si se añade, abrir HO ortogonal.
- **No introducir configuración de umbrales** ni historial de transiciones
  (Fase 3).
- **El modal de confirmación de Autonomous es obligatorio** y usa el texto
  literal declarado en `TrustStateSection.tsx::activateAutonomous`. No
  parafrasear ni omitir.

---

## Criterios de cierre (los 16 verificables de TS-2-004 + 2 externos)

El HO de cierre (a Technical Architect) debe reportar cada uno con
referencia verificable:

1. `src-tauri/src/pattern_blocks.rs` existe con schema y API declarados.
2. `mod pattern_blocks;` registrado en `lib.rs` línea 7→8.
3. Tres comandos Tauri nuevos implementados con firmas exactas y
   registrados en `invoke_handler!`.
4. `get_detected_patterns` ordena por `last_seen` desc + `pattern_id` asc.
5. Cinco tipos TypeScript nuevos en `src/types.ts` con shape exacto.
6. `evaluate_transition` con parámetro `user_blocked_pre: bool`. Helper
   privado `user_blocked()` eliminado.
7. `apply_trust_action` precomputa `user_blocked_pre`.
8. Test `test_learning_to_trusted_blocked_when_user_blocked` reactivado.
9. Los 11 tests previos actualizados con `false` como último param.
10. `PrivacyDashboard.tsx` modificado componiendo los tres subcomponentes.
11. `PatternsSection.tsx` con estructura exacta + helpers privados.
12. `TrustStateSection.tsx` con estructura exacta + modal obligatorio.
13. `PrivacyDashboardNeverSeen.tsx` con texto literal exacto.
14. Test estructural D1 presente y pasando.
15. `cargo test` reporta ≥ 49 tests / 0 failed / 0 ignored.
16. `npx tsc --noEmit` limpio.

### Criterios externos (no bloqueantes para `cargo test` pero requeridos
antes de AR-2-006)

- **`HO-PG-T-2-004-d1-review.md`** firmado por Privacy Guardian con
  `approved: true`. El implementador prepara y entrega:
  - Los cuatro archivos del dashboard (`PrivacyDashboard.tsx`,
    `PatternsSection.tsx`, `TrustStateSection.tsx`,
    `PrivacyDashboardNeverSeen.tsx`).
  - Cinco capturas de pantalla del dashboard:
    1. Estado Observing inicial (sin patrones).
    2. Estado Learning con al menos un patrón visible.
    3. Estado Trusted con botón "Activar preparación automática" visible.
    4. Estado Autonomous activo.
    5. Al menos un patrón bloqueado y otro desbloqueado en la misma vista.
  - Inspección manual de tooltips, hover-states y mensajes de error
    (red-path: comando Tauri devuelve error string).

---

## Cierre

Tras completar la implementación y verificar los 16 criterios + el handoff
firmado por Privacy Guardian, el Desktop Tauri Shell Specialist emite
**HO-017-phase-2-ts-2-004-impl-close.md** al Technical Architect solicitando
**AR-2-006** (revisión arquitectónica post-implementación). Sigue el patrón
de HO-014.

AR-2-006 verificará:
1. Los 16 criterios de TS-2-004 §"Criterios de Aprobación
   Post-Implementación" línea por línea.
2. La validez arquitectónica de la desviación declarada (eliminación del
   helper `user_blocked()` + parámetro `user_blocked_pre` en
   `evaluate_transition`) — TS-2-004 §"Edición Mecánica" se compromete a
   esta validación.
3. Coherencia D1 / D4 / D8 / D14 / R12 en el código entregado.

Si AR-2-006 aprueba sin correcciones, **T-2-004 queda cerrado y D14
satisfecho**. El Orchestrator emite notificación de cierre lógico de Fase 2
(a reserva de implementación de FS Watcher en paralelo, que se integrará
al dashboard mediante HO-FW-PD futuro sin reabrir TS-2-004).

Si durante la implementación se detecta:
- Ambigüedad real en TS-2-004 → escalar al Orchestrator antes de proceder
  con interpretación.
- Necesidad de modificar contrato cerrado (TS-2-001 / TS-2-002 /
  TS-2-003) → escalar al Orchestrator antes de proceder.
- Necesidad de desviación adicional respecto a la ya autorizada en TS-2-004
  §"Edición Mecánica" → escalar al Orchestrator antes de proceder.

La implementación queda autorizada únicamente con TS-2-004 firmada y este
HO emitido. Cualquier desviación silenciosa será revertida en AR-2-006.

---

## Firma

submitted_by: Orchestrator
submission_date: 2026-04-27
notes: TS-2-004 validada por Orchestrator 2026-04-27 contra los cuatro criterios de HO-015 §"Cierre". Las cinco decisiones del Technical Architect están tomadas explícitamente con justificación arquitectónica (postura b para persistencia de bloqueo; descomposición en tres subcomponentes; doble verificación D1; FS Watcher out-of-scope con cláusula de extensión; signatures como badges + JSON wire format). Los 16 criterios de aprobación son verificables línea por línea con anclas a archivos/funciones/tests confirmadas contra el código actual (`state_machine.rs:339-341` placeholder de `user_blocked`, `state_machine.rs:519-546` test #4 con `#[ignore]`, `lib.rs:7-8` orden alfabético de mods, `src/types.ts:84-99` bloque T-2-003). La cláusula de reactivación del test #4 está declarada explícitamente en TS-2-004 §"Edición Mecánica" + criterios 8-9 + §"Plan de Tests" #6. La desviación de la firma de `evaluate_transition` (parámetro `user_blocked_pre: bool` y eliminación del helper privado) es una **desviación declarada y justificada** respecto a la "edición mecánica única" de AR-2-005 — no es reapertura silenciosa, está documentada y AR-2-006 la validará. T-2-004 cierra D14 y, junto con la implementación de FS Watcher en paralelo, cierra Fase 2.
