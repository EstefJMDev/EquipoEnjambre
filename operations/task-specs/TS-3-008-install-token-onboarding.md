# Task Spec — TS-3-008

document_id: TS-3-008
task_id: T-3-008
title: Install token UUIDv4 + onboarding de síntesis (Rust + React)
phase: 3
produced_by: Technical Architect
status: APPROVED
date: 2026-05-05
depends_on: T-3-007 (proxy operativo para validar flujo end-to-end)
unblocks: T-3-009 (synthesis_engine), T-3-012 (consentimiento)

---

## Objetivo

Generar y persistir de forma segura el install_token en el primer arranque.
Añadir la pantalla de onboarding donde el beta tester introduce su token.
El sistema debe funcionar completamente sin token (graceful degradation — D8).

---

## Decisiones Arquitectónicas

### 1. Tabla `synthesis_tokens` en SQLCipher

```sql
CREATE TABLE IF NOT EXISTS synthesis_tokens (
    id          INTEGER PRIMARY KEY CHECK (id = 1),
    token_hash  TEXT NOT NULL,     -- SHA-256(token) — NUNCA el token en claro
    set_at      INTEGER NOT NULL   -- unix seconds
);
```

El token se almacena como su hash SHA-256. El token en claro vive únicamente en
memoria durante la sesión activa, donde es recuperado con `get_synthesis_token()`
para el header Authorization. Nunca se escribe el token en claro en SQLCipher.

**Justificación:** si SQLCipher fuera comprometido, el hash no permite recuperar
el token. El proxy solo valida el token en claro — el hash es solo para verificar
localmente si hay token configurado.

### 2. Comandos Tauri nuevos

```rust
// src-tauri/src/commands.rs

/// Persiste el install_token cifrado. Idempotente: sobreescribe si ya existe.
/// El token se almacena como SHA-256 hash + cifrado AES con local_key.
#[tauri::command]
pub fn set_synthesis_token(
    token: String,
    state: State<'_, DbState>,
    app: tauri::AppHandle,
) -> Result<(), String>;

/// Devuelve solo si hay token configurado — NUNCA el token en claro.
#[tauri::command]
pub fn get_synthesis_token_status(
    state: State<'_, DbState>,
) -> Result<TokenStatus, String>;

/// Devuelve el token en claro cifrado para uso interno en synthesis_engine.
/// Solo accesible desde synthesis_engine.rs (pub(crate)).
pub(crate) fn get_synthesis_token_plain(
    state: &DbState,
    app: &tauri::AppHandle,
) -> Result<Option<String>, String>;

/// Elimina el token (desactivación de síntesis desde Privacy Dashboard).
#[tauri::command]
pub fn clear_synthesis_token(
    state: State<'_, DbState>,
) -> Result<(), String>;

#[derive(Debug, Serialize)]
pub struct TokenStatus {
    pub is_set: bool,
}
```

### 3. Registro en `lib.rs`

Añadir al `invoke_handler!` tras los comandos T-2-004:
```rust
commands::set_synthesis_token,
commands::get_synthesis_token_status,
commands::clear_synthesis_token,
```

`get_synthesis_token_plain` es `pub(crate)` — no se registra como comando Tauri.

### 4. Pantalla de onboarding React

```typescript
// src/components/SynthesisOnboarding.tsx

// Se muestra cuando:
//   1. El usuario activa síntesis desde Privacy Dashboard (T-3-011), Y
//   2. No hay token configurado (get_synthesis_token_status → { is_set: false })

// Estados: idle | saving | error
// Props: onComplete: () => void, onSkip: () => void

// Texto obligatorio del campo:
//   placeholder: "Introduce tu token de acceso beta"
//   descripción: "Tu token te fue enviado por el equipo FlowWeaver."

// Botón primario: "Activar síntesis"
//   → llama set_synthesis_token(token)
//   → en éxito: onComplete()

// Botón secundario: "Continuar sin síntesis"
//   → onSkip() — el sistema funciona con plantillas locales (D8)
```

---

## Schema SQLCipher

El módulo `synthesis_tokens.rs` gestiona la tabla. Patrón coherente con
`pattern_blocks.rs` (módulo dueño del schema — TS-2-004):

