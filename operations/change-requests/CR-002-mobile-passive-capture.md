# Change Request

request_id: CR-002
owner_agent: Orchestrator
change_type: Extensión de capacidad de captura — nuevo observer activo en Android
date: 2026-04-24
status: PENDIENTE DE DECISIÓN — requiere aprobación del Orchestrator
triggered_by: Product owner — el usuario quiere que la app Android detecte y agrupe
              automáticamente los enlaces que navega, no solo los que comparte explícitamente
priority: MEDIA — no bloquea beta; requiere análisis profundo antes de implementar

---

## Proposed Change

Añadir a la app Android una capacidad de captura **pasiva o semi-pasiva**: detectar
automáticamente las URLs que el usuario visita en el navegador móvil y procesarlas
con el mismo pipeline (Classifier → Grouper → galería) que las capturas explícitas.

El usuario dejaría de necesitar la acción de "Compartir → FlowWeaver" para cada
enlace. FlowWeaver observaría su actividad de navegación y organizaría el contenido
de forma automática, igual que el FS Watcher hace en desktop con las apps abiertas.

---

## Why It Is Needed

El product owner identifica que el Share Intent tiene rozamiento real:

> "El usuario navega 10 links en el metro. Compartir cada uno a FlowWeaver es
> un gesto que no se repite. Queremos que la app lo recoja sola, igual que en
> el desktop."

La propuesta de valor del producto es "prepararte el workspace antes de que lo pidas".
En desktop, el FS Watcher observa pasivamente qué apps y contenidos usa el usuario
para construir el contexto. En móvil, el equivalente sería observar qué URLs navega.

---

## Problem It Solves

**Rozamiento de captura explícita (alta frecuencia):**
El Share Intent requiere que el usuario interrumpa su lectura para compartir. En
contextos de consumo rápido (redes sociales, artículos, vídeos) ese gesto no se
produce — el usuario sigue navegando y el contenido no se captura.

**Gap respecto al desktop:**
El FS Watcher de Fase 2 desktop observará pasivamente el contexto del usuario. Sin
un equivalente móvil, la captura en Android sigue dependiendo del usuario, mientras
que en desktop ocurre sola. Esta asimetría debilita la propuesta unificada del producto.

---

## Conflicto Directo con D9

**D9 (DECISIÓN CERRADA) dice:**

> "FS Watcher es el único módulo de observación activa en Fase 2. No hay observer
> activo fuera del Share Intent en el MVP. Requiere delimitación formal antes
> de implementar."

La captura pasiva en Android ES un observer activo. Cualquier implementación
técnica de esta funcionalidad — sin excepción — viola D9 en su formulación actual.

D9 no puede ignorarse. Puede extenderse o reinterpretarse, pero solo mediante
decisión formal del Orchestrator con revisión del Privacy Guardian y el Technical
Architect. Este CR es ese proceso formal.

---

## Opciones Técnicas y Sus Tradeoffs de Privacidad

Las formas de implementar captura pasiva en Android, ordenadas de más a menos invasiva:

### Opción A — Accessibility Service

**Mecanismo:** Android Accessibility Service puede leer el contenido de la pantalla
de cualquier app, incluyendo la barra de URLs del navegador.

**Coste técnico:** moderado. Requiere permiso de accesibilidad; el usuario debe
activarlo manualmente en Configuración → Accesibilidad.

**Riesgo de privacidad: ALTO.**
- Lee TODO lo que hay en pantalla, no solo URLs (contraseñas, mensajes, datos bancarios)
- Google Play rechaza apps que usan Accessibility para fines no declarados
- Usuarios técnicos reconocen este permiso como una "bandera roja"
- Inconsistente con el posicionamiento de privacidad de FlowWeaver

**Veredicto Privacy Guardian anticipado:** RECHAZADO. Incompatible con D1 y con la
promesa de privacidad del producto.

---

### Opción B — Historial del navegador (READ_HISTORY_BOOKMARKS)

