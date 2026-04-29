# Standard Handoff

document_id: HO-015
from_agent: Orchestrator
to_agent: Technical Architect
status: ready_for_execution
phase: 2
date: 2026-04-27
cycle: Kickoff Fase 2 — T-2-004 Privacy Dashboard completo (drafting de TS)
opens: TS-2-004 (Privacy Dashboard completo — spec formal)
depends_on: T-2-001 implementado y aprobado (AR-2-003); T-2-003 implementado y aprobado (AR-2-005, 2026-04-27); contrato `TrustStateView` + tres comandos Tauri estables y verificados.
unblocks: implementación de la expansión de `src/components/PrivacyDashboard.tsx` + nuevos comandos Tauri sobre patrones (`get_detected_patterns`, `block_pattern`, `unblock_pattern`) + nuevos tipos TypeScript (`PatternSummary`) por Desktop Tauri Shell Specialist tras aprobación de TS-2-004. **Cierre de D14 y, con él, cierre lógico de Fase 2** (junto con T-2-000 implementado en paralelo).

---

## Objetivo

Producir `operations/task-specs/TS-2-004-privacy-dashboard.md`: especificación
formal e implementable de la expansión del Privacy Dashboard completo, el
último entregable bloqueante de Fase 2 según D14. Esta TS materializa los
acceptance criteria de backlog-phase-2.md §"T-2-004" (líneas 484-498) y los
contratos ya estables de TS-2-001 (`DetectedPattern`) y TS-2-003
(`TrustStateView`, `TrustStateEnum`, `Transition`).

Este HO entrega solo la spec formal — **no** implementación. La implementación
queda diferida a un HO posterior tras aprobación de TS-2-004 por el
Orchestrator y el Technical Architect.

Particularidad respecto a HOs previos: T-2-004 introduce **superficie de UI**
(no solo backend Rust). La TS debe declarar contratos exactos para los tres
ejes — Rust (comandos Tauri y schema de bloqueo de patrones), TypeScript
(tipos consumidos por la UI) y React (estructura del componente y
componentes auxiliares) — sin ambigüedad sobre qué se implementa en T-2-004
y qué pertenece a fases posteriores.

---

## Inputs

Lectura obligatoria antes del drafting:

- **Backlog Fase 2:** `operations/backlogs/backlog-phase-2.md` §"T-2-004"
  (líneas 432-514). Acceptance criteria normativos.
- **TS-2-001:** `operations/task-specs/TS-2-001-pattern-detector.md` — contrato
  de `DetectedPattern` (campos `pattern_id`, `label`, `category_signature`,
  `domain_signature`, `temporal_window`, `frequency`, `first_seen`, `last_seen`).
  La TS-2-004 debe declarar `PatternSummary` como **proyección serializable**
  consumida por la UI; el subset exacto y el shape final son responsabilidad
  del Technical Architect.
- **TS-2-002:** `operations/task-specs/TS-2-002-trust-scorer.md` — relevante
  por el flag `is_blocked` que TS-2-004 debe materializar (vía addendum a
  TS-2-002 o tabla auxiliar `pattern_blocks` — la TS debe declarar la
  decisión y justificarla; ver §"Decisiones a tomar" abajo).
- **TS-2-003:** `operations/task-specs/TS-2-003-state-machine.md` — contrato
  cerrado de `TrustStateView`, `TrustStateEnum`, `Transition` y los tres
  comandos Tauri (`get_trust_state`, `reset_trust_state`,
  `enable_autonomous_mode`). T-2-004 los **consume sin modificación**.
- **AR-2-003 / AR-2-004 / AR-2-005:** revisiones arquitectónicas que cierran
  los contratos heredados. AR-2-005 §"Compatibilidad con T-2-004" lista la
  superficie consumida campo a campo (ver tabla en líneas ~290-305 de
  AR-2-005) — la TS-2-004 puede tomarla como base.
- **Project-docs/decisions-log.md** — D1 (transversal absoluto), D4 (T-2-004
  no introduce nueva autoridad de transición), D14 (T-2-004 cierra el gate),
  R12 (transitivo: T-2-004 no debe introducir lógica de detección).
- **CLAUDE.md (FlowWeaver):** §"T-2-004 — Privacy Dashboard completo
  (`PrivacyDashboard.tsx`)" — listado de las cuatro secciones, comandos
  consumidos y la regla absoluta D1 sin excepciones.
