# Change Request

request_id: CR-001
owner_agent: Orchestrator
change_type: Producto restringido
date: 2026-04-24
status: PENDIENTE DE DECISIÓN — requiere aprobación del Orchestrator
triggered_by: Product owner — solicitud explícita de que el producto tenga valor en móvil de forma independiente
priority: ALTA — identificado como diferencial de producto crítico

---

## Proposed Change

Extender la app móvil (Android primario; iOS track secundario) de "punto de
captura exclusivo" a "cliente completo con vista organizada por categoría y
sincronización bidireccional con el desktop".

El cambio tiene dos componentes inseparables:

**Componente 1 — Mobile Client UI**
La app Android incluye una pantalla de galería propia donde el usuario puede
ver todos los recursos que ha capturado, organizados por categoría. El mismo
backend Rust (Classifier + Grouper) que corre en desktop compila y corre en
Android via Tauri 2, sobre su propio SQLCipher local.

**Componente 2 — Sync bidireccional**
El relay de Google Drive (actualmente unidireccional: móvil → desktop) se
extiende para que los datos fluyan en ambas direcciones. Cada dispositivo
tiene su propia SQLCipher y procesa de forma independiente. El relay sincroniza
los eventos capturados en ambas direcciones, de modo que:
- Lo capturado en el móvil aparece organizado en el desktop (ya funciona hoy)
- Lo capturado en el desktop (ej: bookmarks importados) aparece también en el móvil

---

## Why It Is Needed

El product owner ha identificado este gap como uno de los mayores problemas
reales de sus usuarios objetivo:

> "Los usuarios quieren tener los enlaces organizados en otro lugar. El móvil
> es donde ocurre la captura — pero si el móvil no les muestra nada, tienen
> que ir al desktop para ver qué guardaron."

El flujo actual tiene rozamiento real:
1. Usuario captura un Reel en Instagram → lo comparte a FlowWeaver
2. La app en el móvil no le muestra nada (solo confirma la captura)
3. El usuario tiene que abrir el desktop para ver su galería organizada

Si el usuario está en el metro, en una reunión o en el sofá, ese tercer paso
no ocurre. El valor del producto queda bloqueado detrás del desktop.

Con este cambio, el flujo completo funciona desde el móvil:
1. Captura → FlowWeaver procesa en el mismo dispositivo
2. Usuario abre la app → ve sus recursos organizados por categoría
3. Cuando abre el desktop → el workspace también está preparado (flujo existente)

---

## Problem It Solves

**Pain point principal (alta frecuencia):**
El usuario guarda contenido de redes sociales (Reels, videos, artículos) desde
el móvil y no tiene un lugar organizado donde verlo después sin abrir el desktop.

**Gap que crea el diseño actual:**
- Móvil = sensor sin feedback de organización
- Desktop = único lugar donde se ve el valor
- Si el desktop no está accesible, el producto no entrega valor

**Lo que resuelve este CR:**
- Móvil con galería propia → valor inmediato en el dispositivo de captura
- Sync bidireccional → consistencia entre dispositivos sin elegir uno como fuente de verdad
- El desktop sigue siendo el lugar del workspace rico (Panel A + B + C)
- El móvil es el lugar del acceso rápido y la captura

---

## Affected Documents

| Documento | Tipo de impacto | Cambio requerido |
| --- | --- | --- |
| `Project-docs/decisions-log.md` — D12 | Extensión de decisión | D12 dice "único caso: puente móvil → desktop". Con este CR el puente es bidireccional y el móvil también es destino de valor. D12 debe extenderse o clarificarse — no se revoca, se amplía. |
| `Project-docs/decisions-log.md` — D6 | Extensión de decisión | D6 define relay cifrado como mecanismo. El mecanismo no cambia (sigue siendo Google Drive); la dirección del flujo se extiende a bidireccional. D6 debe declararlo explícitamente. |
| `Project-docs/decisions-log.md` — D9 | Clarificación | D9 dice "único observer activo: Share Intent Android". Este CR no añade nuevos observers; añade una UI de galería. No requiere cambio normativo en D9, solo verificación de que la galería no introduce observación activa. |
| `Project-docs/roadmap.md` | Adición de fase | Añadir "Fase 0c — Mobile Client" como fase nueva entre 0b y 1, o integrar en Fase 1 según decisión del Orchestrator. |
| `Project-docs/scope-boundaries.md` | Extensión de scope | La restricción "no incluye galería/organización en móvil" en Fase 0b debe mantenerse. La nueva capacidad entra en la fase que decida el Orchestrator (0c o 1). |
| `Project-docs/phase-definition.md` | Adición | Si se crea Fase 0c, añadir su definición formal. |
| `agents/13_android_share_intent_specialist.md` | Extensión de responsabilidades | El agente pasa de "captura + relay" a "captura + procesamiento local + UI galería + relay bidireccional". |

---

## Phase Impact

### Fase 0b (EN PROGRESO — no debe modificarse)

**Impacto: NINGUNO.** Fase 0b sigue su curso sin cambios.

