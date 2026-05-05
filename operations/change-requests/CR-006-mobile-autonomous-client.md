# Change Request

request_id: CR-006
owner_agent: Functional Analyst
change_type: Producto + arquitectura (mobile escalado a cliente autónomo)
date: 2026-05-05

## Proposed Change

Convertir FlowWeaver Mobile de cliente companion (captura + lectura de síntesis
desktop) a cliente autónomo de captura → agrupación → síntesis proactiva, dirigido
al usuario móvil-only de 25-45 años que actualmente usa Instagram saved y WhatsApp
consigo mismo como sistema de gestión de intención.

**Contexto de producto:** el estudio de usuarios demostró que el mercado mayoritario
es usuario móvil-only que captura compulsivamente y pierde el material. La hipótesis
"el desktop es el cerebro, mobile es companion" resultó incorrecta para este segmento.
Mobile como cliente autónomo es un producto entero, no una feature.

### Componentes nuevos en mobile (Kotlin/Android)

**1. Vista principal agrupada por intención**
La pantalla de inicio muestra los recursos agrupados por categoría con badges de
"X nuevos", no una lista cronológica. Reemplaza el comportamiento actual de la
galería mobile.

**2. Sistema de síntesis proactiva con badge silencioso**
Cuando el sistema detecta material suficiente para una síntesis (≥3 recursos del
mismo episodio), genera la síntesis y muestra un badge en la app. Sin notificación
push agresiva — el usuario entra cuando tiene tiempo y la lee.

**3. Botón manual "Generar ahora"**
Acción explícita de síntesis bajo demanda disponible en cualquier episodio detectado,
sin esperar al trigger automático.

**4. Cliente del proxy en mobile (Kotlin)**
Equivalente al synthesis_engine.rs de Rust pero en Kotlin. Construye el payload
D25-compliant `{category, titles, domains, synthesis_type, language}`, llama al proxy
con install_token, parsea streaming SSE, persiste resultado cifrado en SQLCipher mobile
vinculado al pattern_id o session_hash (D27).

**5. Renderizador Markdown mobile**
Componente Compose o WebView para renderizar Markdown streaming. Botones "Copiar"
y "Compartir".

**6. Plantillas locales para listados básicos sin LLM (25 categorías)**
Equivalente Kotlin de templates.ts con las 25 categorías del Classifier. Listados,
agrupaciones y ordenaciones generados localmente sin llamar al proxy. Es la
funcionalidad free ilimitada base.

**7. Privacy Dashboard mobile con sección síntesis**
Sección "Síntesis inteligente" equivalente a la del desktop, adaptada a UI mobile.
Toggle de activación, contador de uso del mes, descripción exacta de transmisión.

**8. Diálogo de consentimiento mobile (D25)**
Modal informado equivalente al desktop pero con UX mobile. Versionado del aviso
para invalidación futura. Coherente con PGR-CR-005 §6.

**9. Configuración → Captura (D28)**
UI para configurar niveles A/B/C por categoría con toggle simple (aplica Nivel C)
y acceso avanzado para seleccionar Nivel A o B.

**10. Configuración → Perfiles (D29, PAID)**
UI para crear perfiles con horarios. Solo accesible para usuarios paid. Visible para
free con call-to-action "Activar paid para usar perfiles".

**11. Configuración → Sincronización → Filtro (D30)**
UI para configurar qué categorías acepta el dispositivo del relay. Modo flexible
(free) + modo estricto (paid) seleccionables.

**12. Sync bidireccional de tabla syntheses (D27)**
Extensión del schema RawEvent para incluir el tipo `synthesis_generated`. Mobile
sube síntesis generadas al relay; desktop las recibe y viceversa.

**13. Rate limiting freemium en cliente mobile**
Contador local de síntesis del mes. Al llegar a 5 síntesis/mes (tier free), botones
de generación deshabilitados con mensaje explicativo. Proxy es fuente de verdad;
el cliente sincroniza periódicamente.

## Why It Is Needed

El estudio de usuarios mostró que el mercado mayoritario de FlowWeaver es el usuario
móvil-only de 25-45 años que captura compulsivamente (URLs, artículos, vídeos,
recetas) y pierde el material en Instagram saved, WhatsApp consigo mismo y capturas
de pantalla. Mobile como cliente autónomo convierte esa captura compulsiva en valor
accionable sin requerir desktop.

## Problem It Solves

- El usuario móvil-only tiene un producto completo sin necesitar desktop.
- La captura compulsiva se convierte en valor accionable (síntesis automática
  proactiva) sin trabajo manual del usuario.
- El usuario que también tiene desktop ve sincronizado todo el material y todas las
  síntesis entre dispositivos (D27).
- El control granular (D28, D29, D30) le da al usuario poder real sobre qué se captura
  y qué se procesa en cada dispositivo.

## Affected Documents

- `Project-docs/decisions-log.md` — D27, D28, D29, D30, D31 añadidas (Bloque F);
  D24 actualizada con modelo freemium consolidado.
- `Project-docs/scope-boundaries.md` — mobile como cliente autónomo es ampliación
  coherente con D24 ya actualizada, no nueva excepción al scope.
