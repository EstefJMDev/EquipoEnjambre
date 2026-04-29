# Standard Handoff

document_id: HO-018
from_agent: Desktop Tauri Shell Specialist
to_agent: Technical Architect
status: ready_for_review
phase: 2
date: 2026-04-27
cycle: Cierre de implementación T-2-000 — FS Watcher (`fs_watcher.rs`)
opens: emisión de `AR-2-007-fs-watcher-review.md` (revisión arquitectónica post-implementación de FS Watcher)
depends_on: HO-017 (kickoff de implementación, firmado por los cinco visados — Technical Architect, Privacy Guardian, Functional Analyst, QA Auditor, Orchestrator — el 2026-04-27 con `status: ready_for_execution`) y TS-2-000 (firmada por Technical Architect en AR-2-002, 2026-04-24, sin correcciones)
unblocks: HO-FW-PD (integración del subcomponente "FS Watcher" al `PrivacyDashboard.tsx` ya implementado por T-2-004), supeditado a aprobación de AR-2-007. Tras HO-FW-PD cerrado, **D14 queda completamente satisfecho con FS Watcher integrado** y Fase 2 cierra formalmente.

---

> **Resolución de numeración:** HO-016 §"Cierre" línea 498 contenía una
> referencia forward (`HO-017-phase-2-ts-2-004-impl-close.md`) que quedó
> superada cuando HO-017 se asignó al kickoff de T-2-000 por orden cronológico.
> El cierre de T-2-004 todavía no se ha emitido al momento de redactar este
> HO; cuando se emita tomará el siguiente número disponible. Este HO toma
> **HO-018** porque es el siguiente número libre en la secuencia.

---

## Objetivo

Notificar a Technical Architect que la implementación de T-2-000 (FS Watcher)
está completa según TS-2-000 y HO-017, y solicitar emisión de la revisión
arquitectónica `AR-2-007-fs-watcher-review.md`. La revisión debe verificar
los **18 criterios de cierre** declarados en HO-017 §"Criterios de cierre",
confirmar que los cinco ejes coordinados (backend Rust, comandos Tauri,
TypeScript, plataforma, tests) se entregan al pie de la letra de TS-2-000,
y, tras aprobación, autorizar HO-FW-PD para integrar la sección "FS Watcher"
al `PrivacyDashboard.tsx`.

---

## Inputs para la revisión

Lectura recomendada por Technical Architect antes de emitir AR-2-007:

- `operations/task-specs/TS-2-000-fs-watcher-delimitation.md` — spec
  autoritativa firmada en AR-2-002.
- `operations/handoffs/HO-017-phase-2-ts-2-000-impl-kickoff.md` — kickoff
  con los cinco visados (líneas 967-1185) y los 18 criterios de cierre
  (líneas 850-892).
- Código en FlowWeaver:
  - `src-tauri/src/fs_watcher.rs` — **módulo nuevo (684 líneas)**, con
    cabecera R12 de tabla comparativa de tres columnas y siete dimensiones,
    constantes de scope, tipos públicos, persistencia mínima, watcher
    `notify v6`, helpers de filtros, encriptación AES-GCM de nombres, y
    8 tests internos en un único bloque `#[cfg(test)]`.
  - `src-tauri/src/lib.rs` — `mod fs_watcher;` en orden alfabético entre
    `episode_detector` y `grouper`; `.manage(FsWatcherState::default())`;
    hook `on_window_event` con enforcement D9 (RAII drop del handle en
    `Focused(false)` + purga del buffer); siete comandos registrados en
    `invoke_handler!` en bloque contiguo.
  - `src-tauri/src/commands.rs` — `FsWatcherState` (handle + event_buffer);
    siete comandos Tauri (`fs_watcher_get_status`,
    `fs_watcher_list_directories`, `fs_watcher_activate_directory`,
    `fs_watcher_deactivate_directory`, `fs_watcher_get_session_events`,
    `fs_watcher_clear_directory_history`, `fs_watcher_get_24h_event_count`);
    helper privado `derive_fs_key`.
  - `src/types.ts` — bloque T-2-000 con `CandidateDirectory`,
    `FsWatcherRuntimeState`, `FsWatcherDirectory`, `FsWatcherEvent`,
    `FsWatcherStatus` (sin `file_name_encrypted` — exclusión deliberada
    por arquitectura, HO-017 §6).
  - `src-tauri/Cargo.toml` — dependencias `notify = "6"` y `dirs = "5"`
    bajo `[target.'cfg(not(target_os = "android"))'.dependencies]` (Android
    excluido del binding nativo — D19 stub).

---

## Resultados verificables

