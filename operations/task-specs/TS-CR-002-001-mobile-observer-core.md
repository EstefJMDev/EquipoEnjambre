# Task Spec — TS-CR-002-001

document_id: TS-CR-002-001
task_id: T-CR-002-001
title: Mobile Observer Core — TileService + ForegroundService + Capture Layer + Session Builder mobile
phase: 2 (track paralelo Android — CR-002)
produced_by: Technical Architect
status: APPROVED — visados completos en HO-021 (2026-04-28)
date: 2026-04-27
depends_on:
  - D9 extensión (decisions-log.md, 2026-04-27 — autoriza Tile de sesión + handler dinámico)
  - AR-CR-002-mobile-observer.md (Technical Architect, 2026-04-27)
  - PGR-CR-002-mobile-observer.md (Privacy Guardian, 2026-04-27 — controles C1–C5 obligatorios)
  - D22 Opción B (decisions-log.md, 2026-04-24 — tier paid existe)
  - D20 / D21 (mobile standalone, relay sin cambios)
unblocks:
  - T-CR-002-002 (Episode Detector mobile + Privacy Dashboard mobile section)
  - AR-CR-002-IMPL-001 (revisión arquitectónica post-implementación de Observer Core)

---

## Distinción Obligatoria R12 — Observer Mobile ≠ Pattern Detector ≠ Episode Detector

**Esta sección debe reproducirse como comentario de cabecera en los módulos nuevos.**

| Dimensión | Observer Mobile (Capture Layer) | `pattern_detector.rs` | `episode_detector.rs` (desktop) |
|---|---|---|---|
| Función | Captura de URL en sesión activa de tile | Patrones longitudinales | Episodios de sesión activa |
| Plataforma | Android (Kotlin) + Rust (Capture Layer) | Cross-platform Rust | Cross-platform Rust |
| Escala temporal | Tiempo real, durante tile ON | Días/semanas | Sesión activa |
| Input | ACTION_SEND + paste explícito en app | SQLCipher resources | Stream de captures |
| Output | `RawEvent` cifrado (D1) | `DetectedPattern` | `Episode` |
| Persistencia | Solo SQLCipher resources Android (D1) | Patrones detectados | Sin estado |
| Activación | Tile ON + suscripción activa | No aplica (lectura) | No aplica (memoria) |
| Decisión clave | D9 extensión, D22 | D17 | (heredado Fase 1) |

**El Observer Mobile no llama directamente a Pattern Detector / Trust Scorer / State Machine durante la captura.** Esos módulos consumen SQLCipher de forma asíncrona (Trust Scorer en T-CR-002-002). El Observer solo persiste raw_events en SQLCipher Android.

---

## Objetivo

Implementar el pipeline de captura mobile end-to-end:

1. **TileService** (Android Quick Settings tile) — punto de activación consciente del usuario.
2. **ForegroundService** — servicio activo solo durante sesión del tile, con notificación visible y acción de cierre directamente accesible (PGR C3).
3. **Capture Layer** — handler dinámico de ACTION_SEND + paste explícito en app, cifrado de URL/title en RAM ≤ 500 ms (PGR C4), persistencia en SQLCipher Android via interfaz Rust existente.
4. **Session Builder mobile** — reutiliza `session_builder.rs` con constantes mobile (`GAP_SECS = 2_700`, `MAX_WINDOW_SECS = 7_200`).
5. **Subscription stub** — tabla `subscription_state` en SQLCipher Android; el tile verifica `paid_active = 1` antes de iniciar el ForegroundService (AC-9).
6. **Verificación NDK** — Pattern Detector / Trust Scorer / State Machine compilan para `aarch64-linux-android` sin modificar lógica Rust desktop (AC-7).
7. **Onboarding de consentimiento** (PGR B1, C1) — pantalla de consentimiento explícito antes del primer uso del tile.
8. **Timeout automático de sesión** (PGR B5, C5) — default 30 min de inactividad cierra la sesión, configurable 5 min–4 h.

**Out of scope de este TS** (cubierto en T-CR-002-002 o posteriores):

- `episode_detector_mobile.rs` (módulo Rust separado) → T-CR-002-002.
- Sección "Observer" del Privacy Dashboard mobile → T-CR-002-002 (PGR B4/C2).
- Integración real de Google Play Billing → CR formal antes de Fase 3.
- Sync de raw_events mobile → desktop vía relay → ya cubierto por D21 sin cambios.

---

## Resoluciones del Technical Architect (declaradas para implementación)

Estas cuatro resoluciones cierran las ambigüedades detectadas tras AR-CR-002 y PGR-CR-002. El implementador no debe interpretarlas — están declaradas literalmente.

