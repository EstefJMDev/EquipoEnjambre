## Tarea: Bloque mobile completo — D27, D28, D29, D30 + CR-006 + actualización modelo freemium

### Contexto previo
CR-005 (síntesis desktop) cerrado y pusheado. HEAD EquipoEnjambre:
b580153. Próximo bloque: documentar el sistema mobile completo
con sus decisiones de captura granular, perfiles, filtros por
dispositivo, y modelo freemium consolidado. NO hay implementación
en este turno — solo trabajo documental.

### Decisiones de producto ya tomadas por el PO

**Sobre captura y configuración:**
- Niveles A/B/C de captura por categoría: A=no capturar (destructivo,
  con aviso), B=capturar pero quedar pendiente, C=capturar silenciosa
  (sin notificación ni síntesis automática). Por defecto todas las
  categorías están en captura normal con procesamiento completo.
  El usuario elige el nivel desde Configuración → Captura.
- Perfiles globales con horarios (Trabajo, Fin de semana, Vacaciones,
  etc.). El usuario crea perfiles que definen qué categorías están
  activas. Asigna horarios o días a cada perfil. El sistema aplica
  el perfil activo según fecha/hora actual. Decisión global,
  sincronizada entre dispositivos.
- Filtro de entrada por dispositivo con dos modos: ESTRICTO
  (los eventos de categorías bloqueadas se descartan a la entrada,
  no entran al SQLCipher local) y FLEXIBLE (los eventos se guardan
  pero quedan ocultos en la vista; al cambiar el filtro reaparecen).
  Decisión por dispositivo, no global.

**Sobre sincronización:**
- Sync bidireccional explícita de tabla syntheses (no solo resources).
- Mobile que genera síntesis las sube al relay; desktop las recibe
  y viceversa. La infraestructura del relay ya soporta esto;
  solo se extiende el schema de eventos para incluir
  synthesis_generated.

**Sobre modelo freemium consolidado (afecta D24, D25, y todo el sistema):**

Free:
- Captura ilimitada (en cualquier dispositivo)
- Listados y agrupaciones básicas sin LLM (plantillas locales) —
  ilimitado
- Síntesis con LLM enriquecida — 5 al mes con reset mensual
- D28 (control por categoría con niveles A/B/C) — sí, free.
  Es control de privacidad básico.
- D30 modo flexible (filtro por dispositivo simple) — sí, free.
- Mobile y desktop, ambos completos para tier free con sus límites
  comunes.

Paid:
- Síntesis LLM ilimitadas (en cualquier dispositivo)
- D29 (perfiles globales con horarios) — paid
- D30 modo estricto (descarte a la entrada) — paid
- Funcionalidades avanzadas futuras (modo pregunta, conexiones
  entre episodios, OCR de capturas) — paid

Precio: TBD post-beta con datos reales. NO documentar precio
exacto. Beta cerrada es completamente gratuita para todos los
testers.

**Sobre prioridad de implementación:**
- Desktop primero (CR-005 ya documentado, T-3-007 a T-3-013).
- Mobile en iteración inmediatamente posterior usando el mismo
  proxy. CR-006 documenta mobile pero implementación viene
  después de cerrar desktop.

**Sobre captura de pantalla con OCR:**
- Dentro de la visión del producto (D31, ver bloque).
- Fuera de beta. Documentar como dirección de producto, no
  implementar todavía.

### Archivos de referencia obligatoria
- Project-docs/decisions-log.md (D1, D4, D8, D14, D19, D20-D26)
- Project-docs/scope-boundaries.md (excepción backend ya añadida)
- Project-docs/vision.md
- Project-docs/phase-definition.md
- operations/backlogs/backlog-phase-3.md (T-3-007 a T-3-013)
- operations/change-requests/CR-005-llm-synthesis-backend.md
- operations/architecture-reviews/AR-CR-005-llm-synthesis.md
- operations/architecture-reviews/PGR-CR-005-llm-synthesis.md
- operating-system/change-control.md
- operating-system/templates/change-request-template.md

---

## BLOQUE F — Decisiones nuevas D27-D31

