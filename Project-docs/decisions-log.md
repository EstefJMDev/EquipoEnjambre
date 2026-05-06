# FlowWeaver - Decisions Log

Este documento contiene decisiones cerradas del producto y del proyecto marco.

Ninguna decisión aquí registrada puede cambiarse sin:

* propuesta formal de cambio
* justificación
* impacto en fases
* impacto en arquitectura conceptual
* validación del Orchestrator

## Uso en este repositorio

Estas decisiones no son instrucciones de implementación. Son restricciones
normativas que el enjambre debe preservar.

## Registro de decisiones cerradas

| ID | Área | Elección | Justificación |
| --- | --- | --- | --- |
| D1 | Privacidad | Nivel 1: títulos + meta-tags cifrados. Narrativa "verificable", no "radical". | Sin títulos no hay workspace útil. Sigue siendo gran diferencial frente a competencia. |
| D2 | Motores de detección | Episode Detector dual-mode inmediato; Pattern Detector completo solo en Fase 2. | Fase 1 usa Episode Detector adaptado para descargas. Pattern Detector no se divide entre fases. |
| D3 | Precisión del Episode Detector | Dual-mode: preciso con Jaccard + ecosistemas, con fallback amplio por categoría. | Evita ser demasiado conservador sin sacrificar precisión. Umbrales configurables en beta. |
| D4 | Autoridad de confianza | La máquina de estados manda; `trust_score` es input con doble condición. | Elimina divergencia entre score y transiciones. |
| D5 | Estabilidad | Slot concentration score con entropía normalizada. | Se mantiene acotado entre 0 y 1 y funciona con pocos datos. |
| D6 | Sync MVP | Relay cifrado por iCloud/Google Drive con ACK, idempotencia y reintentos. | Fiable, sin infraestructura propia y robusto ante race conditions. |
| D7 | Migración de sync | LAN añade canal en V1; P2P requiere nuevo emparejamiento en V2+. | No se promete transparencia total. Los cambios se comunican. |
| D8 | Motor de resumen | Plantillas como baseline; LLM como mejora opcional. | El baseline debe funcionar en cualquier hardware. |
| D9 | Observer MVP | Único observer activo: Share Intent Android (primario); Share Extension iOS (track paralelo secundario). Desktop no observa en MVP. **[EXTENDIDA 2026-04-27 — REVERTIDA 2026-04-29 por OD-007]** ~~Observer semi-pasivo Android (tier paid) autorizado via Tile de sesión.~~ Extensión revertida porque dependía de D22, que ha sido aplazada. La sección de detalle "D9 — Extensión: Observer Semi-Pasivo Android (Tier Paid)" se conserva como referencia técnica pero NO autoriza implementación. **[REVISADA 2026-04-28 — ver detalle abajo]** FS Watcher desktop: modo background-persistent (no foreground-only). | Es el mínimo necesario para el caso dorado. FS Watcher entra en Fase 1. Plataforma primaria cambia a Android per D19. Extensión formal aprobada por AR-CR-002-mobile-observer + PGR-CR-002-mobile-observer. Revisión FS Watcher aprobada por Orchestrator 2026-04-28: el modelo foreground-only causaba pérdida de eventos al cambiar de foco. |
| D10 | Roadmap | Fase 0 se divide en 0a workspace y 0b puente. Desktop nativo Tauri. | 0a valida formato; 0b valida el puente. Reduce riesgo. |
| D11 | Plataforma | ~~macOS + iOS first.~~ **SUPERSEDIDA por D19.** | Supersedida por decisión estratégica de mercado. |
| D12 | Foco MVP | Único caso: puente móvil -> desktop. Bookmarks son onboarding, no caso de uso núcleo. | Obliga a proteger un solo caso excepcional antes de ampliar. |
| D13 | Narrativa | "Detecta y anticipa, sin reglas manuales" en lugar de "aprende observando". | Es más honesto con el MVP actual y deja el aprendizaje para fases posteriores. |
| D14 | Privacy Dashboard | Mínimo en 0b; completo en Fase 2 y obligatorio antes de beta. | Se despliega progresivamente según el alcance real de cada fase. |
| D15 | Monetización | Beta con free generoso; límites definidos con datos reales en V1. | Optimizar pricing antes de PMF es prematuro. |
| D16 | Esquema BD | `INTEGER PRIMARY KEY` más UUID indexado. | Evita fragmentación de B-tree. |
| D17 | Pattern Detector timing | Completo en Fase 2. Fase 1 reutiliza Episode Detector para descargas. | Evita tener un Pattern Detector a medias entre fases. |
| D18 | Buffer de sync | Fase 0b incluye semana 8 de buffer; escape QR si iCloud falla en semana 6. | Se reconoce el riesgo real del sync sin retrasar toda la validación. |

