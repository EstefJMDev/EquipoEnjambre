# Task Spec — TS-3-010

document_id: TS-3-010
task_id: T-3-010
title: SynthesisView.tsx — renderizado Markdown streaming, Copiar, Exportar
phase: 3
produced_by: Technical Architect
status: APPROVED
date: 2026-05-05
depends_on: T-3-009 (synthesis_engine con streaming via Tauri events)
unblocks: integración en AnticipatedWorkspace

---

## Objetivo

Implementar `src/components/SynthesisView.tsx` — componente React que recibe
chunks SSE del synthesis_engine vía eventos Tauri y renderiza markdown en tiempo
real. Visible en AnticipatedWorkspace según estado de la State Machine.

---

## Contrato del Componente

```typescript
// src/components/SynthesisView.tsx

type SynthesisState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "streaming"; content: string }
  | { status: "complete"; content: string }
  | { status: "error"; message: SynthesisErrorMessage };

type SynthesisErrorMessage =
  | "Sin conexión — el proxy no está disponible."
  | "Has alcanzado el límite de 5 síntesis al mes."
  | "Token de acceso no válido. Contacta con el equipo."
  | "El servicio de síntesis no está disponible temporalmente.";

interface SynthesisViewProps {
  anchorKey: string;       // pattern_id o session_hash
  anchorType: "pattern" | "session";
  category: string;
  synthesisType: string;
  titles: string[];
  domains: string[];
  // Si no se pasa onRequest, el botón "Generar" no aparece (uso embebido).
  onRequest?: () => void;
}

export function SynthesisView(props: SynthesisViewProps): JSX.Element;
```

---

## Decisiones Arquitectónicas

### 1. Streaming vía eventos Tauri

El synthesis_engine emite eventos Tauri para cada chunk:
```typescript
// Escuchar en el frontend:
import { listen } from "@tauri-apps/api/event";

// Evento de chunk:
// event.payload: { anchor_key: string, chunk: string }
await listen("synthesis_chunk", (event) => { ... });

// Evento de completado:
// event.payload: { anchor_key: string }
await listen("synthesis_complete", (event) => { ... });

// Evento de error:
// event.payload: { anchor_key: string, error: string }
await listen("synthesis_error", (event) => { ... });
```

El componente escucha solo eventos con `anchor_key` que coincida con sus props —
múltiples instancias no interfieren entre sí.

### 2. Renderizado Markdown

Se usa la librería `react-markdown` (ya puede estar en el proyecto) o un renderer
ligero inline. El output del proxy siempre tiene `## sección` y texto en negrita —
no requiere soporte de tablas ni código en la primera versión.

```typescript
// Renderizado mínimo viable:
import ReactMarkdown from "react-markdown";

<ReactMarkdown>{synthesisContent}</ReactMarkdown>
```

### 3. Botón "Copiar"

```typescript
async function copyToClipboard() {
  await navigator.clipboard.writeText(content);
  setCopied(true);
  setTimeout(() => setCopied(false), 2000);
}
// Texto del botón: "Copiar" → "¡Copiado!" durante 2s
```

### 4. Botón "Exportar Markdown"

```typescript
function exportMarkdown() {
  const blob = new Blob([content], { type: "text/markdown" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `synthesis-${new Date().toISOString().slice(0, 10)}.md`;
  a.click();
  URL.revokeObjectURL(url);
}
```

### 5. Visibilidad en AnticipatedWorkspace según estado SM

```typescript
// src/components/AnticipatedWorkspace.tsx — integración

// En estado Trusted: mostrar botón "Generar síntesis" que activa SynthesisView
// En estado Autonomous: SynthesisView se muestra automáticamente si hay síntesis disponible
// En estados Observing/Learning: SynthesisView no se muestra

{trustState === "Trusted" && (
  <SynthesisView
    {...episodeProps}
    onRequest={handleGenerateRequest}
  />
)}
{trustState === "Autonomous" && (
  <SynthesisView {...episodeProps} />  // sin onRequest — automática
)}
```

### 6. Mensajes de error mapeados desde el backend

```typescript
function mapError(backendError: string): SynthesisErrorMessage {
  if (backendError.includes("NoConnectivity"))   return "Sin conexión — el proxy no está disponible.";
  if (backendError.includes("RateLimitExceeded")) return "Has alcanzado el límite de 5 síntesis al mes.";
  if (backendError.includes("InvalidToken"))      return "Token de acceso no válido. Contacta con el equipo.";
  return "El servicio de síntesis no está disponible temporalmente.";
}
```

---

## Criterios de Aceptación

| # | Criterio | Verificable |
|---|---|---|
| AC-1 | Los 5 estados del componente (`idle`, `loading`, `streaming`, `complete`, `error`) se renderizan sin errores. | `npx tsc --noEmit` + inspección visual |
| AC-2 | El contenido Markdown se actualiza chunk a chunk durante el streaming (no aparece todo al final). | Verificación visual con proxy real |
| AC-3 | Headers `##` del Markdown se renderizan como `<h2>` HTML. Negrita `**texto**` se renderiza como `<strong>`. | Inspección DOM |
| AC-4 | Botón "Copiar" copia el contenido completo al portapapeles. El botón cambia a "¡Copiado!" durante 2 segundos. | Test manual |
| AC-5 | Botón "Exportar Markdown" genera descarga de archivo `.md` con nombre `synthesis-{fecha}.md`. | Test manual |
| AC-6 | En estado `error`, se muestra el mensaje correspondiente según el tipo de error. Ningún mensaje expone información técnica interna (rutas, IDs internos). | Inspección de casos de error |
| AC-7 | El componente no renderiza url ni title en claro en ningún estado (D1 transitivo). | Inspección del código — `grep "url\|title" SynthesisView.tsx` con tokens D1 |
| AC-8 | En AnticipatedWorkspace: botón de generación visible en estado Trusted; síntesis automática en Autonomous; ausente en Observing/Learning. | Verificación con estado SM forzado a cada valor |
| AC-9 | `npx tsc --noEmit` limpio. | CI verde |

---

## Restricciones No Negociables

- **D1 transitivo:** el componente no expone url ni title en ningún elemento visual, incluyendo tooltips, aria-labels y mensajes de error.
- **D4 transitivo:** el componente no invoca comandos que cambien el estado de la State Machine. Solo invoca `generate_synthesis` (output, no decisión).
- Los textos de error son mensajes de usuario final — no mensajes técnicos del backend.

---

## Handoffs Requeridos

1. **Implementador → Technical Architect**: handoff de cierre con todos los ACs verificados.
2. **Privacy Guardian**: revisión de AC-7 (ausencia de url/title en el componente).

---

## Referencias

- `operations/task-specs/TS-3-009-synthesis-engine.md` (eventos Tauri)
- `operations/architecture-reviews/AR-CR-005-llm-synthesis.md` §3 (formato SSE)
- Patrón: `src/components/TrustStateSection.tsx` (componente React con invoke Tauri)
