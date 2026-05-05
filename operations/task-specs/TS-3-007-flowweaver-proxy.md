# Task Spec — TS-3-007

document_id: TS-3-007
task_id: T-3-007
title: flowweaver-proxy — Cloudflare Worker stateless, zero-log, SSE (D23)
phase: 3
produced_by: Technical Architect
status: APPROVED
date: 2026-05-05
depends_on: ninguna (primera tarea de síntesis — desbloquea toda la cadena)
unblocks: T-3-008 (install token), T-3-013 (prompts server-side)
repo: flowweaver-proxy (independiente de FlowWeaver — AR-CR-005 §2)

---

## Decisiones Arquitectónicas del Technical Architect

Todas las decisiones provienen de AR-CR-005. Se reproducen aquí en forma ejecutable.

### 1. Repo independiente `flowweaver-proxy`

Repo separado del monorepo FlowWeaver. Razones:
- Ciclo de vida independiente: se despliega en Cloudflare sin rebuild del cliente Tauri.
- Secretos (API keys) nunca conviven con código del cliente.
- Cloudflare Workers usa Wrangler — toolchain incompatible con Cargo/npm de Tauri.
- Los prompts son un activo de producto versionable server-side.

### 2. Contrato del endpoint: POST /synthesize

```typescript
// src/index.ts — Worker entry point

interface SynthesisRequest {
  category: string;
  titles: string[];
  domains: string[];
  synthesis_type: "entretenimiento" | "cocina" | "noticias" | "tecnologia";
  language: string;           // "es"
  prompt_version?: string;    // default "v1"
}

// Headers obligatorios en petición:
//   Authorization: Bearer {install_token}
//   Content-Type: application/json

// Respuesta éxito (SSE):
//   HTTP 200 Content-Type: text/event-stream Cache-Control: no-cache
//   data: {"chunk": "## Sección\n\n"}\n\n
//   data: {"chunk": "texto..."}\n\n
//   data: [DONE]\n\n

// Respuestas de error (JSON, no stream):
//   401: {"error": "INVALID_TOKEN"}
//   429: {"error": "RATE_LIMIT_EXCEEDED"}   + Retry-After header
//   400: {"error": "SYNTHESIS_TYPE_UNKNOWN"}
//   503: {"error": "PROVIDER_UNAVAILABLE"}
```

### 3. Estructura del repo

```
flowweaver-proxy/
  src/
    index.ts              — Worker entry point, routing, auth
    token_validator.ts    — KV lookup: install_token → valid | invalid
    rate_limiter.ts       — KV counter: {token}_month_{YYYYMM}
    providers/
      cloudflare_ai.ts    — Llama 3.1 8B via @cloudflare/ai
      claude_haiku.ts     — Anthropic API via fetch
    prompts/
      v1/
        entretenimiento.txt
        cocina.txt
        noticias.txt
        tecnologia.txt
    types.ts              — SynthesisRequest, SynthesisError
  wrangler.toml
  package.json
  tsconfig.json
```

### 4. Flujo de ejecución del Worker

```
POST /synthesize
    │
    ├─► token_validator.validate(token, env.VALID_TOKENS_KV)
    │       NO → 401
    │
    ├─► rate_limiter.check(token, env.RATE_LIMITS_KV)
    │       EXCEEDED → 429
    │
    ├─► validate synthesis_type
    │       UNKNOWN → 400
    │
    ├─► load prompt: prompts/{prompt_version}/{synthesis_type}.txt
    │
    ├─► providers.cloudflare_ai.stream(prompt, payload)   timeout: 8s
    │       OK  → SSE stream → cliente
    │       ERR →
    │           providers.claude_haiku.stream(prompt, payload)  timeout: 10s
    │               OK  → SSE stream → cliente
    │               ERR → 503
    │
    └─► rate_limiter.increment(token, env.RATE_LIMITS_KV)
```

### 5. KV Bindings en wrangler.toml

```toml
[[kv_namespaces]]
binding = "VALID_TOKENS_KV"
id = "..."     # tokens preasignados por el PO para beta cerrada

[[kv_namespaces]]
binding = "RATE_LIMITS_KV"
id = "..."     # contadores por token/mes con TTL de 31 días
```

**Claves en `RATE_LIMITS_KV`:**
```
{install_token}_month_{YYYYMM} = N   (N = síntesis usadas este mes)
```
TTL de 31 días (Cloudflare KV TTL nativo). Reset automático al expirar.

### 6. Header de respuesta con contador

Cada respuesta SSE exitosa incluye:
```
X-Synthesis-Remaining: N
```
donde N = límite_free - síntesis_usadas_este_mes. El cliente Rust/Kotlin
almacena este valor localmente para la UI de rate limiting.

### 7. Versionado de prompts

- Directorio `prompts/v1/` — 4 archivos para beta.
- Request incluye campo opcional `prompt_version` (default `"v1"`).
- Clientes antiguos siguen funcionando con `"v1"` aunque exista `v2`.
- Deprecación con 30 días de antelación mínima.