### R1 — Mecanismo de captura del Capture Layer

El Capture Layer recibe URLs de **dos fuentes y solo dos**:

1. **ACTION_SEND** vía handler de Intent registrado **dinámicamente** al activar el tile (D9 extensión — registro en `AndroidManifest` está prohibido).
2. **Paste explícito dentro de la app FlowWeaver** — el usuario abre FlowWeaver y pega manualmente una URL en un campo dedicado de la UI mobile.

**Prohibido bajo cualquier circunstancia:**

- Listener pasivo de cambios del portapapeles del sistema (`ClipboardManager.OnPrimaryClipChangedListener` o equivalente). Si el implementador propusiera este mecanismo, se requiere CR formal con re-revisión del Privacy Guardian.
- Accessibility Service (rechazado permanentemente por PGR §7.3).
- Lectura del historial del navegador (rechazado permanentemente por PGR §7.3).

Esta delimitación satisface PGR Condición 3 ("scope de captura declarado y delimitado") sin necesidad de lista de exclusión de dominios sensibles, porque ambos vectores requieren **doble acción consciente del usuario** (tile ON + share/paste).

### R2 — Subscription verification (AC-9)

El tile verifica el estado de suscripción contra la tabla SQLCipher Android `subscription_state`:

```sql
CREATE TABLE IF NOT EXISTS subscription_state (
    id              INTEGER PRIMARY KEY CHECK (id = 1),
    paid_active     INTEGER NOT NULL DEFAULT 0 CHECK (paid_active IN (0, 1)),
    validated_at    INTEGER,
    expires_at      INTEGER,
    updated_at      INTEGER NOT NULL
);
```

Inicialización idempotente: una sola fila con `id = 1`, `paid_active = 0`, `validated_at = NULL`, `expires_at = NULL`.

**Comportamiento del tile:**

- `paid_active = 0` → tile muestra paywall stub (UI declarada en AC-9b); no inicia ForegroundService; cero raw_events generados.
- `paid_active = 1` → tile procede normalmente con la activación de sesión.

**Out of scope:** integración real con Google Play Billing. El TS entrega un comando Tauri de prueba `subscription_set_paid_active(active: bool)` (solo accesible en build debug) para que QA pueda alternar el estado durante validación. La integración real con billing se declara como **CR requerido antes de Fase 3** — el observer mobile no se despliega en producción sin esa CR.

### R3 — Relay sin cambios

El relay D21 (bidireccional Google Drive) transporta `raw_events`. Los raw_events generados por el Observer Mobile son sintácticamente idénticos a los del Share Intent (tier free) y se sincronizan al desktop por el mismo canal sin cambios al protocolo.

**El Observer Mobile NO sincroniza:**

- `DetectedPattern` (se recalculan en el desktop a partir de los raw_events sincronizados — D20: cada dispositivo procesa de forma independiente).
- `TrustState` (idem — local al dispositivo).
- Estado de la sesión activa del tile (efímero, no persiste entre dispositivos).

**El Observer Mobile SÍ sincroniza:**

- `raw_events` con campo nuevo opcional `source: 'share_intent' | 'tile_session' | 'paste'` para que el dashboard pueda distinguir el origen (PGR C2 requiere distinguir capture explícita de capture del observer en el Privacy Dashboard).

### R4 — Distinción tier free / tier paid en SQLCipher (PGR Condición 5)

Los raw_events generados por el observer (tier paid) se etiquetan con `source = 'tile_session'`. Los raw_events del Share Intent (tier free) usan `source = 'share_intent'`. El paste explícito usa `source = 'paste'`.

**Migración del schema `resources` Android:**

```sql
ALTER TABLE resources ADD COLUMN source TEXT NOT NULL DEFAULT 'share_intent';
CREATE INDEX IF NOT EXISTS idx_resources_source ON resources(source);
```

Si el usuario cancela el tier paid (`paid_active = 0`):

- Los raw_events con `source = 'tile_session'` permanecen (el usuario decide si los purga desde el Privacy Dashboard).
- Los raw_events con `source = 'share_intent'` y `'paste'` permanecen siempre (tier free).
- El tile pasa a paywall; cero capturas nuevas con `source = 'tile_session'`.

---

## Contratos del Módulo

### Módulo Kotlin: `android/app/src/main/kotlin/.../tile/FlowWeaverTileService.kt`

