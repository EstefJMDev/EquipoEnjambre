# Task Spec — TS-3-012

document_id: TS-3-012
task_id: T-3-012
title: Modal de consentimiento informado primer uso de síntesis (PG-003)
phase: 3
produced_by: Technical Architect
status: APPROVED
date: 2026-05-05
depends_on: T-3-008 (install token), T-3-011 (Privacy Dashboard sección síntesis)
unblocks: generación de síntesis (sin consent_log, synthesis_engine bloquea — D25)

---

## Objetivo

Implementar el modal de consentimiento informado que aparece una sola vez antes
del primer uso de síntesis. Registrar el consentimiento con versión del aviso
en SQLCipher. El consentimiento es obligatorio para llamar al proxy (D25).

---

## Decisiones Arquitectónicas

### 1. Tabla `consent_log` en SQLCipher

```sql
-- Idempotente — patrón coherente con syntheses_store
CREATE TABLE IF NOT EXISTS consent_log (
    id              INTEGER PRIMARY KEY,
    consent_type    TEXT NOT NULL,    -- 'synthesis'
    consent_version TEXT NOT NULL,    -- 'synthesis_v1'
    accepted_at     INTEGER NOT NULL  -- unix seconds
);
CREATE INDEX IF NOT EXISTS idx_consent_type ON consent_log(consent_type, consent_version);
```

**Módulo auxiliar `consent_log_store.rs`:**
```rust
// src-tauri/src/consent_log_store.rs
pub(crate) fn ensure_schema(conn: &Connection) -> Result<(), rusqlite::Error>;
pub(crate) fn record_consent(conn: &Connection, consent_type: &str, version: &str, now_unix: i64) -> Result<(), rusqlite::Error>;
pub(crate) fn has_consent(conn: &Connection, consent_type: &str, version: &str) -> Result<bool, rusqlite::Error>;
pub(crate) fn revoke_consent(conn: &Connection, consent_type: &str) -> Result<(), rusqlite::Error>;
```

### 2. Comandos Tauri

```rust
// src-tauri/src/commands.rs

/// Verifica si existe consentimiento vigente para el tipo y versión dados.
#[tauri::command]
pub fn check_synthesis_consent(
    state: State<'_, DbState>,
) -> Result<ConsentStatus, String>;

/// Registra el consentimiento en consent_log.
#[tauri::command]
pub fn record_synthesis_consent(
    state: State<'_, DbState>,
) -> Result<(), String>;

#[derive(Debug, Serialize)]
pub struct ConsentStatus {
    pub has_consent:      bool,
    pub consent_version:  String,   // "synthesis_v1" si existe
    pub current_version:  String,   // "synthesis_v1" siempre en beta
    pub needs_renewal:    bool,     // true si consent_version != current_version
}
```

### 3. Componente React `SynthesisConsentModal.tsx`

```typescript
// src/components/SynthesisConsentModal.tsx

interface SynthesisConsentModalProps {
  onAccept: () => void;
  onDecline: () => void;
}

export function SynthesisConsentModal(
  props: SynthesisConsentModalProps
): JSX.Element;
```

**El modal se muestra cuando:**
1. El usuario activa síntesis (toggle en SynthesisSection), Y
2. `check_synthesis_consent()` devuelve `{ has_consent: false }` o `{ needs_renewal: true }`.

**El modal NO se muestra en cada arranque** — solo cuando falta o ha caducado
el consentimiento.

### 4. Textos exactos del modal (PGR-CR-005 §6 — NO parafrasear)

```tsx
// Título:
<h2>Antes de activar la síntesis inteligente</h2>

// Cuerpo (tres párrafos separados):
<p>
  La síntesis envía al proxy FlowWeaver: los títulos de tus páginas guardadas,
  la categoría y los dominios. La URL completa y el contenido de las páginas
  nunca se transmiten.
</p>
<p>
  El proxy no almacena tu contenido. La síntesis generada se guarda solo en
  tu dispositivo.
</p>
<p>
  Puedes desactivar la síntesis en cualquier momento desde el Privacy Dashboard.
</p>

// Acciones:
<button onClick={handleAccept}>Activar síntesis</button>        {/* primario */}
<button onClick={props.onDecline}>No activar</button>           {/* secundario */}
```