- **HO-014 §"Ítems pendientes":** declara que T-2-004 reactiva el test #4
  `test_learning_to_trusted_blocked_when_user_blocked` (`#[ignore]` en
  `state_machine.rs:519-546`) cuando se materialice `is_blocked`. La TS-2-004
  debe declarar **explícitamente** la cláusula de reactivación.
- **AR-2-005 §"Compatibilidad con T-2-004":** confirma que `TrustStateView`
  + 3 comandos Tauri son input suficiente sin modificación. La TS-2-004
  debe heredar este contrato sin alteración.
- **Código existente:**
  - `src/components/PrivacyDashboard.tsx` — estado actual (Fase 0b — solo
    sección "Recursos" con `resource_count`, `categories`, `domains`).
  - `src/types.ts:84-99` — bloque T-2-003 con `TrustStateEnum`, `Transition`,
    `TrustStateView`. La TS-2-004 declara qué se añade (al menos
    `PatternSummary`).
  - `src-tauri/src/pattern_detector.rs` — para verificar la firma de
    `detect_patterns(conn, &PatternConfig)` y la estructura de
    `DetectedPattern`.
  - `src-tauri/src/commands.rs` — patrón existente de comandos Tauri y de
    integración con `DbState`.

---

## Entregable esperado

`operations/task-specs/TS-2-004-privacy-dashboard.md` con como mínimo los
siguientes once elementos:

### 1. Distinción de scope y D14 declarado

Sección explícita declarando:

- **Qué materializa T-2-004:** la expansión del componente
  `PrivacyDashboard.tsx` con tres secciones nuevas (Patrones detectados,
  Estado de confianza, opcionalmente FS Watcher si TS-2-000 está
  implementado), más los comandos Tauri y tipos TypeScript que las soportan.
- **Qué cierra T-2-004:** el gate D14 (Privacy Dashboard completo es
  prerequisito bloqueante de Fase 3). Tras aprobación de AR-2-006 (revisión
  post-implementación), Fase 2 queda lógicamente cerrada en su componente
  funcional principal.
- **Qué NO materializa T-2-004:** historial de transiciones de la State
  Machine, configuración de umbrales por el usuario, telemetría externa, ni
  exposición de `url`/`title` bajo ninguna circunstancia (D1 transversal).

### 2. Contratos de tipos TypeScript nuevos

Declarar el shape exacto de los tipos a añadir en `src/types.ts` (después del
bloque T-2-003 ya presente, líneas 84-99). Mínimo:

- **`PatternSummary`** — proyección serializable de `DetectedPattern` para
  consumo de UI. Debe excluir campos sensibles transitivos (no debe haber
  forma de derivar `url` ni `title` de los campos expuestos). Decidir y
  justificar:
  - ¿Se expone `category_signature` y `domain_signature` como arrays
    enteros o se reduce a una representación compacta legible (e.g.
    "Documentación · Trabajo")?
  - ¿Se expone `temporal_window` (`time_of_day_bucket` + `day_of_week_mask`)
    de forma legible o se omite del summary?
  - ¿Se expone el flag `is_blocked` aquí o se mantiene en una colección
    paralela del frontend?
- **Posible `BlockedPatternId`** o tipo equivalente si la representación de
  bloqueo lo justifica.

Cualquier tipo nuevo debe declararse en TS-2-004 con el contrato exacto que
el frontend importa sin ambigüedad. **No reabrir contratos cerrados**:
`TrustStateView`, `TrustStateEnum`, `Transition` permanecen idénticos
(AR-2-005 los blindó).

### 3. Contratos de comandos Tauri nuevos

Declarar firma, comportamiento y errores de:

- **`get_detected_patterns(state) -> Result<Vec<PatternSummary>, String>`** —
  invoca `pattern_detector::detect_patterns(conn, &PatternConfig::default())`,
  proyecta `Vec<DetectedPattern>` a `Vec<PatternSummary>`, ordena
  determinísticamente (decidir orden — sugerencia: `last_seen` desc,
  desempate por `pattern_id` ascendente para D8). Marca patrones bloqueados
  según el mecanismo decidido en §"Decisiones a tomar".
- **`block_pattern(state, pattern_id: String) -> Result<(), String>`** —
  registra `pattern_id` como bloqueado (vía tabla `pattern_blocks` o flag
  según decisión). Idempotente.
