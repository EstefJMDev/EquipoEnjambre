# Task Spec — TS-3-011

document_id: TS-3-011
task_id: T-3-011
title: Privacy Dashboard — sección "Síntesis inteligente" (PG-002, PG-005, PG-006)
phase: 3
produced_by: Technical Architect
status: APPROVED
date: 2026-05-05
depends_on: T-2-004 cerrado ✓ (Privacy Dashboard existente — PIR-005-addendum)
unblocks: T-3-012 (consentimiento — depende de sección síntesis visible)

---

## Objetivo

Añadir la sección "Síntesis inteligente" al Privacy Dashboard existente
(`src/components/PrivacyDashboard.tsx`). La sección cumple los 5 elementos
obligatorios de PGR-CR-005 §5 y los controles PG-002, PG-005, PG-006.
No se modifica ninguna sección existente del dashboard.

---

## Decisiones Arquitectónicas

### 1. Nuevo subcomponente `SynthesisSection.tsx`

Coherente con la descomposición de T-2-004 (PatternsSection, TrustStateSection,
PrivacyDashboardNeverSeen). El dashboard existente ya usa este patrón.

```typescript
// src/components/SynthesisSection.tsx

export function SynthesisSection(): JSX.Element;
```

`PrivacyDashboard.tsx` añade:
```typescript
import { SynthesisSection } from "./SynthesisSection";

// Dentro del JSX del panel, tras PrivacyDashboardNeverSeen:
<SynthesisSection />
```

### 2. Nuevos comandos Tauri para la sección

```rust
// src-tauri/src/commands.rs

/// Devuelve cuántas síntesis ha usado el usuario hoy (contador local).
/// Lee el header X-Synthesis-Remaining almacenado por synthesis_engine.
#[tauri::command]
pub fn get_synthesis_usage(
    state: State<'_, DbState>,
) -> Result<SynthesisUsage, String>;

#[derive(Debug, Serialize)]
pub struct SynthesisUsage {
    pub used_today:      u32,
    pub limit_today:     u32,  // 5 para tier free
    pub synthesis_active: bool, // si hay token configurado y consentimiento
}
```

Nota: el contador de síntesis es mensual (5/mes), no diario. El campo `used_today`
debe renombrarse a `used_this_month` en implementación para coherencia con D24.
El backlog usa "hoy" por simplicidad histórica — la TS es la fuente de verdad.

### 3. Los 5 elementos obligatorios de PG-002

```tsx
// src/components/SynthesisSection.tsx

export function SynthesisSection() {
  // Estado: { synthesis_active, used_this_month, limit: 5 }

  return (
    <section aria-labelledby="pd-sintesis">
      <h4 id="pd-sintesis">Síntesis inteligente</h4>

      {/* Elemento 1 — Qué se envía (texto EXACTO obligatorio) */}
      <p className="synthesis__description">
        Cuando solicitas una síntesis, FlowWeaver envía al proxy únicamente:
        la categoría del episodio, los títulos de las páginas que guardaste,
        y los dominios. Nunca se envía la URL completa ni el contenido de las páginas.
      </p>

      {/* Elemento 2 — Destino + referencia política (PG-005) */}
      <p className="synthesis__destination">
        Los datos se envían al{" "}
        <strong>Proxy FlowWeaver en Cloudflare (zero-retention)</strong>.{" "}
        <a
          href="https://developers.cloudflare.com/workers-ai/privacy/"
          target="_blank"
          rel="noopener noreferrer"
        >
          Política de privacidad de Cloudflare Workers AI
        </a>
      </p>

      {/* Elemento 3 — Política de retención */}
      <p className="synthesis__retention">
        El proxy no almacena tu contenido. La síntesis generada se guarda
        solo en tu dispositivo, cifrada.
      </p>

      {/* Elemento 4 — Toggle de activación/desactivación (PG-006) */}
      <div className="synthesis__toggle">
        <label htmlFor="synthesis-toggle">
          Síntesis activa
        </label>
        <input
          id="synthesis-toggle"
          type="checkbox"
          checked={synthesisActive}
          onChange={handleToggle}
          aria-describedby="synthesis-toggle-desc"
        />
        <span id="synthesis-toggle-desc" className="synthesis__toggle-note">
          Al desactivar, tu token de acceso se elimina de este dispositivo.
        </span>
      </div>

      {/* Elemento 5 — Contador de uso */}
      {synthesisActive && (
        <p className="synthesis__counter">
          {usedThisMonth} de {limit} síntesis usadas este mes
        </p>
      )}
    </section>
  );
}
```