```kotlin
// Mobile Observer — TileService (T-CR-002-001)
// Punto de activación consciente del observer semi-pasivo (D9 extensión).
// Solo registra el handler dinámico de ACTION_SEND mientras el tile está ON.
// Verifica suscripción contra subscription_state antes de iniciar sesión (AC-9).
// Cierre del tile o timeout (30 min default por PGR C5) → drop del handler + stop del ForegroundService.

class FlowWeaverTileService : TileService() {
    override fun onClick() { /* alterna estado activo/inactivo del observer */ }
    override fun onStartListening() { /* refresca el icono según estado */ }
    override fun onStopListening() { /* sin efecto en el observer activo */ }
}
```

**Ciclo de vida estricto del tile:**

| Evento Android | Acción del observer |
|---|---|
| `onClick()` con `state == INACTIVE` y `paid_active == 0` | Lanza paywall activity, no cambia estado del tile |
| `onClick()` con `state == INACTIVE` y `paid_active == 1` | Verifica consentimiento (PGR C1), inicia ForegroundService, registra handler dinámico, marca tile como `ACTIVE` |
| `onClick()` con `state == ACTIVE` | Detiene ForegroundService, desregistra handler, purga buffer en RAM, marca tile como `INACTIVE` |
| Notificación → "Cerrar sesión" | Idéntico a `onClick()` con `state == ACTIVE` |
| Timeout de inactividad (30 min default) | Idéntico a `onClick()` con `state == ACTIVE` + log "session_timeout" |

### Módulo Kotlin: `.../service/FlowWeaverObserverService.kt`

```kotlin
// Mobile Observer — ForegroundService (T-CR-002-001)
// Activo solo durante sesión del tile. Notificación visible obligatoria con
// acción de cierre directa accesible (PGR C3). No reanuda automáticamente
// si el usuario lo termina desde la notificación (PGR PV-M-004).

class FlowWeaverObserverService : Service() {
    override fun onCreate() { /* construye notificación con acción de cierre */ }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // START_NOT_STICKY — no reanuda automáticamente (PGR PV-M-004)
        return START_NOT_STICKY
    }
    override fun onDestroy() { /* libera recursos, purga buffer */ }
    override fun onBind(intent: Intent?): IBinder? = null
}
```

**Constraints de la notificación (PGR C3, no negociables):**

- Texto visible: `"FlowWeaver capturando — sesión activa desde {HH:MM}"`.
- Acción primaria: `"Cerrar sesión"` (PendingIntent que invoca el cierre del tile).
- No dismissable mientras el observer esté activo (`setOngoing(true)`).
- Canal de notificación con importancia `IMPORTANCE_LOW` para evitar sonido pero garantizar visibilidad.
- Actualización del campo de tiempo transcurrido cada 60 segundos.

### Módulo Kotlin: `.../capture/CaptureLayer.kt`

```kotlin
// Mobile Observer — Capture Layer (T-CR-002-001)
// Recibe ACTION_SEND y paste explícito. Cifra URL/title en ≤ 500 ms (PGR C4)
// y persiste en SQLCipher Android via JNI hacia Rust (crypto.rs + storage.rs).
// Si el cifrado supera 500 ms, descarta la captura (no retiene plaintext en RAM).
// Logs de debug NUNCA contienen url ni title (D1, PGR C4).

object CaptureLayer {
    fun handleShareIntent(intent: Intent, source: CaptureSource): Result<Unit>
    fun handleExplicitPaste(rawText: String): Result<Unit>
    private fun encryptAndPersist(url: String, title: String?, source: CaptureSource): Result<Unit>
}

enum class CaptureSource { SHARE_INTENT, TILE_SESSION, PASTE }
```

### Módulo Rust: extensión de `src-tauri/src/session_builder.rs`

`session_builder.rs` debe parametrizar `GAP_SECS` y `MAX_WINDOW_SECS` por configuración en lugar de constantes globales hardcoded. **Decisión arquitectónica:** se introduce un struct `SessionBuilderConfig`:

```rust
pub struct SessionBuilderConfig {
    pub gap_secs: i64,
    pub max_window_secs: i64,
}

impl SessionBuilderConfig {
    pub const fn desktop() -> Self {
        Self { gap_secs: 10_800, max_window_secs: 86_400 }
    }

    pub const fn mobile() -> Self {
        Self { gap_secs: 2_700, max_window_secs: 7_200 }
    }
}

pub fn build_sessions(
    resources: &[Resource],
    config: &SessionBuilderConfig,
) -> Vec<Session>;
```

Las constantes `GAP_SECS` y `MAX_WINDOW_SECS` actuales pasan a ser **deprecated** dentro de `session_builder.rs` y se mantienen como alias hacia `SessionBuilderConfig::desktop()` por compatibilidad con código desktop existente. Cualquier caller debe migrar a `SessionBuilderConfig::desktop()` en una iteración posterior — fuera de scope de este TS.

