## Tarea: Proceso formal completo — Síntesis LLM con proxy backend + cierre Fase 2

### Contexto previo
Análisis estratégico completado entre Product Owner y asesor.
Decisiones tomadas explícitamente por el PO:

1. T-3-005 (LLM local Ollama) se cierra como superseded.
   La síntesis va exclusivamente vía proxy backend.
2. scope-boundaries.md se actualiza honestamente reconociendo
   el backend como excepción opt-in al principio "100% local".
3. Beta cerrada con tokens preasignados manualmente por el PO.
   No hay registro email + OTP. Se diferirá a post-validación.
4. Las capturas pendientes del Privacy Dashboard se sustituyen
   por un test E2E automatizado que verifica los 4 estados
   con datos sintéticos. Eso desbloquea AR-2-006.

### Archivos de referencia obligatoria (leer antes de escribir)
- Project-docs/decisions-log.md (D1, D4, D8, D14, D19, D20-D22)
- Project-docs/vision.md
- Project-docs/phase-definition.md
- Project-docs/scope-boundaries.md
- operations/backlogs/backlog-phase-3.md (T-3-001 a T-3-006 existentes)
- operations/task-specs/TS-2-003-state-machine.md
- operations/task-specs/TS-2-004-privacy-dashboard.md
- operations/architecture-notes/AN-classifier-enrichment-options.md
- operations/change-requests/CR-004-classifier-enrichment.md
- operating-system/change-control.md
- operating-system/templates/change-request-template.md
- operating-system/handoff-template.md

---

## BLOQUE A — Cierre Fase 2 (test E2E como sustituto de capturas)

### PASO A.1 — Functional Analyst: TS del test E2E

Crear `operations/task-specs/TS-2-004-privacy-dashboard-e2e-test.md`

Contenido requerido:
- task_id: T-2-004-e2e
- objective: artefacto de verificación que sustituye las 5 capturas
  manuales del Privacy Dashboard previstas en TS-2-004 §Mecanismo ii.
- Justificación: las capturas requieren forzar estados Trusted y
  Autonomous con un comando debug temporal. Un test E2E con datos
  sintéticos cubre los 4 estados (Observing, Learning, Trusted,
  Autonomous) de forma reproducible y mantenible. Es objetivamente
  mejor que screenshots estáticos.
- Criterios de aceptación:
  · El test inicializa la BD con datos sintéticos para cada estado.
  · El test verifica que Privacy Dashboard renderiza los 4 elementos
    requeridos por TS-2-004 §UI: indicador de estado, lista de
    mecanismos activos, controles disponibles, métricas de privacidad.
  · El test ejecuta sin red externa, sin LLM, sin proxy.
  · El test se ejecuta como `cargo test` o `npm run test:e2e`.
  · El test es determinístico — misma entrada, mismo resultado.

### PASO A.2 — Technical Architect: AR sobre el test

Crear `operations/architecture-reviews/AR-2-006-privacy-dashboard-test.md`

Evaluar:
- ¿El test cubre los 4 estados con la misma fidelidad que las
  5 capturas planificadas?
- ¿El método de inyección de datos sintéticos respeta D1
  (no escribe url ni title en claro)?
- ¿El test es mantenible cuando el Privacy Dashboard evolucione?

Aprobar o devolver con cambios. Si aprueba: declarar D14 satisfecho.

### PASO A.3 — Orchestrador: cierre formal Fase 2

Crear `operations/phase-integrity-reviews/PIR-005-addendum-d14-satisfied.md`

Declarar:
- D14 formalmente satisfecho vía AR-2-006 sobre TS-2-004-e2e.
- Las capturas manuales originalmente planificadas se archivan
  como deuda documental no bloqueante.
- Fase 2 cerrada sin condiciones pendientes.
- Habilita apertura de Fase 3.

---

## BLOQUE B — Mini-fix sincronización templates

### PASO B.1 — Functional Analyst: handoff a Claude Code