**Mecanismo:** permiso de Android para leer el historial de Chrome/Firefox.

**Coste técnico:** bajo. La API existe.

**Riesgo de privacidad: ALTO.**
- Permiso deprecado en Android 10+ (API 29). No disponible en dispositivos modernos.
- Lee el historial completo, no solo las sesiones activas.
- Inconsistente con D1 (historial completo incluye URLs sensibles sin consentimiento
  granular del usuario).

**Veredicto:** RECHAZADO. No viable técnicamente en Android moderno.

---

### Opción C — Intent interception / Trusted Web Activity

**Mecanismo:** registrarse como handler de ciertos tipos de Intent
(android.intent.action.VIEW / http / https). El SO ofrece al usuario elegir qué
app abre los links. FlowWeaver puede capturar el Intent, registrarlo, y luego
delegar al navegador preferido del usuario.

**Coste técnico:** moderado. Requiere que el usuario elija FlowWeaver como handler
por defecto (no automático).

**Riesgo de privacidad: BAJO-MEDIO.**
- Solo captura los links que el usuario abre activamente (semi-pasivo, no pasivo puro)
- El usuario está en control: eligió FlowWeaver como intermediario
- Introduce latencia en la apertura de links (FlowWeaver procesa antes de delegar)

**Viabilidad:** técnicamente posible. Experiencia de usuario: potencialmente
disruptiva si hay latencia visible.

---

### Opción D — Extensión de navegador (Chrome Custom Tab + Share API)

**Mecanismo:** en lugar de un observer de sistema, crear una extensión de Chrome
para Android que comparte automáticamente la URL activa a FlowWeaver cuando el
usuario permanece en una página > N segundos.

**Coste técnico:** alto. Requiere desarrollar una extensión de Chrome independiente
(Manifest V3) + API de comunicación entre la extensión y FlowWeaver.

**Riesgo de privacidad: MEDIO.**
- Solo opera dentro del navegador; no lee otras apps
- El umbral de tiempo es configurable (ej: 30s = intención de leer)
- Requiere que el usuario instale la extensión manualmente

**Viabilidad:** técnicamente correcto. Complejidad de distribución alta.

---

### Opción E — Captura semi-pasiva via notificaciones del sistema

**Mecanismo:** cuando el usuario copia una URL al portapapeles, o cuando el SO
detecta que hay una URL en el portapapeles (ClipboardManager), FlowWeaver muestra
una notificación discreta "¿Guardar este enlace en FlowWeaver?". El usuario confirma
con un tap.

**Coste técnico:** bajo. ClipboardManager está disponible; no requiere permisos
especiales en Android 12+.

**Riesgo de privacidad: BAJO.**
- Solo actúa sobre URLs que el usuario copia explícitamente
- El usuario confirma antes de que se guarde (semi-pasivo, no automático)
- No lee apps ni historial
- Compatible con D9 (extensión minimal del Share Intent)

**Viabilidad:** técnicamente simple. Experiencia de usuario: discreta y controlada.
Caveat: solo captura URLs copiadas, no todas las navegadas.

---

## Análisis de Alineación con la Visión del Producto

La visión de FlowWeaver es **privacidad verificable + anticipación del workspace**.
El posicionamiento actual es "solo datos explícitos del usuario, procesados localmente".

La captura pasiva implícita (Opciones A y B) **contradice el posicionamiento de
privacidad** y generaría rechazo en el segmento de usuarios que FlowWeaver atrae
(usuarios conscientes de privacidad, profesionales de tecnología).

La captura semi-pasiva controlada (Opciones C y E) **es coherente con el
posicionamiento** si se comunica claramente y el usuario tiene control.

**La pregunta real del product owner no es "observar sin que el usuario lo sepa"
sino "reducir el rozamiento de captura"**. Las opciones C y E logran eso sin
comprometer la propuesta de privacidad.

---

## Phase Impact

### Fases 0a/0b/0c/1/2 (en progreso o completadas)

