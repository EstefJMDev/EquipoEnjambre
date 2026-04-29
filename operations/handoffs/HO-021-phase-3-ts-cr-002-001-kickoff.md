# Standard Handoff

document_id: HO-021
from_agent: Handoff Manager
to_agent: Android Share Intent Specialist
status: ready_for_execution
phase: 3
date: 2026-04-28
cycle: Implementación Fase 3 — T-CR-002-001 Mobile Observer Core (TileService + ForegroundService + Capture Layer + Session Builder mobile)
opens: implementación del pipeline de captura mobile end-to-end — TileService (Quick Settings tile), ForegroundService (START_NOT_STICKY, PGR C3), Capture Layer (ACTION_SEND dinámico + paste explícito, cifrado ≤ 500 ms PGR C4), Session Builder mobile (SessionBuilderConfig::mobile()), subscription stub (tabla subscription_state), consentimiento explícito (PGR C1), timeout automático 30 min (PGR C5).
depends_on: TS-CR-002-001 aprobada con 4 visados (Privacy Guardian, Functional Analyst, QA Auditor, Orchestrator — 2026-04-28). Autorizado por D9 extensión (2026-04-27), AR-CR-002-mobile-observer (Technical Architect, 2026-04-27), PGR-CR-002-mobile-observer (Privacy Guardian, 2026-04-27), D22 Opción B (2026-04-24), backlog-phase-3.md APROBADO por AR-3-001 (2026-04-28), OD-006 (Fase 3 abierta, 2026-04-28).
unblocks: T-CR-002-002 (Episode Detector mobile + sección Observer del Privacy Dashboard mobile) y AR-CR-002-IMPL-001 (revisión arquitectónica post-implementación de Observer Core — a emitir tras cierre de este HO).

---

## Objetivo

Implementar el pipeline de captura mobile end-to-end definido en TS-CR-002-001
al pie de la letra: el observer semi-pasivo Android que activa la captura de
URLs exclusivamente durante sesiones explícitas del usuario (tile ON), cumple
todos los controles de privacidad PGR B1/B2/B3/B5/C1/C3/C4/C5/PV-M-004, y
persiste raw_events en SQLCipher Android con distinción de tier libre/paid
(columna `source`).

La implementación abarca seis ejes coordinados:

1. **TileService Kotlin** — `FlowWeaverTileService.kt`: punto de activación
   consciente del observer. Registra handler dinámico de ACTION_SEND al activar
   el tile (D9 extensión); desregistra al desactivar. Verifica suscripción
   (`paid_active`) antes de iniciar ForegroundService. Verifica consentimiento
   explícito (PGR C1) antes del primer uso.

2. **ForegroundService Kotlin** — `FlowWeaverObserverService.kt`:
   `START_NOT_STICKY` (PGR PV-M-004). Notificación visible obligatoria con
   texto `"FlowWeaver capturando — sesión activa desde {HH:MM}"` y acción
   "Cerrar sesión" no dismissable (PGR C3). Timer de inactividad de 30 min
   default (PGR C5).

3. **Capture Layer Kotlin** — `CaptureLayer.kt`: handler de ACTION_SEND
   registrado dinámicamente + paste explícito en app. Cifrado URL/title en
   RAM ≤ 500 ms vía JNI hacia `crypto.rs` (PGR C4). Si supera 500 ms,
   descarte sin persistencia en plaintext. Persistencia en SQLCipher Android
   via `storage.rs`. Logs de debug sin `url` ni `title` (D1).

4. **Session Builder mobile Rust** — refactor de `session_builder.rs` a
   `SessionBuilderConfig` con presets `desktop()` y `mobile()` (`GAP_SECS =
   2_700`, `MAX_WINDOW_SECS = 7_200`). Constantes legacy mantenidas como alias
   de compatibilidad. Sin modificar `episode_detector.rs` (R12 explícito).

5. **Subscription stub Rust/SQLCipher** — tabla `subscription_state`
   (singleton, `paid_active = 0` por defecto). Comando Tauri de prueba
   `subscription_set_paid_active` gated por `#[cfg(debug_assertions)]`
   (ausente en release — AC-14). Integración Google Play Billing: CR antes
   de Fase 3 — out of scope de este TS.

6. **Tests** — 8 tests Rust nuevos + 6 tests instrumentados Android cubriendo
   los 19 criterios de aceptación de TS-CR-002-001.