**Restricción R12:** este cambio NO toca `episode_detector.rs`. La parametrización del Episode Detector mobile se cubre en T-CR-002-002 con módulo separado.

### Subscription verification — comando Tauri nuevo

```rust
#[tauri::command]
pub fn subscription_get_state(state: State<'_, DbState>) -> Result<SubscriptionState, String>;

#[tauri::command]
#[cfg(debug_assertions)]
pub fn subscription_set_paid_active(
    state: State<'_, DbState>,
    active: bool,
) -> Result<(), String>;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubscriptionState {
    pub paid_active: bool,
    pub validated_at: Option<i64>,
    pub expires_at: Option<i64>,
}
```

El comando `subscription_set_paid_active` solo está disponible en builds `debug_assertions` (no se compila en release). Auditable por inspección del binario release.

---

## Migraciones SQLCipher Android

Tres migraciones nuevas (idempotentes, patrón existente de `storage.rs`):

```sql
-- 1. Tabla de estado de suscripción (singleton row)
CREATE TABLE IF NOT EXISTS subscription_state (
    id              INTEGER PRIMARY KEY CHECK (id = 1),
    paid_active     INTEGER NOT NULL DEFAULT 0 CHECK (paid_active IN (0, 1)),
    validated_at    INTEGER,
    expires_at      INTEGER,
    updated_at      INTEGER NOT NULL
);

INSERT OR IGNORE INTO subscription_state (id, paid_active, updated_at)
VALUES (1, 0, strftime('%s', 'now'));

-- 2. Origen de la captura en raw_events (PGR C2 requiere distinguir tier free / tier paid)
ALTER TABLE resources ADD COLUMN source TEXT NOT NULL DEFAULT 'share_intent';
CREATE INDEX IF NOT EXISTS idx_resources_source ON resources(source);

-- 3. Configuración del observer (timeout de sesión y consentimiento del usuario)
CREATE TABLE IF NOT EXISTS observer_config (
    id                          INTEGER PRIMARY KEY CHECK (id = 1),
    inactivity_timeout_secs     INTEGER NOT NULL DEFAULT 1800 CHECK (inactivity_timeout_secs BETWEEN 300 AND 14400),
    consent_granted_at          INTEGER,
    consent_version             INTEGER NOT NULL DEFAULT 1,
    updated_at                  INTEGER NOT NULL
);

INSERT OR IGNORE INTO observer_config (id, inactivity_timeout_secs, updated_at)
VALUES (1, 1800, strftime('%s', 'now'));
```

**Restricción D1 absoluta:** ninguna de las tres tablas contiene `url`, `title` ni la URL completa de ninguna captura. Auditable por test estructural `test_no_url_or_title_in_observer_schemas`.

---

## Pantalla de Consentimiento (PGR B1, C1)

Activity Android (`ConsentActivity.kt`) bloqueante antes del primer uso del tile. Si `observer_config.consent_granted_at IS NULL`, el tile no es activable y al pulsarlo se lanza esta activity.

**Contenido literal obligatorio (PGR C1):**

```
[Título] FlowWeaver — Modo de captura activa

Cuando activas este modo, FlowWeaver guarda las URLs que tú compartes con
la app desde el navegador o que pegas manualmente, mientras el tile esté
encendido.

Lo que captura:
  • URLs que tú compartes vía "Compartir → FlowWeaver" durante la sesión
  • URLs que tú pegas manualmente en la app FlowWeaver

Lo que NO captura:
  • Tu navegación cuando el tile está apagado
  • El contenido de las páginas que visitas
  • URLs que copias al portapapeles (FlowWeaver no lee el portapapeles solo)
  • Datos de otras apps

Dónde se guardan:
  • Localmente en tu dispositivo, cifradas con SQLCipher (AES-256)
  • Nunca salen de tu dispositivo en texto claro

Cómo controlarlo:
  • Apagas el tile cuando quieras y se detiene la captura
  • Desde el Privacy Dashboard puedes ver y borrar lo capturado
  • Esta función forma parte del tier paid; puedes cancelarla en cualquier momento

[Botón secundario]  Cancelar
[Botón primario]    Acepto y activo el modo
```

El botón "Acepto y activo el modo" actualiza `observer_config.consent_granted_at = NOW`, `consent_version = 1`. Si el texto del consentimiento cambia en el futuro, se incrementa `consent_version` y se reabre el flujo (no se asume consentimiento previo).

---

## Timeout de Inactividad de Sesión (PGR B5, C5)

