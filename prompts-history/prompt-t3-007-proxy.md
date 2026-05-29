## Tarea: Implementar T-3-007 — flowweaver-proxy (Cloudflare Worker)

### Contexto
Repo NUEVO e INDEPENDIENTE: `flowweaver-proxy`.
NO es parte de FlowWeaver ni de EquipoEnjambre.
Crear desde cero en un directorio hermano o donde indiques.
TS completa en: EquipoEnjambre/operations/task-specs/TS-3-007-flowweaver-proxy.md
Leerla antes de escribir cualquier línea de código.

### Stack
- Cloudflare Workers (TypeScript)
- Wrangler CLI
- @cloudflare/ai para Llama 3.1 8B
- Anthropic API (fetch nativo) para Claude Haiku fallback
- Cloudflare KV para tokens y rate limiting

### Estructura exacta del repo (no inventar variaciones)
flowweaver-proxy/
src/
index.ts
token_validator.ts
rate_limiter.ts
providers/
cloudflare_ai.ts
claude_haiku.ts
prompts/
v1/
entretenimiento.txt
cocina.txt
noticias.txt
tecnologia.txt
types.ts
wrangler.toml
package.json
tsconfig.json
.gitignore
README.md

### Implementación por archivo

**types.ts**

```typescript
export interface SynthesisRequest {
  category: string;
  titles: string[];
  domains: string[];
  synthesis_type: "entretenimiento" | "cocina" | "noticias" | "tecnologia";
  language: string;
  prompt_version?: string;
}

export interface SynthesisError {
  error:
    | "INVALID_TOKEN"
    | "RATE_LIMIT_EXCEEDED"
    | "SYNTHESIS_TYPE_UNKNOWN"
    | "PROVIDER_UNAVAILABLE";
}

export interface Env {
  VALID_TOKENS_KV: KVNamespace;
  RATE_LIMITS_KV: KVNamespace;
  ANTHROPIC_API_KEY: string;
  CLOUDFLARE_AI_ACCOUNT_ID: string;
}
```

**token_validator.ts**
Función `validate(token: string, kv: KVNamespace): Promise<boolean>`.
Hace `kv.get(token)`. Si existe y no es null → válido. Si no → inválido.
Los tokens son UUIDs que el PO insertará manualmente con:
`wrangler kv:key put --binding VALID_TOKENS_KV {token} "active"`

**rate_limiter.ts**
Dos funciones:
- `check(token, kv, limit): Promise<{allowed: boolean, remaining: number}>`
  Lee clave `{token}_month_{YYYYMM}`. Si no existe → 0 usos. Si >= limit → deniega.
- `increment(token, kv): Promise<number>`
  Incrementa el contador. TTL: 31 días (2678400 segundos).

Límite free: 5 síntesis/mes. Definirlo como constante `FREE_LIMIT = 5`.

**providers/cloudflare_ai.ts**
Llama a Cloudflare Workers AI con el binding `AI`.
Usa el modelo `@cf/meta/llama-3.1-8b-instruct`.
Implementa streaming SSE. Timeout: 8 segundos con `AbortController`.
Si el stream se corta o timeout → lanza error que el caller captura.

**providers/claude_haiku.ts**
Llama a Anthropic API (`https://api.anthropic.com/v1/messages`).
Modelo: `claude-haiku-4-5-20251001`.
`max_tokens: 1000`.
Headers: `x-api-key: env.ANTHROPIC_API_KEY`, `anthropic-version: 2023-06-01`.
Stream: `"stream": true`, parsear `text_delta` de los eventos SSE.
Timeout: 10 segundos.

