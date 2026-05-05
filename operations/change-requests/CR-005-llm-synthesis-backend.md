# Change Request

request_id: CR-005
owner_agent: Functional Analyst
change_type: Producto + arquitectura + privacidad (multi-impacto)
date: 2026-05-05

## Proposed Change

Añadir a FlowWeaver el módulo de síntesis automática de episodios usando LLM
externo a través de proxy backend propio. Componentes:

**1. Cloudflare Worker proxy (repo independiente: flowweaver-proxy)**
Stateless, zero-log, zero-retention. Valida install_tokens contra lista preasignada
en Cloudflare KV. Rate limiting por token (5 síntesis/día tier free). Relay a
Cloudflare Workers AI (primario, Llama 3.1 8B) y Claude Haiku via Anthropic API
(fallback). Prompts especializados server-side por synthesis_type. Streaming SSE
de la respuesta.

**2. Módulo synthesis_engine (Rust, src-tauri)**
Construye payload `{category, titles, domains, synthesis_type, language}`. Llama al
proxy con install_token como header Authorization. Parsea streaming SSE. Persiste
resultado cifrado en SQLCipher vinculado a pattern_id (UUIDv5 determinístico) o a
`hash(session_id + sorted_resource_ids)` para episodios sin patrón recurrente.

**3. Componente SynthesisView (React)**
Renderiza markdown con streaming progresivo. Visible en AnticipatedWorkspace según
estado de la State Machine: botón en Trusted, automática en Autonomous. Botón
"Copiar" y "Exportar como Markdown".

**4. Schema SQLCipher: tabla `syntheses`**
Columnas: `(pattern_id_or_session_hash, category, content_encrypted, synthesis_type,
generated_at)`. Vinculación a pattern_id (no episode_id — episode_ids son efímeros).

**5. Install token**
UUIDv4 generado en primer arranque, persistido en SQLCipher cifrado, enviado como
header Authorization. NO vinculado a email ni identidad. Para beta cerrada: el PO
genera N tokens manualmente, los inserta en Cloudflare KV, los reparte a beta
testers que los introducen una sola vez en la app.

**6. Privacy Dashboard extensión**
Nueva sección "Síntesis inteligente" con descripción exacta de qué se envía, a
dónde, política de retención, toggle de activación, contador de uso del día.

**7. Rate limiting freemium**
Contador por token/día en Cloudflare KV. Tier free (todos los beta testers): 5
síntesis/día. Tier paid (futuro): ilimitado, gestionado por etiqueta en KV.

**8. Tipos de síntesis para beta (4 tipos priorizados)**
- `entretenimiento`: lista de películas/series con sinopsis, año, género, sugerencia
  de orden de visionado.
- `cocina`: receta consolidada con ingredientes y pasos.
- `noticias`: "lo esencial en 5 puntos" sobre el tema.
- `tecnología`: comparativa de herramientas/frameworks vistos.

Output formato: Markdown estructurado con headers predecibles (`## sección`).
Frontend renderiza con markdown-to-React.

## Why It Is Needed

La visión del producto ("preparar el workspace antes de que el usuario lo pida")
requiere síntesis inteligente. Las plantillas estáticas de Panel C son el baseline
(D8) pero no producen valor diferencial. La síntesis LLM convierte FlowWeaver de
"organizador visual" a "asistente que adelanta trabajo tedioso".

## Problem It Solves

- Convierte episodios detectados en outputs accionables de alta calidad.
- Materializa la promesa del estado Autonomous (preparación silenciosa).
- Diferencia FlowWeaver de Pocket, Raindrop, Notion Web Clipper (captura +
  organización) hacia un asistente de síntesis.

## Affected Documents

- `Project-docs/decisions-log.md` — D23, D24, D25, D26 añadidas (Bloque C)
- `Project-docs/scope-boundaries.md` — excepción proxy backend añadida (Bloque C)
- `Project-docs/roadmap.md` — actualizar Fase 3 con síntesis
- `operations/backlogs/backlog-phase-3.md` — T-3-007 a T-3-013 + cierre T-3-005 (Bloque E)
- `src-tauri/src/synthesis_engine.rs` — nuevo módulo (implementación futura)
- `src-tauri/src/storage.rs` — schema tabla syntheses (implementación futura)
- `src/components/SynthesisView.tsx` — nuevo componente (implementación futura)
- `src/components/PrivacyDashboard.tsx` — sección síntesis (implementación futura)
- `ShareIntentActivity.kt` — SIN cambios (mobile no genera síntesis — D24)

## Phase Impact

Todo dentro de Fase 3. Fase 2 ya cerrada formalmente (PIR-005-addendum).
T-3-007 a T-3-013 se añaden al backlog Fase 3 con dependencias explícitas (Bloque E).
T-3-005 se cierra como superseded (D26).

## Architectural Impact

- Primer componente que vive fuera del dispositivo del usuario (proxy en Cloudflare).
- Repo independiente `flowweaver-proxy` (decisión tomada en AR-CR-005 §2).
- Gestión de secretos: API keys en Cloudflare environment variables, nunca en el
  binario de Tauri.
- Conectividad requerida solo para síntesis. Sin red, todo lo demás funciona (D8).
- Schema de prompts versionable: cambios server-side sin rebuild del cliente.

## Scope Creep Risk

**ALTO.** El catálogo original tenía 15+ outputs y 8 funcionalidades transversales.
Este CR acota explícitamente:

**INCLUIDO en beta:**
- 4 tipos de síntesis (entretenimiento, cocina, noticias, tecnología)
- Exportación Markdown + portapapeles
- Persistencia local de síntesis
- Streaming SSE
- Beta cerrada con tokens preasignados

**EXCLUIDO de beta (diferido a post-validación):**
- Síntesis para finanzas, salud, inmobiliario, comercio, gobierno, viajes, deportes,
  IA, ciencia, gaming, social, música, educación, investigación, desarrollo
- Modo pregunta / chat sobre recursos
- Conexiones entre episodios (requiere embeddings)
- Detección de contradicciones entre fuentes
- Fetch ligero de og:description
- Exportación PDF
- Beta abierta con email + OTP
- Tier paid (precios y facturación se diseñan post-validación de PMF)

## Alternatives Rejected

- **Ollama local**: contrario a "el usuario no instala nada" (D24). Cerrado vía D26.
- **Groq API**: tier free retiene logs 30 días, incompatible con D25.
- **Backend con BD completa de usuarios**: overengineering para beta cerrada.
  Diferido a post-validación.
- **Prompts en el binario del cliente**: extraíbles via reverse engineering, complican
  deploy de mejoras. Prompts server-side.
- **Vinculación a episode_id**: episode_ids son efímeros (Episode Detector regenera en
  cada cálculo). Vinculación a pattern_id (UUIDv5 determinístico) o a
  hash(session_id + sorted_resource_ids).

## Recommendation

Aprobar para implementación en Fase 3 con las acotaciones explícitas anteriores.
Las 7 tareas T-3-007 a T-3-013 deben respetar las dependencias declaradas.
El Technical Architect emitirá las TS individuales tras la aprobación.

## Required Reviewers

- Technical Architect (proxy, token security, schema, fallback)
- Privacy Guardian (D25 strict compliance, GDPR, Privacy Dashboard)
- Phase Guardian (scope Fase 3, no contaminación de Fase 2)

## Final Decision

APROBADO — Orchestrator vía HO-029 (2026-05-05).
Decisiones D23, D24, D25, D26 registradas. AR-CR-005 y PGR-CR-005 aprobados.
T-3-007 a T-3-013 activadas en backlog-phase-3.md. T-3-005 cerrada como superseded.