Fase 0b valida la hipótesis núcleo: "el usuario abre el desktop y experimenta
espontáneamente el 'ya me lo había preparado'". Este CR no toca esa hipótesis.

Fase 0b no debe ampliarse para incluir el Mobile Client. Está en progreso, tiene
una hipótesis clara y cambiarla ahora introduciría riesgo y desenfoque.

### Fase 0c — NUEVA (recomendada)

**Propuesta:** crear Fase 0c como fase dedicada al Mobile Client y sync
bidireccional, que comienza cuando Fase 0b pasa su gate.

Entregables de Fase 0c:
- Pantalla de galería Android con recursos organizados por categoría
- Classifier + Grouper corriendo localmente en Android (Tauri 2 + Rust)
- SQLCipher local en Android (misma implementación que desktop)
- Google Drive relay extendido a bidireccional (raw_events en ambas direcciones)
- Persistencia local: lo capturado en el móvil persiste en el móvil aunque el
  desktop esté apagado
- UI mínima: lista de categorías → recursos por categoría → tap abre URL en navegador
- Privacy Dashboard mínimo en móvil: qué categorías tiene, cuántos recursos

**Hipótesis a validar en 0c:**
El usuario abre la app en el móvil y encuentra sus capturas organizadas sin
necesitar el desktop.

### Fase 1 (no afectada)

El FS Watcher y Panel B siguen siendo el scope de Fase 1. No se mueve nada.

### Fase 2 y siguientes (no afectadas)

Pattern Detector, Trust Scorer, State Machine siguen en Fase 2. Si el Pattern
Detector en móvil fuera relevante, entraría en Fase 2-mobile (no en este CR).

---

## Architectural Impact

### Impacto en el modelo de datos

**Actual:** SQLCipher vive solo en el desktop. El móvil no tiene base de datos local persistente.

**Con este CR:** SQLCipher vive en cada dispositivo de forma independiente.
- SQLCipher-Android: almacena los recursos capturados en el móvil
- SQLCipher-Windows: almacena todos los recursos (propios + sincronizados del móvil)
- No hay base de datos compartida. No hay maestro/esclavo. Cada dispositivo es soberano.

### Impacto en el sync layer (D6)

**Actual:** móvil serializa `raw_events` → Google Drive → desktop deserializa y procesa.

**Con este CR:** el relay es bidireccional sobre el mismo mecanismo:
- móvil → Google Drive → desktop (ya existe)
- desktop → Google Drive → móvil (nuevo, para bookmarks importados en desktop)

El formato del payload no cambia. La idempotencia y ACK ya están diseñados.
El único cambio es que el desktop también emite `raw_events` hacia el relay.

**Riesgo técnico a evaluar:** conflictos de `event_id` si ambos dispositivos
capturan simultáneamente. La idempotencia actual asume que el móvil es el único
emisor. Esto debe revisarse en el Technical Architect review de Fase 0c.

### Impacto en el pipeline de procesamiento

**Actual:** Classifier + Grouper solo en desktop (Rust compilado para Windows).

**Con este CR:** Classifier + Grouper también en Android.

Tauri 2 compila el mismo backend Rust para Android sin reescritura. Esta es
la ventaja estructural de la elección de stack (D19). El impacto es de compilación
y testing — no de rediseño de módulos.

### Impacto en la UI

**Desktop:** sin cambios. Panel A + B + C siguen siendo la experiencia rica.

**Android — nueva pantalla:**
```
[FlowWeaver Mobile]

  Categorías (N)
  ├── research (12 recursos)
  ├── entertainment (8 recursos)
  ├── shopping (3 recursos)
  └── ...

  → tap en categoría → lista de recursos
  → tap en recurso → abre URL en navegador
```

No hay Episode Detector ni workspace en la UI móvil de Fase 0c. La galería
es directa: categorías → recursos. El workspace rico sigue siendo patrimonio
del desktop.

---

## Scope Creep Risk

**Riesgo: MEDIO-ALTO si no se delimita bien.**

Los vectores de scope creep más probables:

| Vector | Descripción | Cómo bloquearlo |
| --- | --- | --- |
| "Panel B en móvil" | Alguien pide el resumen narrativo de cada categoría en móvil | Panel B es Fase 1 en desktop. No entra en Fase 0c mobile. Requiere CR propio. |
| "Episode Detector en móvil" | Alguien pide el workspace completo en móvil | El workspace en móvil es Fase posterior. 0c solo tiene galería de categorías. |
| "Pattern Detector en móvil" | Aprendizaje longitudinal en móvil | Explícitamente fuera. Pattern Detector entra en Fase 2 desktop primero. |
| "Sync en tiempo real" | Alguien pide que móvil y desktop estén sincronizados al instante | El relay de Fase 0c es async, no real-time. Sync en tiempo real es V1 (LAN). |
| "Notificaciones push" | Notificar al usuario cuando el workspace está preparado | No está en scope de ninguna fase actual. Requiere backend propia (prohibida en MVP). |
| "Vista de contenido embebida" | Mostrar el Reel dentro de la app, no solo el enlace | D1 no lo bloquea, pero el scope lo hace. 0c solo abre URLs en el navegador. |

