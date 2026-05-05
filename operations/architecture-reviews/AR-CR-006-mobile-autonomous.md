# Revisión Arquitectónica — CR-006: Mobile como Cliente Autónomo

document_id: AR-CR-006
owner_agent: Technical Architect
phase: 3
date: 2026-05-05
status: APROBADO — CR-006 puede activarse; T-3-014 a T-3-028 quedan desbloqueadas con bloqueo hasta cierre desktop
documents_reviewed:
  - operations/change-requests/CR-006-mobile-autonomous-client.md
  - Project-docs/decisions-log.md (D24, D27, D28, D29, D30, D31)
  - operations/architecture-reviews/AR-CR-005-llm-synthesis.md
  - operations/backlogs/backlog-phase-3.md (T-3-007 a T-3-013)
  - src-tauri/src/raw_event.rs (referencia de schema actual)

---

## Resultado Global

**APROBADO sin correcciones.** Los 7 puntos de evaluación quedan resueltos.
T-3-014 a T-3-028 quedan desbloqueadas en backlog con dependencia explícita
de cierre formal de T-3-007 a T-3-013. Las TS individuales se emitirán en
prompts posteriores tras validar desktop.

---

## Punto 1 — Extensión RawEvent: schema synthesis_generated

**Decisión: schema mínimo, compatible hacia atrás mediante campo `event_type`.**

Schema del evento `synthesis_generated` (extensión de `RawEvent`):

```rust
// Extensión propuesta para raw_event.rs (T-3-014)
pub struct SynthesisEvent {
    pub event_id:       String,   // UUIDv4 de este evento
    pub event_type:     String,   // "synthesis_generated" (nuevo; "resource_captured" ya existía)
    pub anchor_key:     String,   // pattern_id (UUIDv5) o session_hash (sha256[:16])
    pub anchor_type:    String,   // "pattern" | "session"
    pub category:       String,   // en claro (D1 autoriza)
    pub synthesis_type: String,   // "entretenimiento" | "cocina" | "noticias" | "tecnologia"
    pub content_encrypted: String, // AES-256-GCM con local_key del dispositivo emisor
    // content_encrypted se RE-CIFRA con shared_key para el relay (igual que url/title)
    pub generated_at:   i64,      // unix seconds
    pub source_device_id: String, // device_id del emisor (ya existente en RawEvent)
    pub schema_version: u8,       // 2 (RawEvent actual es versión 1)
}
```

**Compatibilidad hacia atrás:**
- Los clientes que aún no conocen `synthesis_generated` reciben el evento del relay
  y lo ignoran al deserializar (campo `event_type` desconocido → skip sin error).
- `schema_version: 2` permite al receptor decidir si puede procesar el evento.
- Los clientes v1 (solo `resource_captured`) ignoran silenciosamente `schema_version >= 2`.
- No existe migración forzada — cada cliente actualiza a su ritmo.

**Re-cifrado para el relay:**
El campo `content_encrypted` contiene la síntesis cifrada con la `local_key` del
dispositivo emisor. Antes de subirla al relay, se RE-CIFRA con la `shared_key` del
par (igual que `url` y `title` en `resource_captured`). El receptor descifra con
`shared_key → local_key` receptor. Coherente con el modelo de cifrado de drive_relay.rs.

---

## Punto 2 — Cliente Kotlin del proxy: contrato y librería

**Decisión: OkHttp con soporte SSE nativo mediante `EventSource` de OkHttp.**

**Justificación de OkHttp:**
- Ya presente en el proyecto Android (Tauri Android usa OkHttp transitivamente).
- `EventSource` de OkHttp soporta SSE de forma nativa con reconexión automática.
- Alternativa Retrofit: no tiene soporte SSE nativo — requiere adapters adicionales.
  OkHttp es más directo para streaming.

**Contrato del cliente Kotlin (equivalente a synthesis_engine.rs):**

```kotlin
// T-3-015: SynthesisClient.kt
class SynthesisClient(private val proxyUrl: String) {
    fun synthesize(
        installToken: String,
        category: String,
        titles: List<String>,   // títulos en claro con consentimiento D25
        domains: List<String>,
        synthesisType: String,
        language: String = "es",
        onChunk: (String) -> Unit,
        onComplete: () -> Unit,
        onError: (SynthesisError) -> Unit
    )
}

sealed class SynthesisError {
    object InvalidToken : SynthesisError()
    object RateLimitExceeded : SynthesisError()
    object NoConnectivity : SynthesisError()
    object ProviderUnavailable : SynthesisError()
    data class Unknown(val code: Int) : SynthesisError()
}
```

**Manejo de errores y retry:**
- 401 → `InvalidToken` (no retry).
- 429 → `RateLimitExceeded` (no retry, mostrar UI).
- Sin red → `NoConnectivity` (no retry, degradación graceful).
- 503 → `ProviderUnavailable` (1 retry tras 3s, luego error).
- Timeout total cliente: 30s (coherente con AR-CR-005 §3).