La implementación queda **estrictamente acotada** a TS-CR-002-001. Cualquier
ambigüedad o desviación se escala al Orchestrator antes de proceder.

**Restricción de despliegue en producción:** la implementación puede comenzar
en entorno de desarrollo antes del cierre de los prerequisitos de beta. El
observer mobile NO se despliega en producción hasta que P-0 (O-002 — relay
Google Drive operativo) y P-1 (criterio #18 AR-2-007 — FS Watcher
background-persistent verificado) estén cerrados, tal como establece
backlog-phase-3.md.

---

## Inputs

Lectura obligatoria antes de cualquier edición:

### Spec autoritativa

- **TS-CR-002-001:**
  `operations/task-specs/TS-CR-002-001-mobile-observer-core.md`
  (producida por Technical Architect 2026-04-27, APROBADA con 4 visados
  2026-04-28). Es la **única fuente de verdad** para esta implementación.
  Todos los contratos (ciclo de vida del tile, mecanismos de captura, schemas
  SQLCipher, pantalla de consentimiento, timeout de inactividad, comandos
  Tauri, resoluciones R1–R4) están declarados literalmente y deben
  implementarse sin parafrasear.

### Decisiones cerradas

- **`Project-docs/decisions-log.md`:**
  - D1 (transversal absoluto: `url` y `title` cifrados antes de persistir;
    logs sin plaintext; schemas sin campos de URL/título/contenido).
  - D9 extensión (2026-04-27): handler ACTION_SEND registrado dinámicamente
    al activar el tile y desregistrado al desactivarlo; ForegroundService
    activo solo durante sesión del tile; sin observación en background bajo
    ninguna circunstancia.
  - D14: Privacy Dashboard completo obligatorio antes de beta (la sección
    "Observer" del Privacy Dashboard mobile se difiere a T-CR-002-002 — los
    comandos Tauri de este TS son el contrato que T-CR-002-002 consumirá).
  - D17: el observer mobile NO genera DetectedPattern. El Pattern Detector
    existente (compilado para Android via NDK) consume los raw_events de forma
    asíncrona. Sin lógica de patrones nueva en este TS.
  - D19: implementación completa Android; Windows desktop solo afectado por
    el refactor de `session_builder.rs` (comportamiento idéntico para callers
    existentes — AC-18 lo verifica).
  - D20 / D21: relay sin cambios; análisis local al dispositivo; raw_events
    con campo `source` nuevo pero protocolo relay sin modificar.
  - D22 Opción B: tier paid existe como `paid_active = 1` en
    `subscription_state`. La integración real de billing es CR pendiente.
  - R12: Observer Mobile ≠ Pattern Detector ≠ Episode Detector. Comentario
    de cabecera obligatorio en `CaptureLayer.kt` con tabla comparativa de tres
    columnas. `pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs` no
    se modifican (AC-6).

### Controles PGR (no negociables)

- **PGR-CR-002-mobile-observer.md** (Privacy Guardian, 2026-04-27):
  - B1/C1: pantalla de consentimiento explícito antes del primer uso. AC-5.
  - B2: handler dinámico verificable. AC-15.
  - B3/C4: D1 operativo en logs y persistencia; cifrado ≤ 500 ms. AC-8,
    AC-10, AC-11, AC-13.
  - B5/C5: timeout automático de sesión default 30 min, configurable 5 min
    – 4 h. AC-2, AC-12.
  - C3: desactivación accesible desde tile, notificación y (en T-CR-002-002)
    dashboard. AC-3.
  - PV-M-004: ForegroundService START_NOT_STICKY, no reanuda automáticamente
    tras kill manual. AC-16.

### Resoluciones del Technical Architect (declaradas — no interpretables)

- **R1 — Mecanismo de captura:** ACTION_SEND dinámico + paste explícito en
  app. Prohibidos: listener pasivo de portapapeles (`OnPrimaryClipChangedListener`),
  Accessibility Service, lectura del historial del navegador.
- **R2 — Subscription verification:** tabla `subscription_state` singleton;
  `paid_active = 0` por defecto; `subscription_set_paid_active` solo en
  debug; billing real diferido a CR antes de Fase 3.
- **R3 — Relay sin cambios:** raw_events con campo `source` nuevo son
  sintácticamente idénticos al formato existente; relay transporta raw_events
  sin modificar protocolo.
