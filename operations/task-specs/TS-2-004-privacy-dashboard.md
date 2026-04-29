# Task Spec — TS-2-004

document_id: TS-2-004
task_id: T-2-004
title: Privacy Dashboard completo — visibilidad y control total del usuario (D14)
phase: 2
produced_by: Technical Architect
status: APPROVED
date: 2026-04-27
depends_on: T-2-001 (Pattern Detector — AR-2-003), T-2-003 (State Machine — AR-2-005)
unblocks: cierre lógico de Fase 2 (D14 satisfecho); kickoff de Fase 3 una vez T-2-000 implementado en paralelo

---

## Distinción de Scope y D14

**Esta TS materializa el último entregable bloqueante de Fase 2 según D14.**

T-2-004 expande `src/components/PrivacyDashboard.tsx` (existente desde Fase
0b) con tres secciones nuevas, añade tres comandos Tauri sobre patrones, una
tabla auxiliar `pattern_blocks` en SQLCipher, los tipos TypeScript
correspondientes y la edición mecánica única del helper `user_blocked()` en
`state_machine.rs`. Cierra el gate D14 una vez aprobado AR-2-006.

### Qué materializa

- Expansión de `PrivacyDashboard.tsx` con las secciones **Recursos** (ya
  existe), **Patrones detectados** (nueva), **Estado de confianza** (nueva)
  y bloque "Qué no veo nunca" (texto literal — §"Texto literal del bloque
  privacidad").
- Tres comandos Tauri nuevos: `get_detected_patterns`, `block_pattern`,
  `unblock_pattern`.
- Tabla auxiliar `pattern_blocks` en SQLCipher (decisión documentada en
  §"Persistencia de bloqueo").
- Tipos TypeScript nuevos en `src/types.ts`: `PatternSummary`,
  `CategorySignatureItem`, `DomainSignatureItem`.
- Tres subcomponentes nuevos en `src/components/`: `PatternsSection.tsx`,
  `TrustStateSection.tsx`, `PrivacyDashboardNeverSeen.tsx` (decisión
  documentada en §"Estructura del componente").
- Edición mecánica única de `state_machine.rs::user_blocked()`
  (líneas 339-341 actuales) para consultar la tabla `pattern_blocks`.
- Reactivación del test `test_learning_to_trusted_blocked_when_user_blocked`
  (`state_machine.rs:519-546` — actualmente `#[ignore]`).

### Qué cierra

D14 — Privacy Dashboard completo es prerequisito bloqueante de Fase 3. Tras
aprobación de AR-2-006, Fase 2 queda lógicamente cerrada en su componente
funcional principal (FS Watcher implementación corre en paralelo y se
integra al dashboard cuando se complete — §"Sección FS Watcher").

### Qué NO materializa

- Historial de transiciones de la State Machine (Fase 3).
- Configuración de umbrales por el usuario (Fase 3 — calibración).
- Telemetría externa o envío de datos a servicios remotos (D1 transversal).
- Sección FS Watcher en el dashboard (out-of-scope, ver §"Sección FS
  Watcher").
- Modificaciones al contrato de `TrustStateView`, `TrustStateEnum`,
  `Transition` (cerrados por AR-2-005).
- Modificaciones al contrato de `DetectedPattern` (cerrado por AR-2-003).
- Modificaciones al contrato de `TrustScore` (cerrado por AR-2-004 —
  TS-2-002 NO se reabre; ver §"Persistencia de bloqueo").

---

## Decisiones del Technical Architect

Las cinco decisiones del checklist de HO-015 quedan tomadas explícitamente
con justificación arquitectónica.

### 1. Persistencia de bloqueo — opción (b): tabla `pattern_blocks`

**Decisión:** se introduce una tabla auxiliar `pattern_blocks` en SQLCipher.
TS-2-002 no se reabre. `TrustScore` permanece idéntico al cierre de AR-2-004.

**Justificación:**
- Preserva el cierre formal de TS-2-002. Reabrir el contrato de
  `TrustScore` requeriría addendum aprobado y rompería la propiedad
  arquitectónica documentada en AR-2-004 §O.5: "TrustScore es derivable
  on-demand desde Vec<DetectedPattern>". Añadir un campo `is_blocked` que
  necesita lookup adicional rompe esa pureza.
- El bloqueo es una preocupación de **persistencia y autoridad** (el
  usuario expresa una intención que sobrevive a reinicios y afecta el
  siguiente tick de la State Machine), no una preocupación de **scoring**
  (que es derivable y sin estado). Encapsularlo en su propia tabla refleja
  esta separación.
- La firma de `state_machine::user_blocked()` cambia de
  `fn user_blocked(_scores: &[TrustScore]) -> bool` a
  `fn user_blocked(conn: &Connection, scores: &[TrustScore]) -> Result<bool, StateMachineError>`.
  La cadena canónica de `commands.rs::apply_trust_action` queda intacta
  excepto por el paso adicional de pasar `conn` al helper (ya disponible).
- Idempotencia trivial: `INSERT OR IGNORE` para bloquear, `DELETE WHERE
  pattern_id = ?` para desbloquear.

### 2. Estructura del componente — descomposición en subcomponentes

**Decisión:** descomposición en tres subcomponentes en `src/components/`:
- `PatternsSection.tsx` — sección 2.
- `TrustStateSection.tsx` — sección 3.
- `PrivacyDashboardNeverSeen.tsx` — bloque "Qué no veo nunca".

`PrivacyDashboard.tsx` queda como contenedor que compone los subcomponentes
(la sección "Recursos" existente se preserva inline para evitar churn
gratuito).

**Justificación:**
- El dashboard expandido sin descomponer rondaría las 350-400 líneas con
  cuatro responsabilidades claramente separadas (recursos / patrones /
  estado / nunca-visto). La legibilidad cae rápidamente y los tests por
  sección requieren montar el árbol completo.
- Cada subcomponente recibe sus props tipadas y se testea en aislamiento
  (Vitest si el HO de implementación decide añadirlo, o mediante
  inspección estructural mínima — ver §"Plan de Tests").
- Coherente con el resto de `src/components/` (PanelA, PanelB, PanelC,
  EpisodePanel, AnticipatedWorkspace existen como componentes hermanos).
- El bloque "Qué no veo nunca" merece subcomponente propio porque el
  texto literal (D1) es un activo contractual que no debe diluirse en el
  contenedor.

### 3. Verificación textual D1 — ambos mecanismos

**Decisión:** se exige **ambos** mecanismos en paralelo:

- **(i) Test estructural automatizado** — un test de Rust en
  `commands.rs` (sección de tests) que use `include_str!` sobre
  `PrivacyDashboard.tsx` y los tres subcomponentes nuevos buscando los
  identificadores prohibidos. Implementado en `commands.rs` (no en frontend)
  por simplicidad de framework: el suite Rust ya está activo y `cargo test`
  es la verificación canónica de la fase.
- **(ii) Handoff explícito a Privacy Guardian** — antes de cerrar
  AR-2-006, el implementador entrega para revisión los cuatro archivos del
  dashboard. Privacy Guardian firma un memo en
  `operations/handoffs/HO-PG-T-2-004-d1-review.md` confirmando ausencia de
  exposición de `url`/`title` en cualquier estado de UI (incluyendo
  errores, tooltips, hover-states, `aria-labels`).

**Justificación:**
- (i) es automatizable y de coste cero por iteración: garantiza que las
  literales prohibidas no aparecen en el código fuente.
- (ii) cubre lo que (i) no puede: campos compuestos en runtime,
  serialización inesperada de tipos derivados, y el juicio humano sobre UX
  donde "lo razonable" pueda colarse. D1 es absoluto y merece doble red.
- El doble mecanismo es coherente con el patrón D4 de TS-2-002 / TS-2-003
  (test estructural automatizado) **y** la práctica establecida de revisión
  de Privacy Guardian (handoff explícito antes de aprobar AR).

### 4. Sección FS Watcher — out-of-scope

**Decisión:** la sección "FS Watcher" del dashboard queda **fuera** del
scope de T-2-004.

**Justificación:**
- Verificación al momento del drafting: `src-tauri/src/fs_watcher.rs` no
  existe. Solo TS-2-000 (delimitación documental, AR-2-002) está aprobado.
  La implementación de FS Watcher es una tarea independiente que progresa
  en paralelo a T-2-004.
- Bloquear T-2-004 hasta que FS Watcher esté implementado retrasaría el
  cierre de D14 sin beneficio: la State Machine y los patrones son ya el
  corpus principal del dashboard. La sección FS Watcher es un añadido
  ortogonal.
- **Cláusula de extensión:** cuando `fs_watcher.rs` se implemente y
  apruebe (HO de cierre + AR correspondiente), se emitirá HO-FW-PD para
  añadir la sección "FS Watcher" al dashboard como extensión incremental,
  sin reabrir TS-2-004. Ese HO declarará el contrato de los nuevos
  comandos Tauri (e.g. `get_fs_watcher_status`, `stop_fs_watcher`) y la
  expansión del subcomponente correspondiente.
- T-2-004 cierra D14 con tres secciones (Recursos / Patrones / Estado),
  no cuatro. Esto es coherente con D14 ("Privacy Dashboard completo"
  significa completo respecto a lo que existe en código, no respecto a
  features futuros).

### 5. Representación legible de signatures — formato

**Decisión:** las signatures se exponen en el frontend con dos
representaciones complementarias:

- **Lista compacta legible:** array de `{ category | domain, weight }`
  ordenado descendente por `weight`. Cada elemento se renderiza como
  badge con `weight` formateado a porcentaje (e.g. "Documentación 45%",
  "Trabajo 30%", "Reuniones 25%"). Máximo cinco badges visibles; el resto
  se agrupa en un "+N más" sin tooltip detallado (D1: ningún tooltip
  expone identificadores derivados de `url`/`title`).
- **Wire format JSON:** array crudo `Vec<{ category: string, weight: number }>`
  serializado tal cual desde Rust. La traducción a badges es
  responsabilidad del subcomponente `PatternsSection.tsx`.

**Justificación:**
- Mantener la estructura completa en el wire (no concatenar a string) deja
  flexibilidad al frontend para reordenar, filtrar o ajustar formato sin
  cambios en backend.
- El formato badge con porcentaje es legible para usuario no técnico
  (mismo idioma que el componente PanelA existente) y comunica peso
  relativo sin requerir interpretación de UUIDs ni bitmasks.
- Cap de 5 badges + "+N más" evita overflow visual cuando una signature
  tiene 7-10 categorías; el desplegable detallado se difiere a un futuro
  sprint si la UX lo justifica (no en T-2-004).
- `temporal_window` (`time_bucket` + `day_of_week_mask`) **no se expone
  como bitmask** sino traducido a string corta legible: e.g. "Tarde —
  L,M,X,J,V" (días traducidos a iniciales en español, junción con coma).
  Función helper `formatTemporalWindow(tw): string` en
  `PatternsSection.tsx`.

---

## Contrato de Tipos TypeScript

Añadir tras el bloque T-2-003 ya presente en `src/types.ts:84-99`:

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

Notas contractuales:
- `PatternSummary` excluye explícitamente `first_seen` (no necesario para
  UI del dashboard; reduce superficie). Si una iteración futura lo
  necesita, se añade vía addendum sin romper consumidores existentes.
- `is_blocked` se materializa en backend al construir el `PatternSummary`
  (lookup en `pattern_blocks`). El frontend nunca decide bloqueo local; el
  estado autoritativo es la tabla SQLCipher.
- `TimeBucket` se declara como union literal en TypeScript coherente con
  la serialización de `pattern_detector::TimeBucket` (Rust enum sin
  payload → string en JSON).
- `day_of_week_mask` se preserva como `number` (bitmask 7 bits) en el
  contrato; la traducción a string legible es responsabilidad exclusiva
  del subcomponente `PatternsSection.tsx`.

**No reabrir:** `TrustStateEnum`, `Transition`, `TrustStateView` (TS-2-003
cerrado por AR-2-005). T-2-004 los importa sin modificación.

---

## Contratos de Comandos Tauri Nuevos

### `get_detected_patterns(state) -> Result<Vec<PatternSummary>, String>`

```rust
#[tauri::command]
pub fn get_detected_patterns(state: State<'_, DbState>) -> Result<Vec<PatternSummary>, String>;
```

**Comportamiento:**
1. `now_unix = SystemTime::now()…` (igual patrón que `apply_trust_action`).
2. Lock del mutex de `DbState`; obtener `&Connection`.
3. `pattern_blocks::ensure_schema(conn)?` (idempotente).
4. `let patterns = pattern_detector::detect_patterns(conn, &PatternConfig::default())?`.
5. `let blocked: HashSet<String> = pattern_blocks::list_blocked(conn)?`.
6. Proyectar `Vec<DetectedPattern>` → `Vec<PatternSummary>` con
   `is_blocked = blocked.contains(&pattern_id)`.
7. Ordenar **determinísticamente** (D8 transitivo): `last_seen` desc,
   desempate por `pattern_id` ascendente.
8. Devolver `Vec<PatternSummary>`.

### `block_pattern(state, pattern_id: String) -> Result<(), String>`

```rust
#[tauri::command]
pub fn block_pattern(state: State<'_, DbState>, pattern_id: String) -> Result<(), String>;
```

**Comportamiento:**
1. `now_unix = …`.
2. Lock + `&Connection`.
3. `pattern_blocks::ensure_schema(conn)?`.
4. `pattern_blocks::block(conn, &pattern_id, now_unix)?` —
   `INSERT OR IGNORE INTO pattern_blocks (pattern_id, blocked_at) VALUES (?1, ?2)`.
5. `Ok(())`.

Idempotente: bloquear un patrón ya bloqueado es no-op (no reescribe
`blocked_at`).

### `unblock_pattern(state, pattern_id: String) -> Result<(), String>`

```rust
#[tauri::command]
pub fn unblock_pattern(state: State<'_, DbState>, pattern_id: String) -> Result<(), String>;
```

**Comportamiento:**
1. Lock + `&Connection`.
2. `pattern_blocks::ensure_schema(conn)?`.
3. `pattern_blocks::unblock(conn, &pattern_id)?` —
   `DELETE FROM pattern_blocks WHERE pattern_id = ?1`.
4. `Ok(())`.

Idempotente: desbloquear un patrón no bloqueado es no-op (`DELETE` con
0 filas afectadas).

**Restricciones D4:** ninguno de los tres comandos invoca
`evaluate_transition`, `score_patterns`, ni mutaciones de
`state_machine`. El bloqueo afecta el siguiente tick automático **vía
consulta de `state_machine::user_blocked` a `pattern_blocks`**, no por
invocación recíproca.

**Registro en `lib.rs`:** los tres comandos se añaden al
`invoke_handler!` tras los comandos T-2-003 (líneas actuales 75-77),
manteniendo orden lógico:

```rust
commands::get_trust_state,
commands::reset_trust_state,
commands::enable_autonomous_mode,
commands::get_detected_patterns,
commands::block_pattern,
commands::unblock_pattern,
```

---

## Persistencia: tabla `pattern_blocks`

### Módulo nuevo: `src-tauri/src/pattern_blocks.rs`

Módulo independiente para encapsular el schema y operaciones de la tabla
auxiliar. Coherente con el patrón de TS-2-003 §"Persistencia": el módulo
dueño del schema lo gestiona.

**Comentario de cabecera obligatorio:**
```rust
// Pattern Blocks — Fase 2 (T-2-004)
// Propósito: persistir intención del usuario de bloquear patrones detectados.
// Consultado por state_machine::user_blocked() en cada tick automático.
// Distinto de pattern_detector.rs (detección) y state_machine.rs (autoridad) — R12.
// Constraints activos: D1 (sin url/title — solo pattern_id), D4 (no decide
// transiciones — solo persiste intención), D8 (operaciones deterministas).
```

**Schema:**
```sql
CREATE TABLE IF NOT EXISTS pattern_blocks (
    pattern_id TEXT PRIMARY KEY,
    blocked_at INTEGER NOT NULL
);
```

**API pública:**
```rust
pub(crate) fn ensure_schema(conn: &Connection) -> Result<(), rusqlite::Error>;
pub(crate) fn block(conn: &Connection, pattern_id: &str, now_unix: i64) -> Result<(), rusqlite::Error>;
pub(crate) fn unblock(conn: &Connection, pattern_id: &str) -> Result<(), rusqlite::Error>;
pub(crate) fn list_blocked(conn: &Connection) -> Result<HashSet<String>, rusqlite::Error>;
pub(crate) fn is_blocked(conn: &Connection, pattern_id: &str) -> Result<bool, rusqlite::Error>;
```

Visibilidad estricta `pub(crate)` (mismo principio que `state_machine`):
solo `commands.rs` y `state_machine.rs` consumen estas funciones.

**Registro en `lib.rs`:** `mod pattern_blocks;` añadido en orden
alfabético entre `pattern_detector` (línea 7 actual) y `raw_event` (línea 8
actual):

```
mod pattern_blocks;
mod pattern_detector;
```

---

## Edición Mecánica de `state_machine::user_blocked()`

Materialización del helper actualmente placeholder
(`state_machine.rs:339-341`) según postura tomada en §"Persistencia de
bloqueo".

### Antes (T-2-003)

```rust
fn user_blocked(_scores: &[TrustScore]) -> bool {
    false
}
```

### Después (T-2-004)

```rust
/// Consulta la tabla `pattern_blocks` para determinar si alguno de los
/// patrones presentes en `scores` está marcado como bloqueado por el usuario.
/// Materialización post-T-2-004 (decisión de TS-2-004 §"Persistencia de bloqueo").
fn user_blocked(
    conn: &Connection,
    scores: &[TrustScore],
) -> Result<bool, StateMachineError> {
    if scores.is_empty() {
        return Ok(false);
    }
    for score in scores {
        if pattern_blocks::is_blocked(conn, &score.pattern_id)? {
            return Ok(true);
        }
    }
    Ok(false)
}
```

### Cambios derivados en `evaluate_transition`

La firma de `evaluate_transition` recibe `conn: &Connection` adicional
únicamente para propagar al helper. Alternativa contractualmente preferida
(menor superficie de cambio):

**Mantener la firma actual de `evaluate_transition`** y mover la consulta
de `user_blocked` a `commands.rs::apply_trust_action`. El resultado se
empaqueta en un nuevo argumento `user_blocked: bool` (precomputado) o se
añade un campo `is_blocked: bool` a una estructura intermedia consumida
por `evaluate_transition`.

**Decisión arquitectónica de TS-2-004:** se sigue la **alternativa
preferida**: `evaluate_transition` recibe un nuevo parámetro
`user_blocked_pre: bool` calculado en `commands.rs` antes de la llamada.
La firma queda:

```rust
pub fn evaluate_transition(
    scores: &[TrustScore],
    current: TrustStateEnum,
    last_transition_at: i64,
    user_action: Option<UserAction>,
    now_unix: i64,
    config: &StateMachineConfig,
    user_blocked_pre: bool,  // NUEVO
) -> Result<TrustState, StateMachineError>
```

Y el helper privado `user_blocked()` desaparece — la consulta se hace en
`commands.rs::apply_trust_action`:

```rust
let blocked_ids = pattern_blocks::list_blocked(conn).map_err(|e| e.to_string())?;
let user_blocked_pre = scores.iter().any(|s| blocked_ids.contains(&s.pattern_id));
let new_state = state_machine::evaluate_transition(
    &scores, current, last_ts, user_action, now_unix,
    &StateMachineConfig::default(), user_blocked_pre,
)?;
```

**Justificación de esta elección:**
- Preserva D8 estricto en `state_machine::evaluate_transition`: la función
  permanece pura (sin acceso a SQLCipher), determinística bit-a-bit dado
  el mismo input.
- Preserva la propiedad arquitectónica de TS-2-003: `state_machine.rs` no
  abre `Connection` desde dentro de `evaluate_transition`. Solo
  `ensure_schema`, `load_state`, `save_state` acceden a la BD, y solo
  desde `commands.rs`.
- La cadena `pattern_blocks → user_blocked_pre → evaluate_transition` se
  compone exclusivamente en `commands.rs::apply_trust_action`, coherente
  con el principio D4 de TS-2-003 §"Restricción D4 — Autoridad
  Exclusiva".
- AR-2-005 declaró el helper privado `user_blocked()` como "edición
  mecánica única". Esta decisión modifica esa expectativa: en lugar de
  reemplazar el cuerpo del helper, el helper se elimina y la consulta se
  externaliza. Es una desviación menor justificada por preservar D8
  estricto en `evaluate_transition`. AR-2-006 deberá validar.

**Test #4 reactivado:** `test_learning_to_trusted_blocked_when_user_blocked`
en `state_machine.rs:519-546` se modifica de `#[ignore]` a activo y la
aserción cambia para usar el nuevo parámetro:

```rust
#[test]
fn test_learning_to_trusted_blocked_when_user_blocked() {
    let scores = vec![
        score("p1", 0.9, ConfidenceTier::High),
        score("p2", 0.9, ConfidenceTier::High),
        score("p3", 0.9, ConfidenceTier::High),
    ];
    let result = evaluate_transition(
        &scores,
        TrustStateEnum::Learning,
        NOW - 1000,
        None,
        NOW,
        &StateMachineConfig::default(),
        true,  // user_blocked_pre = true → no debe promocionar
    )
    .unwrap();
    assert_eq!(
        result.current_state,
        TrustStateEnum::Learning,
        "user_blocked = true bloquea Learning → Trusted"
    );
}
```

**Tests existentes:** los 11 tests activos de `state_machine.rs` que llaman
`evaluate_transition` se actualizan mecánicamente para pasar `false` como
último parámetro (ningún test previo asume bloqueo). 11 ediciones triviales,
verificables por `cargo test`.

---

## Estructura del Componente

### Contenedor: `src/components/PrivacyDashboard.tsx` (modificado)

Imports nuevos:
```typescript
import { PatternsSection } from "./PatternsSection";
import { TrustStateSection } from "./TrustStateSection";
import { PrivacyDashboardNeverSeen } from "./PrivacyDashboardNeverSeen";
```

Estructura del JSX dentro del panel (cuando `open === true`):

```tsx
<div className="privacy-dashboard__panel" role="dialog" ...>
  <header className="privacy-dashboard__header">{/* sin cambios */}</header>

  {stats ? (
    <div className="privacy-dashboard__body">
      <section aria-labelledby="pd-recursos">
        <h4 id="pd-recursos">Recursos almacenados</h4>
        {/* contenido existente: count, categories, domains, clear button */}
      </section>

      <PatternsSection />

      <TrustStateSection />

      <PrivacyDashboardNeverSeen />
    </div>
  ) : (
    <p className="privacy-dashboard__loading">Cargando…</p>
  )}
</div>
```

La sección "Recursos" preserva el código existente (líneas 64-105 del
componente actual) sin modificación funcional. Solo se envuelve en un
`<section aria-labelledby>` para coherencia con los nuevos hermanos. El
botón "Eliminar todos los datos" preserva su comportamiento actual.

### Subcomponente: `src/components/PatternsSection.tsx`

```tsx
import { useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import type { PatternSummary } from "../types";

export function PatternsSection() {
  const [patterns, setPatterns] = useState<PatternSummary[] | null>(null);
  const [pendingId, setPendingId] = useState<string | null>(null);

  useEffect(() => { refresh(); }, []);

  async function refresh() {
    try {
      const list = await invoke<PatternSummary[]>("get_detected_patterns");
      setPatterns(list);
    } catch {
      setPatterns([]);
    }
  }

  async function toggle(p: PatternSummary) {
    setPendingId(p.pattern_id);
    try {
      if (p.is_blocked) {
        await invoke("unblock_pattern", { patternId: p.pattern_id });
      } else {
        await invoke("block_pattern", { patternId: p.pattern_id });
      }
      await refresh();
    } finally {
      setPendingId(null);
    }
  }

  if (patterns === null) return <section><h4>Patrones detectados</h4><p>Cargando…</p></section>;
  if (patterns.length === 0) {
    return (
      <section aria-labelledby="pd-patrones">
        <h4 id="pd-patrones">Patrones detectados</h4>
        <p>Aún no se han detectado patrones recurrentes.</p>
      </section>
    );
  }

  return (
    <section aria-labelledby="pd-patrones">
      <h4 id="pd-patrones">Patrones detectados</h4>
      <ul>
        {patterns.map((p) => (
          <li key={p.pattern_id} className={p.is_blocked ? "is-blocked" : undefined}>
            <div className="pattern__label">{p.label}</div>
            <div className="pattern__signatures">
              {p.category_signature.slice(0, 5).map((c) => (
                <span key={c.category} className="pattern__badge">
                  {c.category} {Math.round(c.weight * 100)}%
                </span>
              ))}
              {p.category_signature.length > 5 && (
                <span className="pattern__badge pattern__badge--more">
                  +{p.category_signature.length - 5} más
                </span>
              )}
            </div>
            <div className="pattern__meta">
              {formatTemporalWindow(p.temporal_window)} · {p.frequency} veces ·
              {" "}última hace {formatRelative(p.last_seen)}
            </div>
            <button
              onClick={() => toggle(p)}
              disabled={pendingId === p.pattern_id}
              aria-label={p.is_blocked ? "Desbloquear patrón" : "Bloquear patrón"}
            >
              {p.is_blocked ? "Desbloquear" : "Bloquear"}
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}

function formatTemporalWindow(tw: { time_bucket: string; day_of_week_mask: number }): string {
  const bucketLabel = { Morning: "Mañana", Afternoon: "Tarde", Evening: "Noche" }[tw.time_bucket] ?? tw.time_bucket;
  const days = ["L", "M", "X", "J", "V", "S", "D"];
  const active = days.filter((_, i) => (tw.day_of_week_mask & (1 << i)) !== 0).join(",");
  return active ? `${bucketLabel} — ${active}` : bucketLabel;
}

function formatRelative(unixSec: number): string {
  const diffSec = Math.max(0, Math.floor(Date.now() / 1000) - unixSec);
  if (diffSec < 3600) return "menos de 1 h";
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)} h`;
  return `${Math.floor(diffSec / 86400)} días`;
}
```

**Restricción D1 vinculante:** `formatTemporalWindow` y `formatRelative`
no acceden a campos de `url`/`title`. Auditable por inspección directa del
subcomponente.

### Subcomponente: `src/components/TrustStateSection.tsx`

```tsx
import { useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import type { TrustStateView, TrustStateEnum } from "../types";

const STATE_LABEL: Record<TrustStateEnum, string> = {
  Observing: "Observando",
  Learning: "Aprendiendo",
  Trusted: "Confiando",
  Autonomous: "Autónomo",
};

export function TrustStateSection() {
  const [view, setView] = useState<TrustStateView | null>(null);
  const [pending, setPending] = useState(false);

  useEffect(() => { refresh(); }, []);

  async function refresh() {
    try { setView(await invoke<TrustStateView>("get_trust_state")); }
    catch { setView(null); }
  }

  async function reset() {
    if (!confirm("¿Resetear el estado de confianza? El sistema volverá a Observando.")) return;
    setPending(true);
    try { setView(await invoke<TrustStateView>("reset_trust_state")); }
    finally { setPending(false); }
  }

  async function activateAutonomous() {
    const ok = confirm(
      "Vas a activar el modo autónomo.\n\n" +
      "El sistema aplicará automáticamente las preparaciones que coinciden con tus patrones de confianza, " +
      "sin pedir confirmación cada vez. Podrás resetear esto cuando quieras.\n\n" +
      "¿Confirmas la activación?"
    );
    if (!ok) return;
    setPending(true);
    try {
      setView(await invoke<TrustStateView>("enable_autonomous_mode", { confirmed: true }));
    } finally {
      setPending(false);
    }
  }

  if (!view) return <section><h4>Estado de confianza</h4><p>Cargando…</p></section>;

  return (
    <section aria-labelledby="pd-confianza">
      <h4 id="pd-confianza">Estado de confianza</h4>
      <p className="trust__current">
        Estado actual: <strong>{STATE_LABEL[view.current_state]}</strong>
      </p>
      <p className="trust__meta">
        Patrones activos: {view.active_patterns_count} ·
        {" "}última transición hace {formatRelative(view.last_transition_at)}
      </p>
      <div className="trust__actions">
        <button onClick={reset} disabled={pending}>Resetear confianza</button>
        {view.current_state === "Trusted" && (
          <button onClick={activateAutonomous} disabled={pending} className="trust__autonomous">
            Activar preparación automática
          </button>
        )}
      </div>
    </section>
  );
}

function formatRelative(unixSec: number): string {
  const diffSec = Math.max(0, Math.floor(Date.now() / 1000) - unixSec);
  if (diffSec < 3600) return "menos de 1 h";
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)} h`;
  return `${Math.floor(diffSec / 86400)} días`;
}
```

### Subcomponente: `src/components/PrivacyDashboardNeverSeen.tsx`

Texto literal — **no parafrasear** durante implementación:

```tsx
export function PrivacyDashboardNeverSeen() {
  return (
    <section aria-labelledby="pd-nunca-veo" className="privacy-dashboard__never-seen">
      <h4 id="pd-nunca-veo">Qué no veo nunca</h4>
      <ul>
        <li>La URL completa de los recursos que guardas — solo veo el dominio.</li>
        <li>El título de las páginas — se cifra y nunca se descifra para análisis.</li>
        <li>El contenido de las páginas — el sistema nunca lo lee.</li>
        <li>Tu identidad ni nada que pueda identificarte fuera de este dispositivo.</li>
      </ul>
      <p className="privacy-dashboard__never-seen-note">
        Todo lo anterior se almacena cifrado localmente con AES-256-GCM y nunca se transmite.
      </p>
    </section>
  );
}
```

---

## Restricción D1 — Verificación Doble

### Mecanismo (i): test estructural automatizado

Test añadido en `src-tauri/src/commands.rs` (sección de tests del módulo o
test de integración separado):

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

**Nota:** la lista de tokens prohibidos NO incluye literales como
`"url"` o `"title"` desnudas porque
`PrivacyDashboardNeverSeen.tsx` los menciona en texto explicativo. La
discriminación es entre **menciones textuales** (permitidas — explican al
usuario qué NO se ve) y **accesos a campos** (prohibidos — exposición real
de datos).

### Mecanismo (ii): handoff a Privacy Guardian

Antes de cerrar AR-2-006, el implementador entrega a Privacy Guardian:
- Los cuatro archivos: `PrivacyDashboard.tsx`, `PatternsSection.tsx`,
  `TrustStateSection.tsx`, `PrivacyDashboardNeverSeen.tsx`.
- Capturas de pantalla del dashboard en al menos cinco estados:
  Observing inicial / Learning con patrones / Trusted con botón Autonomous
  / Autonomous activo / al menos un patrón bloqueado y otro desbloqueado.
- Inspección manual de tooltips, hover-states, mensajes de error en
  red-path (e.g. comando Tauri devuelve error string).

Privacy Guardian firma `HO-PG-T-2-004-d1-review.md` con uno de:
- `approved: true` — AR-2-006 puede proceder.
- `approved: false` — bloquea AR-2-006 con lista de hallazgos.

---

## Cadena de Invocación y D4 Transitivo

T-2-004 **no introduce nueva autoridad de transición**. Los flujos del
dashboard que afectan estado son:

| Acción del usuario | Comando invocado | Efecto |
|---|---|---|
| Abrir dashboard | `get_privacy_stats`, `get_detected_patterns`, `get_trust_state` | Lectura. No transiciones. |
| Bloquear patrón | `block_pattern(pattern_id)` | Inserta en `pattern_blocks`. La transición efectiva (si la hay) ocurre en el siguiente tick automático cuando el usuario abra el dashboard de nuevo y `get_trust_state` invoque `apply_trust_action` que invoque `evaluate_transition`. La autoridad sigue siendo `state_machine`. |
| Desbloquear patrón | `unblock_pattern(pattern_id)` | Elimina de `pattern_blocks`. Mismo principio que bloquear. |
| Resetear confianza | `reset_trust_state` | Comando ya existente (T-2-003). Sin cambios. |
| Activar autónomo | `enable_autonomous_mode(true)` | Comando ya existente (T-2-003). El modal de confirmación es UX, no autoridad. |
| Eliminar todos los datos | `clear_all_resources` | Comando ya existente (Fase 0b). Sin cambios. |

**Principio D4 transitivo:** "T-2-004 no decide transiciones; solicita
estado y solicita acciones a la State Machine. La autoridad permanece
exclusivamente en `state_machine.rs`."

Verificable por inspección de los tres subcomponentes nuevos: ninguno
contiene lógica que infiera transiciones localmente. Toda mutación de
estado pasa por un comando Tauri.

---

## Plan de Tests

### Tests Rust nuevos (mínimos obligatorios)

1. `pattern_blocks::tests::test_block_unblock_round_trip` — bloquear,
   `is_blocked` devuelve `true`, desbloquear, `is_blocked` devuelve
   `false`.
2. `pattern_blocks::tests::test_block_idempotent` — bloquear dos veces el
   mismo `pattern_id` no falla y `list_blocked` devuelve un solo elemento.
3. `pattern_blocks::tests::test_unblock_idempotent` — desbloquear un
   `pattern_id` no bloqueado no falla.
4. `pattern_blocks::tests::test_list_blocked_returns_set` — bloquear N
   patrones, `list_blocked` devuelve los N.
5. `commands::tests::test_no_url_or_title_in_dashboard_components` — test
   estructural D1 declarado en §"Verificación Doble (i)".

### Tests Rust modificados

6. `state_machine::tests::test_learning_to_trusted_blocked_when_user_blocked`
   — eliminar `#[ignore]`, actualizar firma con
   `user_blocked_pre = true`, aserción `current_state == Learning`.
7. Los **11 tests activos previos** que invocan `evaluate_transition` —
   añadir `false` (o `user_blocked_pre`) como último argumento.
   Edición mecánica trivial; sin cambios semánticos.

### Verificación de no-regresión

`cargo test` debe reportar:
- **Mínimo 49 tests** ejecutados (45 actuales + 4 nuevos de
  `pattern_blocks` — el test estructural D1 cuenta como uno aparte =
  potencialmente 50).
- **0 failed**, **0 ignored** (el #4 deja de estar ignored).

`npx tsc --noEmit` debe quedar limpio tras añadir los tipos en
`src/types.ts` y los tres subcomponentes.

### Tests frontend (opcional, no obligatorio para AR-2-006)

Se difiere a una decisión del implementador si Vitest se introduce en este
sprint o no. **No es bloqueante** para cierre de T-2-004 — la verificación
funcional se cubre por: test estructural D1 (Rust), revisión de Privacy
Guardian, e inspección manual de las cinco capturas requeridas. La
introducción de Vitest es una mejora de tooling ortogonal y se difiere a
HO independiente si se considera.

---

## Restricciones No Negociables

### D1 — sin `url`/`title`

- `PatternSummary` no contiene `url`, `title`, `link`, `href`,
  `bookmark_url`, `page_title` ni variantes. Verificado por inspección
  textual de `src/types.ts` y por el test estructural automatizado.
- Los cuatro archivos de UI (`PrivacyDashboard.tsx`, `PatternsSection.tsx`,
  `TrustStateSection.tsx`, `PrivacyDashboardNeverSeen.tsx`) no acceden a
  campos sensibles. Mencionar `url` y `title` como **texto explicativo**
  (en `PrivacyDashboardNeverSeen.tsx`) es explícitamente parte del valor
  del dashboard — la prohibición es **acceso a campos**, no mención
  textual.
- `pattern_blocks` solo persiste `pattern_id` (UUID) y `blocked_at`
  (timestamp). Sin posibilidad transitiva de exposición.

### D4 — autoridad exclusiva (transitivo)

- T-2-004 NO modifica la firma pública de `evaluate_transition` excepto
  por la adición de un parámetro `user_blocked_pre: bool` precomputado en
  `commands.rs`. El cambio se documenta en §"Edición Mecánica".
- T-2-004 NO introduce comandos Tauri que invoquen
  `state_machine::evaluate_transition` recíprocamente. Los tres comandos
  nuevos (`get_detected_patterns`, `block_pattern`, `unblock_pattern`)
  operan exclusivamente sobre `pattern_detector`, `pattern_blocks` y la
  proyección a `PatternSummary`.
- El frontend NO infiere transiciones. Toda mutación pasa por comando.

### D8 — determinismo (transitivo)

- `get_detected_patterns` ordena `Vec<PatternSummary>` por `last_seen`
  desc, desempate por `pattern_id` asc. Determinístico.
- `pattern_blocks::list_blocked` no garantiza orden (es `HashSet`), pero
  la consulta `is_blocked(pattern_id)` es determinística.
- `evaluate_transition` permanece determinística bit-a-bit dado el mismo
  `(scores, current, last_transition_at, user_action, now_unix, config,
  user_blocked_pre)`. La adición del parámetro precomputado **no rompe**
  D8: la función no toca SQLCipher ni el reloj.

### D14 — Privacy Dashboard completo bloquea cierre Fase 2

- T-2-004 cierra D14 con tres secciones (Recursos / Patrones / Estado) +
  bloque "Qué no veo nunca". La sección FS Watcher es out-of-scope (ver
  §"Sección FS Watcher") con cláusula de extensión declarada.
- Tras AR-2-006 aprobado, Fase 2 queda lógicamente cerrada en su
  componente funcional principal. T-2-000 implementación corre en
  paralelo y se integra al dashboard cuando se complete.

### R12 — distinción transitiva

- `pattern_blocks.rs` es módulo distinto de `pattern_detector.rs`,
  `trust_scorer.rs`, `state_machine.rs`. Comentario de cabecera obligatorio
  declara la distinción.
- Los tres subcomponentes son **presentación**, no detección. Cualquier
  filtro o agrupación adicional vive en backend (en el comando Tauri o en
  `pattern_detector.rs`), no en el frontend.

### Restricciones específicas T-2-004

- **No reabrir contratos cerrados:** TS-2-001 (`DetectedPattern`),
  TS-2-002 (`TrustScore`), TS-2-003 (`TrustStateView`, `TrustStateEnum`,
  `Transition`). Cualquier necesidad de modificación se escala al
  Orchestrator antes de proceder.
- **No introducir telemetría:** ningún `fetch`, ningún POST a externos,
  ningún logger remoto. Frontend puro.
- **No introducir configuración de umbrales:** la UI es lectura del estado
  actual + acciones del usuario, no calibración (Fase 3).
- **No exponer historial de transiciones:** Fase 3.
- **El modal de confirmación de Autonomous es obligatorio** y usa el
  texto literal declarado en `TrustStateSection.tsx::activateAutonomous`.
  No es opcional ni configurable.

---

## Criterios de Aprobación Post-Implementación

AR-2-006 verificará los siguientes 16 criterios. Cada uno con referencia
verificable a líneas de código tras implementación.

1. `src-tauri/src/pattern_blocks.rs` existe como módulo independiente con
   schema `pattern_blocks (pattern_id TEXT PRIMARY KEY, blocked_at INTEGER NOT NULL)`,
   comentario de cabecera obligatorio (D1, D4, D8, R12), y las cinco
   funciones `pub(crate)` declaradas en §"Persistencia".
2. `mod pattern_blocks;` registrado en `lib.rs` en orden alfabético entre
   `mod pattern_detector;` (línea 7 actual) y `mod raw_event;` (línea 8
   actual).
3. Tres comandos Tauri nuevos (`get_detected_patterns`, `block_pattern`,
   `unblock_pattern`) implementados con firmas exactas y registrados en el
   `invoke_handler!` tras los comandos T-2-003.
4. Comando `get_detected_patterns` ordena el resultado por `last_seen`
   desc, desempate por `pattern_id` asc (verificable por test de
   ordenación).
5. Tipos TypeScript nuevos en `src/types.ts`: `CategorySignatureItem`,
   `DomainSignatureItem`, `TimeBucket`, `TemporalWindowView`,
   `PatternSummary` con shape exacto declarado en §"Contrato de Tipos".
6. Edición de `state_machine::evaluate_transition` con parámetro adicional
   `user_blocked_pre: bool`. Helper privado `user_blocked()` eliminado.
7. `commands.rs::apply_trust_action` actualizado para precomputar
   `user_blocked_pre` consultando `pattern_blocks::list_blocked` antes de
   invocar `evaluate_transition`.
8. Test `test_learning_to_trusted_blocked_when_user_blocked` reactivado
   (sin `#[ignore]`), aserción correcta con `user_blocked_pre = true`.
9. Los 11 tests previos que invocan `evaluate_transition` actualizados
   con `false` como último parámetro; ninguno falla.
10. `src/components/PrivacyDashboard.tsx` modificado para componer los tres
    subcomponentes nuevos. Sección "Recursos" preservada sin churn
    funcional.
11. `src/components/PatternsSection.tsx` existe con la estructura exacta
    declarada en §"Estructura del Componente". Botón Bloquear/Desbloquear
    funcional. Manejo de lista vacía con mensaje declarado.
12. `src/components/TrustStateSection.tsx` existe con la estructura exacta.
    Modal de confirmación obligatorio antes de
    `enable_autonomous_mode(true)` con texto literal declarado.
13. `src/components/PrivacyDashboardNeverSeen.tsx` existe con texto
    literal **exacto** del bloque (sin parafraseo).
14. Test estructural D1 (`test_no_url_or_title_in_dashboard_components`)
    presente en `commands.rs` y pasando.
15. `cargo test` reporta ≥ 49 tests / 0 failed / 0 ignored.
16. `npx tsc --noEmit` limpio.

### Criterios externos (no bloqueantes para `cargo test` pero requeridos
antes de AR-2-006 firmado)

- Handoff `HO-PG-T-2-004-d1-review.md` firmado por Privacy Guardian con
  `approved: true`.
- Cinco capturas de pantalla del dashboard en los estados declarados en
  §"Verificación Doble (ii)".

---

## Handoffs Requeridos Post-Implementación

1. **Implementador → Technical Architect:** handoff de cierre solicitando
   AR-2-006 (revisión arquitectónica post-implementación). Sigue el patrón
   de HO-014.
2. **Implementador → Privacy Guardian:** `HO-PG-T-2-004-d1-review.md` con
   los cuatro archivos del dashboard + cinco capturas. Privacy Guardian
   debe firmar antes de AR-2-006.
3. **Technical Architect → Orchestrator:** AR-2-006 emitido. Si aprobado
   sin correcciones, T-2-004 cerrado y D14 satisfecho.
4. **Orchestrator → equipo:** notificación de cierre lógico de Fase 2 (a
   reserva de implementación de FS Watcher en paralelo).

---

## Notas de Trazabilidad

- Esta TS hereda y respeta los cierres de TS-2-001, TS-2-002, TS-2-003.
- AR-2-005 declaró el helper `user_blocked()` como "edición mecánica
  única". TS-2-004 desvía mínimamente esa expectativa (elimina el helper y
  externaliza la consulta a `commands.rs`) por preservación estricta de D8
  en `evaluate_transition`. AR-2-006 deberá validar la desviación; está
  documentada en §"Edición Mecánica".