| D19 | Plataforma | Windows + Android first. iOS como track paralelo secundario cuando haya entorno macOS disponible. | El primer frente de clientes a abordar es Android + Windows. El entorno de desarrollo actual (Windows 10) permite compilar Tauri Android sin Mac. Tauri 2 soporta Android nativamente — el mismo backend Rust compila para ambas plataformas sin reescritura. |
| D20 | Mobile como cliente completo | Desde Fase 0c, la app Android es un cliente completo: captura, procesa localmente (Classifier + Grouper + SQLCipher propio) y muestra galería organizada por categoría. El móvil no depende del desktop para entregar valor. Aprobado en CR-001 / OD-005. | El valor del producto debe estar disponible en el dispositivo donde ocurre la captura. Sin galería móvil, el usuario necesita el desktop para ver lo que guardó — rozamiento inaceptable para un producto de captura cotidiana. |
| D21 | Sync bidireccional | Desde Fase 0c, el relay Google Drive es bidireccional: móvil → desktop (ya existe en 0b) + desktop → móvil (nuevo). Cada dispositivo tiene su propio SQLCipher y procesa de forma independiente. El relay transporta raw_events en ambas direcciones. No hay merge de bases de datos ni fuente de verdad única. Aprobado en CR-001 / OD-005. | El modelo local-first requiere que cada dispositivo sea soberano. El relay bidireccional sobre Google Drive (mecanismo ya probado en 0b) es la extensión más simple y coherente con D6. El merge de BD se evalúa en V1 si es necesario. |
| D22 | FlowWeaver Mobile standalone — tier paid | **APLAZADA por OD-007 (2026-04-29).** Decisión original: Modelo freemium mobile con tier paid (Pattern Detector móvil + observer semi-pasivo + anticipación proactiva). Aplazada para preservar caso núcleo único del MVP. Las condiciones de reactivación están en OD-007 §"Reactivation conditions". | Texto original: "El usuario mobile-only merece el mismo valor de anticipación que el usuario desktop." Motivo del aplazamiento: validar dos hipótesis en paralelo dispersa el MVP. Primero se valida el puente; D22 se reactiva solo si las condiciones de OD-007 se cumplen. |
| D23 | Síntesis LLM vía proxy zero-retention | FlowWeaver añade síntesis automática usando LLM externo a través de un proxy backend stateless propio. El proxy es zero-retention: no persiste, no logea contenido, no asocia tokens a identidad. Provider primario: Cloudflare Workers AI (Llama 3.1 8B, zero-log por diseño de Cloudflare). Provider secundario (fallback + tier paid): Claude Haiku via Anthropic API. Provider Groq descartado por retención de logs de 30 días en tier free. T-3-005 (Ollama local) queda superseded por esta decisión — ver D26. | La síntesis LLM es el componente que convierte FlowWeaver de organizador visual a asistente que adelanta trabajo tedioso. El proxy propio permite control de retención, rate limiting y gestión de tokens sin dependencia de un proveedor con política de datos inadecuada. |
| D24 | Mobile vs Desktop: niveles de funcionalidad | Desktop: síntesis LLM completa, automatización Autonomous, State Machine completa. Primera implementación del proxy de síntesis. Mobile: lectura de síntesis generadas en desktop vía sync de tabla syntheses (SQLCipher). Mobile generará síntesis básicas (listados, agrupaciones, recetas, películas) usando el mismo proxy en una iteración inmediatamente posterior a la validación de síntesis en desktop. La arquitectura del proxy es agnóstica de plataforma — la extensión mobile no requiere cambio de infraestructura backend, solo extensión del cliente Android. Modelo freemium consolidado: ambos dispositivos (mobile y desktop) son completamente accesibles en tier free con los mismos límites — captura ilimitada, listados básicos sin LLM ilimitados, síntesis LLM enriquecida limitada a 5 al mes con reset mensual. Funcionalidades paid (perfiles D29, modo estricto de D30, síntesis ilimitadas, funcionalidades avanzadas futuras) disponibles en cualquier dispositivo. El precio del tier paid se decide post-beta con datos reales — durante la beta cerrada todo es gratuito. | La síntesis LLM requiere conectividad y capacidad de cómputo adecuadas a cada plataforma. Empezar por desktop permite validar el proxy con el cliente más exigente antes de extenderlo a mobile. La diferenciación temporal desktop→mobile no es definitiva: ambas plataformas convergerán en funcionalidad de síntesis. |
| D25 | D1-ext: transmisión de títulos al proxy con consentimiento | D1 (privacidad) NO se modifica en su núcleo: url y title siguen cifrados en BD; el sistema NO accede al contenido de páginas web. Extensión D25: los títulos descifrados (ya visibles en el frontend del usuario) PUEDEN transmitirse al proxy de síntesis FlowWeaver únicamente cuando: (a) el usuario ha activado explícitamente la función de síntesis mediante diálogo modal informado en el primer uso; (b) el proxy es zero-retention auditable; (c) el payload contiene exclusivamente category, titles, domains, synthesis_type, language. NUNCA se transmite: url completa, contenido de página, identidad del usuario, timestamps personales, datos de BD cifrados, install_token vinculado a identidad. El usuario puede desactivar la síntesis en cualquier momento desde el Privacy Dashboard. La desactivación elimina el install_token local. | Los títulos descifrados ya son visibles al usuario en su propio dispositivo. Transmitirlos al proxy con consentimiento explícito no viola el espíritu de D1 — el usuario sabe qué se envía y puede revocar en cualquier momento. La síntesis sin títulos produciría resultados de muy baja calidad. |
| D26 | T-3-005 (Ollama local) deprecada | T-3-005 queda formalmente superseded por D23. Justificación: Ollama exige al usuario instalar 4-8GB y disponer de RAM/CPU suficientes. Es contrario al principio de cero fricción del onboarding. Mantener dos vías paralelas (proxy + Ollama) duplica complejidad sin valor diferencial para beta. La tarea T-3-005 se marca cerrada como `SUPERSEDED by D23` en backlog-phase-3.md. | El proxy backend elimina la barrera de instalación local. Para beta cerrada, el control de acceso (tokens preasignados) es más robusto con el proxy que con Ollama local donde no existe mecanismo de rate limiting. |
| D27 | Sincronización bidireccional explícita de recursos y síntesis | La tabla syntheses se sincroniza vía relay igual que la tabla resources. Cualquier dispositivo (mobile o desktop) que genere una síntesis la sube al relay; los demás dispositivos del usuario la reciben. La infraestructura del relay ya soporta sync bidireccional (drive_relay.rs). La extensión consiste en añadir el tipo de evento `synthesis_generated` al schema RawEvent además del actual `resource_captured`. El payload del evento incluye: anchor_key, category, synthesis_type, content_encrypted, generated_at, source_device_id. La conciliación local descifra y persiste en la tabla syntheses del SQLCipher receptor. | Las síntesis tienen valor en cualquier dispositivo del usuario. Si se genera en mobile, debe estar disponible en desktop y viceversa. La infraestructura del relay ya existe — solo falta extender el schema. Sin esto, desktop y mobile son silos parciales de síntesis. |
| D28 | Control granular de captura por categoría con tres niveles (FREE) | El usuario configura por categoría el nivel de captura desde Configuración → Captura → Por categoría. Tres niveles disponibles: Nivel A "No capturar" (cualquier intento de compartir un recurso de esa categoría se ignora silenciosamente — destructivo, dato se pierde, aviso explícito al activar); Nivel B "Capturar pendiente" (el recurso se captura pero queda en estado pendiente — no se procesa, no genera síntesis, no aparece en listados regulares, revisable desde Configuración → Captura → Pendientes); Nivel C "Capturar silenciosa" (el recurso se captura y procesa normalmente, pero no genera notificaciones proactivas ni síntesis automáticas — por defecto cuando el usuario desactiva una categoría con el toggle simple). Captura normal es el estado por defecto de todas las categorías. El toggle simple aplica Nivel C; ir a "Avanzado" permite elegir A o B. La configuración es global, sincronizada entre dispositivos. Es funcionalidad FREE porque es control de privacidad básico. | Privacy-first práctico llevado al uso cotidiano. Reducción de ruido en síntesis y notificaciones. Ahorro de cuota freemium para el usuario que no quiere síntesis de categorías no prioritarias. El control granular es un derecho básico del usuario, no un feature premium. |
| D29 | Perfiles globales de captura con horarios (PAID) | El usuario puede crear perfiles de captura desde Configuración → Perfiles. Cada perfil tiene un nombre (ej. "Trabajo", "Fin de semana", "Vacaciones") y configura qué categorías están activas. El usuario asigna horarios o días al perfil (ej. lunes-viernes 9-18h, fines de semana, vacaciones manualmente activadas). El sistema aplica el perfil activo según fecha/hora actual. Si dos perfiles solapan, el más específico tiene prioridad (vacaciones > fin de semana > trabajo > horario laboral). Si ningún perfil aplica, el comportamiento es captura normal de todas las categorías. Esta funcionalidad es PAID. El usuario free tiene D28 (control por categoría con niveles A/B/C) que cubre el caso simple. | Casos de uso del estudio de usuarios ("solo lo uso para trabajar", "no quiero capturar social los fines de semana"). Los perfiles son la versión avanzada de D28 para usuarios que quieren control temporal automático. La distinción free/paid es coherente: D28 da control suficiente en free; D29 es automatización temporal avanzada. |
| D30 | Filtro de entrada por dispositivo con dos modos | Cada dispositivo configura desde Configuración → Sincronización → Filtro qué categorías acepta del relay sincronizado. Dos modos: Modo FLEXIBLE (FREE) — los eventos de categorías bloqueadas llegan al SQLCipher local pero quedan ocultos en la vista; si el usuario relaja el filtro, los eventos antiguos reaparecen sin pérdida. Modo ESTRICTO (PAID) — los eventos de categorías bloqueadas se descartan a la entrada, no entran al SQLCipher local; máxima separación de contextos. Configuración por dispositivo, no global. Mi mobile puede tener filtro distinto que mi desktop. | Casos de uso del estudio ("desktop solo para trabajo, no quiero ver datos personales"). El modo flexible respeta los datos del usuario (no destructivo, reversible). El modo estricto está en paid porque la garantía de no-entrada es valor adicional para usuarios con necesidad de separación fuerte entre contextos. |
| D32 | React StrictMode descartado en frontend Tauri | `useEffect` bajo StrictMode ejecuta dos veces en dev. Combinado con `listen()` async de `@tauri-apps/api/event`, produce listeners duplicados que no se pueden recolectar de forma fiable. La primera invocación devuelve la promise pero la cleanup ejecuta antes de que la segunda termine de registrar. Decisión: `src/main.tsx` no envuelve `<App/>` en `<React.StrictMode>`. Cualquier refactor de `App.tsx` o de componentes con listeners Tauri debe preservar esta condición. Las warnings que StrictMode detectaría se ejercitan vía test manual y eslint. |
| D31 | Captura de imágenes con OCR (visión de producto — fuera de beta) | FlowWeaver Mobile incluirá en futuras iteraciones la capacidad de aceptar capturas de pantalla del rollo de cámara y aplicar OCR para extraer texto, dominios y URLs presentes en la imagen. La imagen original se procesa localmente; se extraen los datos relevantes (texto, URLs detectadas, dominios visibles) y la imagen se descarta sin persistirse — solo se guarda lo extraído. El comportamiento es coherente con D25 (se procesa localmente, se transmiten al proxy solo campos textuales como cualquier otra captura). Esta funcionalidad NO se implementa en beta. Se documenta como dirección explícita del producto para que el enjambre no la trate como scope creep cuando llegue su momento. Implementación post-validación de PMF con captura de URLs. | El estudio de usuarios mostró que "la gente hace pantallazos" como mecanismo paralelo a compartir URLs. Capturar pantallazos amplía dramáticamente el alcance del producto sin romper la arquitectura — se procesan localmente y entran al mismo pipeline que las URLs. |