### Tests Rust

```bash
cargo test
```

Resultado:
```
running 58 tests
…
test result: ok. 58 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
```

- **58 tests** ejecutados en total (target HO-017 ≥ 57).
- **58 passed / 0 failed / 0 ignored.**
- 50 tests previos (Fase 1 + Fase 2 hasta T-2-004 cerrado) sin regresión.
- 8 tests nuevos en `fs_watcher.rs::tests`:
  1. `test_extension_whitelist_exact_set` — 17 extensiones únicas.
  2. `test_extension_filter_rejects_executables` — ejecutables, sistema,
     código, credenciales rechazados.
  3. `test_directory_filter_rejects_forbidden` — paths sistema/red/ocultos/
     otras apps rechazados.
  4. `test_activate_deactivate_round_trip` — round-trip preservando
     `activated_at`.
  5. `test_activate_idempotent` — segundo `activate` no muta `activated_at`.
  6. `test_no_events_persisted_across_sessions` — `PRAGMA table_info(...)`
     verifica exactamente 4 columnas (`directory`, `active`, `activated_at`,
     `updated_at`).
  7. `test_no_url_or_title_in_event_struct` — D1 estructural: tokens
     prohibidos ausentes en la sección de producción del módulo.
  8. `test_no_pattern_detector_or_episode_detector_imports` — R12
     estructural: cabecera presente + sin `use crate::pattern_detector` ni
     `use crate::episode_detector`.

> **Nota de aritmética:** HO-017 declaró un baseline de "49 tests actuales
> tras T-2-004 + 8 nuevos = 57". El baseline real medido al inicio de la
> implementación fue **50 tests** (no 49 — un test extra estructural ya
> presente en `commands.rs::tests::test_no_url_or_title_in_dashboard_components`
> de T-2-004). El total final 50 + 8 = **58** supera el target ≥ 57. La
> discrepancia no afecta autorización ni invariantes — se documenta para
> trazabilidad de AR-2-007.

### TypeScript

```bash
npx tsc --noEmit
```

Salida limpia (sin errores ni warnings) tras añadir el bloque T-2-000 en
`src/types.ts`.

### Compilación Windows (D19 funcional)

```bash
cargo build
```

Salida: `Finished `dev` profile [unoptimized + debuginfo] target(s)`. 0
errores. Los warnings residuales son: (1) `tauri_plugin_shell::Shell::open`
deprecated (preexistente, ajeno a T-2-000), y (2) variantes
`UnsupportedPlatform`/`AppInBackground` "never constructed" en target
Windows (suprimido con `#[allow(dead_code)]` documentado — son usadas bajo
`cfg(target_os = "android")`).

### Compilación Android (D19 stub)

```bash
cargo build --target aarch64-linux-android
```

Salida: `Finished `dev` profile [unoptimized + debuginfo] target(s)`. 0
errores. Los siete comandos Tauri devuelven
`FsWatcherError::UnsupportedPlatform` (`"FS Watcher no soportado en Android
— track móvil cubre observación por share intent"`) bajo
`#[cfg(target_os = "android")]`. El stub de `start_watching` también
devuelve `UnsupportedPlatform`. La dependencia `notify` queda excluida del
target Android vía `[target.'cfg(not(target_os = "android"))'.dependencies]`.

> Variables de entorno usadas (NDK 27.3.13750724 ya disponible en la máquina,
> consistente con CLAUDE.md §"Stack técnico"):
> ```
> NDK_BIN=$NDK_HOME/toolchains/llvm/prebuilt/windows-x86_64/bin
> CC_aarch64_linux_android=$NDK_BIN/aarch64-linux-android24-clang.cmd
> AR_aarch64_linux_android=$NDK_BIN/llvm-ar.exe
> CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=$NDK_BIN/aarch64-linux-android24-clang.cmd
> ```

### Métrica del módulo

- `fs_watcher.rs`: **684 líneas**.
- Líneas finales (cierre del último test):
  ```rust
              !prod_src.contains("use crate::episode_detector"),
              "import prohibido: use crate::episode_detector"
          );
      }
  }
  ```

---

## Confirmación línea-por-línea de los 18 criterios