**index.ts**
Flujo exacto según TS-3-007 §4:
1. Validar método POST y ruta /synthesize.
2. Parsear body como SynthesisRequest.
3. Validar Authorization: Bearer {token}.
4. `token_validator.validate` → 401 si falla.
5. `rate_limiter.check` → 429 con header `Retry-After: 86400` si excedido.
6. Validar `synthesis_type` contra los 4 valores permitidos → 400 si falla.
7. Cargar prompt desde `prompts/{prompt_version || "v1"}/{synthesis_type}.txt`.
8. Intentar `cloudflare_ai.stream` con timeout 8s.
9. Si falla → intentar `claude_haiku.stream` con timeout 10s.
10. Si ambos fallan → 503 `{"error": "PROVIDER_UNAVAILABLE"}`.
11. Si éxito → stream SSE al cliente con header `X-Synthesis-Remaining: N`.
12. Al completar stream exitoso → `rate_limiter.increment`.

Formato SSE estricto:
data: {"chunk": "texto"}\n\n
data: [DONE]\n\n
Headers de la respuesta:
Content-Type: text/event-stream
Cache-Control: no-cache
X-Synthesis-Remaining: {remaining}

### Prompts v1 (contenido completo de cada .txt)

**prompts/v1/entretenimiento.txt**
Eres un asistente que ayuda a organizar contenido de entretenimiento
guardado por el usuario. El usuario ha estado consultando estos recursos:
Títulos: {titles}
Dominios: {domains}
Genera un resumen útil en español con este formato Markdown exacto:
Contenido encontrado
[Lista de películas/series/contenido identificado con sinopsis breve
de 1-2 líneas cada uno, año si lo conoces, y género]
Orden sugerido
[Si hay múltiples títulos relacionados, sugiere un orden para verlos
o un maratón. Si son independientes, agrúpalos por tipo o género]
Dónde verlos
[Para cada título, indica en qué plataforma suele estar disponible
en España si lo sabes: Netflix, HBO Max, Filmin, Amazon Prime, etc.]
Sé conciso. Si no reconoces algún título, indícalo brevemente.
No inventes información que no conozcas.

**prompts/v1/cocina.txt**
Eres un asistente de cocina que ayuda a organizar recetas e ideas
guardadas por el usuario. El usuario ha estado consultando estos recursos:
Títulos: {titles}
Dominios: {domains}
Genera un resumen útil en español con este formato Markdown exacto:
Plato identificado
[Nombre del plato o tipo de receta que el usuario estaba buscando]
Ingredientes principales
[Lista de ingredientes clave que necesitará, basándote en lo que
sabes sobre el plato. Incluye cantidades orientativas para 2 personas]
Pasos clave
[3-5 pasos principales del proceso de preparación]
Consejos
[1-3 consejos prácticos para mejorar el resultado o variaciones
interesantes]
Si hay varias recetas distintas, crea una sección por cada una.
Sé práctico y directo. No inventes recetas que no existan.

**prompts/v1/noticias.txt**
Eres un asistente que ayuda a entender el contexto de noticias
que el usuario ha estado leyendo. El usuario ha consultado estos recursos:
Títulos: {titles}
Dominios: {domains}
Genera un resumen útil en español con este formato Markdown exacto:
El tema en resumen
[2-3 frases que expliquen de qué trata el tema general que el
usuario estaba siguiendo]
Lo esencial en 5 puntos
[5 puntos clave sobre este tema, basándote en lo que sabes]
Contexto importante
[1-2 párrafos de contexto histórico o de fondo que ayude a
entender mejor el tema]
Preguntas abiertas
[2-3 aspectos del tema que siguen sin resolverse o que son
objeto de debate]
Basa el resumen en lo que conoces del tema hasta tu fecha de
conocimiento. Si el tema es muy reciente, indícalo.

**prompts/v1/tecnologia.txt**
Eres un asistente técnico que ayuda a evaluar herramientas y
tecnologías. El usuario ha estado investigando estos recursos:
Títulos: {titles}
Dominios: {domains}
Genera un resumen útil en español con este formato Markdown exacto:
Herramientas identificadas
[Lista de herramientas, frameworks o tecnologías que el usuario
estaba evaluando, con una descripción de 1-2 líneas cada una]
Comparativa rápida
[Tabla o lista comparativa con los puntos clave:
para qué sirve cada una, puntos fuertes, limitaciones principales]
Recomendación
[Cuándo elegir cada opción según el caso de uso. Si son
complementarias, indicar cómo pueden usarse juntas]
Recursos para empezar
[Para cada herramienta principal, indica dónde está la documentación
oficial o el mejor recurso para empezar]
Sé técnico pero accesible. No inventes características que no existan.