- **R4 — Distinción tier free/paid:** `source = 'tile_session'` (tier paid),
  `source = 'share_intent'` (tier free), `source = 'paste'` (ambos tiers);
  migración `ALTER TABLE resources ADD COLUMN source TEXT NOT NULL DEFAULT
  'share_intent'`.

### Arquitectura de referencia

- **AR-CR-002-mobile-observer.md** (Technical Architect, 2026-04-27):
  umbrales mobile del Session Builder, flujo del observer, verificación NDK.
- **Código existente a no modificar:**
  - `src-tauri/src/pattern_detector.rs`, `trust_scorer.rs`,
    `state_machine.rs` — sin modificaciones (AC-6).
  - `src-tauri/src/episode_detector.rs` — sin modificaciones (R12; la
    parametrización del Episode Detector mobile es T-CR-002-002).
  - `android/` — infraestructura Tauri Android existente sin cambios de
    protocolo relay.

### Comandos de verificación

```bash
# Rust desktop (sin regresiones)
cd src-tauri && cargo test

# Rust Android (NDK)
cd src-tauri && cargo build --target aarch64-linux-android --release
cd src-tauri && cargo test --target aarch64-linux-android

# TypeScript
npx tsc --noEmit

# Tests instrumentados Android (en dispositivo o emulador)
./gradlew connectedAndroidTest
```

---

## Entregables esperados

### Rust (`src-tauri/src/`)

1. **`session_builder.rs`** — refactor a `SessionBuilderConfig` con presets
   `desktop()` y `mobile()`. Constantes `GAP_SECS` / `MAX_WINDOW_SECS`
   mantenidas como alias deprecated para compatibilidad. Sin modificar
   `episode_detector.rs`.

2. **`commands.rs`** — comandos nuevos:
   - `subscription_get_state`
   - `subscription_set_paid_active` (gated por `#[cfg(debug_assertions)]`)
   - `observer_config_get`
   - `observer_config_set_inactivity_timeout`
   - `observer_consent_grant`

3. **`storage.rs`** — tres migraciones idempotentes:
   - Tabla `subscription_state` (singleton, `paid_active = 0`).
   - `ALTER TABLE resources ADD COLUMN source TEXT NOT NULL DEFAULT
     'share_intent'` + índice `idx_resources_source`.
   - Tabla `observer_config` (singleton, `inactivity_timeout_secs = 1800`).

4. **Tests Rust nuevos (mínimo 8):**
   - `test_mobile_config_splits_at_gap_secs`
   - `test_subscription_state_singleton_idempotent`
   - `test_observer_config_inactivity_timeout_bounds`
   - `test_resources_source_column_default_is_share_intent`
   - `test_no_url_or_title_in_observer_schemas`
   - `test_subscription_set_paid_active_unavailable_in_release`
   - `test_session_builder_desktop_preset_unchanged`
   - `test_consent_grant_updates_timestamp_and_version`

### Kotlin (`android/app/src/main/kotlin/.../`)

5. `tile/FlowWeaverTileService.kt` — TileService con ciclo de vida estricto
   (R1): onClick con estado INACTIVE/ACTIVE, verificación `paid_active`,
   verificación de consentimiento, inicio/cierre de ForegroundService,
   registro/desregistro dinámico del handler ACTION_SEND.

6. `service/FlowWeaverObserverService.kt` — ForegroundService
   `START_NOT_STICKY` (PGR PV-M-004). Notificación no dismissable con acción
   "Cerrar sesión" (PGR C3). Actualización de tiempo transcurrido cada 60 s.

7. `capture/CaptureLayer.kt` — handler dinámico ACTION_SEND + paste explícito.
   `encryptAndPersist` con límite de 500 ms (PGR C4): si supera el límite,
   descarte sin retener plaintext en RAM. Logs de debug sin `url` ni `title`.

8. `consent/ConsentActivity.kt` — pantalla de consentimiento con texto literal
   declarado en TS-CR-002-001 §"Pantalla de Consentimiento". Botón "Acepto y
   activo el modo" actualiza `observer_config.consent_granted_at` y
   `consent_version = 1`.

9. `paywall/PaywallActivity.kt` — stub UI para `paid_active = 0` con texto
   literal declarado en TS-CR-002-001 §R2.