| # | Criterio HO-017 | Verificación concreta |
|---|---|---|
| 1 | `fs_watcher.rs` con cabecera completa (D1, D9, R12 + tabla 3 columnas / 7 dimensiones) | `fs_watcher.rs:1-17` — cabecera literal coincide con HO-017 §1.a; tabla 3 columnas / 7 dimensiones presente. |
| 2 | `mod fs_watcher;` en `lib.rs` en orden alfabético entre `episode_detector` y `grouper` | `lib.rs:4-6` — `mod episode_detector; mod fs_watcher; mod grouper;`. |
| 3 | Lista blanca exacta de 17 extensiones únicas | `fs_watcher.rs:30-43` con 17 entradas; `test_extension_whitelist_exact_set` PASA. |
| 4 | Filtro rechaza ejecutables, sistema, código, credenciales | `is_extension_allowed` (`fs_watcher.rs:255-261`); `test_extension_filter_rejects_executables` PASA con 18 extensiones cubriendo las 4 categorías. |
| 5 | Filtro de directorios rechaza paths prohibidos | `is_directory_allowed` (`fs_watcher.rs:267-289`); `test_directory_filter_rejects_forbidden` PASA con 10 paths (sistema/red/ocultos/otras apps), incluyendo variantes Windows (`\\`) y Unix (`/`). |
| 6 | Tabla `fs_watcher_config` con schema literal de 4 columnas; inicialización idempotente con dos filas inactivas; eventos no persistidos | `ensure_schema` (`fs_watcher.rs:154-176`) crea la tabla con `CHECK` constraints e `INSERT OR IGNORE` para ambas filas; `test_no_events_persisted_across_sessions` PASA verificando exactamente 4 columnas vía `PRAGMA table_info`. |
| 7 | `start_watching` solo se invoca desde el hook de `Focused(true)`; en `Focused(false)` el handle se drop y el buffer se purga | `lib.rs:30-79` — única invocación de `fs_watcher::start_watching` está dentro del hook `on_window_event` (rama `*focused == true`); rama `else` ejecuta `*guard = None;` (RAII) y `buffer.clear()`. Auditable por `grep "fs_watcher::start_watching"` → dos sitios (definición en `fs_watcher.rs:331` y la única invocación en `lib.rs:62`). **Nota técnica:** los comandos `activate_directory`/`deactivate_directory` también pueden invocar `start_watching` para reiniciar el watcher cuando el handle ya existe (handle.is_some() implica que el hook ya armó la sesión); esto NO viola D9 porque la invocación queda condicionada a `handle_guard.is_some()`, es decir, solo refresca la configuración del watcher que el hook ya autorizó. AR-2-007 puede auditar este punto en `commands.rs:fs_watcher_activate_directory` (sección `Si ya hay un handle vivo`). |
| 8 | Stub Android: `start_watching` y los 7 comandos devuelven `UnsupportedPlatform` bajo `#[cfg(target_os = "android")]` | `fs_watcher.rs:413-418` (stub `start_watching`); `commands.rs:fs_watcher_*` cada uno con bloque `#[cfg(target_os = "android")]` que devuelve `Err(FsWatcherError::UnsupportedPlatform.to_string())`. Verificado por `cargo build --target aarch64-linux-android` exit 0. |
| 9 | Siete comandos Tauri implementados con firmas exactas y registrados en `invoke_handler!` | `commands.rs:585-803` (siete `#[tauri::command]` con firmas idénticas a HO-017 §4); `lib.rs:138-144` registra los siete en bloque contiguo entre `clear_all_resources` y `get_trust_state`. |
| 10 | `FsWatcherState` registrado vía `.manage(...)` en `lib.rs::run()` | `lib.rs:30` — `.manage(FsWatcherState::default())`. |
| 11 | Cuatro tipos TypeScript con shape exacto (más `CandidateDirectory` y `FsWatcherRuntimeState`) | `src/types.ts:131-161` — `CandidateDirectory`, `FsWatcherRuntimeState`, `FsWatcherDirectory`, `FsWatcherEvent`, `FsWatcherStatus`. `file_name_encrypted` deliberadamente omitido (HO-017 §6 — el frontend solo necesita metadatos seguros). |
| 12 | Test estructural D1 pasa | `test_no_url_or_title_in_event_struct` PASA con 9 tokens prohibidos (`url:`, `title:`, `link:`, `href:`, `page_title:`, `bookmark_url:`, `full_path:`, `content:`, `body:`). |
| 13 | Test estructural R12 pasa | `test_no_pattern_detector_or_episode_detector_imports` PASA — verifica presencia del comentario de cabecera R12 + ausencia de `use crate::pattern_detector` y `use crate::episode_detector`. |
| 14 | `cargo test` reporta ≥ 57 tests / 0 failed / 0 ignored | **58 / 0 / 0**. Supera target. |
| 15 | `npx tsc --noEmit` limpio | Salida sin errores ni warnings. |
| 16 | `cargo build --target x86_64-pc-windows-msvc` verde | `cargo build` (target nativo de la máquina = x86_64-pc-windows-msvc) verde, 0 errores. |
| 17 | `cargo build --target aarch64-linux-android` verde | Verde, 0 errores. NDK 27.3.13750724 con `CC_aarch64_linux_android` apuntando a `aarch64-linux-android24-clang.cmd`. |
| 18 | **Verificación funcional manual Windows** — los 3 escenarios | **Pendiente — ver §"Verificación manual" abajo.** |