## Decisiones cerradas recientemente

| ID | Decisión | Fecha |
|---|---|---|
| D32 | React StrictMode descartado en frontend Tauri | 2026-05-06 |
| D31 | OCR de capturas de pantalla — visión de producto, fuera de beta | 2026-05-05 |
| D30 | Filtro de entrada por dispositivo — modo flexible (free) + modo estricto (paid) | 2026-05-05 |
| D29 | Perfiles globales de captura con horarios — paid | 2026-05-05 |
| D28 | Control granular de captura por categoría con niveles A/B/C — free | 2026-05-05 |
| D27 | Sync bidireccional de tabla syntheses vía relay + evento synthesis_generated | 2026-05-05 |
| D24 actualización | Modelo freemium consolidado añadido — 5 síntesis/mes free, paid ilimitado, beta gratuita | 2026-05-05 |
| D23 | Síntesis LLM vía proxy zero-retention — provider: Cloudflare Workers AI + Claude Haiku fallback | 2026-05-05 |
| D24 | Mobile vs Desktop: niveles de funcionalidad — puerta abierta a mobile en iteración posterior | 2026-05-05 |
| D25 | D1-ext: transmisión de títulos al proxy con consentimiento explícito | 2026-05-05 |
| D26 | T-3-005 (Ollama local) superseded por D23 | 2026-05-05 |
| D22 | Mobile standalone — Opción B (ver detalle abajo) | 2026-04-24 |
| D22 aplazamiento | Aplazada por OD-007; caso núcleo único reafirmado | 2026-04-29 |
| D9 extensión | Observer semi-pasivo Android (tier paid) via Tile de sesión | 2026-04-27 |
| D9 revisión FS Watcher | FS Watcher desktop cambia a background-persistent (abandona foreground-only) | 2026-04-28 |