10. `timeout/InactivityTimer.kt` — temporizador reseteable con cada
    `RawEvent`. Al expirar (`inactivity_timeout_secs` default 1800 s), invoca
    cierre del tile + log `"session_timeout"`.

11. **Tests instrumentados Android (mínimo 6):** AC-1, AC-2, AC-3, AC-5,
    AC-9a, AC-15.

### TypeScript (`src/types.ts`)

12. Tipos nuevos bajo cabecera
    `// ── Phase 2 — Mobile Observer (T-CR-002-001) ──`:

    ```typescript
    export interface SubscriptionState {
      paid_active: boolean;
      validated_at: number | null;
      expires_at: number | null;
    }

    export interface ObserverConfig {
      inactivity_timeout_secs: number;
      consent_granted_at: number | null;
      consent_version: number;
    }

    export type CaptureSource = 'share_intent' | 'tile_session' | 'paste';
    ```

### AndroidManifest

13. TileService declarado estáticamente (Quick Settings tiles lo requieren).
    **Sin** declaración estática de handler ACTION_SEND para el observer (D9
    extensión — AC-15). ForegroundService declarado con
    `android:foregroundServiceType="dataSync"` o equivalente Android 14+.

### Cargo.toml

14. Sin dependencias nuevas. La integración Android se hace vía la
    infraestructura Tauri Android existente.

---

## Restricciones (no negociables)

### D1 — privacidad (transversal absoluto)

- `url` y `title` cifrados (AES-GCM via `crypto.rs`) antes de persistir en
  SQLCipher Android. Auditable por AC-8.
- `source` NO es campo sensible; almacena valores enumerados en claro.
- Logs de debug y release sin `url`, `title`, ni URL completa de ninguna
  captura. Auditable por AC-11.
- Schemas de las tres tablas nuevas sin ningún campo `url`, `title`, `link`,
  `href`, `bookmark_url`, `page_title`, `content`. Auditable por AC-13.

### D9 extensión (2026-04-27) — observer semi-pasivo Android

- Handler ACTION_SEND registrado **dinámicamente** al activar el tile y
  desregistrado al desactivarlo. Auditable por AC-15.
- ForegroundService activo **solo** durante sesión del tile. Auditable por
  AC-2.
- Notificación visible obligatoria con acción de cierre directamente accesible.
  Auditable por AC-3.
- Sin observación en background bajo ninguna circunstancia. Auditable por
  AC-1, AC-15, AC-16.

### D14 — Privacy Dashboard

- La sección "Observer" del Privacy Dashboard mobile se difiere a
  T-CR-002-002. Este TS entrega los comandos Tauri (`subscription_get_state`,
  `observer_config_get`, etc.) que T-CR-002-002 consumirá.

### D17 — Pattern Detector completo solo en Fase 2 (transitivo)

- El observer mobile NO genera `DetectedPattern`. Sin lógica de patrones nueva
  en este TS. `pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs`
  no se modifican. Auditable por AC-6.

### D19 — Windows + Android primario

- Implementación completa Android (este TS).
- Windows desktop solo afectado por el refactor de `session_builder.rs` que
  mantiene comportamiento idéntico para callers existentes. Auditable por
  AC-18.

### D22 Opción B — freemium mobile

- Tier paid verificado vía `subscription_state.paid_active`. Con
  `paid_active = 0`, el tile lanza paywall y no genera raw_events con
  `source = 'tile_session'`. Auditable por AC-9a/AC-9b.

### R12 — distinción transitiva

- Comentario de cabecera obligatorio en `CaptureLayer.kt` con tabla
  comparativa de tres columnas (Observer Mobile, Pattern Detector, Episode
  Detector).
- `pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs` sin
  modificaciones. Auditable por AC-6.
- Episode Detector mobile se cubre en T-CR-002-002, no aquí.

### Constraints específicos T-CR-002-001 (R1)

- **No listener pasivo del portapapeles.** `OnPrimaryClipChangedListener`
  prohibido. Auditable por AC-17 (grep negativo en Kotlin).
- **No Accessibility Service.** Auditable por AC-15 (inspección de manifest).
- **No lectura del historial del navegador.** Auditable por inspección de
  Kotlin.
- **`subscription_set_paid_active` ausente en release.** Auditable por AC-14
  (inspección del binario release).

---

## Criterios de cierre

El HO de cierre (al Technical Architect, solicitando AR-CR-002-IMPL-001) debe
reportar cada ítem con referencia verificable:

1. **AC-1 a AC-19 satisfechos línea por línea** con referencia a archivo,
   función o test concreto.
2. **Conteo de tests Rust** (`passed / failed / ignored`) de `cargo test`
   desktop. Conteo debe ser igual o mayor al número previo + 8 tests nuevos
   de este TS.
3. **Conteo de tests Rust Android** (`passed / failed / ignored`) de
   `cargo test --target aarch64-linux-android`.
4. **Conteo de tests instrumentados Android** (mínimo 6 pasando): AC-1, AC-2,
   AC-3, AC-5, AC-9a, AC-15.
5. **Estado de `cargo build --target aarch64-linux-android --release`** (verde
   requerido).
6. **Estado de `cargo build --target x86_64-pc-windows-msvc`** (verde
   requerido — regresión desktop).
7. **Estado de `npx tsc --noEmit`** (limpio requerido).
8. **Verificación funcional manual en dispositivo Android real** de los 5
   escenarios críticos: AC-1 (tile OFF → no raw_event), AC-2 (ForegroundService
   ciclo completo — 3 escenarios), AC-3 (notificación con cierre funcional),
   AC-9a (`paid_active = 0` → paywall, sin ForegroundService), AC-15
   (AndroidManifest sin `<intent-filter>` estático ACTION_SEND para observer).
9. **Captura textual de la notificación del ForegroundService** (texto visible
   + acción "Cerrar sesión" verificada).
10. **Confirmación de que `ConsentActivity` se muestra en fresh install** y
    que raw_events con `source = 'tile_session'` no aparecen sin
    `consent_granted_at`.
11. **Confirmación de que el binario release no contiene
    `subscription_set_paid_active`** (`strings binary | grep` negativo o
    equivalente — AC-14).
12. **Confirmación de que `AndroidManifest.xml` no declara
    `<intent-filter android:name="android.intent.action.SEND">`** con la
    actividad del observer (AC-15).
13. **Confirmación de que ningún `Log.*` en Kotlin imprime `url` o `title`**
    (AC-11, grep negativo).
14. **Cualquier desviación de TS-CR-002-001 con justificación** (idealmente
    cero desviaciones).

Si AR-CR-002-IMPL-001 aprueba sin correcciones, **T-CR-002-001 queda cerrado**
y se desbloquea T-CR-002-002 (Episode Detector mobile + sección Observer del
Privacy Dashboard mobile).

---

## Firma

submitted_by: Handoff Manager
submission_date: 2026-04-28
notes: |
  HO emitido tras completar los 4 visados requeridos por TS-CR-002-001 (Privacy
  Guardian, Functional Analyst, QA Auditor, Orchestrator — todos APROBADOS sin
  correcciones el 2026-04-28). La restricción de despliegue en producción (P-0 y P-1
  como prerequisitos bloqueantes de beta) proviene de backlog-phase-3.md y no impide
  el desarrollo en entorno local. La numeración HO-021 sigue el orden cronológico de
  emisión inmediatamente después de HO-020 (cierre de HO-FW-PD, Fase 2).

### Visados completados — autorización formal de implementación

Los cuatro visados se ejecutaron el 2026-04-28 sobre la versión aprobada de
TS-CR-002-001, contra AR-CR-002-mobile-observer y PGR-CR-002-mobile-observer
(2026-04-27) y contra backlog-phase-3.md aprobado por AR-3-001 (2026-04-28).

---

#### Visado 1 — Privacy Guardian ✅

**Visado por:** Privacy Guardian
**Fecha:** 2026-04-28
**Resultado:** APROBADO sin correcciones.

**Hallazgos:**

- **PGR B1 / C1 — Consentimiento explícito (AC-5):** `ConsentActivity.kt`
  bloqueante antes del primer uso del tile. El tile no es activable si
  `observer_config.consent_granted_at IS NULL`: al pulsarlo, lanza
  `ConsentActivity`. El texto literal del consentimiento está declarado
  en TS-CR-002-001 §"Pantalla de Consentimiento" e incluye explícitamente
  qué captura, qué NO captura, dónde se guardan los datos y cómo
  controlarlos. Correcto.

- **PGR B2 — Handler dinámico verificable (AC-15):** el handler de
  ACTION_SEND se registra programáticamente al activar el tile y se
  desregistra al desactivarlo. `AndroidManifest.xml` no declara
  `<intent-filter>` estático para ACTION_SEND con la actividad del
  observer. La verificación es auditable por inspección del manifest +
  test instrumentado AC-15. Correcto.