---

## Punto 3 — Schema syntheses replicado en mobile

**Decisión: IDÉNTICO al desktop, sin modificaciones.**

El schema de la tabla `syntheses` en SQLCipher mobile es idéntico al declarado en
AR-CR-005 §5:

```sql
CREATE TABLE IF NOT EXISTS syntheses (
    id                  INTEGER PRIMARY KEY,
    anchor_key          TEXT NOT NULL,   -- pattern_id o session_hash
    anchor_type         TEXT NOT NULL,   -- 'pattern' | 'session'
    category            TEXT NOT NULL,
    synthesis_type      TEXT NOT NULL,
    content_encrypted   TEXT NOT NULL,   -- AES-256-GCM, key = local_key del dispositivo
    generated_at        INTEGER NOT NULL -- unix seconds
);
CREATE INDEX IF NOT EXISTS idx_syntheses_anchor ON syntheses(anchor_key);
```

**Coherencia con D27:** cuando una síntesis generada en mobile se recibe en desktop
(vía relay), el receptor descifra `content_encrypted` con su propia `local_key` y la
inserta con la misma estructura. El `anchor_key` es determinístico desde ambos lados
(UUIDv5 para pattern_id, sha256 para session_hash), por lo que la misma síntesis
recibida dos veces es idempotente (`INSERT OR IGNORE`).

---

## Punto 4 — Pattern Detector en mobile: decisión explícita

**Decisión: solo Episode Detector en mobile. Pattern Detector longitudinal queda exclusivo de desktop.**

**Justificación:**
- El Pattern Detector requiere historial de días/semanas en SQLCipher para detectar
  recurrencias. En mobile, el usuario tiene el historial pero el cómputo sobre
  semanas de datos es más costoso en CPU/batería.
- El sistema de síntesis proactiva en mobile usa el Episode Detector (sesión activa
  en curso) para detectar "material suficiente" (≥3 recursos del mismo episodio).
  Esto es suficiente para el caso de uso de badge silencioso.
- El Pattern Detector longitudinal en desktop produce los `pattern_id` que móvil
  puede recibir vía sync y usar como `anchor_key` para síntesis vinculadas.
- Si en el futuro los datos de beta demuestran que el Pattern Detector aporta valor
  diferencial en mobile, se evaluará en Fase 4. No se implementa en Fase 3 mobile.

**Implicación en T-3-019 (síntesis proactiva):** el trigger de "material suficiente"
usa `Episode Detector mobile` (ya implementado en fase 0c/0b) con umbral configurable
(default: ≥3 recursos del mismo episodio en una ventana de sesión). Pattern_id
para `anchor_key` viene del sync desktop o se genera como `session_hash` si no hay
patrón sincronizado.

---

## Punto 5 — Configuración D28/D29/D30: persistencia y sincronización

**Decisión:**

| Config | Persistencia | Sincronización |
|---|---|---|
| D28 (niveles A/B/C por categoría) | SQLCipher local + tabla `capture_config` | SÍ — global, sincronizada entre dispositivos vía relay como evento `config_updated` |
| D29 (perfiles con horarios) | SQLCipher local + tabla `capture_profiles` | SÍ — global, sincronizada vía relay (mismo mecanismo) |
| D30 (filtro por dispositivo) | SQLCipher local + tabla `device_filter` | NO — por diseño (D30: "configuración por dispositivo, no global") |

**Schema mínimo para T-3-027:**

```sql
-- D28: niveles por categoría
CREATE TABLE IF NOT EXISTS capture_config (
    category    TEXT PRIMARY KEY,
    level       TEXT NOT NULL  -- 'normal' | 'silent' | 'pending' | 'ignore'
);

-- D29: perfiles (solo paid)
CREATE TABLE IF NOT EXISTS capture_profiles (
    id          TEXT PRIMARY KEY,  -- UUIDv4
    name        TEXT NOT NULL,
    categories  TEXT NOT NULL,     -- JSON array de categorías activas
    schedule    TEXT NOT NULL,     -- JSON: {days: [0-6], start_hour: 0-23, end_hour: 0-23}
    priority    INTEGER NOT NULL   -- mayor = más específico
);

-- D30: filtro por dispositivo (no se sincroniza)
CREATE TABLE IF NOT EXISTS device_filter (
    category    TEXT PRIMARY KEY,
    mode        TEXT NOT NULL,     -- 'flexible' | 'strict'
    blocked     INTEGER NOT NULL   -- 0 | 1
);
```

**Tipo de evento relay para configuración sincronizada:**
```
event_type: "config_updated"
payload: { config_type: "capture_config" | "capture_profiles", data_encrypted: "..." }
```

---

## Punto 6 — Rate limiting cliente vs servidor

**Decisión: proxy es la fuente de verdad; cliente sincroniza periódicamente.**