### PASO F.1 — Orchestrador: añadir D27, D28, D29, D30, D31

Actualizar `Project-docs/decisions-log.md` siguiendo el formato
de tabla existente. Añadir las cinco decisiones tras D26.

**D27 — Sincronización bidireccional explícita de recursos y síntesis**

Decisión: La tabla syntheses se sincroniza vía relay igual que la
tabla resources. Cualquier dispositivo (mobile o desktop) que genere
una síntesis la sube al relay; los demás dispositivos del usuario la
reciben. La infraestructura del relay ya soporta sync bidireccional
(verificado: drive_relay.rs línea 302 hace upload, línea 336 lee).
La extensión consiste en añadir tipo de evento "synthesis_generated"
al schema RawEvent además del actual "resource_captured". El payload
del evento incluye: anchor_key (pattern_id o session_hash), category,
synthesis_type, content_encrypted, generated_at, source_device_id.
La conciliación local descifra y persiste en la tabla syntheses
del SQLCipher receptor.

Justificación: Las síntesis tienen valor en cualquier dispositivo
del usuario. Si las genero en mobile mientras voy en transporte,
quiero verlas en desktop al llegar a casa. La infraestructura
existe — solo falta extender el schema. Sin esto, el desktop
y el mobile son silos parciales.

**D28 — Control granular de captura por categoría con tres niveles**

Decisión: El usuario configura por categoría qué nivel de captura
quiere, con tres niveles disponibles desde Configuración → Captura
→ Por categoría:
- Nivel A "No capturar": cualquier intento de compartir un recurso
  de esa categoría se ignora silenciosamente. Destructivo —
  el dato se pierde. Aviso explícito al activar.
- Nivel B "Capturar pendiente": el recurso se captura pero queda
  en un estado pendiente. No se procesa, no genera síntesis,
  no aparece en listados regulares. El usuario puede revisar
  pendientes desde Configuración → Captura → Pendientes.
- Nivel C "Capturar silenciosa" (por defecto cuando se desactiva
  una categoría con el toggle simple): el recurso se captura
  y procesa normalmente, pero no genera notificaciones proactivas
  ni síntesis automáticas. Aparece en listados solo cuando el
  usuario los abre explícitamente.
- Captura normal: todas las categorías están en este modo por
  defecto. El recurso se captura, procesa, genera síntesis cuando
  hay material suficiente, y notifica al usuario.

El usuario puede elegir nivel granular por categoría. El toggle
simple de la categoría en Configuración aplica Nivel C por
defecto al desactivar; el usuario puede ir a "Avanzado" y cambiar
a A o B si quiere control más fino. La configuración es global,
sincronizada entre dispositivos.

Justificación: Privacy-first práctico llevado al uso cotidiano,
no solo al onboarding. Reducción de ruido en síntesis y
notificaciones. Ahorro de cuota freemium para el usuario que
no quiere síntesis de categorías que no le interesan en este
momento. Es feature free porque es control de privacidad básico.

**D29 — Perfiles globales de captura con horarios (PAID)**

Decisión: El usuario puede crear perfiles de captura desde
Configuración → Perfiles. Cada perfil tiene un nombre
(ej. "Trabajo", "Fin de semana", "Vacaciones") y configura
qué categorías están activas en ese perfil. Asigna horarios
o días al perfil (ej. lunes-viernes 9-18h, fines de semana,
vacaciones manualmente). El sistema aplica el perfil activo
según fecha/hora actual. Si dos perfiles solapan, el más
específico tiene prioridad (vacaciones > fin de semana > trabajo).
Si ningún perfil aplica, el comportamiento es "todo activo"
(captura normal de todas las categorías).

Esta funcionalidad es PAID. El usuario free tiene D28 (control
por categoría con niveles A/B/C) que cubre el caso simple.
Los perfiles son la versión avanzada para usuarios que quieren
control temporal.