- **`unblock_pattern(state, pattern_id: String) -> Result<(), String>`** —
  inverso. Idempotente.

Restricciones:
- Los tres comandos **no** pueden modificar la State Machine ni invocar
  `evaluate_transition` (D4). El bloqueo de un patrón afecta el siguiente
  tick automático de `state_machine` vía la nueva implementación de
  `user_blocked()` en `state_machine.rs` — **edición mecánica única** del
  helper privado declarada en HO-013 §"Restricciones específicas" y en
  AR-2-005 §"Ítems pendientes heredados".
- Los tres comandos consumen `DbState` siguiendo el patrón existente.
- Mensajes de error descriptivos como `String` al frontend.

### 4. Decisión sobre persistencia de bloqueo de patrones

Spec debe tomar y justificar **una** de estas dos posturas:

**(a) Addendum a TS-2-002 — campo `is_blocked: bool` en `TrustScore`**

- Pro: edición mínima del struct existente; consume `Vec<TrustScore>` en
  `state_machine.rs::user_blocked()` directamente.
- Contra: rompe el cierre formal de TS-2-002 (requiere addendum aprobado por
  Technical Architect); `TrustScore` deja de ser puramente derivable de
  `Vec<DetectedPattern>` (necesita lookup adicional en SQLCipher).

**(b) Tabla auxiliar `pattern_blocks` en SQLCipher**

- Schema mínimo: `(pattern_id TEXT PRIMARY KEY, blocked_at INTEGER NOT NULL)`.
- `state_machine.rs::user_blocked(_scores: &[TrustScore])` cambia a
  `user_blocked(conn: &Connection, scores: &[TrustScore]) -> bool` o se
  consulta antes en `commands.rs::apply_trust_action` y se materializa
  como flag transitorio.
- Pro: TS-2-002 no se reabre; el flag vive en su propio módulo de
  persistencia.
- Contra: requiere un cambio de firma en `user_blocked()` o un wiring
  adicional en `commands.rs`.

La spec **debe** decidir y justificar la postura según el contexto de
funcionamiento y utilidad arquitectónica del módulo (no por recomendación
externa). El Technical Architect tiene autoridad plena para elegir la
postura que mejor preserve los contratos cerrados de TS-2-001 / TS-2-002 /
TS-2-003 y la coherencia del dashboard.

Independientemente de la postura: la spec **debe** declarar la cláusula de
reactivación del test `test_learning_to_trusted_blocked_when_user_blocked`
(actualmente `#[ignore]` en `state_machine.rs:519-546`) — el HO de cierre
de T-2-004 **debe** reportar la reactivación con `#[ignore]` removido y
aserción activa.

### 5. Estructura del componente `PrivacyDashboard.tsx` expandido

Spec debe declarar la estructura exacta de las cuatro secciones:

- **Sección 1 — Recursos** (ya existe en 0b): sin cambios. La TS confirma
  que el contrato de `get_privacy_stats` se preserva.
- **Sección 2 — Patrones detectados** (nueva): consume
  `get_detected_patterns`. Por cada patrón muestra `label`,
  `category_signature` (representación legible), `domain_signature` (idem),
  `frequency`, `last_seen` (formato relativo "hace X días"). Botón
  "Bloquear" / "Desbloquear" según estado. Vacío: mostrar mensaje
  "Aún no se han detectado patrones".
- **Sección 3 — Estado de confianza** (nueva): consume `get_trust_state`.
  Muestra `current_state` (etiqueta legible), tiempo en estado actual,
  `active_patterns_count`. Botón "Resetear confianza" siempre visible. Si
  `current_state === 'Trusted'`: botón "Activar preparación automática" con
  modal de confirmación (aviso explícito de qué implica) que invoca
  `enable_autonomous_mode(true)` solo tras confirmación.
- **Sección 4 — FS Watcher** (condicional): si TS-2-000 está implementado,
  expone directorios observados, estado, contador de eventos en sesión y
  botón "Dejar de observar". Si TS-2-000 aún no está implementado, esta
  sección queda fuera de scope de T-2-004 y se difiere al HO de
  implementación de FS Watcher (debe declararse explícitamente en la spec).
- **Bloque "Qué no veo nunca"**: separación visual clara con texto literal
  declarado en spec (sin parafraseo). Nombrar `url`, `title` completo,
  contenido de páginas como ejemplos explícitos. La spec debe proveer el
  texto exacto para evitar drift en implementación.