```rust
// src-tauri/src/synthesis_tokens.rs

// Comentario de cabecera obligatorio:
// Synthesis Tokens — Fase 3 (T-3-008)
// Propósito: persistir el install_token de beta cifrado con local_key.
// El token nunca se almacena en claro — solo como AES-256-GCM ciphertext.
// Consulado por synthesis_engine.rs (pub(crate)) para construir Authorization header.
// Distinto de consent_log.rs (consentimiento) y pattern_blocks.rs (patrones) — R12.
// Constraints: D1 (sin url/title), D8 (sistema funciona sin token), D25 (opt-in explícito).

pub(crate) fn ensure_schema(conn: &Connection) -> Result<(), rusqlite::Error>;
pub(crate) fn set_token(conn: &Connection, token_encrypted: &str, now_unix: i64) -> Result<(), rusqlite::Error>;
pub(crate) fn get_token(conn: &Connection) -> Result<Option<String>, rusqlite::Error>;
pub(crate) fn clear_token(conn: &Connection) -> Result<(), rusqlite::Error>;
pub(crate) fn is_token_set(conn: &Connection) -> Result<bool, rusqlite::Error>;
```

Registro en `lib.rs`: `mod synthesis_tokens;` en orden alfabético entre
`mod state_machine;` y `mod storage;`.

---

## Criterios de Aceptación

| # | Criterio | Verificable |
|---|---|---|
| AC-1 | `synthesis_tokens.rs` existe como módulo con comentario de cabecera obligatorio, schema `synthesis_tokens (id INTEGER PK CHECK id=1, token_hash TEXT NOT NULL, set_at INTEGER NOT NULL)` y las 5 funciones `pub(crate)`. | Inspección + `cargo check` |
| AC-2 | `set_synthesis_token` persiste el token cifrado con AES-256-GCM (local_key). El token en claro no aparece en ningún campo de SQLCipher tras la llamada. | Test: insertar token, leer BD directamente, verificar que el campo es ciphertext. |
| AC-3 | `get_synthesis_token_status` devuelve `{ is_set: true }` si hay token, `{ is_set: false }` si no. Nunca devuelve el token en claro. | Test unitario. Inspección del tipo de retorno. |
| AC-4 | `get_synthesis_token_plain` es `pub(crate)` — no aparece en `invoke_handler!`. Solo `synthesis_engine.rs` lo consume. | Inspección de `lib.rs`. |
| AC-5 | `clear_synthesis_token` elimina el token del SQLCipher. `is_token_set` devuelve `false` tras la llamada. | Test unitario round-trip. |
| AC-6 | Componente `SynthesisOnboarding.tsx` muestra campo de token, botón "Activar síntesis" y botón "Continuar sin síntesis". | Inspección del componente. |
| AC-7 | "Continuar sin síntesis" deja el sistema operativo con plantillas locales — ningún error, ningún intento de llamar al proxy. | Test E2E: sin token, el baseline sigue funcionando (D8). |
| AC-8 | `cargo test` sin regresiones (≥ 90 tests previos). | CI verde. |
| AC-9 | `npx tsc --noEmit` limpio. | CI verde. |

---

## Restricciones No Negociables

- **D8:** sin token, el sistema funciona al 100% con plantillas locales. "Continuar sin síntesis" nunca está deshabilitado.
- **D25:** el token en claro solo vive en memoria durante la sesión activa. Nunca se escribe en claro en SQLCipher, logs ni respuestas de comandos Tauri.
- El token lo genera el PO manualmente e introduce el beta tester una sola vez. No existe generación de token por el servidor en beta.

---

## Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| R-1 | El implementador expone `get_synthesis_token_plain` como comando Tauri público. | AC-4 lo verifica — `pub(crate)` + ausencia en `invoke_handler!`. |
| R-2 | El token se logea en un mensaje de error de Tauri. | Verificar que los mensajes de error en `set_synthesis_token` no incluyen el token en su descripción. |

---

## Handoffs Requeridos

1. **Implementador → Technical Architect**: handoff de cierre tras implementación, solicitando revisión de AC-1 a AC-9.
2. **Privacy Guardian**: verificar AC-2 y AC-4 (token nunca en claro) antes de integrar con T-3-009.

---

## Referencias

- `operations/architecture-reviews/AR-CR-005-llm-synthesis.md` §1
- `operations/architecture-reviews/PGR-CR-005-llm-synthesis.md` §4 (GDPR install_token)
- `Project-docs/decisions-log.md` D25
- Patrón de módulo: `src-tauri/src/pattern_blocks.rs` (coherencia arquitectónica)
