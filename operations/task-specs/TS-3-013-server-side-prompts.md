# Task Spec — TS-3-013

document_id: TS-3-013
task_id: T-3-013
title: Prompts server-side v1 — 4 tipos de síntesis en flowweaver-proxy
phase: 3
produced_by: Technical Architect
status: APPROVED
date: 2026-05-05
depends_on: T-3-007 (proxy operativo — los prompts viven en el mismo repo)
unblocks: síntesis de calidad para T-3-009, T-3-010

---

## Objetivo

Crear los 4 prompts especializados v1 en `flowweaver-proxy/prompts/v1/` y el
mecanismo de selección y versionado en el Worker. Los prompts son el activo de
producto que determina la calidad de las síntesis. Se versionan server-side
para permitir iteración sin rebuild del cliente.

---

## Decisiones Arquitectónicas

### 1. Estructura de prompts

```
flowweaver-proxy/
  prompts/
    v1/
      entretenimiento.txt
      cocina.txt
      noticias.txt
      tecnologia.txt
    v2/             ← futura versión, no en este turno
```

### 2. Carga del prompt en el Worker

```typescript
// src/index.ts — dentro del handler

async function loadPrompt(
  synthesisType: string,
  promptVersion: string
): Promise<string> {
  // Los prompts se importan estáticamente en el bundle del Worker.
  // Cloudflare Workers no tiene filesystem en runtime — se usan imports.
  const prompts: Record<string, Record<string, string>> = {
    v1: {
      entretenimiento: PROMPT_V1_ENTRETENIMIENTO,
      cocina:          PROMPT_V1_COCINA,
      noticias:        PROMPT_V1_NOTICIAS,
      tecnologia:      PROMPT_V1_TECNOLOGIA,
    },
    // v2: { ... } cuando exista
  };
  return prompts[promptVersion]?.[synthesisType]
    ?? prompts["v1"][synthesisType]  // fallback a v1 si versión desconocida
    ?? "";
}
```

Los archivos `.txt` se importan vía módulos TypeScript en `src/prompts.ts`:
```typescript
// src/prompts.ts
export const PROMPT_V1_ENTRETENIMIENTO = `...`;
export const PROMPT_V1_COCINA = `...`;
export const PROMPT_V1_NOTICIAS = `...`;
export const PROMPT_V1_TECNOLOGIA = `...`;
```

### 3. Estructura del payload al LLM

El Worker construye el prompt final combinando el template con los datos:

```typescript
function buildFinalPrompt(template: string, payload: SynthesisRequest): string {
  return template
    .replace("{{category}}", payload.category)
    .replace("{{titles}}", payload.titles.map(t => `- ${t}`).join("\n"))
    .replace("{{domains}}", payload.domains.join(", "))
    .replace("{{language}}", payload.language);
}
```

### 4. Requisitos de los prompts (estructura obligatoria)

Cada prompt debe:
1. Instruir al LLM a producir Markdown con **al menos 2 headers `##`**.
2. Usar los placeholders `{{titles}}`, `{{domains}}`, `{{category}}`, `{{language}}`.
3. Ser autodescriptivo en el primer párrafo (describir qué tipo de síntesis produce).
4. No requerir URL completa ni contenido de páginas — solo titles y domains (D25).
5. Producir output en el idioma indicado por `{{language}}` (default: español).
6. Limitar la longitud del output: ≤ 800 tokens para latencia aceptable en mobile.

### 5. Guía de contenido por tipo (no normativa — el implementador adapta)

**entretenimiento.txt**
```
Eres un asistente que genera resúmenes de contenido de entretenimiento.
El usuario ha guardado los siguientes recursos de la categoría {{category}}:

Títulos:
{{titles}}

Fuentes: {{domains}}

Genera un resumen en {{language}} con el siguiente formato Markdown:
## Lo que has guardado
[lista de elementos con descripción breve de cada uno]

## Sugerencia de orden
[recomendación de cómo consumir el contenido]

Usa solo la información de los títulos. No inventes sinopsis completas.
Mantén el output conciso (máximo 600 palabras).
```