### 4. Lógica del toggle (PG-006)

```typescript
async function handleToggle(e: React.ChangeEvent<HTMLInputElement>) {
  if (!e.target.checked) {
    // Desactivar: mostrar confirmación
    const ok = confirm(
      "Al desactivar la síntesis, tu token de acceso beta se eliminará " +
      "de este dispositivo. Necesitarás introducirlo de nuevo para reactivarla. " +
      "¿Confirmas?"
    );
    if (!ok) return;
    await invoke("clear_synthesis_token");
  } else {
    // Activar: mostrar onboarding de token (SynthesisOnboarding)
    setShowOnboarding(true);
  }
  refresh();
}
```

### 5. Test estructural D1 — extensión del test existente

El test `test_no_url_or_title_in_dashboard_components` en `commands.rs` debe
incluir `SynthesisSection.tsx`:

```rust
const FILES: &[&str] = &[
    include_str!("../../src/components/PrivacyDashboard.tsx"),
    include_str!("../../src/components/PatternsSection.tsx"),
    include_str!("../../src/components/TrustStateSection.tsx"),
    include_str!("../../src/components/PrivacyDashboardNeverSeen.tsx"),
    include_str!("../../src/components/SynthesisSection.tsx"),  // NUEVO
];
```

---

## Criterios de Aceptación

| # | Criterio | Verificable |
|---|---|---|
| AC-1 | `SynthesisSection.tsx` existe con los 5 elementos de PG-002 con los textos exactos declarados en esta TS. | Inspección + diff de texto |
| AC-2 | PG-005: enlace a política de Cloudflare Workers AI presente con URL correcta. | Inspección |
| AC-3 | PG-006: toggle de desactivación funcional. Al desactivar con confirmación → `clear_synthesis_token()` invocado. Al desactivar, `get_synthesis_token_status()` devuelve `{ is_set: false }`. | Test manual |
| AC-4 | Contador "X de 5 síntesis usadas este mes" visible cuando síntesis está activa. | Inspección visual |
| AC-5 | `PrivacyDashboard.tsx` incluye `<SynthesisSection />` sin modificar ninguna sección existente. | Diff de PrivacyDashboard.tsx |
| AC-6 | Test estructural D1 actualizado incluye `SynthesisSection.tsx`. El test pasa. | `cargo test` |
| AC-7 | Sección no expone url ni title en ningún elemento, incluyendo el `aria-describedby`. | Inspección + test D1 |
| AC-8 | `npx tsc --noEmit` limpio. | CI verde |
| AC-9 | El dashboard existente no sufre regresiones visuales ni funcionales. | Verificación manual |

---

## Restricciones No Negociables

- **PG-002:** los textos de los elementos 1, 2 y 3 son textos EXACTOS. No parafrasear.
- **PG-006:** desactivar síntesis elimina el token — esta semántica no puede suavizarse.
- **D1:** `SynthesisSection.tsx` no puede acceder a `url`, `title`, ni campos de recursos.
- El toggle no puede estar oculto, minimizado ni requerir navegación adicional para verlo.

---

## Handoffs Requeridos

1. **Implementador → Privacy Guardian**: entregar `SynthesisSection.tsx` para revisión de PG-002, PG-005, PG-006 antes de cerrar la tarea.
2. **Implementador → Technical Architect**: handoff de cierre con AC-1 a AC-9 verificados.

---

## Referencias

- `operations/architecture-reviews/PGR-CR-005-llm-synthesis.md` §5 (PG-002, PG-005, PG-006)
- `operations/task-specs/TS-2-004-privacy-dashboard.md` (patrón de subcomponentes)
- Patrón: `src/components/PrivacyDashboardNeverSeen.tsx` (texto literal obligatorio)
