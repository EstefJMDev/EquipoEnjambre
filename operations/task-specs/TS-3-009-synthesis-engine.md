# Task Spec — TS-3-009

document_id: TS-3-009
task_id: T-3-009
title: synthesis_engine.rs — payload D25, petición SSE al proxy, persistencia cifrada
phase: 3
produced_by: Technical Architect
status: APPROVED
date: 2026-05-05
depends_on: T-3-007 (proxy con SSE operativo), T-3-008 (install token disponible)
unblocks: T-3-010 (SynthesisView — consume el engine)

---

## Distinción de Módulo

```
synthesis_engine.rs (este) — T-3-009
├─ Propósito: construir payload D25-compliant, llamar al proxy, parsear SSE,
│             persistir síntesis cifrada en SQLCipher.
├─ Distinto de state_machine.rs: no decide transiciones — es output, no autoridad (D4).
├─ Distinto de pattern_detector.rs: no detecta patrones — los consume como anchor_key.
├─ Distinto de synthesis_tokens.rs (T-3-008): no gestiona el token — lo lee vía pub(crate).
└─ Constraints: D1 (payload solo category+titles+domains), D4 (no decide acciones),
                D8 (degradación graceful sin red), D25 (consentimiento previo obligatorio).
```

**Comentario de cabecera obligatorio en el módulo:**
```rust
// synthesis_engine.rs — Fase 3 (T-3-009)
// Propósito: construir payload D25, llamar al proxy FlowWeaver, parsear SSE,
// persistir síntesis cifrada en SQLCipher (tabla syntheses).
// NO decide transiciones (D4 — eso es state_machine.rs).
// NO accede a url ni title cifrados de la BD (D1 — solo category, titles en claro, domains).
// REQUIERE consentimiento previo en consent_log antes de llamar al proxy (D25).
// Degrada gracefully sin red: SynthesisError::NoConnectivity, sin panic (D8).
```

---

## Contrato del Módulo

### Tipos públicos

```rust
// src-tauri/src/synthesis_engine.rs

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SynthesisType {
    Entretenimiento,
    Cocina,
    Noticias,
    Tecnologia,
}

impl SynthesisType {
    pub fn as_str(&self) -> &'static str {
        match self {
            SynthesisType::Entretenimiento => "entretenimiento",
            SynthesisType::Cocina         => "cocina",
            SynthesisType::Noticias       => "noticias",
            SynthesisType::Tecnologia     => "tecnologia",
        }
    }
}

#[derive(Debug)]
pub enum SynthesisError {
    NoToken,                     // install_token no configurado
    NoConsent,                   // consent_log no tiene synthesis_v1
    NoConnectivity,              // sin red o proxy inaccesible
    RateLimitExceeded,           // 429 del proxy
    ProviderUnavailable,         // 503 del proxy
    InvalidToken,                // 401 del proxy
    Persistence(rusqlite::Error),
    Http(String),
}

/// Payload D25-compliant.
/// TEST ESTRUCTURAL PG-001 obligatorio: esta función tiene EXACTAMENTE 5 parámetros.
/// Ningún parámetro es de tipo `NewResource`, `Resource`, url raw, ni title_raw.
pub fn build_synthesis_payload(
    category: &str,
    titles: &[&str],    // títulos en claro — con consentimiento D25
    domains: &[&str],
    synthesis_type: SynthesisType,
    language: &str,
) -> SynthesisPayload;

#[derive(Debug, Serialize)]
pub struct SynthesisPayload {
    pub category:       String,
    pub titles:         Vec<String>,
    pub domains:        Vec<String>,
    pub synthesis_type: String,
    pub language:       String,
    pub prompt_version: String,  // siempre "v1" en beta
}
```

### Función principal