- **PGR B3 / C4 — D1 en cifrado ≤ 500 ms (AC-8, AC-10, AC-11, AC-13):**
  `CaptureLayer.kt` cifra `url` y `title` en RAM en ≤ 500 ms vía JNI
  hacia `crypto.rs`. Si el cifrado supera el límite, la captura se descarta
  sin retener plaintext. Los schemas de las tres tablas nuevas
  (`subscription_state`, `observer_config`, columna `source` en `resources`)
  no contienen ningún campo sensible de URL/título/contenido — auditable por
  `test_no_url_or_title_in_observer_schemas`. Logs de debug sin `url` ni
  `title` — auditable por AC-11 (grep negativo). Correcto.

- **PGR B5 / C5 — Timeout automático 30 min (AC-2, AC-12):** timer dentro
  de `FlowWeaverObserverService` que se reinicia con cada `RawEvent`.
  Default `inactivity_timeout_secs = 1800` (30 min), configurable entre
  300 s (5 min) y 14400 s (4 h) — constraint CHECK en `observer_config`.
  Al expirar, el servicio invoca cierre del tile idéntico al apagado manual.
  El timeout PGR (30 min) es más estricto que `GAP_SECS` (45 min) del
  Session Builder, lo cual es intencional: PGR C5 actúa como control de
  privacidad adicional sobre el límite analítico. Correcto.

- **PGR C3 — Notificación con acción de cierre (AC-3):** notificación no
  dismissable (`setOngoing(true)`) con texto `"FlowWeaver capturando —
  sesión activa desde {HH:MM}"` y acción primaria "Cerrar sesión"
  (PendingIntent que invoca cierre del tile). Canal con
  `IMPORTANCE_LOW` para visibilidad sin sonido. Actualización del tiempo
  transcurrido cada 60 s. Correcto.

- **PGR PV-M-004 — No reanuda automáticamente (AC-16):** `onStartCommand`
  devuelve `START_NOT_STICKY`. Después de un kill manual desde la
  notificación, reiniciar el dispositivo deja el servicio sin reanudar.
  Verificable por test instrumentado AC-16. Correcto.

- **R1 — Sin listener pasivo del portapapeles ni Accessibility Service
  (AC-17, AC-15):** TS-CR-002-001 §R1 declara literalmente la prohibición
  de `ClipboardManager.OnPrimaryClipChangedListener`, Accessibility Service
  y lectura del historial del navegador. AC-17 es un grep negativo
  verificable sobre el código Kotlin. Correcto.

**Sin correcciones.** Todos los controles PGR B1/B2/B3/B5/C1/C3/C4/C5
y PV-M-004 están mapeados a criterios de aceptación verificables.

---

#### Visado 2 — Functional Analyst ✅

**Visado por:** Functional Analyst
**Fecha:** 2026-04-28
**Resultado:** APROBADO sin correcciones.

**Hallazgos:**