---

## Contrato de Secretos (PG-004)

```toml
# wrangler.toml — variables de entorno (no en código)
[vars]
# NUNCA poner API keys aquí — usar secrets

# Configurar con:
# wrangler secret put ANTHROPIC_API_KEY
# wrangler secret put CLOUDFLARE_AI_ACCOUNT_ID
```

Los secretos se configuran vía `wrangler secret put`. No aparecen en código,
no en logs, no en respuestas al cliente. Rotación si hay sospecha de compromiso.

---

## Criterios de Aceptación

| # | Criterio | Cómo verificar |
|---|---|---|
| AC-1 | `POST /synthesize` con token válido en KV devuelve SSE con `data: {...}\n\n` para los 4 tipos. | Test con `wrangler dev` + curl |
| AC-2 | Token ausente o inválido → 401 `{"error": "INVALID_TOKEN"}` sin información adicional. | Test curl sin header / con token falso |
| AC-3 | Rate limit superado → 429 `{"error": "RATE_LIMIT_EXCEEDED"}` + header `Retry-After: 86400`. | Test con contador KV al límite |
| AC-4 | `synthesis_type` desconocido → 400 `{"error": "SYNTHESIS_TYPE_UNKNOWN"}`. | Test curl con synthesis_type="otro" |
| AC-5 | Sintaxis SSE correcta: líneas `data: JSON\n\n`, terminador `data: [DONE]\n\n`, `Content-Type: text/event-stream`. | Inspección de respuesta raw |
| AC-6 | Fallback: Cloudflare AI timeout (8s) → Worker prueba Claude Haiku. Solo si ambos fallan → 503. | Test con mock de timeout en Cloudflare AI |
| AC-7 | API keys en Wrangler secrets, no en código fuente. Grep sobre repo: cero ocurrencias de claves hardcoded. | `grep -r "sk-ant\|Bearer " src/` = vacío |
| AC-8 | `wrangler deploy` exitoso. Worker responde en URL de producción `https://flowweaver-proxy.*.workers.dev/synthesize`. | Despliegue real |
| AC-9 | Header `X-Synthesis-Remaining: N` presente en toda respuesta SSE exitosa. | Inspección de headers |
| AC-10 | Prompts en `prompts/v1/` — los 4 archivos existen y producen output Markdown con ≥ 2 headers `##`. | Test manual + inspección |
| AC-11 | Logs del Worker no contienen contenido de títulos ni dominios del payload. | Revisión de Cloudflare Workers dashboard |

---

## Restricciones No Negociables

- **Zero-log**: no se registra contenido de `titles`, `domains` ni `synthesis_type` en logs. Solo metadata de error (status code, latencia).
- **Zero-retention**: el Worker no persiste ningún dato del payload fuera de KV (solo counters por token, sin contenido).
- **D23**: Cloudflare Workers AI es provider primario. Claude Haiku es fallback. No se añaden otros providers sin nueva decisión.
- **D25**: el Worker no puede acceder a datos que no estén en el payload autorizado. No existe llamada de vuelta al cliente para obtener más datos.
- **Sin base de datos de usuarios**: solo KV para tokens y counters. Sin persistencia de sesiones ni historial de peticiones.

---

## Riesgos

| ID | Riesgo | Mitigación |
|---|---|---|
| R-1 | Cold start del Worker introduce latencia > 8s para Cloudflare AI. | Aumentar timeout a 12s si datos de beta lo justifican. Documentar en addendum de TS. |
| R-2 | Un beta tester comparte su token. | Rate limiting por token (5/mes) mitiga el abuso. Para beta de 50 personas, aceptable. |
| R-3 | Prompt injection vía campos `titles` o `domains`. | Los prompts del servidor usan los campos solo como contexto lista, no como instrucciones ejecutables. El Worker valida que `titles` y `domains` son arrays de strings simples. |
| R-4 | Cloudflare KV eventual consistency retrasa reset mensual. | Aceptable: un usuario puede ver contador incorrecto por segundos, no horas. |

---

## Handoffs Requeridos

1. **Implementador (Desktop Tauri Shell Specialist)** → implementar según esta TS.
2. **Privacy Guardian** → re-auditar antes de despliegue en producción:
   verificar que logs no contienen contenido del payload, secretos configurados
   correctamente, política de KV TTL coherente con D25.
3. **Orchestrator** → aprobar despliegue en producción (URL de producción)
   antes de distribuir install_tokens a beta testers.

---

## Referencias

- `operations/change-requests/CR-005-llm-synthesis-backend.md`
- `operations/architecture-reviews/AR-CR-005-llm-synthesis.md` §1-§4 y §6
- `operations/architecture-reviews/PGR-CR-005-llm-synthesis.md` §2, §4 (PG-004)
- `Project-docs/decisions-log.md` D23, D25
- Cloudflare Workers AI Privacy: https://developers.cloudflare.com/workers-ai/privacy/
- Anthropic API Data Privacy: https://www.anthropic.com/legal/api-data-privacy
