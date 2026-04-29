# OD-007 — Execution Report

date: 2026-04-29
issued_by: Claude Code (executor)

## Resumen

Se aplicó OD-007 a la gobernanza (D22 marcada APLAZADA, extensión D9 REVERTIDA,
caso núcleo único reafirmado), se corrigieron las inconsistencias documentales
post-D19 en `product-spec.md`, se añadieron R13/R14/R15 al risk-register, se
verificó que el código FlowWeaver no tiene restos activos de D22, se entregó
el test E2E baseline del relay (data-roundtrip activo + ciclo completo
ignored con TODO de refactor), se aplicó el fix R14 (refresh automático del
AnticipatedWorkspace por evento Tauri `relay-event-imported`) y se redactó
el plan de migración crypto XOR→AES sin ejecutarlo. Todos los checks
automáticos pasan: 58 unit tests + 1 integration test + TypeScript limpio.

---

## Bloque A — OD-007 aplicada

- [x] OD-007.md creado en orchestration-decisions/
- [x] decisions-log.md actualizado (D22 aplazada en tabla principal +
      fila nueva en "Decisiones cerradas recientemente" + D9 extensión
      REVERTIDA + nueva subsección detallada "D22 — Aplazamiento (2026-04-29)")
- [x] roadmap.md Fase 0c reformulada
- [x] FlowWeaver/CLAUDE.md actualizado (sub-secciones "Bloqueado
      adicionalmente por OD-007" + "Qué sí sigue válido en mobile")
- [x] backlog-phase-0c.md revisado (ver detalle abajo)

### Items del backlog marcados como BLOQUEADO por OD-007

**Ninguno.** El backlog `backlog-phase-0c.md` se aprobó el 2026-04-24
(antes de D22) y todos sus items (T-0c-000 a T-0c-004) caen dentro de
infraestructura D20/D21 que OD-007 preserva explícitamente. Greps de
control en el backlog: 0 ocurrencias de `Tile|Quick Settings|tier paid|
observer semi-pasivo|semi_passive|anticipación proactiva mobile`. Los
items "Pattern Detector móvil" / "Episode Detector móvil" aparecen solo
como `out_of_scope` o `risks_of_misinterpretation` (ya bloqueados por
OD-005, no nuevos por OD-007).

### Items del backlog dudosos

**Ninguno.**

---

## Bloque B — Inconsistencias documentales corregidas

- [x] product-spec.md sección 5 actualizada (observer Android primario +
      iOS secundario)
- [x] product-spec.md sección 6 actualizada (Kotlin Android primario en
      "Observación móvil")
- [x] product-spec.md sección 14 (Fase 0b) actualizada (Share Intent
      Android añadido)
- [x] product-spec.md sección 14 (Fase 0c) insertada completa entre 0b
      y Fase 1
- [x] product-spec.md sección 15 (D11 supersedida + D19/D20/D21/D22
      añadidas/marcadas)
- [x] product-spec.md sección 17 (P95 ACK Drive + P50 móvil→desktop)
- [x] risk-register.md R13/R14/R15 añadidos antes de "Regla Operativa"
- [x] risk-register.md historial 2026-04-29 con owners por riesgo
      (R13 → Privacy Guardian, R14 → Desktop Tauri Shell Specialist,
      R15 → Sync & Pairing Specialist)
- [x] grep de validación cruzada: `macOS + iOS` y `Plataformas iniciales
      = macOS` solo aparecen tachados con SUPERSEDIDA por D19. Limpio.

### Notas del Bloque B

El grep filtrado `tier paid|observer semi-pasivo|mobile standalone|Tile
de sesión` con `-v "APLAZADA|aplazada|OD-007|REVERTIDA"` devuelve 8
ocurrencias residuales, todas en `decisions-log.md`, todas en contextos
donde el aplazamiento ya está documentado en proximidad inmediata
(cabecera REVERTIDA en celda principal D9, subsección "D22 —
Aplazamiento" cerrando la sección detallada D22, o dentro de la propia
subsección de aplazamiento — falsos positivos line-based del grep). No
requieren acción según la regla del prompt ("si proceden referencia
histórica, déjalas como están"); decisión registrada en el resumen del
Bloque B y reportada aquí para auditoría.

---

## Bloque C — Verificación de código

Resultado de cada grep (limitados a `src/` + `src-tauri/src/` +
`src-tauri/gen/android/app/src/`, excluyendo `src-tauri/gen/android/
app/build/`):

- `tier_paid|tile_session|semi_passive|tile_observer|TileService`:
  **vacío en código fuente**. Único match en
  `gen/android/app/build/outputs/mapping/universalRelease/usage.txt`
  (`androidx.core.service.quicksettings.TileServiceCompat`) — ruido
  del minify de release de la librería estándar AndroidX, no es código
  del proyecto.
- `observer_semi_passive|navigation_observer|browsing_observer`: **vacío**.
- `PatternDetector.*android|pattern_detector.*mobile`: **vacío**.

### Acción tomada en lib.rs sobre `pattern_detector` cfg(android)

**No aplicado.** Razón: aunque `MobileGallery.tsx` no usa
`pattern_detector` (verificado, 0 matches), `commands.rs` define cuatro
commands Tauri sin cfg de plataforma que dependen activamente del módulo
(`get_detected_patterns` L408, `get_trust_state` L304, `reset_trust_state`
L310, `enable_autonomous_mode` L317), todos enrutando a
`apply_trust_action` que llama `pattern_detector::detect_patterns` en
L341-342 y L412. Adicionalmente `trust_scorer.rs` y `state_machine.rs`
hacen `use crate::pattern_detector` sin cfg.

Aplicar `#[cfg(not(target_os="android"))]` solo al módulo dejaría a
Android sin las definiciones que `commands.rs`/`trust_scorer.rs`/
`state_machine.rs` requieren → fallo de compilación Android. El doc
contempla este caso explícitamente: "Si MobileGallery.tsx o algún
command expuesto a Android usa Pattern Detector, no apliques el cfg y
reporta. Pattern Detector móvil sigue siendo D22 y estaría bloqueado,
pero eliminarlo en frío puede romper builds."

Estado del código: ningún resto de implementación activa de D22 (observer
semi-pasivo, tile, navigation observer, Pattern Detector específico para
Android). El código respeta OD-007 sin necesidad de cambios.

---

## Bloque D — Mejoras técnicas

### D.1 Test E2E

- archivo creado: `FlowWeaver/src-tauri/tests/e2e_relay_roundtrip.rs`
  (~190 líneas)
- estado: 1 test activo (`e2e_relay_data_roundtrip`) + 1 ignored
  (`e2e_relay_full_cycle_with_mock_drive`) con TODO documentado:
  cuatro pasos del refactor mínimo (extraer `trait DriveApi`, mover
  reqwest a `HttpDriveApi`, cambiar firma de `run_relay_cycle` a
  `&dyn DriveApi`, escribir `InMemoryDriveApi` en el test). Sin
  dependencias nuevas.
- métrica de latencia capturada en run inicial:
  `[METRIC] e2e_latency_ms=X` (X < 5 ms en local; floor del coste de
  procesado puro sin red — R15 sigue ABIERTO hasta instrumentación
  con Drive real).
- QA review baseline: `EquipoEnjambre/operations/qa-reviews/
  qa-review-e2e-relay-roundtrip.md` (declarado **baseline regresional**
  del relay).

### D.2 Refresh automático del workspace

- cambios en `drive_relay.rs`:
  - `process_android_event` cambia firma a `Result<String, String>` y
    devuelve el `resource_uuid` derivado v5.
  - `run_relay_cycle` añade parámetro `app_handle: Option<&AppHandle>`.
    Tras `process_android_event` exitoso, emite evento Tauri
    `relay-event-imported` con el uuid como payload.
  - Importa `tauri::{AppHandle, Emitter}`.
- cambios en `lib.rs`:
  - El spawn del loop async pasa `Some(&handle)` como cuarto argumento.
- cambios en `App.tsx`:
  - Importa `listen` de `@tauri-apps/api/event`.
  - useEffect inicial registra listener de `relay-event-imported` (en
    IIFE async tras `detectPlatformAndInit`).
  - Listener recarga `get_clusters`+`get_episodes` y transiciona `phase`
    de `"empty"` a `"ready"` con callback de `setPhase` (sin captura de
    cierre obsoleto). Cleanup con `unlisten?.()` en el return del effect.
- handoff documentado: **HO-023-fix-anticipated-workspace-refresh.md**
  (no HO-020 — ver sección "Inconsistencias o bloqueos" abajo).
- test manual: **NO ejecutado en esta sesión**. Requiere Drive
  configurado con OAuth real + dispositivo Android emparejado activo.
  Procedimiento concreto y criterios de paso/fallo documentados en HO-023.

### D.3 Plan de migración crypto

- `EquipoEnjambre/operations/architecture-notes/
  AN-crypto-migration-xor-to-aes.md` creado siguiendo literalmente el
  contenido prescrito en OD-007 §D.3 (Fase 1 re-cifrado XOR→AES, Fase 2
  keychain del OS + Android Keystore con PBKDF2-SHA256 600k iter, Fase 3
  eliminar XOR). Owner: Privacy Guardian. Status: PLAN — pendiente de
  aprobación para sprint dedicado.
- ejecución: **NO** (solo plan, requiere sprint dedicado, sin código
  tocado, sin deps nuevas).

---

## Pruebas

- `cd src-tauri && cargo test`:
  ```
  test result: ok. 58 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
       Running tests\e2e_relay_roundtrip.rs
  test result: ok. 1 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out
     Doc-tests flowweaver_lib
  test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
  ```
  **PASS.** 58 unit tests + 1 integration test (`e2e_relay_data_roundtrip`)
  + 1 ignored (`e2e_relay_full_cycle_with_mock_drive`). Único warning:
  `tauri_plugin_shell::Shell::open` deprecated en `commands.rs:482`,
  preexistente, no introducido por este cambio.

- `npx tsc --noEmit`:
  ```
  EXIT_CODE=0
  ```
  **PASS.** Sin output.

---

## Archivos creados (rutas completas)

1. `EquipoEnjambre/operations/orchestration-decisions/OD-007-defer-d22-mobile-standalone.md`
2. `EquipoEnjambre/operations/orchestration-decisions/OD-007-execution-report.md` (este archivo)
3. `EquipoEnjambre/operations/qa-reviews/qa-review-e2e-relay-roundtrip.md`
4. `EquipoEnjambre/operations/handoffs/HO-023-fix-anticipated-workspace-refresh.md`
5. `EquipoEnjambre/operations/architecture-notes/AN-crypto-migration-xor-to-aes.md`
6. `FlowWeaver/src-tauri/tests/e2e_relay_roundtrip.rs`

## Archivos modificados (rutas completas + diff resumido)

1. **`EquipoEnjambre/Project-docs/decisions-log.md`**
   - Fila D22 en tabla principal: celdas "Elección" y "Justificación"
     reemplazadas por texto APLAZADA con cita a OD-007.
   - Tabla "Decisiones cerradas recientemente": fila nueva
     `D22 aplazamiento … 2026-04-29` añadida bajo la fila histórica D22.
   - Fila D9 en tabla principal: fragmento de extensión "Observer
     semi-pasivo Android (tier paid)…" marcado como REVERTIDA por
     OD-007 con `~~strikethrough~~` y nota explicativa.
   - Subsección nueva "D22 — Aplazamiento (2026-04-29)" insertada al
     final de la sección detallada D22, antes del separador `---` que
     precede a "## Regla operativa".

2. **`EquipoEnjambre/Project-docs/roadmap.md`**
   - Bloque "## Fase 0c" reemplazado completo: objetivo redefinido como
     "soporte mobile al Usuario A multi-dispositivo", marca explícita
     `[REFORMULADA por OD-007]`, sección "No valida" con primer bullet
     "hipótesis mobile-only standalone (D22 aplazada)", riesgo nuevo
     "Riesgo de interpretación (OD-007)", y "Autorizado por" con doble
     cita OD-005 + OD-007.

3. **`FlowWeaver/CLAUDE.md`**
   - Dentro de `## Qué no implementar sin TS aprobada`: añadidas dos
     sub-secciones nuevas — `### Bloqueado adicionalmente por OD-007
     (2026-04-29)` (9 bullets) + `### Qué sí sigue válido en mobile`
     (6 bullets, infraestructura preservada D20/D21).

4. **`EquipoEnjambre/docs/product-spec.md`**
   - §5: "único observer activo del MVP = Share Extension iOS"
     reemplazado por dos líneas (Android primario D19 + iOS secundario
     macOS-bound).
   - §6 "Observación móvil": tres líneas Swift iOS reemplazadas por
     bloque "Primario: Kotlin Android — Share Intent (D19) /
     Secundario (track paralelo, requiere macOS): Swift iOS".
   - §14 Fase 0b: "Share Extension iOS" sustituido por dos líneas
     (Android primario + iOS track paralelo).
   - §14: bloque completo "### Fase 0c" insertado entre Fase 0b y Fase 1
     (objetivo, Incluye, No incluye con bullet "mobile standalone con
     tier paid (D22 aplazada por OD-007)", Qué valida, Qué NO valida).
   - §15: D11 marcado SUPERSEDIDA por D19 + secciones nuevas D19, D20,
     D21, D22 (esta última APLAZADA).
   - §17 Técnicas: dos métricas nuevas añadidas (P95 ACK Drive < 60s
     y P50 móvil→desktop < 90s).

5. **`EquipoEnjambre/Project-docs/risk-register.md`**
   - Tres filas nuevas R13/R14/R15 insertadas en la tabla antes de
     "## Regla Operativa", con owners distintos (Privacy Guardian /
     Desktop Tauri Shell Specialist / Sync & Pairing Specialist).
   - Entrada nueva en "## Historial De Actualizaciones": fecha
     2026-04-29, ciclo "Auditoría post-OD-007", citando OD-007 + los
     tres riesgos en estado ABIERTO con sus owners respectivos.

6. **`FlowWeaver/src-tauri/src/drive_relay.rs`**
   - Imports añadidos: `tauri::{AppHandle, Emitter}`.
   - `fn build_raw_event` → `pub fn` (visibilidad para integration tests).
   - `fn process_android_event` → `pub fn` y firma cambiada de
     `Result<(), String>` a `Result<String, String>` (devuelve
     `resource_uuid` derivado v5).
   - `pub async fn run_relay_cycle` añade parámetro
     `app_handle: Option<&AppHandle>`.
   - En la rama `if !already` del bucle de download Android pending,
     tras `process_android_event` exitoso, emite evento Tauri
     `relay-event-imported` con el `resource_uuid` como payload (R14).
     Comentario citando R14.

7. **`FlowWeaver/src-tauri/src/lib.rs`**
   - Cuatro módulos cambiados de `mod` a `pub mod`: `crypto`,
     `raw_event`, `storage`, `drive_relay` (esta última conservando el
     `#[cfg(not(target_os = "android"))]`).
   - El spawn de `run_relay_cycle` en el setup pasa `Some(&handle)` como
     cuarto argumento.

8. **`FlowWeaver/src/App.tsx`**
   - Import añadido: `listen` desde `@tauri-apps/api/event`.
   - `useEffect` inicial: el cuerpo cambia de llamada directa a
     `detectPlatformAndInit()` a IIFE async que primero llama
     `detectPlatformAndInit` y después registra listener de
     `relay-event-imported`. El listener recarga `get_clusters` +
     `get_episodes`, actualiza `clusters` y `episodes`, y transiciona
     `phase` de `"empty"` a `"ready"` con callback de `setPhase` para
     evitar capturar el valor obsoleto del cierre. Cleanup del effect
     llama a `unlisten?.()`. Try/catch alrededor del `listen` para
     tolerancia a entornos sin Tauri.

---

## Inconsistencias o bloqueos no resueltos

### Bloqueo 1 — Numeración HO-020

OD-007 §D.2.d especifica que el handoff del bugfix de R14 se llame
`HO-020-fix-anticipated-workspace-refresh.md`. Sin embargo, HO-020
**ya estaba ocupado** desde antes de esta sesión por
`HO-020-phase-2-ho-fw-pd-close.md` (cierre del HO-FW-PD que cerró Fase 2),
y HO-021 / HO-022 también están tomados (kickoff CR-002 y QA criterio 18
de Fase 3). Asigné el handoff a **HO-023** por ser el siguiente número
libre, con nota explícita al inicio del archivo explicando la colisión.
**Decisión humana requerida:** confirmar HO-023 como nombre canónico, o
indicar otra convención (renombrar a sufijo descriptivo sin número, etc.).

### Bloqueo 2 — Pattern Detector cfg en Android (C.3)

No se aplicó `#[cfg(not(target_os="android"))]` sobre `mod
pattern_detector` por el acoplamiento descrito arriba en Bloque C.
Los detalles de impacto:
- aislarlo correctamente requeriría poner `cfg` en cascada en cuatro
  commands de `commands.rs`, en los `use` de `trust_scorer.rs` y
  `state_machine.rs`, en el tipo `PatternSummary`, y en la lista de
  `tauri::generate_handler!` del `lib.rs`.
- **Decisión humana requerida:** ¿se considera aceptable que
  `pattern_detector` siga compilado para Android como infraestructura
  preservada por D20 (no es producto B, solo módulo de soporte sin
  uso desde la galería), o quieres abrir TS dedicado para aislar en
  cascada con scope formal?

### Bloqueo 3 — 8 referencias residuales en decisions-log.md (B.3)

El grep `tier paid|observer semi-pasivo|mobile standalone|Tile de
sesión` filtrado por `-v "APLAZADA|aplazada|OD-007|REVERTIDA"` devuelve
8 líneas en `decisions-log.md`, todas en contextos donde el aplazamiento
está documentado en proximidad (mismas secciones cuyo encabezado o
cierre cita el aplazamiento). Las dejé como están aplicando la regla
"si son referencia histórica con el contexto cubierto en su sección,
déjalas". **Decisión humana requerida (opcional):** ¿quieres una
pasada extra para anotar inline cada ocurrencia con `(REVERTIDA por
OD-007)` aunque sea redundante?

### Pendiente 1 — Test manual D.2.c

Verificación end-to-end del fix R14 con dispositivo real no ejecutable
en esta sesión (requiere Drive OAuth configurado + Android emparejado).
Procedimiento concreto y criterios de paso/fallo en HO-023. Hasta que
se ejecute, **R14 sigue ABIERTO** en el risk-register.

### Pendiente 2 — Refactor `trait DriveApi`

Test ignored `e2e_relay_full_cycle_with_mock_drive` queda pendiente del
refactor descrito en su doc-comment. Owner: Sync & Pairing Specialist.
**Decisión humana requerida:** ¿abrimos TS dedicado o esperamos al
próximo sprint que toque `drive_relay.rs`?

### Pendiente 3 — Aprobación del plan crypto (R13)

`AN-crypto-migration-xor-to-aes.md` necesita aprobación + asignación de
sprint dedicado para ejecutar las tres fases. Hasta entonces, **R13
sigue ABIERTO**.

---

## Siguientes pasos recomendados

1. **Ejecutar el test E2E con dispositivos reales** (no mock): poner el
   procedimiento de HO-023 §"Verificación pendiente" en práctica con
   Drive configurado y un Android emparejado. Cierra R14 si pasa.
2. **Aprobar y planificar el sprint de migración crypto (R13)** —
   `AN-crypto-migration-xor-to-aes.md` está listo para revisión por
   Privacy Guardian + Orchestrator.
3. **Decidir el destino del refactor `trait DriveApi`**: TS dedicado o
   diferido al siguiente sprint que toque relay.
4. **Decisión humana sobre los tres Bloqueos** registrados arriba
   (numeración HO-023, Pattern Detector cfg, referencias residuales).
5. **Instrumentar P50/P95 producción** del relay (R15) — requiere
   telemetría opt-in en Fase 3.