**Mitigación:** el gate de Fase 0c debe requerir que ninguno de estos vectores
haya entrado en la implementación. El Phase Guardian y el QA Auditor son
responsables de este control.

---

## Alternatives Rejected

### Alternativa 1 — Ampliar Fase 0b para incluir Mobile Client

**Rechazada.** Fase 0b está en progreso con hipótesis y scope claros. Ampliarla
ahora añade riesgo de desenfoque y retrasa la validación del puente móvil→desktop,
que es la hipótesis más importante del producto.

### Alternativa 2 — Incluir Mobile Client en Fase 1

**Viable pero no recomendada.** Fase 1 tiene scope propio (FS Watcher, Panel B).
Mezclar Mobile Client con Fase 1 haría la fase más grande sin ganar cohesión.
Además, el Mobile Client debería validarse antes del aprendizaje longitudinal de
Fase 2, y situarlo en Fase 1 lo retrasa más de lo necesario.

### Alternativa 3 — Mobile como espejo del desktop (desktop como fuente de verdad)

**Rechazada.** Requiere que el desktop esté encendido o haya sincronizado antes
de que el móvil muestre datos. Viola la autonomía del dispositivo y el modelo
local-first. Si el usuario solo tiene el móvil, no ve nada.

### Alternativa 4 — Sync de base de datos SQLCipher completa (merge)

**Rechazada para 0c.** El merge de bases de datos SQLCipher entre dispositivos
es complejo y requiere resolución de conflictos. La alternativa propuesta
(sync de raw_events bidireccional + procesamiento independiente en cada dispositivo)
es más simple, más robusta y coherente con el modelo actual. El merge puede
revisarse en V1 si es necesario.

---

## Recommendation

**Aprobar como Fase 0c — Mobile Client**, con inicio inmediato tras el gate de
Fase 0b.

**Condiciones de aprobación:**

1. Fase 0b completa su gate antes de que Fase 0c comience implementación.
2. El Technical Architect emite AR-0c-001 verificando:
   - coherencia del sync bidireccional con D6
   - idempotencia del relay extendido a dos emisores
   - ausencia de conflictos en el esquema SQLCipher Android
3. El scope de Fase 0c se limita estrictamente a:
   - galería de categorías en móvil (no workspace completo)
   - Classifier + Grouper en Android (no Pattern Detector, no Trust Scorer)
   - relay bidireccional (no sync en tiempo real)
4. D12 se extiende (no se revoca) para declarar que el puente es bidireccional
   y que el móvil también es destino de valor.
5. D6 se extiende para declarar la bidireccionalidad del relay.
6. El Functional Analyst produce backlog-phase-0c.md como primer entregable
   antes de ninguna implementación.

**Argumento para la aprobación:**

Esta función no es un nice-to-have. Es el cierre del loop de valor del producto:
el usuario captura en el móvil y el valor debe estar disponible también en el
móvil. Sin esto, el producto requiere dos dispositivos para entregar su promesa.
Con esto, entrega valor en el mismo dispositivo donde ocurre la captura — y además
en el desktop cuando el usuario lo abra.

El stack elegido (Tauri 2 + Rust + Android) está diseñado exactamente para esto:
el mismo backend compila para ambas plataformas sin reescritura. El coste técnico
es menor de lo que parecería con otro stack.

La pregunta ya no es "¿debería hacerse?" sino "¿cuándo?". La recomendación
es: inmediatamente después de que Fase 0b valide el puente.

---

## Required Reviewers

| Agente | Rol en la revisión | Obligatorio |
| --- | --- | --- |
| Orchestrator | Aprueba o rechaza este CR; decide la fase de implementación | ✅ obligatorio |
| Technical Architect | Verifica coherencia de sync bidireccional, SQLCipher en Android, impacto en D6 | ✅ obligatorio |
| Privacy Guardian | Verifica que la galería móvil no introduce vectores de privacidad nuevos (D1, D9) | ✅ obligatorio |
| Phase Guardian | Verifica que el scope de 0c no contamina 0b ni introduce scope creep en fases posteriores | ✅ obligatorio |
| Functional Analyst | Produce backlog-phase-0c.md si el CR es aprobado | contingente (post-aprobación) |
| Android Share Intent Specialist | Revisa viabilidad de Tauri 2 + Classifier + Grouper + SQLCipher en Android | ✅ obligatorio (técnico) |

---

## Final Decision

status: APROBADO
decision_by: Orchestrator
date_decided: 2026-04-24
outcome: APROBADO — Fase 0c creada. D20 y D21 añadidos al decisions-log.md.
  Roadmap, scope-boundaries y phase-definition actualizados. OD-005 emitido.
conditions:
  - Fase 0b debe pasar su gate antes de que Fase 0c comience implementación
  - Technical Architect emite AR-0c-001 (sync bidireccional + SQLCipher Android)
    antes de ninguna implementación de Fase 0c
  - Scope de Fase 0c estrictamente limitado a lo declarado (galería, no workspace)
  - Functional Analyst produce backlog-phase-0c.md como primer entregable
  - Privacy Guardian verifica que la galería móvil no introduce vectores nuevos