```rust
/// Genera una síntesis llamando al proxy y la persiste en SQLCipher.
/// PRECONDICIÓN: consent_log debe tener registro synthesis_v1 (D25).
/// PRECONDICIÓN: install_token debe estar configurado.
///
/// Retorna el anchor_key de la síntesis persistida.
pub async fn generate_and_persist(
    conn: &Connection,
    app: &tauri::AppHandle,
    category: &str,
    titles: &[&str],
    domains: &[&str],
    synthesis_type: SynthesisType,
    anchor_key: &str,   // pattern_id (UUIDv5) o session_hash
    anchor_type: &str,  // "pattern" | "session"
    proxy_url: &str,
    on_chunk: impl Fn(&str) + Send + 'static,  // callback para streaming UI
) -> Result<String, SynthesisError>;
```

### Schema SQLCipher (tabla `syntheses`)

```sql
-- Idempotente — AR-CR-005 §5
CREATE TABLE IF NOT EXISTS syntheses (
    id                  INTEGER PRIMARY KEY,
    anchor_key          TEXT NOT NULL,
    anchor_type         TEXT NOT NULL,   -- 'pattern' | 'session'
    category            TEXT NOT NULL,
    synthesis_type      TEXT NOT NULL,
    content_encrypted   TEXT NOT NULL,   -- AES-256-GCM, key = local_key
    generated_at        INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_syntheses_anchor ON syntheses(anchor_key);
```

**Módulo auxiliar `syntheses_store.rs`** (patrón de pattern_blocks.rs):
```rust
pub(crate) fn ensure_schema(conn: &Connection) -> Result<(), rusqlite::Error>;
pub(crate) fn save(conn: &Connection, entry: &SynthesisEntry) -> Result<(), rusqlite::Error>;
pub(crate) fn get_by_anchor(conn: &Connection, anchor_key: &str) -> Result<Option<SynthesisEntry>, rusqlite::Error>;
pub(crate) fn list_recent(conn: &Connection, limit: usize) -> Result<Vec<SynthesisEntry>, rusqlite::Error>;
```

### Integración con State Machine (D4 transitivo)

`synthesis_engine.rs` no invoca `evaluate_transition`. La síntesis solo se genera
cuando el comando Tauri que la solicita (`generate_synthesis`) verifica que el
estado actual es `Trusted` o `Autonomous` antes de llamar al engine:

```rust
// src-tauri/src/commands.rs — comando Tauri nuevo

#[tauri::command]
pub async fn generate_synthesis(
    state: State<'_, DbState>,
    app: tauri::AppHandle,
    category: String,
    titles: Vec<String>,
    domains: Vec<String>,
    synthesis_type: String,
    anchor_key: String,
    anchor_type: String,
) -> Result<(), String> {
    let db = state.0.lock().map_err(|e| e.to_string())?;
    let conn = db.conn();

    // 1. Verificar estado SM ≥ Trusted (D4 — no delegamos autoridad al engine)
    let (current, _) = state_machine::load_state(conn).map_err(|e| e.to_string())?;
    if !matches!(current, TrustStateEnum::Trusted | TrustStateEnum::Autonomous) {
        return Err("synthesis requires Trusted or Autonomous state".to_string());
    }

    // 2. Verificar consentimiento (D25)
    // 3. Llamar a synthesis_engine::generate_and_persist
    // 4. El streaming se envía al frontend vía Tauri events (tauri::Emitter)
    ...
}
```

### Parser SSE

```rust
// Dentro de synthesis_engine.rs — función privada

fn parse_sse_chunk(line: &str) -> Option<String> {
    // Líneas del stream:
    // "data: {\"chunk\": \"texto\"}\n\n" → Some("texto")
    // "data: [DONE]\n\n"                → None (fin)
    // Otras líneas                      → None (ignorar)
    if line.starts_with("data: [DONE]") {
        return None;
    }
    if let Some(json_str) = line.strip_prefix("data: ") {
        if let Ok(v) = serde_json::from_str::<serde_json::Value>(json_str) {
            return v["chunk"].as_str().map(String::from);
        }
    }
    None
}
```

---

## Test Estructural PG-001 (OBLIGATORIO)