### 6. Restricción D1 reforzada para UI

Sección explícita declarando que ningún campo, tooltip, atributo `title`,
texto de placeholder, hover-state ni log del frontend puede contener `url`
ni `title`. Auditable en revisión post-implementación. Lista negra de
identificadores prohibidos en propiedades JSX y en strings de TS:
- `resource.url`, `resource.title`, `bookmark_url`, `page_title`, `link`,
  `href` (salvo cuando son atributos JSX legítimos sin contenido sensible).

La spec debe declarar también el mecanismo de **verificación textual**: e.g.
test estructural que haga grep en `PrivacyDashboard.tsx` y subcomponentes
buscando los identificadores prohibidos (similar al patrón D4 de TS-2-002 /
TS-2-003 con `include_str!` en Rust — para TS, equivalente con `fs.readFile`
en un test de Vitest **o** un comentario explícito en spec sobre revisión
manual obligatoria por Privacy Guardian — decidir y justificar la postura).

### 7. Decisión sobre subcomponentes

¿Se mantiene `PrivacyDashboard.tsx` monolítico (≈400 líneas finales
estimadas) o se descompone en subcomponentes (`PatternsSection.tsx`,
`TrustStateSection.tsx`, `FSWatcherSection.tsx`)?

La spec **debe** decidir y justificar según contexto de funcionamiento y
utilidad (legibilidad, testabilidad, coste de framework, coherencia con el
resto de `src/components/`). El Technical Architect elige la postura sin
recomendación externa.

### 8. Plan de tests

Criterios mínimos verificables post-implementación. Para Rust (comandos
Tauri):

- Test estructural de comando `get_detected_patterns`: deserialización
  correcta de `DetectedPattern` → `PatternSummary` sin pérdida ni inclusión
  de campos sensibles.
- Test de idempotencia de `block_pattern` y `unblock_pattern`.
- Test de persistencia de bloqueo (round-trip): bloquear, leer, desbloquear,
  leer.
- Test de reactivación de `test_learning_to_trusted_blocked_when_user_blocked`
  (mover de `#[ignore]` a activo, verificar que con `is_blocked = true`
  para algún score, `Learning → Trusted` no se promociona).

Para frontend:
- Test de Vitest (si la spec decide añadirlo): render de `PrivacyDashboard`
  con datos sintéticos. Verificación de las cuatro secciones presentes.
- Verificación textual D1 (mecanismo decidido en §6).
- `npx tsc --noEmit` limpio tras añadir los tipos.