Crear `operations/handoffs/HO-030-templates-sync-classifier.md`

Contenido:
- Trigger: el Classifier ahora tiene 25 categorías, templates.ts
  solo tiene 15. Las 10 categorías nuevas (deportes, tecnología,
  cocina, gobierno, salud, viajes, finanzas, inmobiliario, IA,
  ciencia) caen al fallback "otro" en Panel C.
- Acción requerida: añadir plantillas de 3 acciones cada una para
  las 10 categorías nuevas en `src/templates.ts` (FlowWeaver).
- Las plantillas siguen el patrón existente: 3-5 acciones cortas
  en español, sin LLM, determinísticas.
- Ejemplos sugeridos (no normativos):
  · deportes: ["Ver resultados y clasificación", "Revisar próximos
    partidos", "Guardar lo más relevante"]
  · cocina: ["Revisar las recetas guardadas", "Hacer lista de
    ingredientes", "Planificar el menú"]
  · viajes: ["Revisar destinos guardados", "Comparar precios",
    "Crear borrador de itinerario"]
  · ...etc para las 10
- Criterios de aceptación:
  · Las 25 categorías del Classifier tienen entrada en
    CATEGORY_TEMPLATES.
  · `npx tsc --noEmit` pasa.
  · Un único commit en FlowWeaver:
    `chore(templates): sincronizar plantillas con classifier 25 cats`

---

## BLOQUE C — Decisiones nuevas (D23, D24, D25, D26)

### PASO C.1 — Orchestrador: emitir D23, D24, D25, D26

Actualizar `Project-docs/decisions-log.md` añadiendo cuatro decisiones
nuevas siguiendo el formato existente. La numeración continúa desde
D22 (que ya existe).

**D23 — Síntesis LLM vía proxy zero-retention**
Contenido:
- FlowWeaver añade síntesis automática usando LLM externo a través
  de un proxy backend stateless propio.
- El proxy es zero-retention: no persiste, no logea contenido,
  no asocia tokens a identidad.
- Provider primario: Cloudflare Workers AI (Llama 3.1 8B,
  zero-log por diseño de Cloudflare).
- Provider secundario (fallback + tier paid): Claude Haiku via
  Anthropic API.
- Provider Groq descartado por retención de logs de 30 días en
  tier free.
- T-3-005 (Ollama local) queda superseded por esta decisión —
  ver D26.

**D24 — Mobile vs Desktop: niveles de funcionalidad**
- Mobile: categorización, listados, acceso a URLs, detección de
  episodios visual. NO síntesis LLM, NO automatización progresiva.
- Desktop: todo lo de mobile + síntesis LLM + exportación +
  automatización progresiva (State Machine completa).
- Mobile puede mostrar síntesis generadas previamente en desktop
  vía sync (lectura de SQLCipher), nunca generarlas.

**D25 — D1-ext: transmisión de títulos al proxy con consentimiento**
- D1 (privacidad) NO se modifica en su núcleo: url y title siguen
  cifrados en BD; el sistema NO accede al contenido de páginas web.
- Extensión D25: los títulos descifrados (que ya son visibles en
  el frontend del usuario) PUEDEN transmitirse al proxy de síntesis
  FlowWeaver únicamente cuando:
  · El usuario ha activado explícitamente la función de síntesis
    mediante un diálogo modal informado en el primer uso.
  · El proxy es zero-retention auditable.
  · El payload contiene exclusivamente: category (string),
    titles (strings), domains (strings), synthesis_type (enum),
    language (string).
  · NUNCA se transmite: url completa, contenido de página,
    identidad del usuario, timestamps personales, datos de BD
    cifrados, install_token vinculado a identidad.
- El usuario puede desactivar la síntesis en cualquier momento
  desde el Privacy Dashboard. La desactivación elimina el
  install_token local.

**D26 — T-3-005 (Ollama local) deprecada**
- T-3-005 queda formalmente superseded por D23.
- Justificación: Ollama exige al usuario instalar 4-8GB y disponer
  de RAM/CPU suficientes. Es contrario al principio de cero
  fricción del onboarding (ver D24). Mantener dos vías paralelas
  duplica complejidad sin valor para beta.
- La tarea T-3-005 se marca cerrada como `superseded by D23`
  en backlog-phase-3.md (ver Bloque E).

### PASO C.2 — Orchestrador: actualizar scope-boundaries.md

Añadir al final de `Project-docs/scope-boundaries.md` una sección
nueva:
---

## BLOQUE D — Cadena formal CR-005

### PASO D.1 — Functional Analyst: emitir CR-005

Crear `operations/change-requests/CR-005-llm-synthesis-backend.md`
siguiendo la plantilla de change-control.md.

Contenido:

**request_id:** CR-005
**owner_agent:** Functional Analyst
**change_type:** Producto + arquitectura + privacidad (multi-impacto)
**date:** 2026-05-04

**Proposed Change:**
Añadir a FlowWeaver el módulo de síntesis automática de episodios
usando LLM externo a través de proxy backend propio. Componentes:

1. Cloudflare Worker proxy (repo independiente: flowweaver-proxy):
   stateless, zero-log, zero-retention, validación de install_tokens
   contra lista preasignada en Cloudflare KV, rate limiting por token,
   relay a Cloudflare Workers AI (primario) y Claude Haiku (fallback),
   prompts especializados server-side por synthesis_type, streaming
   SSE de la respuesta.

2. Módulo synthesis_engine (Rust, src-tauri): construye payload
   {category, titles, domains, synthesis_type, language}, llama al
   proxy con install_token, parsea streaming, persiste resultado
   cifrado en SQLCipher vinculado a pattern_id (no episode_id, ya
   que episode_ids son efímeros).

3. Componente SynthesisView (React): renderiza markdown con
   streaming progresivo. Visible en AnticipatedWorkspace según
   estado de la State Machine. Botón en Trusted, automática
   en Autonomous. Botón "Copiar" y "Exportar como Markdown".

4. Schema SQLCipher: tabla syntheses con (pattern_id_or_session_hash,
   category, content_encrypted, synthesis_type, generated_at).

5. Install token: UUIDv4 generado en primer arranque, persistido en
   SQLCipher cifrado, enviado como header Authorization. NO vinculado
   a email ni identidad. Para beta cerrada: el PO genera N tokens
   manualmente, los inserta en Cloudflare KV, los reparte a beta
   testers que los introducen una sola vez en la app.

6. Privacy Dashboard extensión: nueva sección "Síntesis inteligente"
   con descripción exacta de qué se envía, a dónde, política de
   retención, toggle de activación, contador de uso del día.

7. Rate limiting freemium: contador por token/día en Cloudflare KV.
   Tier free (todos los beta testers): 5 síntesis/día. Tier paid
   (futuro): ilimitado, gestionado por etiqueta en KV.

8. Tipos de síntesis para beta (4 tipos priorizados):
   · entretenimiento: lista de películas/series con sinopsis,
     año, género, sugerencia de orden de visionado
   · cocina: receta consolidada con ingredientes y pasos
   · noticias: "lo esencial en 5 puntos" sobre el tema
   · tecnología: comparativa de herramientas/frameworks vistos

   Output formato: Markdown estructurado con headers predecibles
   (## sección 1, ## sección 2). Frontend renderiza con
   markdown-to-React.

**Why It Is Needed:**
La visión del producto ("preparar el workspace antes de que el
usuario lo pida") requiere síntesis inteligente. Las plantillas
estáticas de Panel C son el baseline (D8) pero no producen valor
diferencial. La síntesis LLM es el componente que convierte
FlowWeaver de "organizador visual" a "asistente que adelanta
trabajo tedioso".

**Problem It Solves:**
- Convierte episodios detectados en outputs accionables.
- Materializa la promesa del estado Autonomous (preparación
  silenciosa).
- Diferencia FlowWeaver de Pocket, Raindrop, Notion Web Clipper
  (captura+organización) hacia un asistente de síntesis.

**Affected Documents:**
- Project-docs/decisions-log.md (D23, D24, D25, D26 ya añadidas
  en Bloque C)
- Project-docs/scope-boundaries.md (excepción ya añadida)
- Project-docs/roadmap.md (actualizar Fase 3 con síntesis)
- operations/backlogs/backlog-phase-3.md (T-3-007 a T-3-013
  nuevas + cierre T-3-005)
- src-tauri/src/synthesis_engine.rs (nuevo módulo)
- src-tauri/src/storage.rs (schema syntheses)
- src/components/SynthesisView.tsx (nuevo componente)
- src/components/PrivacyDashboard.tsx (sección síntesis)
- ShareIntentActivity.kt: SIN cambios (mobile no genera síntesis)

**Phase Impact:**
Todo dentro de Fase 3. Fase 2 ya cerrada vía Bloque A.
T-3-007 a T-3-013 se añaden al backlog Fase 3 con dependencias
explícitas (ver Bloque E).

**Architectural Impact:**
- Primer componente que vive fuera del dispositivo del usuario
  (proxy en Cloudflare).
- Nuevo repo flowweaver-proxy o subdirectorio proxy/ en monorepo
  (Technical Architect decide en AR).
- Gestión de secretos: API keys en Cloudflare environment
  variables, nunca en el binario de Tauri.
- Conectividad requerida solo para síntesis. Sin red, todo lo
  demás del producto funciona.
- Schema de prompts versionable: cambios server-side sin rebuild
  del cliente.

**Scope Creep Risk:**
ALTO. El catálogo original tenía 15+ outputs y 8 funcionalidades
transversales. Este CR acota explícitamente:

INCLUIDO en beta:
- 4 tipos de síntesis (entretenimiento, cocina, noticias, tecnología)
- Exportación Markdown + portapapeles
- Persistencia local de síntesis
- Streaming SSE
- Beta cerrada con tokens preasignados

EXCLUIDO de beta (diferido a post-validación):
- Síntesis para finanzas, salud, inmobiliario, comercio, gobierno,
  viajes, deportes, IA, ciencia, gaming, social, música, educación,
  investigación, desarrollo
- Modo pregunta / chat sobre recursos
- Conexiones entre episodios (requiere embeddings)
- Detección de contradicciones entre fuentes (requiere contenido)
- Fetch ligero de og:description
- Exportación PDF
- Beta abierta con email + OTP
- Tier paid (los precios y la facturación se diseñan
  post-validación de PMF)

**Alternatives Rejected:**
- Ollama local: contrario a "el usuario no instala nada" (D24).
  Cerrado vía D26.
- Groq API: tier free retiene logs 30 días, incompatible con D25.
- Backend con base de datos completa de usuarios: overengineering
  para beta cerrada. Diferido a post-validación.
- Prompts en el binario del cliente: extraíbles via reverse
  engineering, complican deploy de mejoras. Prompts server-side.
- Vinculación de síntesis a episode_id: episode_ids son efímeros
  (Episode Detector regenera en cada cálculo). Vinculación a
  pattern_id (UUIDv5 determinístico desde fix de hoy) o a
  hash(session_id + sorted_resource_ids).

**Recommendation:**
Aprobar para implementación en Fase 3 con las acotaciones
explícitas anteriores. Las 7 tareas T-3-007 a T-3-013 deben
respetar las dependencias declaradas. El Technical Architect
emitirá las TS individuales tras la aprobación.

**Required Reviewers:**
- Technical Architect (proxy, token security, schema, fallback)
- Privacy Guardian (D25 strict compliance, GDPR, Privacy Dashboard)
- Phase Guardian (scope Fase 3, no contaminación de Fase 2)

**Final Decision:** PENDIENTE — Orchestrador post-revisión

### PASO D.2 — Technical Architect: AR-CR-005

Crear `operations/architecture-reviews/AR-CR-005-llm-synthesis.md`

Evaluar y resolver:

1. Token farming: ¿la beta cerrada con tokens preasignados en
   Cloudflare KV es suficiente? Validar que el flujo de
   distribución manual del token está documentado.

2. Decisión repo: ¿proxy en repo independiente flowweaver-proxy
   o subdirectorio proxy/ en monorepo FlowWeaver? Recomendar
   con justificación.

3. Streaming SSE: especificar contrato del endpoint
   (POST /synthesize, headers, formato de chunks SSE,
   manejo de errores en stream).

4. Fallback de provider: timeout primario (Cloudflare AI) en X
   segundos → switch a Claude Haiku → si ambos fallan, error
   estructurado al cliente.

5. Schema SQLCipher: validar que pattern_id es la clave correcta.
   Definir el comportamiento para episodios sueltos sin pattern
   recurrente (hash determinístico session_id + resources).

6. Versionado de prompts: definir cómo se versionan los prompts
   server-side para compatibilidad con clientes antiguos.

7. Criterios de aceptación por tarea (T-3-007 a T-3-013).

### PASO D.3 — Privacy Guardian: PGR-CR-005

Crear `operations/architecture-reviews/PGR-CR-005-llm-synthesis.md`

Verificar y declarar:

1. D25 compliance: el payload nunca incluye url completa, contenido
   cifrado, identidad. Verificar en el código del synthesis_engine
   tras implementación.

2. Cloudflare Workers AI: zero-log confirmado por documentación
   oficial de Cloudflare. Adjuntar referencia.

3. Claude API: data privacy policy de Anthropic confirma
   no-retention en API. Adjuntar referencia.

4. GDPR: install_token UUID sin vinculación a email/identidad
   no constituye dato personal. Validar.

5. Privacy Dashboard sección síntesis: requisitos mínimos de
   contenido (qué se envía, dónde, retención, toggle, contador).

6. Diálogo de consentimiento del primer uso: redacción exacta
   y mecanismo de registro del consentimiento (timestamp + versión
   del aviso aceptado, persistido en SQLCipher).

7. Política de revocación: desactivar síntesis elimina
   install_token local. ¿Se notifica al backend? (Recomendación:
   no necesario — sin token, no hay requests al proxy).

### PASO D.4 — Orchestrador: HO-029 con aprobación

Crear `operations/handoffs/HO-029-cr-005-llm-synthesis-approval.md`

Si AR y PGR aprueban: declarar CR-005 aprobado, activar Functional
Analyst para actualizar backlog-phase-3.md.

---

## BLOQUE E — Actualizar backlog Fase 3

### PASO E.1 — Functional Analyst: actualizar backlog-phase-3.md

Editar `operations/backlogs/backlog-phase-3.md`:

**1. Cerrar T-3-005 como superseded:**
Marcar T-3-005 con estado: `SUPERSEDED by D23 — ver T-3-009`.
Mantener la entrada por trazabilidad histórica.

**2. Añadir tareas nuevas T-3-007 a T-3-013:**

T-3-007 — Cloudflare Worker proxy (flowweaver-proxy)
- Repo independiente o subdirectorio según AR-CR-005.
- Stateless, zero-log, validación de tokens, rate limiting,
  fallback de provider, streaming SSE.
- Dependencias: D23, D24, D25, D26 firmadas. T-3-001 (infra
  beta) parcialmente: necesario saber cómo se distribuyen
  los tokens iniciales.

T-3-008 — Install token + onboarding
- Generación UUID al primer arranque.
- UI onboarding: pantalla "introduce tu token de beta" + botón
  "Continuar sin síntesis" (graceful degradation).
- Persistencia en SQLCipher.
- Dependencias: T-3-007.

T-3-009 — Synthesis engine (Rust)
- Módulo synthesis_engine en src-tauri.
- Vinculación a pattern_id o hash de sesión.
- Schema SQLCipher syntheses.
- Integración con State Machine: solo Trusted o superior.
- Degradación graceful sin red.
- Dependencias: T-3-007, T-3-008, T-3-003 (calibración State
  Machine).

T-3-010 — SynthesisView (React)
- Renderiza markdown streaming.
- Botón "Copiar", botón "Exportar Markdown".
- Estados: idle, loading, streaming, complete, error.
- Dependencias: T-3-009.

T-3-011 — Privacy Dashboard sección síntesis
- Nueva sección con toggle, contador, descripción de
  transmisión de datos.
- Dependencias: cierre formal T-2-004 vía Bloque A.

T-3-012 — Diálogo de consentimiento primer uso
- Modal informado (D25) con registro del consentimiento.
- Versión del aviso versionada para invalidación futura.
- Dependencias: T-3-008, T-3-011.

T-3-013 — Sistema de prompts server-side por categoría
- 4 prompts especializados (entretenimiento, cocina, noticias,
  tecnología) en el Worker.
- Versionado de prompts para compatibilidad con clientes.
- Dependencias: T-3-007.

**3. Actualizar dependencias de tareas existentes** que ahora
dependen de las nuevas, si aplica.

---

## Restricciones del proceso

- Los Bloques A, B, C, D, E son secuenciales. NO empezar Bloque
  C antes de cerrar A. NO empezar D antes de C. Etc.
- Bloque A produce archivos en EquipoEnjambre + un test E2E en
  FlowWeaver. Es la única excepción donde se toca FlowWeaver
  además de B.
- Bloque B es un único cambio en FlowWeaver (templates.ts).
- Bloques C, D, E son exclusivamente documentales en EquipoEnjambre.
- Ninguna implementación de T-3-007 a T-3-013 en este turno.
  Eso vendrá en prompts posteriores, una tarea por prompt, después
  de que el Technical Architect emita las TS individuales.

## Orden de ejecución y commits

Todos commits atómicos, un commit por documento o cambio lógico.

Bloque A:
1. EquipoEnjambre: `docs(TS-2-004-e2e): test E2E como sustituto
   de capturas`
2. FlowWeaver: `test(privacy-dashboard): E2E con datos sintéticos
   para 4 estados`
3. EquipoEnjambre: `docs(AR-2-006): aprobado D14 satisfecho`
4. EquipoEnjambre: `docs(PIR-005-addendum): cierre formal Fase 2`

Bloque B:
5. FlowWeaver: `chore(templates): sincronizar plantillas con
   classifier 25 cats`
6. EquipoEnjambre: `docs(HO-030): templates sync handoff cerrado`

Bloque C:
7. EquipoEnjambre: `docs(decisions-log): D23, D24, D25, D26 +
   scope-boundaries excepción backend`

Bloque D:
8. EquipoEnjambre: `docs(CR-005): change request — LLM synthesis
   backend`
9. EquipoEnjambre: `docs(AR-CR-005): technical architect review`
10. EquipoEnjambre: `docs(PGR-CR-005): privacy guardian review`
11. EquipoEnjambre: `docs(HO-029): orchestrador aprueba CR-005`

Bloque E:
12. EquipoEnjambre: `docs(backlog-phase-3): T-3-005 superseded +
    T-3-007 a T-3-013 nuevas`

Total: 12 commits atómicos. Pasar Cross-Repo Consistency check
(agente 14) al final para verificar que FlowWeaver y EquipoEnjambre
quedan coherentes.

## Verificación post-bloques
- `cargo test` en FlowWeaver: ≥ tests previos + tests nuevos del
  E2E del Privacy Dashboard.
- `npx tsc --noEmit` en FlowWeaver: EXIT=0.
- En EquipoEnjambre: todos los enlaces internos entre documentos
  resuelven correctamente.

Confirmar al final cuántos commits se produjeron en cada repo y
los hashes de HEAD.