Mecanismo: **timer dentro del ForegroundService** que se reinicia con cada `RawEvent` capturado. Si el timer alcanza `observer_config.inactivity_timeout_secs` (default 1800 = 30 min), el servicio invoca el cierre del tile como si el usuario lo hubiera apagado manualmente.

**Coexistencia con timeouts del Episode Detector mobile (T-CR-002-002):**

- `inactivity_timeout_secs` (PGR, default 30 min, configurable 5 min–4 h) — cierra la sesión del tile y detiene el ForegroundService.
- `GAP_SECS` (TA, 45 min) — define el corte entre sesiones del Session Builder mobile dentro del análisis posterior.
- `MAX_WINDOW_SECS` (TA, 2 h) — define la ventana máxima de una sesión analítica.

**El que expire antes cierra la sesión.** En la práctica, el timeout de PGR (30 min) suele ser más estricto que el GAP_SECS (45 min) — esto es intencional: PGR C5 es un control de privacidad adicional sobre el límite analítico.

UI del timeout: configurable desde la sección Observer del Privacy Dashboard mobile (T-CR-002-002), no desde este TS. Por ahora el valor default queda fijado en 1800 s.

---

## Verificación NDK (AC-7)

Los módulos Rust existentes (`pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs`) deben compilar para `aarch64-linux-android` sin modificar su lógica.

**Comando de verificación:**

```bash
cd src-tauri && cargo build --target aarch64-linux-android --release
cd src-tauri && cargo test --target aarch64-linux-android
```

**Restricción R12:** ninguna de las pruebas de NDK puede introducir `#[cfg(target_os = "android")]` dentro de `pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs`. Si se requiere algún ajuste de plataforma, se hace en módulos auxiliares (e.g. `crypto.rs` puede tener variantes por plataforma, pero los tres módulos de la cadena de confianza no).

---

## Criterios de Aceptación

| # | Criterio | Verificable |
|---|---|---|
| AC-1 | Tile activa/desactiva la sesión. Con tile OFF, ACTION_SEND a FlowWeaver no produce raw_event. | Test instrumentado Android: tile OFF → ACTION_SEND → query `SELECT COUNT(*) FROM resources WHERE source = 'tile_session'` → 0 |
| AC-2 | ForegroundService inicia con tile ON y termina con tile OFF, con `MAX_WINDOW_SECS`, o con timeout de inactividad. | Test instrumentado: 3 escenarios (cierre manual, timeout PGR, timeout TA) |
| AC-3 | Notificación incluye acción "Cerrar sesión" no dismissable. Cierre desde notificación apaga el tile y detiene el servicio. | Test instrumentado en dispositivo real |
| AC-4 | Session Builder usa `SessionBuilderConfig::mobile()` cuando se invoca desde Android. Capturas con gap > 2_700 s producen sesiones distintas. | Test unitario Rust: `cargo test session_builder::tests::test_mobile_config_splits_at_gap_secs` |
| AC-5 | Consentimiento explícito bloquea el tile en primer uso. Sin `consent_granted_at`, el tile lanza `ConsentActivity`. | Test instrumentado: fresh install → tap tile → ConsentActivity visible |
| AC-6 | Sin condicionales de plataforma en `pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs`. | Grep negativo: `#[cfg(target_os = "android")]` ausente en los tres archivos |
| AC-7 | Pattern Detector, Trust Scorer y State Machine compilan para `aarch64-linux-android` sin modificar su lógica. | `cargo build --target aarch64-linux-android` verde + `cargo test --target aarch64-linux-android` verde |
| AC-8 | Ninguna query SQLCipher Android accede a `url` o `title` en claro (D1). Ningún log de debug imprime `url` o `title`. | Test estructural Rust + revisión manual de Kotlin |
| AC-9a | Con `paid_active = 0`, el tile lanza paywall y NO inicia ForegroundService. | Test instrumentado: `subscription_set_paid_active(false)` → tap tile → paywall visible, servicio no arrancado |
| AC-9b | Con `paid_active = 1`, el tile procede normalmente. | Test instrumentado complementario a AC-9a |
| AC-10 | Cifrado de URL/title ocurre en ≤ 500 ms desde recepción. Si supera el límite, la captura se descarta sin persistir. | Test unitario Kotlin con mock de Classifier lento (>500 ms) → 0 raw_events |
| AC-11 | Logs de debug no contienen `url` ni `title` (PGR C4). | Test estructural: grep negativo de `Log.*url` y `Log.*title` en código Kotlin |
| AC-12 | Migraciones SQLCipher idempotentes: ejecutar `ensure_schema` dos veces no rompe ni duplica filas. | Test unitario Rust |
| AC-13 | Schema `subscription_state`, `observer_config`, columna `source` en `resources` no contienen ningún campo `url`, `title`, `link`, `href`, `bookmark_url`, `page_title`, `content`. | Test estructural `test_no_url_or_title_in_observer_schemas` |
| AC-14 | Comando `subscription_set_paid_active` ausente en builds release. | Inspección del binario release con `strings` o equivalente |
| AC-15 | Handler de ACTION_SEND registrado dinámicamente. AndroidManifest no contiene `<intent-filter>` para ACTION_SEND con la actividad del observer (D9 extensión). | Inspección de `AndroidManifest.xml` + verificación runtime: tile OFF + ACTION_SEND → no se entrega al observer |
| AC-16 | `ForegroundService` declarado con `START_NOT_STICKY`. Después de un kill manual desde la notificación, reiniciar el dispositivo deja el servicio sin reanudar (PGR PV-M-004). | Test instrumentado: cerrar desde notificación → reboot → verificar servicio inactivo |
| AC-17 | Listener pasivo del portapapeles ausente. No se registra `OnPrimaryClipChangedListener` en ningún punto. | Grep negativo en Kotlin |
| AC-18 | `cargo test` desktop completo sin regresiones (≥ tests actuales / 0 failed / 0 ignored). | `cargo test` reporta el conteo previo + nuevos tests Rust de este TS |
| AC-19 | `npx tsc --noEmit` limpio en frontend. | Salida limpia |