Target total esperado tras T-2-004: **≥ 47 tests Rust** (45 actuales + al
menos 2 nuevos de comandos T-2-004 + reactivación del #4) **con failed = 0
y ignored = 0**.

### 9. Restricciones específicas (posturas a tomar)

Reiteración de los constraints D1, D4, D8 (transitivo), D14, R12, y de las
decisiones específicas que TS-2-004 debe tomar:

- **Postura sobre persistencia de bloqueo:** opción (a) addendum a TS-2-002
  o opción (b) tabla `pattern_blocks` (ver §4).
- **Postura sobre subcomponentes:** monolito o descomposición (ver §7).
- **Postura sobre verificación textual D1:** test estructural automatizado
  o revisión manual por Privacy Guardian (ver §6).
- **Postura sobre sección FS Watcher:** in-scope si TS-2-000 está
  implementado al momento del kickoff de T-2-004; out-of-scope si no.
- **Postura sobre representación legible de signatures:** array crudo,
  string concatenada, badge UI, etc.

La spec debe tomar las cinco posturas explícitamente y dejarlas fuera del
trabajo de implementación.

### 10. Cadena de invocación y D4 transitivo

Sección explícita declarando que T-2-004 **no introduce nueva autoridad de
transición**. Los flujos del dashboard que afectan estado son:

- Modificación de bloqueo de patrón (`block_pattern` / `unblock_pattern`)
  → afecta `user_blocked()` en el siguiente tick automático de
  `state_machine`. La transición efectiva la decide la State Machine, no el
  dashboard.
- Reset (`reset_trust_state`) → invoca el comando ya existente; ninguna
  lógica adicional en el dashboard.
- Activar autónomo (`enable_autonomous_mode(true)`) → invoca el comando ya
  existente tras confirmación; el modal de confirmación es UX, no autoridad.

Reproducir el principio D4: "T-2-004 no decide transiciones; solicita
transiciones a la State Machine. La autoridad permanece en
`state_machine.rs`."

### 11. Criterios de aprobación post-implementación

Lista enumerada con N criterios verificables (paralelo a TS-2-002 §"Criterios
de Aprobación Post-Implementación" y TS-2-003 §"Criterios de Aprobación
Post-Implementación"). Mínimo:

1. `PrivacyDashboard.tsx` contiene las tres (o cuatro si FS Watcher) secciones
   declaradas, con la estructura JSX exacta de la spec.
2. Bloque "Qué no veo nunca" presente con texto literal declarado en spec.
3. Tres comandos Tauri nuevos (`get_detected_patterns`, `block_pattern`,
   `unblock_pattern`) implementados con firmas exactas.
4. Tipos TypeScript nuevos (`PatternSummary` y los que la spec añada)
   presentes en `src/types.ts` con shape exacto.
5. Persistencia de bloqueo implementada según postura tomada en §4 con
   migración idempotente.
6. Helper `user_blocked()` en `state_machine.rs:339-341` actualizado a la
   implementación real (edición mecánica única).
7. Test `test_learning_to_trusted_blocked_when_user_blocked` reactivado
   (sin `#[ignore]`).
8. Verificación textual D1 ejecutada y limpia (según mecanismo de §6).
9. Modal de confirmación obligatorio antes de invocar
   `enable_autonomous_mode(true)`.
10. `cargo test` ≥ 47 tests / 0 failed / 0 ignored.
11. `npx tsc --noEmit` limpio.

---

## Decisiones a tomar (resumen — para checklist del drafting)

El Technical Architect decide cada postura según el contexto de
funcionamiento del módulo y la utilidad arquitectónica. **No hay
recomendación del Orchestrator.** Cada decisión debe quedar documentada con
justificación explícita en la TS.

1. **Persistencia de bloqueo:** addendum a TS-2-002 (a) vs tabla
   `pattern_blocks` (b). Decidir según preservación de contratos cerrados y
   simplicidad operativa.
2. **Subcomponentes:** monolito vs descomposición. Decidir según
   legibilidad, testabilidad y coherencia con `src/components/`.
3. **Verificación textual D1:** test estructural automatizado vs revisión
   manual por Privacy Guardian vs ambos. Decidir según garantías reales que
   provee cada mecanismo.
4. **Sección FS Watcher:** in-scope si TS-2-000 está implementado al
   momento del drafting, out-of-scope si no. Verificar estado real y
   documentar la decisión.
5. **Representación legible de signatures:** formato de exposición de
   `category_signature` y `domain_signature` en UI. Decidir según UX para
   usuario no técnico.

---

## Restricciones

### D1 — sin `url`/`title` (transversal absoluto)

- Ningún campo, tooltip, atributo `title`, log, ni placeholder de
  `PrivacyDashboard.tsx` ni de sus subcomponentes puede contener `url`,
  `title` ni variantes (ver §6).
- `PatternSummary` debe ser una proyección **estricta** de
  `DetectedPattern`: solo campos en claro (`label`, signatures de
  category/domain, `frequency`, `last_seen` y similares). Sin
  re-derivaciones que puedan exponer campos cifrados.
- La verificación textual D1 (test o revisión manual) debe ejecutarse
  **antes** de cerrar AR-2-006.

### D4 — autoridad exclusiva de la State Machine (transitivo)

- Los nuevos comandos Tauri **no** invocan transiciones de la State Machine
  más allá de los tres comandos ya existentes (`get_trust_state`,
  `reset_trust_state`, `enable_autonomous_mode`). El bloqueo de patrones
  afecta el siguiente tick automático vía `user_blocked()` —
  responsabilidad de la State Machine, no del dashboard.
- El frontend **no** decide transiciones: solicita estado y solicita
  acciones. Ninguna inferencia local de transición ("si trust > X, mostrar
  ya como Trusted") está permitida — siempre consultar `get_trust_state`.

### D8 — determinismo (transitivo)

- `get_detected_patterns` debe devolver el `Vec<PatternSummary>` ordenado
  determinísticamente. Decidir orden en spec (sugerencia: `last_seen` desc,
  desempate por `pattern_id`).
- `block_pattern` / `unblock_pattern` son operaciones puras de persistencia.
  Sin RNG, sin LLM, sin invocaciones externas.

### D14 — Privacy Dashboard completo bloquea cierre Fase 2

- T-2-004 cierra D14. La spec debe declarar explícitamente que tras
  AR-2-006, Fase 2 queda lógicamente cerrada (junto con T-2-000 implementado
  en paralelo).
- La spec **no** puede declarar "incremento futuro" o "MVP" — D14 exige el
  dashboard **completo**, no parcial. Cualquier funcionalidad declarada en
  el backlog §"T-2-004 In Scope" debe estar en T-2-004 o explícitamente
  movida fuera con justificación arquitectónica.

### R12 — distinción transitiva

- T-2-004 **no** introduce lógica de detección. Consume `DetectedPattern`
  via comando Tauri y lo proyecta a `PatternSummary` para UI. Cualquier
  filtro o agrupación adicional vive en `pattern_detector.rs` o en el
  comando, no en el frontend.
- Los subcomponentes (si la spec los introduce) deben respetar el mismo
  principio: presentación, no detección.

### Restricciones específicas de T-2-004

- **No reabrir `TrustStateView`:** AR-2-005 cerró el contrato con
  `current_state`, `available_transitions`, `active_patterns_count`,
  `last_transition_at`. Cualquier necesidad de campo nuevo se escala al
  Orchestrator antes del drafting.
- **No reabrir tipos cerrados:** `TrustStateEnum`, `Transition` (TS-2-003);
  `DetectedPattern` (TS-2-001); `TrustScore` (TS-2-002 — salvo addendum
  explícito si la spec elige opción (a) en §4).
- **No introducir telemetría:** ningún `fetch`, ningún POST a externos,
  ningún logger remoto. Frontend puro.
- **No introducir configuración de umbrales:** la UI es lectura del estado
  actual + acciones del usuario, no calibración (Fase 3).
- **No exponer historial de transiciones:** Fase 3.
- **El modal de confirmación de Autonomous es obligatorio:** no es opcional
  ni configurable. La spec debe declarar el texto exacto del aviso.

---

## Cierre

Tras completar el drafting, el Technical Architect debe **firmar TS-2-004**
(`approved_by: Technical Architect`, `approval_date: <fecha>`) y emitir
**handoff de validación al Orchestrator** solicitando confirmación final
antes del HO de implementación.

El Orchestrator validará:
1. Que las cinco decisiones del checklist (§"Decisiones a tomar") están
   tomadas explícitamente con justificación.
2. Que los criterios de aprobación post-implementación son verificables
   línea por línea (paralelo al patrón de TS-2-002 / TS-2-003).
3. Que la cláusula de reactivación del test `#[ignore]` está declarada
   explícitamente.
4. Que ninguna decisión de T-2-004 reabre contratos cerrados de TS-2-001 /
   TS-2-002 / TS-2-003 sin addendum formal aprobado por Technical Architect.

Tras validación del Orchestrator, se emite **HO-016-phase-2-ts-2-004-impl-kickoff.md**
al Desktop Tauri Shell Specialist para implementación. La implementación
queda autorizada únicamente con TS-2-004 firmada y validada.

Si durante el drafting el Technical Architect encuentra ambigüedades en los
inputs (TS-2-001 / TS-2-002 / TS-2-003 / AR-2-003 / AR-2-004 / AR-2-005) o
necesita escalar una decisión que reabriría un contrato cerrado, debe
escalar al Orchestrator **antes** de proceder. El drafting no introduce
posturas nuevas sobre módulos ya cerrados sin change control formal.

---

## Firma

submitted_by: Orchestrator
submission_date: 2026-04-27
notes: Cierre de T-2-003 confirmado por AR-2-005 (2026-04-27). Contrato `TrustStateView` + tres comandos Tauri estables y consumibles sin modificación. T-2-004 es el último entregable bloqueante de Fase 2 según D14. La spec debe tomar cinco decisiones explícitas (persistencia de bloqueo, subcomponentes, verificación D1, sección FS Watcher, representación de signatures) y declarar criterios de aprobación verificables paralelos a TS-2-002 / TS-2-003. La reactivación del test `test_learning_to_trusted_blocked_when_user_blocked` (`#[ignore]` actual en `state_machine.rs:519-546`) es una cláusula obligatoria de TS-2-004. El track FS Watcher (T-2-000 aprobado documentalmente vía AR-2-002) puede progresar en paralelo a T-2-004; su implementación, cuando se active, alimentará la sección 4 del dashboard según TS-2-004 §5.