### D9 — Revisión FS Watcher Desktop: Background-Persistent

**Estado:** REVISADA — aprobada por Orchestrator (2026-04-28).

**Cambio:**
El FS Watcher desktop pasa de **foreground-only** a **background-persistent**.

**Modelo anterior (TS-2-000 §2 original):**
El watcher arrancaba al recibir `Focused(true)` y se detenía (RAII drop + purga de buffer)
al recibir `Focused(false)`. La decisión original se justificó como mínimo necesario
para cumplir D9 sin observación pasiva.

**Modelo revisado:**
El watcher arranca una única vez en el primer `Focused(true)` y permanece activo mientras
el proceso de la app esté vivo, sin importar el estado de foco. No se detiene al perder
el foco. El handle se mantiene en `FsWatcherState` y solo se libera al cerrar la app.

**Motivo del cambio:**
El modelo foreground-only provocaba pérdida de eventos del sistema de ficheros cuando el
usuario cambiaba de ventana durante una sesión de trabajo (comportamiento habitual). Los
eventos de creación/renombre ocurren precisamente cuando el usuario trabaja en otras apps
(editor, terminal, explorador de ficheros), no cuando está mirando el dashboard de
FlowWeaver. El modelo foreground-only hacía que el watcher se detuviera exactamente cuando
más eventos se producen.