---

## Entregables

### Rust (`src-tauri/src/`)

1. `session_builder.rs` — refactor a `SessionBuilderConfig` con presets `desktop()` y `mobile()`. Constantes deprecated mantenidas como alias.
2. `commands.rs` — comandos nuevos:
   - `subscription_get_state`
   - `subscription_set_paid_active` (gated por `#[cfg(debug_assertions)]`)
   - `observer_config_get`
   - `observer_config_set_inactivity_timeout`
   - `observer_consent_grant`
3. `storage.rs` — migraciones de las tres tablas declaradas (`subscription_state`, `observer_config`, columna `source` en `resources`).
4. Tests Rust nuevos (mínimo 8):
   - `test_mobile_config_splits_at_gap_secs`
   - `test_subscription_state_singleton_idempotent`
   - `test_observer_config_inactivity_timeout_bounds` (rechaza valores fuera de 300–14400)
   - `test_resources_source_column_default_is_share_intent`
   - `test_no_url_or_title_in_observer_schemas`
   - `test_subscription_set_paid_active_unavailable_in_release` (verificación condicional)
   - `test_session_builder_desktop_preset_unchanged` (regresión: desktop callers ven el mismo comportamiento)
   - `test_consent_grant_updates_timestamp_and_version`

### Kotlin (`android/app/src/main/kotlin/.../`)

5. `tile/FlowWeaverTileService.kt` — TileService con ciclo de vida estricto (R1).
6. `service/FlowWeaverObserverService.kt` — ForegroundService `START_NOT_STICKY` con notificación PGR C3.
7. `capture/CaptureLayer.kt` — handler dinámico de ACTION_SEND + paste explícito; cifrado ≤ 500 ms.
8. `consent/ConsentActivity.kt` — pantalla de consentimiento PGR C1 con texto literal declarado.
9. `paywall/PaywallActivity.kt` — stub UI para `paid_active = 0` (texto: "Esta función forma parte del tier paid de FlowWeaver. La integración con Google Play Billing se activa en la versión beta.").
10. `timeout/InactivityTimer.kt` — temporizador reseteable con cada raw_event.
11. Tests instrumentados Android (mínimo 6): AC-1, AC-2, AC-3, AC-5, AC-9a, AC-15.

### TypeScript (`src/types.ts`)

12. Tipos nuevos:

```typescript
// ── Phase 2 — Mobile Observer (T-CR-002-001) ───────────────────────────────

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

13. **Sin** declaración estática de handler ACTION_SEND para el observer (D9 extensión). El TileService sí se declara estáticamente porque Quick Settings tiles requieren registro en el manifest — esto es esperado y compatible con D9 (el tile se declara, pero NO captura URLs por sí mismo: solo abre/cierra la sesión).
14. ForegroundService declarado con `android:foregroundServiceType="dataSync"` o equivalente Android 14+.

### Cargo.toml

15. Sin dependencias nuevas en este TS. La integración Android se hace vía la infraestructura Tauri Android existente.

---

## Verificación Final

```bash
# Rust desktop (sin regresiones)
cd src-tauri && cargo test
cd src-tauri && cargo build --target x86_64-pc-windows-msvc