- **Cobertura de T-3-004 en backlog-phase-3.md:** T-3-004 figura como
  "Observer semi-pasivo Android — Tile de sesión (tier paid, D9 extensión,
  CR-002)" con nota `[BLOQUEADO hasta TS formal aprobada por Technical
  Architect y Privacy Guardian]`. TS-CR-002-001 ha sido aprobada por ambos
  agentes. Este HO levanta formalmente el bloqueo documental de T-3-004.
  La condición de despliegue en producción (P-0 y P-1) es un bloqueo de
  beta pública separado del bloqueo de implementación — el backlog lo
  distingue explícitamente.

- **Coherencia con D22 + CR-002:** D22 Opción B (freemium mobile) establece
  que el tier paid existe. CR-002 aprobó en intención el observer
  semi-pasivo con Tile de sesión. TS-CR-002-001 materializa esa intención
  con resoluciones precisas: subscription stub con `paid_active`, paywall
  UI stub, billing real diferido a CR antes de Fase 3. Coherente.

- **Suficiencia de los 19 ACs para la hipótesis de Fase 3:** la hipótesis
  de Fase 3 es "tolerancia del usuario a la automatización progresiva".
  Los 19 ACs cubren el pipeline completo — desde consentimiento explícito
  (AC-5) hasta distinción de tier en SQLCipher (R4), pasando por timeout
  configurable (AC-2, AC-12), notificación transparente (AC-3) y
  subscription stub testeable en QA (AC-9a/AC-9b). El pipeline entregado
  por este TS genera los raw_events con `source = 'tile_session'` que la
  State Machine consumirá en Fase 3 para medir aceptación de sugerencias
  del tier paid. Suficiente.

- **Distinción tier free / paid en columna `source`:** R4 declara
  `source = 'tile_session'` para el observer (tier paid), `source =
  'share_intent'` para el Share Intent (tier free), `source = 'paste'`
  para paste explícito. La migración `ALTER TABLE resources ADD COLUMN
  source TEXT NOT NULL DEFAULT 'share_intent'` mantiene compatibilidad
  con raw_events existentes. PGR C2 (distinguir capture explícita de
  capture del observer en Privacy Dashboard) queda satisfecho —
  T-CR-002-002 lo consumirá para la sección Observer del dashboard.
  Correcto.

- **Out of scope explícitos consistentes con el backlog:** `episode_detector_mobile.rs`
  → T-CR-002-002; sección "Observer" del Privacy Dashboard mobile →
  T-CR-002-002; integración Google Play Billing → CR antes de Fase 3.
  Todos estos out-of-scopes son coherentes con la cadena de entregables
  declarada en backlog-phase-3.md y con las decisiones D14, D17.

**Sin correcciones.** TS-CR-002-001 cubre T-3-004 por completo y es
coherente con D22, CR-002 y la hipótesis de validación de Fase 3.

---

#### Visado 3 — QA Auditor ✅

**Visado por:** QA Auditor
**Fecha:** 2026-04-28
**Resultado:** APROBADO sin correcciones.

**Hallazgos:**

**Mapeo de los 19 ACs contra métodos de verificación:**

| AC | Método de verificación | Verificable |
|---|---|---|
| AC-1 | Test instrumentado Android: tile OFF → ACTION_SEND → `SELECT COUNT(*)` = 0 | Sí |
| AC-2 | Test instrumentado Android: 3 escenarios (manual, timeout PGR, timeout TA) | Sí |
| AC-3 | Test instrumentado en dispositivo real: notificación + acción "Cerrar sesión" | Sí |
| AC-4 | Test unitario Rust: `test_mobile_config_splits_at_gap_secs` | Sí |
| AC-5 | Test instrumentado: fresh install → tap tile → `ConsentActivity` visible | Sí |
| AC-6 | Grep negativo: `#[cfg(target_os = "android")]` ausente en los 3 archivos | Sí |
| AC-7 | `cargo build --target aarch64-linux-android` verde + `cargo test` verde | Sí |
| AC-8 | Test estructural Rust + revisión manual Kotlin | Sí |
| AC-9a | Test instrumentado: `subscription_set_paid_active(false)` → paywall, sin servicio | Sí |
| AC-9b | Test instrumentado complementario a AC-9a con `paid_active = 1` | Sí |
| AC-10 | Test unitario Kotlin con mock de Classifier lento (>500 ms) → 0 raw_events | Sí |
| AC-11 | Grep negativo de `Log.*url` y `Log.*title` en código Kotlin | Sí |
| AC-12 | Test unitario Rust: `test_subscription_state_singleton_idempotent` + `test_observer_config_inactivity_timeout_bounds` | Sí |
| AC-13 | Test estructural `test_no_url_or_title_in_observer_schemas` | Sí |
| AC-14 | Inspección binario release: `strings binary \| grep subscription_set_paid_active` → ausente | Sí |
| AC-15 | Inspección `AndroidManifest.xml` + test instrumentado tile OFF → ACTION_SEND no entregado | Sí |
| AC-16 | Test instrumentado: cerrar desde notificación → reboot → servicio inactivo | Sí |
| AC-17 | Grep negativo `OnPrimaryClipChangedListener` en Kotlin | Sí |
| AC-18 | `cargo test` desktop: conteo previo + nuevos tests / 0 failed / 0 ignored | Sí |
| AC-19 | `npx tsc --noEmit`: salida limpia | Sí |

**Hallazgos adicionales:**

- **Ningún AC imposible de comprobar:** los 19 ACs tienen método de
  verificación concreto — tests unitarios Rust, tests instrumentados Android,
  greps estructurales o inspección de artefacto (binario, manifest). El AC
  más complejo (AC-16 — reboot tras kill manual) es verificable en dispositivo
  real y está correctamente categorizado como test instrumentado.