**Impacto en implementación:**
- `lib.rs`: `Focused(false)` ya no hace `*guard = None` ni purga el buffer.
- `lib.rs`: `Focused(true)` solo arranca el watcher si `guard.is_none()` (arranque único).
- `commands.rs`: `fs_watcher_activate_directory` y `fs_watcher_deactivate_directory` reinician
  el watcher sin condicionar la operación a que haya un handle previo.
- Commits: `ab1b192` (BUG A, FlowWeaver main, 2026-04-28).

**Restricciones que no cambian:**
- D9 sigue prohibiendo cualquier observer en background en mobile sin sesión explícita del usuario.
- La observación desktop sigue limitada a directorios activados explícitamente por el usuario.
- D1 sigue vigente: nunca se leen contenidos de fichero; solo nombre, extensión y directorio padre.
- El FS Watcher no tiene acceso a urls ni titles (D1).

---

### D9 — Extensión: Observer Semi-Pasivo Android (Tier Paid)

**Estado:** EXTENDIDA — aprobada por AR-CR-002-mobile-observer (Technical Architect,
2026-04-27) y PGR-CR-002-mobile-observer (Privacy Guardian, 2026-04-27).

**Extensión:**
Además del Share Intent (que permanece como mecanismo free), el tier paid autoriza
un segundo observer en Android basado en **Tile de sesión (Quick Settings tile)**.
El observer semi-pasivo solo está activo mientras el tile esté encendido (sesión
explícitamente iniciada por el usuario). Requiere foreground service con notificación
visible durante la sesión activa. El foreground service se termina automáticamente
al apagar el tile o al superar los timeouts de sesión mobile (`GAP_SECS = 2_700 s`,
`MAX_WINDOW_SECS = 7_200 s`). El observer NO puede funcionar en background sin que
el usuario haya activado la sesión explícitamente mediante el tile. Si el mecanismo
técnico subyacente es un Intent handler (Opción C), el handler debe registrarse
dinámicamente al activar el tile y desregistrarse al desactivarlo — nunca declarado
estáticamente en AndroidManifest sin control de activación. Opciones permanentemente
excluidas: Accessibility Service, historial del navegador, Intent handler siempre
registrado sin control de inicio/fin de sesión.