### wrangler.toml

```toml
name = "flowweaver-proxy"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[kv_namespaces]]
binding = "VALID_TOKENS_KV"
id = "PLACEHOLDER_VALID_TOKENS_KV_ID"

[[kv_namespaces]]
binding = "RATE_LIMITS_KV"
id = "PLACEHOLDER_RATE_LIMITS_KV_ID"

[ai]
binding = "AI"
```

Nota: los IDs de KV son placeholders. El PO los sustituirá por los
IDs reales al crear los namespaces en Cloudflare Dashboard o con
`wrangler kv:namespace create`.

### .gitignore
node_modules/
.wrangler/
dist/
*.env
.dev.vars

### README.md

Incluir:
1. Descripción del proxy (qué hace, qué no hace)
2. Requisitos: Node.js, Wrangler CLI
3. Setup local: `npm install`, `wrangler dev`
4. Cómo configurar los secretos:
wrangler secret put ANTHROPIC_API_KEY
wrangler secret put CLOUDFLARE_AI_ACCOUNT_ID
5. Cómo crear los KV namespaces y actualizar wrangler.toml
6. Cómo añadir un token de beta:
wrangler kv:key put --binding VALID_TOKENS_KV {uuid} "active"
7. Cómo deployar: `wrangler deploy`
8. Verificación de ACs con curl

### Criterios de aceptación a verificar antes de entregar

Verificar todos los ACs de TS-3-007 con `wrangler dev` corriendo
localmente. Para cada AC indicar PASS/FAIL y el comando exacto usado:

- AC-1: curl POST con token válido → SSE stream para los 4 tipos
- AC-2: curl sin Authorization → 401
- AC-3: simular rate limit → 429 con Retry-After
- AC-4: synthesis_type="invalido" → 400
- AC-5: inspección raw del SSE → formato correcto
- AC-6: simular timeout Cloudflare AI → debe usar Claude Haiku
- AC-7: `grep -r "sk-ant\|Bearer " src/` → vacío
- AC-9: header X-Synthesis-Remaining presente
- AC-10: los 4 prompts existen y producen output con ≥ 2 headers ##
- AC-11: logs en `wrangler dev` no muestran titles ni domains

AC-8 (deploy real) y AC-11 (dashboard Cloudflare) se verifican
manualmente con el PO tras el deploy.

### Restricciones No Negociables (de TS-3-007)

- ZERO-LOG: no registrar titles, domains ni synthesis_type en logs.
  Solo metadata: status code y latencia.
- ZERO-RETENTION: solo KV para tokens y counters. Sin persistencia
  de payload.
- Las API keys nunca en código — solo wrangler secrets.
- Cloudflare AI es primario, Claude Haiku es fallback.
  No añadir otros providers.
- Los prompts viven en archivos .txt en prompts/v1/.
  No en código TypeScript.

### Entrega

Al terminar:
1. Lista de archivos creados
2. Resultado de cada AC (PASS/FAIL)
3. Instrucciones exactas para que el PO haga el deploy
   (paso a paso, sin asumir conocimiento de Cloudflare)
4. Comando curl exacto para probar el endpoint en producción
   una vez desplegado
5. Aviso de que AC-8 y AC-11 requieren verificación manual del PO

Dos cosas antes de pasarlo:
Primera: T-3-007 vive en un repo nuevo flowweaver-proxy, no en FlowWeaver ni EquipoEnjambre. Asegúrate de que Claude Code entiende dónde crearlo — dile la ruta exacta donde quieres el repo nuevo.
Segunda: Después de que Claude Code genere el repo, hay pasos manuales tuyos antes de hacer funcionar el proxy en producción:

Crear cuenta en Cloudflare (si no tienes)
Crear dos KV namespaces desde el Dashboard
Actualizar los IDs en wrangler.toml
Configurar los secrets con wrangler secret put
Hacer wrangler deploy