# Rust Android (NDK)
cd src-tauri && cargo build --target aarch64-linux-android --release
cd src-tauri && cargo test --target aarch64-linux-android

# TypeScript
npx tsc --noEmit

# Tests instrumentados Android (en dispositivo o emulador)
./gradlew connectedAndroidTest

# Verificación manual en dispositivo Android real
# (los 5 escenarios declarados en AC-1, AC-2, AC-3, AC-9a, AC-15)
```

Reportar en el HO de cierre:

- Conteo `passed / failed / ignored` de `cargo test` desktop.
- Conteo `passed / failed / ignored` de `cargo test --target aarch64-linux-android`.
- Conteo de tests instrumentados Android.
- Estado de cada `cargo build` por target.
- Confirmación literal de los 19 AC con referencia a archivo / función / test.
- Captura textual de la notificación del ForegroundService (visible + acción de cierre verificada).
- Confirmación de que `ConsentActivity` se muestra en fresh install y que `tile_session` raw_events no aparecen sin consentimiento.

---

## Restricciones (no negociables)

### D1 — privacidad (transversal absoluto)

- `url` y `title` cifrados antes de persistir en SQLCipher Android (mismo cifrado que desktop, AES-GCM vía `crypto.rs`).
- `source` (columna nueva en `resources`) NO es un campo sensible; almacena valores enumerados en claro.
- Logs de debug y release no contienen `url`, `title`, ni la URL completa de ninguna captura. Auditable por AC-11.
- Schemas de las tres tablas nuevas no contienen ningún campo de URL/título/contenido. Auditable por AC-13.

### D9 (extendida 2026-04-27) — observer semi-pasivo Android

- Handler ACTION_SEND registrado **dinámicamente** al activar el tile y desregistrado al desactivarlo. Auditable por AC-15.
- ForegroundService activo solo durante sesión del tile. Auditable por AC-2.
- Notificación visible obligatoria con acción de cierre directamente accesible. Auditable por AC-3.
- Sin observación en background bajo ninguna circunstancia. Auditable por AC-1, AC-15, AC-16.

### D14 — Privacy Dashboard

- La sección "Observer" del Privacy Dashboard mobile se difiere a T-CR-002-002 (declarado en Out of scope). Este TS entrega los comandos Tauri (`subscription_get_state`, `observer_config_get`, etc.) que T-CR-002-002 consumirá.

### D17 — Pattern Detector completo solo en Fase 2 (transitivo)

- El observer mobile NO genera DetectedPattern por sí mismo. El cálculo de patrones a partir de los raw_events del observer se hace por el Pattern Detector existente (compilado para Android via NDK). Sin lógica de patrones nueva en este TS.

### D19 — Windows + Android primario

- Implementación completa Android (este TS).
- Windows desktop NO se ve afectado más allá del refactor de `session_builder.rs` (que mantiene comportamiento idéntico para callers existentes — AC-18 lo verifica).

### D20 / D21 — mobile standalone, relay sin cambios

- El observer mobile no modifica el protocolo del relay.
- La capa de análisis (DetectedPattern, TrustState) permanece local al dispositivo. Auditable por inspección de los comandos Tauri de este TS (no exponen sync de patterns/trust state).

### R12 — distinción transitiva

- Comentario de cabecera obligatorio en `CaptureLayer.kt` con tabla comparativa de tres columnas (Observer Mobile, Pattern Detector, Episode Detector).
- `pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs` no se modifican. Auditable por AC-6.
- Episode Detector mobile (que SÍ es módulo nuevo) se cubre en T-CR-002-002, no aquí.

### Constraints PGR (no negociables)

- **B1 / C1** — pantalla de consentimiento explícito antes del primer uso. AC-5.
- **B2** — handler dinámico verificable. AC-15.
- **B3** — D1 operativo en logs y persistencia. AC-8, AC-11, AC-13.
- **B5 / C5** — timeout automático de sesión, default 30 min, configurable 5 min–4 h. AC-2, AC-12.
- **C3** — desactivación accesible desde tile, dashboard (T-CR-002-002), notificación. AC-3.
- **C4** — cifrado ≤ 500 ms o descarte. AC-10.
- **PV-M-004** — ForegroundService NO se reanuda automáticamente tras kill manual. AC-16.

### Constraints específicos T-CR-002-001

- **No listener pasivo del portapapeles.** AC-17.
- **No Accessibility Service.** AC-15 (verificación de manifest).
- **No lectura de historial del navegador.** Auditable por inspección de Kotlin.
- **`subscription_set_paid_active` ausente en release.** AC-14.

---

## Criterios de Cierre

El HO de cierre (a Technical Architect, solicitando AR-CR-002-IMPL-001) debe reportar cada AC con referencia verificable:

1. AC-1 a AC-19 satisfechos línea por línea.
2. Conteo de tests Rust + tests Android instrumentados con resultado limpio.
3. Verificación funcional manual de los 5 escenarios críticos (AC-1, AC-2, AC-3, AC-9a, AC-15) en dispositivo Android real.
4. Captura textual de la notificación del ForegroundService.
5. Confirmación de que el binario release no contiene `subscription_set_paid_active` (`strings binary | grep` negativo).
6. Confirmación de que `AndroidManifest.xml` no declara `<intent-filter android:name="android.intent.action.SEND">` con la actividad del observer.
7. Confirmación de que ningún `Log.*` en código Kotlin imprime `url` o `title`.
8. Cualquier desviación de este TS con justificación (idealmente cero).

Si AR-CR-002-IMPL-001 aprueba sin correcciones, **T-CR-002-001 queda cerrado** y se desbloquea T-CR-002-002 (Episode Detector mobile + sección Observer del Privacy Dashboard mobile).

---

## Riesgos Conocidos

| ID | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| RT-001 | OEM Android (EMUI, MIUI) mata el ForegroundService pese a la notificación. | Media-alta | Alto | Documentar limitación en onboarding. `onTaskRemoved` para cierre limpio. Narrativa: "captura las URLs que el sistema permite". (Heredado de AR R-M-002.) |
| RT-002 | Refactor de `session_builder.rs` rompe callers desktop existentes. | Baja | Alto | AC-18 (regresión desktop) + alias `GAP_SECS = SessionBuilderConfig::desktop().gap_secs` para callers no migrados. |
| RT-003 | Cifrado de URL excede 500 ms en dispositivos lentos. | Baja-media | Medio | AC-10 establece descarte explícito. Telemetría futura (opt-in) puede medir tasa de descarte. |
| RT-004 | El usuario activa el tile pero olvida que está activo. | Alta | Medio | Notificación con tiempo transcurrido (sección ForegroundService) + timeout PGR (30 min default). |
| RT-005 | Implementador propone listener pasivo de portapapeles "para mejorar UX". | Media | Alto | R1 declarado literalmente en este TS + AC-17 (grep negativo). Cualquier propuesta debe escalar a CR. |
| RT-006 | Pattern Detector NDK falla en dispositivo real (primera compilación). | Alta | Alto | AC-7 obliga a `cargo test --target aarch64-linux-android` verde antes de cierre. Si falla, escalar al TA antes de declarar implementación completa. |
| RT-007 | Implementador asume que la integración Google Play Billing es parte del TS. | Media | Medio | R2 declara explícitamente "out of scope, CR antes de Fase 3". El stub debug-only es suficiente para AC-9. |

---

## Trazabilidad

| Decisión / Documento | Referencia en este TS |
|---|---|
| D9 extensión | R1, R2, R4, AC-15, sección Restricciones |
| D22 | R2, sección Subscription verification |
| D20 / D21 | R3, sección Restricciones D20/D21 |
| AR-CR-002-mobile-observer | Umbrales mobile (Session Builder), flujo del observer, AC-7 |
| PGR-CR-002-mobile-observer | C1/B1 (consentimiento), C3 (notificación), C4 (cifrado ≤ 500 ms), C5/B5 (timeout), PV-M-004 (no reanudar) |
| R12 | Sección R12 + AC-6 + comentarios de cabecera obligatorios |

---

## Firma

```
produced_by: Technical Architect
production_date: 2026-04-27
status_detail: |
  DRAFT. Pendiente de visados (Privacy Guardian, Functional Analyst, QA Auditor,
  Orchestrator) antes de pasar a APPROVED. Resoluciones R1–R4 incorporadas
  literalmente como decisiones declaradas (no interpretables por implementador).
  Cuatro ambigüedades de AR-CR-002 cerradas: (1) "portapapeles" = paste explícito
  en app, no listener pasivo; (2) granularidad = dos tasks (T-CR-002-001 cubre
  Observer Core; T-CR-002-002 cubrirá Episode Detector mobile + Dashboard
  section); (3) subscription = stub SQLCipher con paid_active, billing real
  diferido a Fase 3 vía CR; (4) relay sin cambios — análisis local al dispositivo.
  19 criterios de aceptación emitidos (incluye 6 instrumentados Android, 8 tests
  Rust, 5 estructurales). Todos los controles PGR B1/B2/B3/B5 + C1/C3/C4/C5
  + PV-M-004 mapeados a AC verificables. Implementación queda autorizada solo
  tras los cuatro visados.
```
