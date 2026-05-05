# Revisión Arquitectónica — CR-005: Síntesis LLM vía Proxy Backend

document_id: AR-CR-005
owner_agent: Technical Architect
phase: 3
date: 2026-05-05
status: APROBADO — CR-005 puede activarse; T-3-007 a T-3-013 quedan desbloqueadas
documents_reviewed:
  - operations/change-requests/CR-005-llm-synthesis-backend.md
  - Project-docs/decisions-log.md (D23, D24, D25, D26)
  - Project-docs/scope-boundaries.md (excepción proxy backend)
  - operations/backlogs/backlog-phase-3.md

---

## Resultado Global

**APROBADO sin correcciones.** Los 7 puntos de evaluación quedan resueltos con
decisiones arquitectónicas explícitas. CR-005 puede activarse. Las TS individuales
de T-3-007 a T-3-013 se emitirán en prompts posteriores.

---

## Punto 1 — Token Farming (beta cerrada con tokens preasignados en KV)

**Decisión: SUFICIENTE para beta cerrada.**

El flujo de distribución manual de tokens:
1. PO genera N UUIDv4 tokens offline.
2. PO los inserta en Cloudflare KV vía Wrangler CLI o dashboard.
3. PO los distribuye a beta testers por canal seguro (email, mensaje directo).
4. Beta tester los introduce en la app en la pantalla de onboarding (T-3-008).
5. El proxy valida el token en cada petición contra la lista en KV.

**Salvaguardas:**
- Rate limiting por token: 5 síntesis/día en tier free (KV counter).
- Token inválido → 401 sin información adicional.
- Token no está vinculado a email ni identidad → no hay fuga de datos personales.
- El token se persiste cifrado en SQLCipher local; no viaja en claro fuera del
  dispositivo excepto como header Authorization (HTTPS).

**Riesgo residual:** un beta tester puede compartir su token. Para beta cerrada
de 20-50 personas, el riesgo es aceptable. El rate limiting mitiga el abuso.
Para beta abierta (post-validación), se diseñará autenticación formal.

---

## Punto 2 — Decisión de repo: flowweaver-proxy independiente

**Decisión: REPO INDEPENDIENTE `flowweaver-proxy`.**

**Justificación:**
- El proxy tiene ciclo de vida independiente del cliente Tauri: se despliega,
  actualiza y revierte en Cloudflare sin rebuild del cliente.
- Los secretos (Cloudflare API keys, Anthropic API key) no deben convivir con
  el código del cliente. Repos separados evitan la confusión.
- Cloudflare Workers tiene su propio toolchain (Wrangler); incluirlo en el
  monorepo de Tauri mezcla ecosistemas incompatibles.
- Los prompts de síntesis son un activo de producto que puede iterarse
  server-side sin PR en el repo principal.

**Estructura del repo flowweaver-proxy:**
```
flowweaver-proxy/
  src/
    index.ts          — Worker entry point (POST /synthesize)
    providers/
      cloudflare_ai.ts — Llama 3.1 8B wrapper
      claude_haiku.ts  — Anthropic API fallback
    prompts/
      v1/
        entretenimiento.txt
        cocina.txt
        noticias.txt
        tecnologia.txt
    rate_limiter.ts   — KV counter por token/día
    token_validator.ts — KV lookup de install_tokens válidos
  wrangler.toml
  package.json
```

---

## Punto 3 — Streaming SSE: contrato del endpoint

**Contrato canónico:**

```
POST /synthesize
Authorization: Bearer {install_token}
Content-Type: application/json

{
  "category": "string",
  "titles": ["string", ...],
  "domains": ["string", ...],
  "synthesis_type": "entretenimiento" | "cocina" | "noticias" | "tecnologia",
  "language": "es"
}
```

**Respuesta (SSE stream):**
```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache

data: {"chunk": "## Lo más destacado\n\n"}
data: {"chunk": "**Película 1**: ..."}
data: {"chunk": " continuación..."}
data: [DONE]
```

**Respuestas de error (JSON, no stream):**
```json
{"error": "INVALID_TOKEN"}        // 401
{"error": "RATE_LIMIT_EXCEEDED"}   // 429  (con Retry-After header)
{"error": "SYNTHESIS_TYPE_UNKNOWN"}// 400
{"error": "PROVIDER_UNAVAILABLE"}  // 503  (tras intentar ambos providers)
```

**El cliente Rust (synthesis_engine.rs) maneja:**
- Chunks parciales de UTF-8 (acumulados hasta `\n\n`).
- `[DONE]` como señal de fin de stream.
- 429 con backoff exponencial (máximo 2 reintentos antes de error al usuario).
- 503 como error estructurado visible en SynthesisView.

---

## Punto 4 — Fallback de provider

**Cadena de fallback:**
```
1. POST a Cloudflare Workers AI (Llama 3.1 8B)
   timeout: 8 segundos
   │
   ├── éxito → stream al cliente
   │
   └── fallo (timeout, 5xx) →
       2. POST a Anthropic API (Claude Haiku)
          timeout: 10 segundos
          │
          ├── éxito → stream al cliente
          │
          └── fallo →
              503 {"error": "PROVIDER_UNAVAILABLE"}
              El cliente muestra error estructurado en SynthesisView.
```