```rust
#[test]
fn pg_001_build_synthesis_payload_signature() {
    // Verifica que build_synthesis_payload tiene exactamente 5 parámetros
    // del tipo declarado y NO acepta url, title_raw ni NewResource.
    // Este test falla en compilación si la signatura cambia.
    let payload = synthesis_engine::build_synthesis_payload(
        "cocina",
        &["Tarta de queso", "Brownie de chocolate"],
        &["recetasdeescandalo.com", "elcomidista.es"],
        SynthesisType::Cocina,
        "es",
    );
    assert_eq!(payload.synthesis_type, "cocina");
    assert_eq!(payload.titles.len(), 2);
    assert_eq!(payload.prompt_version, "v1");
    // Si se añade url/title_raw a la función, el test no compila → D25 protegido.
}
```

---

## Criterios de Aceptación

| # | Criterio | Verificable |
|---|---|---|
| AC-1 | `synthesis_engine.rs` existe con comentario de cabecera obligatorio. | Inspección |
| AC-2 | PG-001: test estructural `pg_001_build_synthesis_payload_signature` presente y pasando. | `cargo test` |
| AC-3 | `build_synthesis_payload` tiene exactamente 5 parámetros del tipo declarado. Ningún parámetro es `url`, `title_raw`, `NewResource` ni `Resource`. | Inspección de signatura |
| AC-4 | Antes de llamar al proxy, `generate_and_persist` verifica existencia de consent_log `synthesis_v1`. Sin consentimiento → `SynthesisError::NoConsent`. | Test unitario |
| AC-5 | Sin red → `SynthesisError::NoConnectivity` propagado al comando Tauri → UI muestra error sin panic. | Test con proxy inaccesible |
| AC-6 | Schema `syntheses` creado vía `syntheses_store::ensure_schema` idempotente. | Test: llamar ensure_schema dos veces sin error |
| AC-7 | Síntesis persistida con `content_encrypted = AES-256-GCM(content, local_key)`. El contenido en claro no aparece en SQLCipher. | Test: insertar síntesis, leer BD, verificar que el campo es ciphertext |
| AC-8 | `generate_synthesis` comando Tauri verifica estado SM ≥ Trusted antes de llamar al engine. En estado Observing/Learning → error al cliente. | Test con estado SM forzado a Observing |
| AC-9 | Chunks SSE del proxy se emiten al frontend vía Tauri events en tiempo real (no se acumulan hasta el final). | Verificación manual en UI |
| AC-10 | `cargo test` sin regresiones. | CI verde |

---

## Restricciones No Negociables

- **PG-001 permanente:** la signatura de `build_synthesis_payload` no puede ampliarse con `url`, `title_raw`, datos de BD cifrados ni identificadores de usuario sin nuevo CR aprobado.
- **D4:** `synthesis_engine.rs` no invoca `evaluate_transition`. La verificación de estado SM ocurre en `commands.rs`, no en el engine.
- **D8:** sin proxy, `SynthesisError::NoConnectivity` — el sistema sigue funcionando con plantillas.
- **D25:** `NoConsent` bloquea la llamada antes de construir el payload. No se puede saltarse.

---

## Handoffs Requeridos

1. **Implementador → Privacy Guardian**: presentar AC-3 y AC-4 (payload y consentimiento) antes de integrar con T-3-010.
2. **Implementador → Technical Architect**: handoff de cierre con todos los ACs verificados.

---

## Referencias

- `operations/architecture-reviews/AR-CR-005-llm-synthesis.md` §3, §4, §5
- `operations/architecture-reviews/PGR-CR-005-llm-synthesis.md` §1 (PG-001), §6 (consent_log)
- `operations/task-specs/TS-3-007-flowweaver-proxy.md` (contrato SSE)
- `operations/task-specs/TS-3-008-install-token-onboarding.md` (install_token)
- Patrón: `src-tauri/src/pattern_blocks.rs` (módulo auxiliar dueño del schema)