### 5. Flujo de aceptación

```typescript
async function handleAccept() {
  await invoke("record_synthesis_consent");  // persiste en consent_log
  props.onAccept();  // cierra el modal y continúa el flujo de síntesis
}
```

### 6. Flujo de rechazo (graceful degradation — D8)

```typescript
// Si el usuario pulsa "No activar":
props.onDecline();
// El sistema opera con plantillas locales sin llamar al proxy.
// El toggle de SynthesisSection queda en posición OFF.
// No se elimina nada — el usuario puede activar más tarde.
```

### 7. Versionado del consentimiento

La versión actual es `"synthesis_v1"`. Si en el futuro el texto cambia materialmente:
- La nueva versión se llama `"synthesis_v2"`.
- `needs_renewal = true` cuando `consent_version != current_version`.
- El modal se muestra de nuevo al siguiente intento de síntesis.
- El campo `consent_version` en `consent_log` permite auditar cuándo aceptó cada versión.

---

## Criterios de Aceptación

| # | Criterio | Verificable |
|---|---|---|
| AC-1 | `consent_log_store.rs` existe como módulo con schema `consent_log` y las 4 funciones `pub(crate)`. | Inspección + `cargo check` |
| AC-2 | `SynthesisConsentModal.tsx` existe con los títulos y cuerpos con texto EXACTO declarado en esta TS. | Diff de texto línea a línea |
| AC-3 | El modal aparece al primer intento de síntesis si `has_consent = false`. No aparece en cada arranque. | Test manual: reiniciar app, el modal no aparece hasta activar síntesis |
| AC-4 | Tras pulsar "Activar síntesis": `consent_log` contiene fila con `consent_type='synthesis'`, `consent_version='synthesis_v1'`, `accepted_at > 0`. | Test: inspección de SQLCipher |
| AC-5 | Tras pulsar "Activar síntesis": `check_synthesis_consent()` devuelve `{ has_consent: true, needs_renewal: false }`. | Test unitario |
| AC-6 | "No activar" cierra el modal sin escribir nada en `consent_log`. El sistema sigue operativo con plantillas (D8). | Test: pulsar "No activar", verificar que SQLCipher no tiene fila de consentimiento |
| AC-7 | `synthesis_engine.rs` verifica `has_consent('synthesis', 'synthesis_v1')` antes de construir el payload. Sin consentimiento → `SynthesisError::NoConsent`. | Test con BD sin fila de consentimiento |
| AC-8 | Con `needs_renewal = true` (versión futura), el modal se muestra al siguiente intento de síntesis. | Test simulando versión desactualizada |
| AC-9 | `npx tsc --noEmit` limpio. `cargo test` sin regresiones. | CI verde |

---

## Restricciones No Negociables

- **PG-003:** el texto del modal es EXACTO según PGR-CR-005 §6. No se puede parafrasear, abreviar ni omitir ninguno de los tres párrafos.
- **D25:** `synthesis_engine.rs` no puede llamar al proxy sin verificar `has_consent`. Esta verificación no puede ser opcional ni configurable.
- **D8:** "No activar" siempre está disponible y funciona. El sistema opera sin síntesis si el usuario rechaza el consentimiento.
- El modal no puede mostrarse en segundo plano ni como notificación — solo como modal bloqueante explícito.

---

## Handoffs Requeridos

1. **Implementador → Privacy Guardian**: presentar `SynthesisConsentModal.tsx` con los textos exactos para verificación antes de cerrar la tarea.
2. **Implementador → Technical Architect**: handoff de cierre con AC-1 a AC-9 verificados.

---

## Referencias

- `operations/architecture-reviews/PGR-CR-005-llm-synthesis.md` §6 (PG-003 — textos exactos)
- `operations/task-specs/TS-3-009-synthesis-engine.md` (verificación pre-llamada al proxy)
- Patrón: `src/components/TrustStateSection.tsx::activateAutonomous` (modal de confirmación existente)