**cocina.txt**
```
Eres un asistente de cocina que organiza recetas e ingredientes.
El usuario ha guardado los siguientes recursos de cocina:

Títulos:
{{titles}}

Fuentes: {{domains}}

Genera un resumen en {{language}} con el siguiente formato Markdown:
## Recetas guardadas
[lista de recetas con ingredientes principales si se pueden inferir del título]

## Lista de compra consolidada
[ingredientes que probablemente necesitas, basado en los títulos]

Usa solo la información disponible en los títulos. No inventes recetas completas.
```

**noticias.txt**
```
Eres un asistente de noticias que sintetiza información de actualidad.
El usuario ha guardado los siguientes artículos:

Títulos:
{{titles}}

Fuentes: {{domains}}

Genera un resumen en {{language}} con el siguiente formato Markdown:
## Lo esencial en 5 puntos
[5 puntos clave sobre los temas cubiertos por los artículos]

## Temas relacionados
[2-3 temas o preguntas que conectan los artículos]

Basa el resumen solo en los títulos disponibles. No inventes información.
```

**tecnologia.txt**
```
Eres un asistente técnico que organiza recursos de tecnología.
El usuario ha guardado los siguientes recursos:

Títulos:
{{titles}}

Fuentes: {{domains}}

Genera un resumen en {{language}} con el siguiente formato Markdown:
## Herramientas y tecnologías guardadas
[lista de herramientas, frameworks o conceptos mencionados en los títulos]

## Comparativa o relación
[cómo se relacionan o comparan las tecnologías si hay suficiente información]

Usa solo la información de los títulos y dominios. No inventes especificaciones técnicas.
```

---

## Criterios de Aceptación

| # | Criterio | Verificable |
|---|---|---|
| AC-1 | Los 4 archivos de prompt existen en `flowweaver-proxy/prompts/v1/` o como constantes en `src/prompts.ts`. | Inspección del repo |
| AC-2 | Cada prompt contiene los 4 placeholders obligatorios: `{{titles}}`, `{{domains}}`, `{{category}}`, `{{language}}`. | Grep en prompts |
| AC-3 | El output de cada prompt para un payload de prueba contiene ≥ 2 headers `##`. | Test con `wrangler dev` + payload sintético para cada tipo |
| AC-4 | El Worker selecciona el prompt correcto según `synthesis_type` del request. | Test curl con cada tipo |
| AC-5 | El Worker acepta `prompt_version: "v1"` y lo usa correctamente. Con versión desconocida, hace fallback a `"v1"` sin error. | Test curl con `prompt_version: "v99"` → debe responder con v1 |
| AC-6 | La versión v1 sigue disponible tras un despliegue hipotético de v2. | Verificación del mecanismo de selección en código |
| AC-7 | Ningún prompt incluye instrucciones que requieran URL completa o contenido de página web. | Inspección manual de cada prompt |
| AC-8 | El output de síntesis para un payload típico es ≤ 800 tokens (verificado manualmente). | Test manual con payload realista |

---

## Restricciones No Negociables

- **D25:** los prompts solo usan `titles`, `domains`, `category` y `language` como contexto. Nunca piden al LLM buscar URLs ni acceder a contenido externo.
- **No existe `"latest"` dinámico.** La versión es siempre explícita o fallback explícito a `"v1"`.
- Los prompts son **propiedad del producto** — se versionan en el repo `flowweaver-proxy`, no en el cliente Tauri.

---

## Handoffs Requeridos

1. **Implementador → Orchestrator/PO**: los prompts son un activo de producto. El PO debe revisar y aprobar el contenido de cada prompt antes del despliegue en producción.
2. **Implementador → Technical Architect**: handoff de cierre con resultados de AC-3 y AC-8 (calidad del output).

---

## Referencias

- `operations/architecture-reviews/AR-CR-005-llm-synthesis.md` §6
- `operations/task-specs/TS-3-007-flowweaver-proxy.md` (Worker donde se usan los prompts)
- `Project-docs/decisions-log.md` D23, D25