**Riesgo de confiar en el cliente:** el usuario podría resetear la app, reinstalar,
o usar múltiples dispositivos. El contador local sería inconsistente.

**Mecanismo aprobado:**
1. El proxy mantiene el contador canónico en Cloudflare KV: `{token}_month_{YYYYMM} = N`.
2. Cada petición al proxy devuelve en el header de respuesta el contador actual:
   `X-Synthesis-Remaining: 3` (síntesis restantes del mes).
3. El cliente almacena el valor en SQLCipher local y lo usa para deshabilitar la UI
   sin necesidad de ping al servidor.
4. Al expirar el mes (cliente compara `generated_at` del último reset), el cliente
   solicita el contador actualizado al proxy en la próxima síntesis.
5. El reset mensual es en el proxy (primer día del mes UTC). El cliente se sincroniza
   automáticamente en la primera petición del mes.

**Implicación en T-3-028:** el cliente mobile lee `X-Synthesis-Remaining` de cada
respuesta del proxy y actualiza su contador local. La UI muestra "X de 5 síntesis
usadas este mes" con datos locales.

---

## Punto 7 — Criterios de aceptación por tarea

| Tarea | Criterio clave | Bloqueante hasta |
|---|---|---|
| T-3-014 (schema RawEvent) | `synthesis_generated` añadido; clientes v1 ignoran sin error; `schema_version: 2` | TS-T-3-014 aprobada |
| T-3-015 (cliente Kotlin proxy) | SSE parseado, 4 tipos de síntesis, manejo de errores SynthesisError | T-3-014 |
| T-3-016 (schema syntheses mobile) | Tabla idéntica a desktop; INSERT OR IGNORE idempotente | T-3-014 |
| T-3-017 (plantillas locales mobile) | 25 categorías en templates.kt; sin proxy; sin red | Ninguna |
| T-3-018 (vista agrupada) | Pantalla principal por categoría con badges; reemplaza lista cronológica | T-3-016, T-3-017 |
| T-3-019 (síntesis proactiva + badge) | Badge aparece con ≥3 recursos mismo episodio; sin push | T-3-015, T-3-016 |
| T-3-020 (botón "Generar ahora") | Síntesis bajo demanda funcional; degradación sin red | T-3-015 |
| T-3-021 (Markdown mobile) | Streaming renderizado progresivo; Copiar y Compartir | T-3-015 |
| T-3-022 (Privacy Dashboard mobile) | Toggle + contador + descripción; no regresionar dashboard | T-3-015, T-2-004 ✓ |
| T-3-023 (consentimiento mobile) | Modal con redacción exacta PGR-CR-006; consent_log en SQLCipher | T-3-022 |
| T-3-024 (config D28) | Toggle simple + avanzado para niveles A/B/C; aviso en Nivel A | Ninguna |
| T-3-025 (config D29 paid) | UI perfiles con horarios; paywall para free | T-3-024 |
| T-3-026 (config D30) | Modo flexible (free) + estricto (paid) por dispositivo | Ninguna |
| T-3-027 (sync syntheses + config) | Syntheses subidas al relay; D28/D29 sincronizadas; D30 no sincronizada | T-3-014, T-3-016 |
| T-3-028 (rate limiting mobile) | Contador local sincronizado con proxy; UI "X de 5 usadas" | T-3-015, T-3-007 ✓ |

**Dependencia GLOBAL bloqueante:**
TODAS las tareas T-3-014 a T-3-028 quedan BLOQUEADAS hasta cierre formal de T-3-007
a T-3-013 (desktop validado en beta cerrada). Las TS individuales se emitirán en
prompts posteriores.

---

## Constraints Verificados

| Constraint | Estado en CR-006 |
|---|---|
| D1 núcleo | Payload mobile al proxy: solo category + titles (con consentimiento D25) + domains + synthesis_type + language. Idéntico al desktop. |
| D4 | synthesis_engine Kotlin no invoca evaluate_transition. Badge silencioso es output, no decisión de acción. |
| D8 | Sin red, plantillas locales funcionan (T-3-017). La síntesis LLM es opt-in en mobile igual que en desktop. |
| D19 | Android + Windows primario. Mobile en Fase 3. iOS track paralelo — no afectado por CR-006. |
| D24 | Mobile genera síntesis vía mismo proxy en iteración posterior a desktop. D24 ya actualizada con modelo freemium. |
| D27 | Sync de syntheses bidireccional. Schema RawEvent extendido (T-3-014). |
| D28 | Control de captura free implementado en T-3-024. |
| D29 | Perfiles con horarios paid implementados en T-3-025. |
| D30 | Filtro por dispositivo implementado en T-3-026. Modo flexible free, modo estricto paid. |
| R12 | Episode Detector mobile es módulo separado. Pattern Detector no se ejecuta en mobile en Fase 3. |