- La sección FS Watcher queda explícitamente fuera de scope con cláusula
  de extensión declarada en §"Sección FS Watcher".
- El reactivado del test #4 cumple la cláusula obligatoria de HO-015.

---

## Firma

approved_by: Technical Architect
approval_date: 2026-04-27
notes: TS-2-004 cierra el contrato de Privacy Dashboard completo materializando D14. Las cinco decisiones del checklist de HO-015 quedan tomadas con justificación arquitectónica (postura b en persistencia de bloqueo; descomposición en subcomponentes; doble verificación D1; FS Watcher out-of-scope con cláusula de extensión; signatures como badges legibles con porcentaje). El parámetro adicional `user_blocked_pre: bool` en `evaluate_transition` es una desviación mínima de la "edición mecánica única" declarada en AR-2-005, justificada por preservar D8 estricto sin acceso a SQLCipher en la función de transición. La cláusula obligatoria de reactivación del test `test_learning_to_trusted_blocked_when_user_blocked` queda explícita en §"Edición Mecánica" y en los criterios 8-9 de aprobación. La sección FS Watcher queda out-of-scope porque `fs_watcher.rs` aún no existe en código; cuando se implemente se emitirá HO-FW-PD para extensión incremental sin reabrir TS-2-004. Los 16 criterios post-implementación son verificables línea por línea (paralelo a TS-2-002 §"12 criterios" y TS-2-003 §"14 criterios"). T-2-004 queda autorizado para implementación únicamente con esta TS firmada por Technical Architect y validada por Orchestrator.