**Condiciones bloqueantes (deben cumplirse en implementación):**
- B1: pantalla de consentimiento explícito antes del primer uso del tile
- B2: handler dinámico verificable (no estático en AndroidManifest)
- B3: D1 operativo en logs y persistencia (url/title nunca en texto plano)
- B4: Privacy Dashboard mobile completo con sección específica del observer
- B5: timeout automático de sesión (default 30 min, configurable 5 min–4 h)

**Umbrales del Episode Detector mobile aprobados:**
`GAP_SECS = 2_700 s`, `MAX_WINDOW_SECS = 7_200 s`, `PRECISE_MIN = 2`,
`BROAD_MIN = 2`, `JACCARD_THRESHOLD = 0.20`. Módulo mobile separado obligatorio
— sin condicionales de plataforma en `episode_detector.rs` desktop.

**Referencia:** `operations/architecture-reviews/AR-CR-002-mobile-observer.md`,
`operations/architecture-reviews/PGR-CR-002-mobile-observer.md`.

### D22 — FlowWeaver Mobile como producto completo con tier paid

**Estado:** CERRADA — Opción B aprobada por Orchestrator (2026-04-24)

**Decisión:**  
FlowWeaver Mobile es un producto standalone completo con modelo freemium:

- **Tier Free:** captura explícita (Share Intent) + galería organizada por categoría + sync bidireccional con desktop. Lo implementado en Fase 0c.
- **Tier Paid:** detección de intención a partir del comportamiento de navegación + Pattern Detector en Android + anticipación proactiva (notificaciones contextuales) + resumen/agrupación de episodios de búsqueda.

**Qué es "workspace anticipado" en mobile (definición cerrada):**  
El usuario navega durante un período de tiempo con coherencia temática (ej: 5 URLs sobre recetas de tarta de queso en 15 minutos). FlowWeaver detecta el episodio de intención, agrupa el contenido, genera contexto y lo presenta sin que el usuario lo haya pedido. No es captura de URLs aleatorias — es inferencia de intención consistente sobre una ventana temporal.

**Implicaciones técnicas:**
- Pattern Detector, Episode Detector y Trust Scorer compilados para Android via Tauri 2 + NDK (la arquitectura ya lo permite)
- Observer semi-pasivo en Android para captura del input de navegación (D9 requiere extensión formal — ver CR-002)
- Modelo freemium: el observer pasivo y la anticipación son tier paid; la captura explícita es siempre free
- FS Watcher no aplica en mobile — el input es el comportamiento de navegación, no el filesystem

**Segmento de usuario que abre:**  
Mobile-only power user: persona que captura, investiga y consume contenido principalmente desde el teléfono y no necesita ni usa el desktop de FlowWeaver.

**Referencia:** CR-002 (observer móvil), Fase 3 (beta pública), V1 (LAN sync, features avanzadas)

---

### D22 — Aplazamiento (2026-04-29)

**Estado:** APLAZADA por OD-007.

**Motivo:** la decisión introducía una segunda hipótesis de producto (mobile
standalone) en paralelo a la hipótesis del caso núcleo (puente móvil → desktop),
sin que se hubiera validado la primera. Mantener ambas hipótesis activas
durante el MVP dispersa el esfuerzo y compromete la diferenciación
competitiva del producto.

**Qué se conserva:**
- D20 (mobile como cliente con Classifier + Grouper + SQLCipher local) sigue
  válida como infraestructura de soporte del Usuario A
- D21 (sync bidireccional) sigue válida
- la galería móvil organizada por categorías sigue funcional

**Qué queda bloqueado hasta nueva orden:**
- Pattern Detector móvil (más allá de la base técnica ya existente)
- Observer semi-pasivo Android (Tile de sesión)
- Detección de intención sobre comportamiento de navegación
- Anticipación proactiva mobile (notificaciones contextuales)
- Cualquier feature etiquetada "tier paid mobile"

**Condiciones de reactivación:** ver OD-007 §"Reactivation conditions".

**Referencia:** OD-007-defer-d22-mobile-standalone.md

---

## Regla operativa

Si un documento posterior contradice este registro y no existe una propuesta
formal aprobada, el documento posterior debe corregirse.