- `Project-docs/roadmap.md` — actualizar Fase 3 con bloque mobile.
- `operations/backlogs/backlog-phase-3.md` — nuevas tareas T-3-014 a T-3-028
  (Bloque H).
- `src-tauri/src/raw_event.rs` — extender schema con tipo `synthesis_generated`
  (implementación futura, T-3-014).
- `ShareIntentActivity.kt` + nuevos componentes Kotlin/Compose — implementación
  futura, T-3-015 a T-3-028.
- `flowweaver-proxy` — SIN cambios. La arquitectura del proxy es agnóstica de
  plataforma; sirve a ambos clientes con el mismo contrato.

## Phase Impact

Todo dentro de Fase 3. T-3-014 a T-3-028 se añaden al backlog con dependencia
EXPLÍCITA de cierre formal de T-3-007 a T-3-013 (desktop validado en beta cerrada).
NO se implementa ninguna tarea mobile hasta que desktop esté validado.

Prioridad de implementación:
1. Desktop: T-3-007 a T-3-013 (en curso).
2. Mobile: T-3-014 a T-3-028 (bloqueadas hasta cierre de desktop).

## Architectural Impact

- Mobile pasa de cliente reactivo (Share Intent + sync) a cliente con lógica de
  procesamiento (Episode Detector mobile, generación de síntesis, gestión de D28-D30).
- Schema RawEvent se extiende con tipo `synthesis_generated` (T-3-014).
- Tabla `syntheses` replicada en SQLCipher mobile con la misma estructura que desktop.
- Sync bidireccional verificada y operativa para el nuevo tipo de evento (D27).
- El proxy backend NO cambia — sirve a ambos clientes con el mismo contrato SSE
  y el mismo mecanismo de install_token.
- Rate limiting del proxy es compartido entre clientes; el contador en Cloudflare KV
  es por token, no por plataforma.

## Scope Creep Risk

**ALTO.** El catálogo de funcionalidades mobile es extenso. Este CR acota
explícitamente:

**INCLUIDO en Fase 3 mobile:**
- Vista agrupada por intención (T-3-018)
- Síntesis proactiva con badge + botón manual (T-3-019, T-3-020)
- Cliente del proxy mobile Kotlin (T-3-015)
- Renderizador Markdown mobile (T-3-021)
- 4 tipos de síntesis (mismos que desktop: entretenimiento, cocina, noticias, tecnología)
- Plantillas locales sin LLM para 25 categorías (T-3-017)
- Privacy Dashboard mobile (T-3-022)
- Diálogo de consentimiento mobile (T-3-023)
- Configuración D28 (T-3-024), D29 (T-3-025), D30 (T-3-026)
- Sync bidireccional syntheses + configuración (T-3-027)
- Rate limiting freemium (T-3-028)

**EXCLUIDO de Fase 3 mobile (diferido a Fase 4 o post-validación):**
- OCR de capturas de pantalla (D31 — visión de producto, fuera de beta)
- Modo pregunta / chat mobile
- Conexiones entre episodios mobile
- Tipos de síntesis adicionales (finanzas, salud, viajes, etc.)
- Notificaciones push agresivas (solo badge silencioso en Fase 3)
- Widgets de pantalla de inicio
- Wearables (Wear OS)
- Beta abierta con email + OTP

## Alternatives Rejected

- **Mobile solo lectura de síntesis desktop:** insuficiente para el usuario
  móvil-only. Desautoriza el estudio de usuarios y cierra el mercado mayoritario.
- **Notificaciones push agresivas:** violan el principio de "preparar sin
  interrumpir". Badge silencioso es coherente con la visión de anticipación no-invasiva.
- **Mobile con LLM local:** mismas razones que descartaron Ollama en desktop (D26).
  Mobile tiene aún menos recursos de RAM/CPU.
- **Duplicar lógica de proxy en app:** el proxy es agnóstico, los clientes son
  distintos. La duplicación de lógica de cliente (Kotlin vs Rust) es aceptable porque
  las plataformas son intrínsecamente distintas y el contrato del proxy es estable.

## Recommendation

Aprobar para implementación en Fase 3 con la dependencia explícita: T-3-014 a T-3-028
BLOQUEADAS hasta cierre formal de T-3-007 a T-3-013 (desktop validado en beta).
El Technical Architect emitirá las TS individuales de T-3-014 a T-3-028 en prompts
posteriores, después de que desktop esté validado.

## Required Reviewers

- Technical Architect (extensión schema RawEvent, cliente mobile Kotlin, sync D27,
  rate limiting distribuido)
- Privacy Guardian (D25 en mobile, control granular D28-D30, consentimiento mobile,
  sync cifrado de syntheses y configuración)
- Phase Guardian (scope Fase 3, dependencia con desktop, no contaminación)

## Final Decision

APROBADO — Orchestrator vía HO-031 (2026-05-05).
Decisiones D27-D31 registradas. AR-CR-006 y PGR-CR-006 aprobados.
T-3-014 a T-3-028 activadas en backlog-phase-3.md con bloqueo hasta desktop.