- **Tests Rust cubren la cadena de invariantes de privacidad:**
  `test_no_url_or_title_in_observer_schemas` (AC-13) y
  `test_resources_source_column_default_is_share_intent` (AC para R4) son
  tests estructurales que blindan los schemas contra drift futuro. El
  mismo patrón probado en TS-2-000 (test estructural D1) se aplica aquí
  con coherencia.

- **Tests instrumentados Android cubren el ciclo de vida crítico:**
  los 6 tests mínimos (AC-1, AC-2, AC-3, AC-5, AC-9a, AC-15) cubren el
  tile completo — desde activación con consentimiento hasta verificación
  de subscription y ausencia de ACTION_SEND en background. El conjunto
  es suficiente para detectar regresiones en el ciclo de vida del observer.

- **Verificación de binario release (AC-14):** el comando
  `subscription_set_paid_active` gated por `#[cfg(debug_assertions)]` es
  auditable por inspección del binario release con `strings` o equivalente.
  Patrón correcto y verificable por QA sin requerir compilación adicional.

- **Plan de verificación completo:** los 5 escenarios de verificación manual
  en dispositivo real declarados en TS-CR-002-001 §"Verificación Final"
  complementan los tests automatizados cubriendo el ciclo end-to-end que
  los tests unitarios no pueden ejercitar sin infraestructura Android real.

**Sin correcciones.** Los 19 ACs son verificables, el plan de tests cubre
la suite completa sin ACs imposibles de comprobar.

---

#### Visado 4 — Orchestrator ✅

**Visado por:** Orchestrator
**Fecha:** 2026-04-28
**Resultado:** APROBADO. Status: `ready_for_execution`.

**Verificaciones finales:**

- **Visados 1-3 completos:** Privacy Guardian, Functional Analyst y QA
  Auditor han firmado sin correcciones el 2026-04-28. Los cuatro visados
  requeridos por TS-CR-002-001 están completos.

- **Alineación con OD-006 y backlog-phase-3.md:** OD-006 abre Fase 3 el
  2026-04-28. backlog-phase-3.md (APROBADO por AR-3-001, 2026-04-28)
  incluye T-3-004 como entregable de Fase 3 — observer semi-pasivo Android
  con Tile de sesión. TS-CR-002-001 es la spec formal de T-3-004.
  Alineación confirmada.

- **Prerequisitos de implementación satisfechos:** TS-CR-002-001 firmada
  (Technical Architect, 2026-04-27), AR-CR-002-mobile-observer aprobado
  (2026-04-27), PGR-CR-002-mobile-observer aprobado (2026-04-27), D9
  extensión registrada (2026-04-27), D22 Opción B cerrada (2026-04-24),
  backlog-phase-3.md aprobado (2026-04-28), OD-006 emitido (2026-04-28).
  Ningún bloqueo documental activo.

- **Restricción de despliegue en producción:** el observer mobile no se
  despliega ante usuarios beta hasta que P-0 (O-002 — relay Google Drive
  operativo) y P-1 (criterio #18 AR-2-007 — FS Watcher background-persistent
  verificado) estén cerrados. Estos son prerequisitos de beta pública, no
  de implementación en desarrollo. El Android Share Intent Specialist puede
  comenzar la implementación inmediatamente en entorno de desarrollo.

- **Numeración HO-021:** sigue el orden cronológico de emisión
  inmediatamente después de HO-020 (cierre de HO-FW-PD).

**Autorización:** el Android Share Intent Specialist queda formalmente
autorizado a comenzar la implementación de T-CR-002-001 siguiendo
TS-CR-002-001 y este HO al pie de la letra. Cualquier ambigüedad detectada
durante la implementación se escala al Orchestrator antes de proceder con
interpretación.

Tras completar los 14 criterios de cierre (sección §"Criterios de cierre"),
el implementador emite el HO de cierre al Technical Architect solicitando
AR-CR-002-IMPL-001 (revisión arquitectónica post-implementación de Observer
Core). El patrón a seguir es HO-018 (cierre de T-2-000 implementación).
Si AR-CR-002-IMPL-001 aprueba sin correcciones, T-CR-002-001 queda cerrado
y se desbloquea T-CR-002-002.
