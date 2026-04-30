# SESSION 2026-04-29 — State Update 1 (2026-04-30)

Update generado durante Phase 2.3 (tests cross-language naming) de Prio 2.
Preserva trazabilidad de SESSION-2026-04-29-state.md sin sobrescribir.

---

## Bug #5 — `desktop_acked` con event_id vacío rompe lectura de ACKs Android→Desktop

**Severidad:** alta. Bloquea la limpieza de cola pending desktop.
**Detectado:** 2026-04-30, durante Phase 2.3 al diseñar el fixture cross-lang.
**Lado afectado:** desktop Rust (`src-tauri/src/drive_relay.rs`).
**Independiente de:** Bugs #1, #2, #3 (Android) y #4 (rebuild APK).

### Causa raíz

`drive_relay.rs:314`:
```rust
let ack_prefix = desktop_acked(&config.device_id, "");
```

`desktop_acked` se define como:
```rust
fn desktop_acked(device_id: &str, event_id: &str) -> String {
    format!("fw-{device_id}-acked-{event_id}.json")
}
```

Con `event_id = ""`, el prefix construido es `"fw-desktop-X-acked-.json"`. Se pasa
a `drive_list_prefix` que arma query Drive REST:

```rust
let q = format!("name contains '{prefix}' and trashed = false");
```

→ `name contains 'fw-desktop-X-acked-.json'`.

Los ACKs reales escritos por Android (vía `RelayNaming.desktopAcked` /
`drive_relay.rs::desktop_acked` con event_id real) tienen forma:

```
fw-desktop-X-acked-<event_id_uuid>.json
```

El substring `acked-.json` **nunca aparece** en estos nombres reales (entre
`acked-` y `.json` siempre hay un event_id). Drive `contains` es match
substring estricto → 0 matches → desktop nunca recibe ACKs Android.

### Impacto

- Lista pending desktop crece monótonamente: cada evento desktop se sube a Drive,
  Android lo procesa y escribe ACK, pero desktop nunca lo ve → reintenta upload
  indefinidamente (con backoff/retry counters subiendo).
- En Drive AppData se acumulan ACKs huérfanos `fw-desktop-X-acked-<id>.json` que
  jamás se borran ni se procesan.
- No hay corrupción de datos ni leak de plaintext: solo crecimiento ilimitado de
  cola pending y de archivos huérfanos en Drive.

### Por qué nunca se manifestó