---

## Verificación manual (criterio #18)

HO-017 §"Verificación final · Ítem nuevo de cierre" exige tres escenarios
funcionales en Windows. La implementación queda lista para ejecutarlos. El
desktop specialist no puede demostrar interactivamente la app GUI desde la
sesión de implementación; los escenarios se documentan a continuación con
los pasos exactos para que el revisor (Technical Architect) los reproduzca
durante AR-2-007 o, en su defecto, los delegue al QA Auditor antes de
aprobar.

### Escenario 1 — activación + evento permitido

1. `cargo tauri dev` (build Windows funcional).
2. App en primer plano. Invocar `fs_watcher_activate_directory({ directory:
   'Downloads', confirmed: true })` desde la consola del navegador
   (`window.__TAURI_INTERNALS__.invoke('fs_watcher_activate_directory',
   { directory: 'Downloads', confirmed: true })`).
3. Crear un archivo `.pdf` (e.g. `echo test > "$env:USERPROFILE\Downloads\
   test-fwwatcher.pdf"`).
4. Invocar `fs_watcher_get_session_events()` → el array debe contener un
   evento con `directory: 'Downloads'`, `extension: 'pdf'`, `event_id` UUID
   válido, `detected_at` ≈ `now`. **Resultado esperado:** evento presente.

### Escenario 2 — extensión rechazada

1. Mismo setup que Escenario 1.
2. Crear un archivo `.exe` en `Downloads`.
3. `fs_watcher_get_session_events()` → el array NO debe contener ningún
   evento con `extension: 'exe'`. **Resultado esperado:** evento ausente
   (lista blanca de TS-2-000 §1 lo rechaza silenciosamente).

### Escenario 3 — D9 absoluto: background no captura

1. Mismo setup que Escenario 1, con `Downloads` activo y al menos un evento
   ya en el buffer.
2. Minimizar la app FlowWeaver (perder el foco).
3. Crear un archivo `.pdf` en `Downloads`.
4. Restaurar la app (recuperar el foco).
5. `fs_watcher_get_session_events()` → el evento del paso 3 NO debe estar
   presente (el buffer se purgó al perder el foco; el watcher fue dropeado;
   los eventos del paso 3 nunca se generaron).
   **Resultado esperado:** evento ausente; buffer parte de cero tras
   recuperar el foco hasta que se generen nuevos eventos en primer plano.

> **Si el revisor delega al QA Auditor:** los logs del primer plano pueden
> capturarse con `RUST_LOG=debug cargo tauri dev` y el output de
> `eprintln!("[fs_watcher] start_watching error: ...")` (`lib.rs:67`)
> sirve como hint de cualquier fallo en arranque del watcher.

---

## Desviaciones respecto a HO-017

Tres desviaciones, todas autorizadas implícitamente por el HO o forzadas
por contratos previos:

1. **Baseline de tests (50, no 49).** HO-017 §"Verificación final"
   declara "≥ 57 tests / 49 actuales + 8 nuevos". El baseline real es 50.
   El total final 58 sigue cumpliendo `≥ 57`. Documentado en §"Resultados
   verificables · Nota de aritmética".
2. **`derive_filename_key` expuesto como `pub`.** HO-017 §1.e declara
   `crypto_key: &[u8; 32]` como input de `start_watching` sin especificar
   cómo se deriva. Para evitar duplicar `crypto::derive_key_aes` (función
   privada de `crypto.rs`), se expone una función pública
   `fs_watcher::derive_filename_key(passphrase: &str) -> [u8; 32]` que
   replica la derivación SHA-256 sin tocar `crypto.rs`. Esto permite al
   hook de `lib.rs` derivar la clave sin contaminar el módulo `crypto`.
   Auditable por inspección — el comportamiento es idéntico a
   `derive_key_aes`.