Justificación: Casos de uso reales del estudio de usuarios
("solo lo uso para trabajar", "no quiero capturar nada de social
los fines de semana"). Funcionalidad de control avanzado que
justifica paid sin ser mezquino — el usuario free ya tiene control
suficiente vía D28.

**D30 — Filtro de entrada por dispositivo con dos modos**

Decisión: Cada dispositivo configura desde Configuración →
Sincronización → Filtro qué categorías acepta del relay
sincronizado. El filtro tiene dos modos seleccionables por
el usuario:

- Modo FLEXIBLE (free): los eventos de categorías bloqueadas
  llegan al SQLCipher local pero quedan ocultos en la vista.
  Si el usuario relaja el filtro, los eventos antiguos
  reaparecen sin pérdida.
- Modo ESTRICTO (paid): los eventos de categorías bloqueadas
  se descartan a la entrada, no entran al SQLCipher local.
  Para máxima separación de contextos personal/trabajo entre
  dispositivos del mismo usuario.

Ambos modos son configuración por dispositivo, no global.
Mi mobile puede tener filtro distinto que mi desktop.

Justificación: Casos de uso del estudio ("desktop solo para
trabajo, no quiero ver datos personales"). El modo flexible
respeta los datos del usuario (no destructivo, reversible).
El modo estricto está en paid porque la garantía de no-entrada
es valor adicional para usuarios que necesitan separación
fuerte entre contextos.

**D31 — Captura de imágenes con OCR (visión, fuera de beta)**

Decisión: FlowWeaver Mobile incluirá en futuras iteraciones la
capacidad de aceptar capturas de pantalla del rollo de cámara
y aplicar OCR para extraer texto, dominios y URLs presentes
en la imagen. La imagen original se procesa localmente, se
extraen los datos relevantes (texto, URLs detectadas, dominios
visibles), y la imagen se descarta sin persistirse — solo se
guarda lo extraído. El comportamiento es coherente con D1-ext
(D25): se procesa localmente, se transmiten al proxy solo
campos textuales como cualquier otra captura.

Esta funcionalidad NO se implementa en beta. Se documenta
como dirección explícita del producto para que el enjambre
no la trate como contaminación de scope cuando llegue su
momento. Implementación post-validación de PMF con captura
de URLs.

Justificación: El estudio de usuarios mostró que "la gente
hace pantallazos" como mecanismo paralelo a compartir URLs.
Capturar pantallazos amplía dramáticamente el alcance del
producto sin romper la arquitectura — se procesan localmente
y entran al mismo pipeline que las URLs.

### PASO F.2 — Orchestrador: actualizar D24 (modelo freemium)

D24 quedó redactada en CR-005 con la formulación abierta a mobile.
Ahora se completa con el modelo freemium consolidado. Editar la
celda "Decisión" de D24 en decisions-log.md añadiendo al final
del texto actual:

"Modelo freemium consolidado: ambos dispositivos (mobile y
desktop) son completamente accesibles en tier free con los
mismos límites — captura ilimitada, listados básicos sin LLM
ilimitados, síntesis LLM enriquecida limitada a 5 al mes con
reset mensual. Funcionalidades paid (perfiles D29, modo estricto
de D30, síntesis ilimitadas, funcionalidades avanzadas futuras)
disponibles en cualquier dispositivo. El precio del tier paid
se decide post-beta con datos reales — durante la beta cerrada
todo es gratuito."

---

## BLOQUE G — Cadena formal CR-006

### PASO G.1 — Functional Analyst: emitir CR-006

Crear `operations/change-requests/CR-006-mobile-autonomous-client.md`
siguiendo la plantilla de change-control.md.

**request_id:** CR-006
**owner_agent:** Functional Analyst
**change_type:** Producto + arquitectura (mobile escalado a cliente
autónomo)
**date:** 2026-05-05

**Proposed Change:**
Convertir FlowWeaver Mobile de cliente companion (captura + lectura
de síntesis) a cliente autónomo de captura → agrupación → síntesis
proactiva, dirigido al usuario móvil-only de 25-45 años que actualmente
usa Instagram saved y WhatsApp consigo mismo como sistema de gestión
de intención.

Componentes nuevos en mobile (Kotlin/Android):

1. **Vista principal agrupada por intención**: la pantalla de inicio
   muestra los recursos agrupados por categoría con badges de
   "X nuevos", no una lista cronológica. Reemplaza el comportamiento
   actual.

2. **Sistema de síntesis proactiva con badge silencioso**: cuando
   el sistema detecta que hay material suficiente para una síntesis
   (≥3 recursos del mismo episodio), genera la síntesis y muestra
   un badge en la app. Sin notificación push agresiva. El usuario
   entra a la app cuando tiene tiempo y la lee.

3. **Botón manual "Generar ahora"** disponible siempre en cualquier
   episodio detectado. Permite al usuario solicitar síntesis bajo
   demanda sin esperar al trigger automático.

4. **Cliente del proxy en mobile (Kotlin)**: equivalente al
   synthesis_engine de Rust pero en Kotlin. Construye el mismo
   payload {category, titles, domains, synthesis_type, language},
   llama al proxy con install_token, parsea streaming SSE, persiste
   resultado cifrado en SQLCipher mobile vinculado al pattern_id
   o session_hash.

5. **Renderizador Markdown mobile**: equivalente al SynthesisView
   de React pero con un componente Compose o WebView mobile.
   Streaming progresivo + botones "Copiar" y "Compartir".

6. **Plantillas locales para listados básicos sin LLM**: extensión
   de templates.kt con las 25 categorías. Listados, agrupaciones
   y ordenaciones generados localmente sin llamar al proxy. Esto
   es la funcionalidad gratis ilimitada base.

7. **Privacy Dashboard mobile** con sección síntesis equivalente
   a la del desktop, adaptada a UI mobile. Incluye toggle de
   activación, contador de uso del mes, descripción exacta de
   transmisión.

8. **Diálogo de consentimiento mobile (D25)** equivalente al
   desktop pero con UX mobile. Versionado del aviso para
   invalidación futura.

9. **Configuración → Captura**: UI para configurar D28 (niveles
   A/B/C por categoría) con toggle simple + avanzado.

10. **Configuración → Perfiles (PAID)**: UI para crear perfiles
    D29 con horarios. Solo accesible para usuarios paid. Visible
    para free pero con call-to-action "Activar paid para usar
    perfiles".

11. **Configuración → Sincronización → Filtro (D30)**: UI para
    configurar qué categorías acepta el dispositivo del relay.
    Modo flexible (free) + modo estricto (paid) seleccionables.

12. **Sync bidireccional de tabla syntheses (D27)**: extensión
    del schema RawEvent para incluir synthesis_generated.
    Mobile sube síntesis generadas; desktop las recibe y viceversa.

13. **Rate limiting freemium en cliente mobile**: contador local
    de síntesis del mes; al llegar a 5, deshabilitar botones
    de generación con mensaje explicativo.

**Why It Is Needed:**
El estudio de usuarios mostró que el mercado mayoritario es
usuario móvil-only de 25-45 años que captura compulsivamente y
pierde el material en Instagram saved, WhatsApp consigo mismo, y
capturas de pantalla. La hipótesis "el desktop es el cerebro,
mobile es companion" resultó incorrecta para el segmento mayoritario.
Mobile como cliente autónomo es un producto entero, no una feature.

**Problem It Solves:**
- El usuario móvil-only tiene un producto útil sin necesitar desktop.
- La captura compulsiva se convierte en valor accionable
  (síntesis automática proactiva) sin trabajo manual.
- El usuario que también tiene desktop ve sincronizado todo
  el material entre dispositivos sin esfuerzo.
- El control granular (D28, D29, D30) le da al usuario poder
  real sobre qué se captura y qué se procesa.

**Affected Documents:**
- Project-docs/decisions-log.md (D27, D28, D29, D30, D31 ya
  añadidas en Bloque F; D24 ya actualizada)
- Project-docs/scope-boundaries.md (mobile como cliente autónomo
  es ampliación coherente, no nueva excepción)
- Project-docs/roadmap.md (actualizar Fase 3 con bloque mobile)
- operations/backlogs/backlog-phase-3.md (nuevas tareas
  T-3-014 a T-3-026)
- src-tauri/src/raw_event.rs (extender schema con synthesis_generated)
- ShareIntentActivity.kt + nuevos componentes Kotlin/Compose
- flowweaver-proxy: SIN cambios (la arquitectura del proxy
  es agnóstica de plataforma)

**Phase Impact:**
Todo dentro de Fase 3. T-3-014 a T-3-026 se añaden al backlog
con dependencia EXPLÍCITA de cierre formal de T-3-007 a T-3-013
(desktop). NO se implementa mobile hasta que desktop esté validado.

**Architectural Impact:**
- Mobile pasa de cliente reactivo (Share Intent + sync) a cliente
  con lógica de procesamiento (Episode Detector mobile, generación
  de síntesis, gestión de perfiles).
- Schema RawEvent extiende con synthesis_generated.
- Tabla syntheses replicada en SQLCipher mobile.
- Sync bidireccional verificada y operativa para nuevo tipo
  de evento.
- El proxy backend NO cambia — sirve a ambos clientes con el
  mismo contrato.

**Scope Creep Risk:**
ALTO. El catálogo de funcionalidades mobile es extenso. Este CR
acota explícitamente:

INCLUIDO en Fase 3 mobile:
- Vista agrupada por intención
- Síntesis proactiva con badge + botón manual
- Cliente del proxy mobile
- Renderizador Markdown mobile
- 4 tipos de síntesis (mismos que desktop: entretenimiento, cocina,
  noticias, tecnología)
- Plantillas locales sin LLM para 25 categorías
- Privacy Dashboard mobile
- Diálogo de consentimiento mobile
- Configuración D28 (niveles A/B/C)
- Configuración D29 (perfiles paid)
- Configuración D30 (filtro por dispositivo)
- Sync bidireccional D27
- Rate limiting freemium

EXCLUIDO de Fase 3 mobile (diferido a Fase 4 o post-validación):
- OCR de capturas de pantalla (D31)
- Modo pregunta / chat mobile
- Conexiones entre episodios mobile
- Tipos de síntesis adicionales (finanzas, salud, viajes, etc.)
- Notificaciones push agresivas (mantener solo badge silencioso)
- Widgets de pantalla de inicio
- Wearables / Apple Watch / Wear OS
- Beta abierta con email + OTP

**Alternatives Rejected:**
- Mobile solo lectura de síntesis desktop: insuficiente para
  el usuario mobile-only que no usa desktop. Desautoriza el
  estudio de usuarios.
- Notificaciones push agresivas: violan el principio de "preparar
  sin interrumpir". Badge silencioso es coherente con la
  visión de anticipación no-invasiva.
- Mobile con LLM local: mismas razones que descartaron Ollama
  en desktop (D26). Mobile tiene aún menos recursos.
- Funcionalidades duplicadas en desktop y mobile: el proxy es
  agnóstico, los clientes son distintos. La duplicación de
  lógica de cliente es aceptable porque las plataformas son
  intrínsecamente distintas.

**Recommendation:**
Aprobar para implementación en Fase 3 con la dependencia explícita:
T-3-014 a T-3-026 BLOQUEADAS hasta cierre formal de T-3-007 a
T-3-013 (desktop validado en beta). El Technical Architect emitirá
las TS individuales tras la aprobación.

**Required Reviewers:**
- Technical Architect (extensión schema, cliente mobile, sync
  bidireccional)
- Privacy Guardian (D25 en mobile, control granular D28-D30,
  consentimiento mobile)
- Phase Guardian (scope Fase 3, dependencia con desktop)

**Final Decision:** PENDIENTE — Orchestrador post-revisión

### PASO G.2 — Technical Architect: AR-CR-006

Crear `operations/architecture-reviews/AR-CR-006-mobile-autonomous.md`

Evaluar y resolver:

1. **Extensión RawEvent**: definir el schema exacto del evento
   synthesis_generated con sus campos. Compatibilidad hacia atrás
   con clientes que aún no entienden este tipo (deben ignorarlo
   sin error).

2. **Cliente Kotlin del proxy**: contrato del cliente mobile
   equivalente al de Rust. Streaming SSE en Android usa qué
   librería (OkHttp, Retrofit). Manejo de errores y retry.

3. **Schema syntheses replicado en mobile**: validar que la
   estructura es idéntica al desktop. Anchor key (pattern_id
   o session_hash) usado igual.

4. **Pattern Detector en mobile**: ¿se ejecuta? ¿es Episode Detector
   lo que basta para mobile? Decidir explícitamente. Recomendación:
   solo Episode Detector en mobile, Pattern Detector longitudinal
   solo en desktop por simplicidad y coste de cómputo.

5. **Configuración (D28, D29, D30) persistencia**: cómo se almacena,
   cómo se sincroniza vía relay (¿se sincroniza?).

6. **Rate limiting cliente vs servidor**: el contador local mobile
   debe coincidir con el contador del proxy. ¿Se confía en el
   cliente o el proxy es la fuente de verdad? (Recomendación:
   proxy es source of truth, cliente lee periódicamente.)

7. **Criterios de aceptación por cada T-3-014 a T-3-026.**

### PASO G.3 — Privacy Guardian: PGR-CR-006

Crear `operations/architecture-reviews/PGR-CR-006-mobile-autonomous.md`

Verificar y declarar:

1. **D25 en mobile**: el payload mobile cumple las mismas
   restricciones que el desktop. Verificar en código tras
   implementación.

2. **D28 niveles A/B/C**: documentar exactamente qué pasa con
   los datos en cada nivel. Nivel A es destructivo y debe avisar
   explícitamente al usuario.

3. **D30 modo estricto vs flexible**: en modo flexible los datos
   bloqueados están ocultos pero presentes en BD. ¿Implicaciones
   GDPR? El usuario debe poder ver TODOS sus datos (incluso los
   ocultos por filtro) si solicita acceso. Documentar mecanismo.

4. **Diálogo de consentimiento mobile**: redacción exacta y
   mecanismo de versionado. Referencia explícita al diálogo
   desktop (PGR-CR-005 §6) para coherencia.

5. **Sync bidireccional de syntheses**: las síntesis cifradas
   en BD viajan cifradas por el relay. Verificar que el
   cifrado es correcto.

6. **Configuración sincronizada vía relay**: ¿es necesario
   sincronizar D28 y D29 entre dispositivos? Si sí, son datos
   personales y deben estar cifrados.

7. **Captura silenciosa (Nivel C)**: documentar exactamente qué
   significa. El usuario debe poder ver listados de capturas
   silenciosas si lo pide.

### PASO G.4 — Orchestrador: HO-031 con aprobación

Crear `operations/handoffs/HO-031-cr-006-mobile-autonomous-approval.md`

Si AR y PGR aprueban: declarar CR-006 aprobado, activar Functional
Analyst para actualizar backlog-phase-3.md.

---

## BLOQUE H — Actualizar backlog Fase 3

### PASO H.1 — Functional Analyst: actualizar backlog-phase-3.md

Editar `operations/backlogs/backlog-phase-3.md`:

**Añadir tareas nuevas T-3-014 a T-3-026:**

T-3-014 — Schema RawEvent con synthesis_generated
- Extender raw_event.rs en src-tauri y schema equivalente en
  Kotlin. Compatibilidad hacia atrás.
- Dependencias: T-3-007 (proxy) cerrado.

T-3-015 — Cliente Kotlin del proxy
- Equivalente Kotlin del synthesis_engine.rs. Streaming SSE.
- Dependencias: T-3-007, T-3-014.

T-3-016 — Schema syntheses replicado en mobile
- Tabla SQLCipher mobile con la misma estructura del desktop.
- Dependencias: T-3-014.

T-3-017 — Plantillas locales mobile (25 categorías)
- Equivalente Kotlin de templates.ts con plantillas para las
  25 categorías del Classifier.
- Sin dependencia de proxy.

T-3-018 — Vista agrupada por intención (mobile)
- Pantalla principal con recursos agrupados por categoría +
  badges. Reemplaza vista cronológica.
- Dependencias: T-3-016, T-3-017.

T-3-019 — Sistema de síntesis proactiva con badge
- Detector de "material suficiente" + trigger automático +
  badge silencioso en la app.
- Dependencias: T-3-015, T-3-016.

T-3-020 — Botón manual "Generar ahora"
- Acción explícita de síntesis bajo demanda.
- Dependencias: T-3-015.

T-3-021 — Renderizador Markdown mobile + exportación
- Componente Compose o WebView para renderizar Markdown streaming.
  Botones Copiar y Compartir.
- Dependencias: T-3-015.

T-3-022 — Privacy Dashboard mobile
- Sección síntesis con toggle, contador, descripción.
- Dependencias: T-3-015, cierre formal T-2-004.

T-3-023 — Diálogo de consentimiento mobile (D25)
- Modal informado equivalente al desktop con versionado.
- Dependencias: T-3-022.

T-3-024 — Configuración D28 (control por categoría)
- UI mobile para niveles A/B/C por categoría. Toggle simple
  + avanzado.
- Sin dependencia de proxy.

T-3-025 — Configuración D29 (perfiles paid)
- UI mobile para crear perfiles con horarios. Solo paid.
- Dependencias: T-3-024 (UI base de configuración).

T-3-026 — Configuración D30 (filtro por dispositivo)
- UI mobile para filtro de entrada. Modo flexible (free)
  + modo estricto (paid).
- Sin dependencia de proxy.

T-3-027 — Sync bidireccional de syntheses + configuración
- Implementación efectiva del sync bidireccional D27.
  Configuración D29 sincronizada (global), configuración D30
  no sincronizada (local por dispositivo).
- Dependencias: T-3-014, T-3-016.

T-3-028 — Rate limiting freemium mobile
- Contador local + sincronización con proxy. UI de "5/5 síntesis
  usadas este mes".
- Dependencias: T-3-015, T-3-007 (proxy con rate limit
  ya operativo).

**Dependencia GLOBAL bloqueante:**
T-3-014 a T-3-028 BLOQUEADAS hasta cierre formal de Fase 3
desktop (todas T-3-007 a T-3-013 con TS firmadas, implementadas,
y validadas en beta cerrada desktop).

---

## Restricciones del proceso

- Bloques F, G, H son SECUENCIALES. NO empezar G antes de cerrar F.
  NO empezar H antes de cerrar G.
- Bloques F, G, H son EXCLUSIVAMENTE documentales en EquipoEnjambre.
  Ninguna implementación en FlowWeaver en este turno.
- Las tareas T-3-014 a T-3-028 quedan en backlog BLOQUEADAS.
  No se emiten TS individuales en este turno — eso vendrá después
  de validar desktop.
- Cualquier ambigüedad en las decisiones se resuelve consultando
  al PO, NO inventando.

## Orden de ejecución y commits

Bloque F:
1. EquipoEnjambre: `docs(decisions-log): D27, D28, D29, D30, D31
   + actualización D24 modelo freemium`

Bloque G:
2. EquipoEnjambre: `docs(CR-006): mobile como cliente autónomo`
3. EquipoEnjambre: `docs(AR-CR-006): technical architect review`
4. EquipoEnjambre: `docs(PGR-CR-006): privacy guardian review`
5. EquipoEnjambre: `docs(HO-031): orchestrador aprueba CR-006`

Bloque H:
6. EquipoEnjambre: `docs(backlog-phase-3): T-3-014 a T-3-028 mobile
   bloqueadas hasta cierre desktop`

Total: 6 commits documentales en EquipoEnjambre. NO commits en
FlowWeaver.

## Verificación post-bloques
- En EquipoEnjambre: enlaces internos entre documentos resuelven.
- D27, D28, D29, D30, D31 tienen formato de tabla coherente con
  decisiones existentes.
- D24 actualizada SIN romper la formulación abierta a mobile
  que ya tenía.
- Backlog refleja claramente bloqueo de mobile hasta desktop.

Confirmar al final cuántos commits se produjeron y el HEAD de
EquipoEnjambre.