- El flujo end-to-end Desktop→Android→ACK→Desktop nunca completó un ciclo limpio
  porque Bugs #1/#2/#3 rompían fases anteriores: Android no descifraba el evento
  desktop (Bug #2), Android cifraba upload con field_key local (Bug #3), naming
  flat no coincidía (Bug #1).
- El test `e2e_relay_roundtrip.rs` cubre wire-shape Rust↔Rust pero NO el ciclo
  completo `run_relay_cycle` (test ignored — requiere refactor `trait DriveApi`,
  ver doc-comment de `e2e_relay_full_cycle_with_mock_drive`).
- Sin tests cross-language ni mock Drive, la divergencia silenciosa pasó audits
  previos. Misma raíz que INC-002.

### Fix propuesto (NO aplicado en Phase 2.3)

Línea 314 sustituir por nuevo helper canónico (ya añadido en
`drive_relay.rs` como `#[doc(hidden)] pub fn desktop_acked_prefix`):

```rust
let ack_prefix = desktop_acked_prefix(&config.device_id);
```

`desktop_acked_prefix(id)` retorna `"fw-{id}-acked-"` — el substring que `name
contains` SÍ matchea contra ACKs reales.

El helper existe pero **no se usa**. La sustitución de línea 314 va en sesión de
fixes (Prio 1 extendida), no en Prio 2 (tests-only).

### Cobertura de tests añadida en Phase 2.3

Doble capa para que Bug #5 no quede dormido:

1. **Test characterization activo** — `tests/relay_naming_convention.rs::
   characterization_bug5_desktop_acked_with_empty_event_id_yields_broken_prefix`.
   No `#[ignore]`. Corre verde HOY contra el código actual roto. Asserta:
   - `desktop_acked(id, "")` produce literalmente `"fw-{id}-acked-.json"`.
   - Ese substring NO aparece en ningún ACK name canónico del fixture.

   Cuando alguien arregle Bug #5 cambiando línea 314, el comportamiento de
   `desktop_acked(id, "")` por sí mismo no cambia (la fn sigue produciendo el
   mismo string), pero el fix probablemente vendrá acompañado de eliminar el
   call site → este test sigue verde como contrato del helper. **Más
   importante:** este test existe para que cualquiera que lea el repo vea que
   la API rota está documentada y vinculada al fix pendiente.

2. **Test expected post-fix ignorado** — `tests/relay_naming_convention.rs::
   desktop_acked_prefix_matches_fixture_post_bug5_fix`. Marcado `#[ignore]`.
   Asserta que `desktop_acked_prefix(id)` retorna el prefix canónico del
   fixture. Activable removiendo `#[ignore]` cuando el fix se aplique y se
   quiera verificar que el helper canónico se usa.

3. **Test Kotlin defensivo** — `RelayNamingTest::
   bug5_canonical_acked_prefix_does_not_contain_dot_json`. No `@Ignore`.
   Asserta que ningún prefix canónico del fixture contiene `.json` (closes la
   regresión hacia el shape roto en cualquiera de los dos lados).

4. **Placeholder Kotlin ignored** — `RelayNamingTest::
   desktop_acked_prefix_post_bug5_fix_kotlin_counterpart`. `@Ignore`. Cuando el
   Worker Kotlin necesite listar ACKs (hoy solo los escribe), añadir
   `RelayNaming.desktopAckedPrefix` y activar este test.

### Procedimiento para cerrar Bug #5

1. En `drive_relay.rs:314`: cambiar `desktop_acked(&config.device_id, "")` por
   `desktop_acked_prefix(&config.device_id)`.
2. Ejecutar `cargo test --test relay_naming_convention -- --include-ignored` —
   debe pasar el test `desktop_acked_prefix_matches_fixture_post_bug5_fix`.
3. Borrar el test characterization si ya no aporta señal (a discreción del PO),
   o dejarlo para pinear el contrato de la fn `desktop_acked` con event_id no
   vacío en flujos legítimos (build de nombre completo).
4. Validar E2E real: subir evento desktop → Android lo recibe y escribe ACK →
   desktop ve el ACK y limpia pending. (Phase Prio 4 del resume.md original.)
5. Documentar fix en INC-002 como sub-hallazgo cerrado.

---

## Otros cambios en Phase 2.3 (no son bugs)

- Refactor menor: 4 helpers de naming en `drive_relay.rs` ahora son
  `#[doc(hidden)] pub` (antes privados) para que las integration tests los
  puedan invocar. Sin cambio funcional.
- Nuevo helper `desktop_acked_prefix` en `drive_relay.rs` (no usado en
  producción; existe para que el test post-fix lo pueda asertar).
- Nuevo objeto Kotlin `RelayNaming` en
  `app/src/main/java/com/flowweaver/app/RelayNaming.kt`. `DriveRelayWorker`
  ahora delega construcción de nombres aquí (mismo patrón que
  `RelayCrypto.kt` introducido en Phase 2.1). Sin cambio funcional.
- Fixtures compartidas:
  - `src-tauri/tests/fixtures/cross_lang_vectors.json` — golden crypto.
  - `src-tauri/tests/fixtures/cross_lang_naming.json` — tabla naming (3 casos).
  Ambos lados las cargan vía `env!("CARGO_MANIFEST_DIR")` (Rust) o
  `systemProperty("fw.fixtures.*")` (gradle/JVM).