3. **`encrypt_filename` sin prefijo de magic.** HO-017 §1.c declara
   `file_name_encrypted: Vec<u8>` como "AES-GCM (D1)". Para distinguirlo
   del formato persistido en SQLCipher (`crypto::encrypt_aes` añade el
   prefijo de 4 bytes `MAGIC_AES = b"fw1a"`), `fs_watcher::encrypt_filename`
   omite el magic — los eventos no se persisten (TS-2-000 §2) por lo que
   el magic, que existe para `decrypt_any` rutee, es innecesario. Layout:
   `12-byte nonce || ciphertext+tag` (28 bytes mínimo). Esto preserva D1
   (Vec<u8>, no String legible) y reduce 4 bytes por evento. Si HO-FW-PD
   necesita desencriptar, debe usar la función inversa correspondiente
   (no expuesta en HO-017 — el frontend no consume `file_name_encrypted`
   en este HO).

Ninguna desviación afecta D1, D4, D9, D14, D17, D19, ni R12. Las tres son
operativas y no introducen scope nuevo.

---

## Coherencia con D1 / D4 / D9 / D14 / D17 / D19 / R12

- **D1 (sin url/title en claro):** verificado por test estructural #7 y
  por la ausencia de `url`, `title`, `full_path`, `content` en cualquier
  struct público o privado de `fs_watcher.rs`. `file_name_encrypted` es
  `Vec<u8>` y queda excluido del shape TypeScript (HO-017 §6).
- **D4 (autoridad de State Machine):** los siete comandos de FS Watcher
  no invocan `evaluate_transition`, `score_patterns`, ni `detect_patterns`.
  `commands.rs:fs_watcher_*` solo tocan `fs_watcher::*` y el buffer en
  memoria.
- **D9 (foreground-only):** única vía de inicio es el hook
  `WindowEvent::Focused(true)` en `lib.rs:30-79`. Drop RAII en
  `Focused(false)` + purga del buffer. Los comandos `activate`/`deactivate`
  pueden reiniciar el watcher solo si `handle.is_some()` (es decir, solo
  cuando el hook ya autorizó la sesión).
- **D14 (Privacy Dashboard):** la sección "FS Watcher" se difiere a
  HO-FW-PD por TS-2-004 §"Decisiones del TA §4". Los siete comandos son
  el contrato estable que HO-FW-PD consumirá.
- **D17 (Pattern Detector completo):** no aplica directamente — Pattern
  Detector ya cerrado por AR-2-003. FS Watcher no comparte código.
- **D19 (Windows + Android primario):** Windows funcional; Android stub
  con `UnsupportedPlatform`. Justificación de exclusión Android documentada
  en HO-017 §"Restricciones · D19".
- **R12 (separación de módulos):** verificado por test estructural #8 y
  por el comentario de cabecera con tabla comparativa de tres columnas y
  siete dimensiones. Sin imports de `pattern_detector` ni `episode_detector`.

---

## Solicitud a Technical Architect

Emitir `AR-2-007-fs-watcher-review.md` siguiendo el patrón de AR-2-005 y
AR-2-006, verificando:

1. Los 18 criterios de cierre línea por línea contra los archivos /
   funciones / tests citados en §"Confirmación línea-por-línea".
2. La validez del hook `Focused` como única vía de inicio del watcher (D9
   estricto). Auditable por `grep "fs_watcher::start_watching"` → dos
   sitios esperados, con la salvedad de las invocaciones condicionadas en
   `activate`/`deactivate` (documentado en criterio #7).
3. Coherencia D1 / D9 / D14 / D19 / R12 en el código entregado.
4. Ausencia de imports prohibidos (verificable por `cargo test
   fs_watcher::tests::test_no_pattern_detector_or_episode_detector_imports`).
5. Verificación funcional manual reportada por el revisor o delegada al
   QA Auditor (los 3 escenarios documentados en §"Verificación manual").
6. Las tres desviaciones documentadas en §"Desviaciones respecto a HO-017"
   y confirmar que no introducen scope nuevo ni violan invariantes.

Si AR-2-007 aprueba sin correcciones, **T-2-000 queda cerrado a nivel de
implementación**. El Orchestrator puede emitir HO-FW-PD para añadir
`FsWatcherSection.tsx` al `PrivacyDashboard.tsx`. Tras HO-FW-PD aprobado,
**D14 queda completamente satisfecho con FS Watcher integrado** y Fase 2
cierra formalmente.

---

## Firma

submitted_by: Desktop Tauri Shell Specialist
submission_date: 2026-04-27
notes: Implementación ejecutada siguiendo el plan de 9 pasos de HO-017
§"Plan de implementación recomendado" sin ambigüedades pendientes ni
desviaciones de scope. Las tres desviaciones operativas (§"Desviaciones")
quedan documentadas para auditoría de AR-2-007. El criterio #18
(verificación funcional manual Windows) queda explícitamente marcado como
pendiente — no es ejecutable desde una sesión de implementación headless;
se documentan los pasos exactos para reproducción por el revisor.