**Impacto: NINGUNO.** Este CR no modifica nada de lo ya implementado ni de las
fases activas. D9 sigue vigente hasta que el Orchestrator decida.

### Fase propuesta para este CR

Dependiendo de la opción elegida:

- **Opción E (portapapeles):** podría entrar en **Fase 2 o 3** como extensión
  minimal del Share Intent. Requiere delimitación formal (nuevo sub-task de D9).
- **Opción C (Intent handler):** candidata a **Fase 3** (post-beta). Requiere
  análisis de UX, latencia y consentimiento del usuario.
- **Opciones A y B:** no recomendadas. No deben entrar en ninguna fase.
- **Opción D (extensión Chrome):** candidata a **V1**. Fuera del scope del MVP.

---

## Affected Decisions

| Decisión | Impacto |
| --- | --- |
| D9 — Sin observer activo fuera del Share Intent | **REQUIERE EXTENSIÓN FORMAL** si se aprueba cualquier opción. El texto actual prohíbe explícitamente cualquier observer activo en Android. La extensión debe especificar qué mecanismo está permitido y bajo qué condiciones. |
| D1 — url/title siempre cifrados | Compatible con todas las opciones salvo A (Accessibility lee en claro). |
| D19 — Android + Windows primario | Compatible. |

---

## Alternatives Rejected

### "Implementar Accessibility Service para máxima captura"

Rechazada. Incompatible con D1, con el posicionamiento de privacidad y con las
políticas de Google Play. No debe considerarse.

### "Esperar a que el usuario comparta manualmente siempre"

Rechazada como postura permanente. El rozamiento de captura explícita es real y
reduce el valor del producto en contextos de uso móvil intenso.

### "Portar FS Watcher a Android"

Rechazada. El FS Watcher en Android no tiene equivalente semántico: el SO Android
no expone información de qué app está en primer plano de la misma forma que
Windows. Las APIs equivalentes en Android requieren permisos de Accessibility
(ver Opción A, rechazada).

---

## Recommendation

**Aprobar como CR condicionado: iniciar con Opción E (portapapeles) en Fase 3.**

**Rationale:**

1. La Opción E es la única que reduce rozamiento sin comprometer privacidad ni
   violar D9 en su espíritu (captura controlada por el usuario).
2. Implementarla antes de beta pública (Fase 3) la convierte en un diferencial
   de experiencia de captura.
3. La Opción C (Intent handler) puede evaluarse en paralelo en Fase 3 como
   alternativa complementaria o sustituta si la UX de portapapeles resulta
   insuficiente.
4. Las opciones A y B no deben implementarse nunca bajo la propuesta de valor
   actual del producto.

**Condiciones:**

1. El Privacy Guardian valida que la Opción E es compatible con D9 extendido.
2. El Technical Architect delimita el alcance exacto (¿qué URLs se capturan?
   ¿con qué umbral de confirmación?) antes de ninguna implementación.
3. D9 se actualiza para declarar explícitamente qué observers pasivos/semi-pasivos
   están permitidos en Android (Share Intent + [Opción elegida]).
4. La galería Android (Fase 0c) continúa siendo el receptor de estas capturas —
   no se introduce nuevo almacenamiento ni nueva capa de procesamiento.

---

## Required Reviewers

| Agente | Rol | Obligatorio |
| --- | --- | --- |
| Orchestrator | Aprueba o rechaza; decide opción técnica y fase | ✅ |
| Privacy Guardian | Valida compatibilidad de la opción elegida con D9, D1 y posicionamiento de privacidad | ✅ |
| Technical Architect | Delimita viabilidad técnica de Opción C y E; redacta extensión de D9 | ✅ |
| Phase Guardian | Verifica que la opción elegida no contamina las fases activas | ✅ |
| Android Share Intent Specialist | Evalúa implementación técnica de la opción elegida en Android | ✅ (técnico) |

---

## Final Decision

status: PENDIENTE
decision_by: —
date_decided: —
outcome: —