**Justificación de timeouts:**
- 8s Cloudflare: el Worker tiene límite de CPU time; Llama 3.1 8B puede ser
  más lento con payloads grandes. 8s cubre el p99 estimado.
- 10s Anthropic: Claude Haiku es más rápido por diseño pero el cold start
  del Worker + latencia API puede sumar.
- El cliente Rust tiene timeout de extremo a extremo de 30s antes de cancelar
  la petición y mostrar error.

---

## Punto 5 — Schema SQLCipher: `syntheses`

**Schema aprobado:**
```sql
CREATE TABLE IF NOT EXISTS syntheses (
    id                      INTEGER PRIMARY KEY,
    anchor_key              TEXT NOT NULL,   -- pattern_id o session_hash
    anchor_type             TEXT NOT NULL,   -- 'pattern' | 'session'
    category                TEXT NOT NULL,
    synthesis_type          TEXT NOT NULL,
    content_encrypted       TEXT NOT NULL,   -- AES-256-GCM, key = local_key
    generated_at            INTEGER NOT NULL -- unix seconds
);
CREATE INDEX IF NOT EXISTS idx_syntheses_anchor ON syntheses(anchor_key);
```

**Clave de vinculación:**
- Si el episodio tiene `pattern_id` asociado (Pattern Detector lo detectó):
  `anchor_key = pattern_id`, `anchor_type = 'pattern'`.
- Si no hay patrón recurrente:
  `anchor_key = sha256(session_id || sorted_resource_ids)[:16]`,
  `anchor_type = 'session'`.

**Justificación de `anchor_key` vs `episode_id`:**
Los episode_ids son efímeros — el Episode Detector los regenera en cada cálculo.
El pattern_id es UUIDv5 determinístico desde domain/category/temporal_window
(cerrado en AR-2-003). El hash de sesión es determinístico desde los recursos
que forman la sesión. Ambos son estables para vincular síntesis persistidas.

---

## Punto 6 — Versionado de prompts server-side

**Mecanismo aprobado:**

Los prompts se versionan en el repo `flowweaver-proxy/prompts/`:
```
prompts/
  v1/entretenimiento.txt
  v1/cocina.txt
  v1/noticias.txt
  v1/tecnologia.txt
  v2/... (futuras versiones)
```

El endpoint acepta un campo opcional `prompt_version` (por defecto `"v1"`):
```json
{"synthesis_type": "cocina", "prompt_version": "v1", ...}
```

El cliente Rust envía siempre `"v1"` en beta. Cuando se despliegue `v2`, los
clientes antiguos siguen funcionando con `v1`. La deprecación de versiones
antiguas se anuncia con mínimo 30 días de antelación (comunicación a beta testers).

**Garantía de compatibilidad hacia atrás:** el Worker mantiene todas las versiones
de prompts hasta deprecación explícita. No existe "latest" dinámico — la versión es
siempre explícita en el request.

---

## Punto 7 — Criterios de aceptación por tarea

| Tarea | Criterio clave | Bloqueante hasta |
|---|---|---|
| T-3-007 (proxy) | POST /synthesize responde con SSE válido para los 4 tipos; token inválido → 401; rate limit → 429 | TS-T-3-007 aprobada |
| T-3-008 (install token + onboarding) | UUIDv4 generado en primer arranque; UI introduce token; SQLCipher cifra token; "Continuar sin síntesis" funcional | T-3-007 operativo |
| T-3-009 (synthesis_engine Rust) | Payload construido sin url completa ni title raw; streaming SSE parseado; síntesis persistida cifrada; degradación graceful sin red | T-3-007, T-3-008 |
| T-3-010 (SynthesisView React) | Markdown streamed renderizado progresivo; estados idle/loading/streaming/complete/error; botones Copiar y Exportar | T-3-009 |
| T-3-011 (Privacy Dashboard sección) | Toggle activación; contador diario; descripción exacta de transmisión | T-2-004 cerrado ✓ |
| T-3-012 (diálogo consentimiento) | Modal primer uso; registro timestamp + versión aviso en SQLCipher | T-3-008, T-3-011 |
| T-3-013 (prompts server-side) | 4 prompts en flowweaver-proxy; versionado v1; salida Markdown estructurado | T-3-007 |

---

## Constraints Verificados

| Constraint | Estado en CR-005 |
|---|---|
| D1 núcleo | url y title siguen cifrados en BD. Payload al proxy solo incluye category, titles (descifrados con consentimiento D25), domains, synthesis_type, language. |
| D4 | synthesis_engine.rs no invoca evaluate_transition ni tiene autoridad de transición. La síntesis es output, no decisión. |
| D8 | Sin síntesis, el baseline (plantillas estáticas) sigue funcionando en cualquier hardware sin red. La síntesis es opt-in. |
| D14 | T-3-011 (sección síntesis en Privacy Dashboard) es prerequisito de beta. No regresionar el dashboard existente. |
| D23 | Implementado exactamente como especificado: proxy propio, zero-retention, Cloudflare primario, Claude Haiku fallback. |
| D24 | Mobile no genera síntesis. ShareIntentActivity.kt sin cambios. |
| D25 | Payload limitado a category + titles + domains + synthesis_type + language. Test estructural obligatorio en T-3-009. |
| D26 | T-3-005 cerrada como superseded. No se implementará Ollama local en beta. |
