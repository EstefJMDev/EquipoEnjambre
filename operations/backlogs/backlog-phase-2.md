# Backlog Funcional — Fase 2

date: 2026-04-24
owner_agent: Functional Analyst
phase: 2
status: APROBADO — Technical Architect (AR-2-001, 2026-04-24)
referenced_decision: OD-004-phase-2-activation.md

---

## Functional Breakdown

phase: 2
objective: Añadir aprendizaje longitudinal y escalera de confianza progresiva.

validates:
- aprendizaje longitudinal a partir de patrones recurrentes sobre domain/category
- transición entre estados de confianza gestionada por la State Machine
- tolerancia del usuario a preparación silenciosa y automatización progresiva
- suficiencia del Privacy Dashboard completo como control visible antes de beta

does_not_validate:
- escalado comercial definitivo
- product-market fit a escala
- beta pública (eso es Fase 3)
- comportamiento bajo carga real con usuarios externos

in_scope:
- T-2-000: Delimitación documental de FS Watcher como segundo caso de uso local
- T-2-001: Pattern Detector — detección de patrones longitudinales sobre domain/category
- T-2-002: Trust Scorer — score de confianza determinístico por patrón detectado
- T-2-003: State Machine — máquina de estados de confianza con autoridad sobre acciones
- T-2-004: Privacy Dashboard completo — visibilidad y control total para el usuario

out_of_scope:
- implementación de FS Watcher (no puede comenzar sin T-2-000 aprobado por Technical Architect)
- beta pública (Fase 3)
- LLM local como requisito (D8 — baseline determinístico obligatorio en todos los módulos)
- telemetría ni métricas de usuarios externos (Fase 3)
- calibración de umbrales con datos reales de usuarios (Fase 3)
- exposición de url o title en cualquier módulo o pantalla (D1)
- Panel D ni nuevos paneles en el Shell (fuera del roadmap de Fase 2)
- background monitoring sin consentimiento activo del usuario

dependencies:
- `storage.rs` (SQLCipher) — tabla resources con domain, category, captured_at disponibles
- `episode_detector.rs` — módulo de referencia de detección independiente (R12 activo)
- `grouper.rs` — clusters de Panel A son la fuente histórica principal
- `PrivacyDashboard.tsx` — el dashboard mínimo de 0b es la base que T-2-004 expande

risks_of_misinterpretation:
- extender episode_detector.rs para hacer Pattern Detector "gradualmente" —
  viola R12; son módulos con propósitos distintos (longitudinal vs sesión); la
  distinción debe declararse explícitamente en cada TS de Fase 2
- añadir LLM como requisito de cualquier módulo antes de tener baseline — viola D8
- adelantar observación activa sin T-2-000 aprobado — viola D9
- mostrar url o title en el Privacy Dashboard completo — viola D1
- implementar Trust Scorer antes de que Pattern Detector esté aprobado —
  viola la cadena de dependencias estricta de OD-004
- implementar State Machine antes de que Trust Scorer esté aprobado — ídem
- hacer la State Machine consultiva en lugar de autoritaria — viola D4
- adelantar aprendizaje longitudinal a Panel B como "mejora del resumen" —
  Panel B en Fase 1 es stateless; Pattern Detector no puede retrointroducirse

---

## Mapa De Dependencias

```
storage.rs (SQLCipher — domain/category/captured_at en claro, D1)
    │
    ├──► T-2-000  Delimitación FS Watcher (documental)
    │        │
    │        └──► [Implementación FS Watcher — sprint independiente post-T-2-000]
    │
    └──► T-2-001  Pattern Detector
             │
             ▼
         T-2-002  Trust Scorer
             │
             ▼
         T-2-003  State Machine
             │
             ▼  (y T-2-001 implementado)
         T-2-004  Privacy Dashboard completo
```

T-2-000 y T-2-001 pueden prepararse en paralelo una vez OD-004 está emitido.
T-2-000 no bloquea T-2-001, pero la implementación de FS Watcher no puede comenzar
sin T-2-000 aprobado.
T-2-004 puede definirse antes, pero su implementación completa requiere T-2-001
implementado (los patrones detectados son la fuente principal del dashboard completo).

---

## Constraints Activos

| ID | Constraint | Impacto en Fase 2 |
| --- | --- | --- |
| D1 | Solo domain y category en claro | Pattern Detector, Trust Scorer y Privacy Dashboard operan exclusivamente sobre domain/category. url/title no pueden aparecer en ninguna salida |
| D4 | State Machine tiene autoridad; trust_score es input con doble condición | Trust Scorer produce scores; la State Machine decide qué acción corresponde. Trust Scorer no puede desencadenar acciones directamente |
| D5 | Slot concentration score con entropía normalizada (0–1) | Trust Scorer usa esta fórmula como baseline de stability_score |
| D8 | Baseline determinístico sin LLM obligatorio | Cada módulo debe funcionar sin modelo local. LLM es mejora opcional que debe declararse explícitamente en el TS correspondiente |
| D9 | FS Watcher es el único módulo de Fase 2 que introduce observación activa | T-2-000 debe especificar exactamente qué directorios observa, por cuánto tiempo y con qué controles de privacidad |
| D14 | Privacy Dashboard completo obligatorio antes de beta | T-2-004 es prerequisito bloqueante de Fase 3 |
| D17 | Pattern Detector completo en Fase 2 | No se divide entre fases ni se construye "a medias" |
| R12 WATCH ACTIVO | Pattern Detector ≠ Episode Detector | Propósitos distintos: patrones longitudinales (días/semanas) vs episodios de sesión (tiempo real). Esta distinción debe declararse en cada TS de Fase 2 |

---

## Tareas Y Criterios De Aceptación

---

### T-2-000 — Delimitación Formal De FS Watcher

task_id: T-2-000
title: Delimitación formal de FS Watcher como segundo caso de uso local
phase: 2
owner_agent: Functional Analyst (redacta); Technical Architect (aprueba)
entregable: documental — no implementación
satisfies: Condición 1 del gate formal de Fase 1 (phase-gates.md)

#### Objective

Producir el documento de delimitación formal de FS Watcher que permita al
Technical Architect aprobar o rechazar su implementación. Este documento debe
responder tres preguntas específicas exigidas por D9: qué observa, por cuánto
tiempo y con qué controles de privacidad.

FS Watcher es el segundo caso de uso local del desktop después del Bookmark
Importer. No es una extensión del Share Intent ni una reescritura del MVP.
Su rol es detectar patrones en archivos locales (descargas/capturas) para
enriquecer el workspace del usuario sin introducir vigilancia de fondo.

#### In Scope

- definición precisa de qué directorios puede observar FS Watcher (candidatos:
  Downloads, Desktop — seleccionables por el usuario, ninguno por defecto)
- duración de la observación: solo mientras la app está en primer plano; no hay
  monitoring en background bajo ninguna circunstancia
- controles de privacidad mínimos exigidos: consentimiento explícito del usuario
  para cada directorio; posibilidad de revocar en cualquier momento desde el
  Privacy Dashboard
- relación con Episode Detector adaptado: FS Watcher produce eventos de archivo;
  el Episode Detector adaptado (ya implementado para 0b) puede reutilizar su lógica
  de detección sobre esos eventos — pero son dos módulos distintos
- qué extensiones de archivo quedan en scope (ejemplo: .pdf, .png, .jpg, .zip)
  y cuáles quedan explícitamente fuera (ejecutables, archivos de sistema)
- declaración explícita de separación de FS Watcher respecto a Pattern Detector
  (R12: FS Watcher detecta eventos de sesión local, no patrones longitudinales)

#### Out Of Scope

- implementación de FS Watcher (este documento la bloquea hasta aprobación)
- integración con Pattern Detector (FS Watcher es entrada opcional)
- monitoring de directorios de sistema, red o ocultos
- extensión al Episode Detector de 0b como si fueran el mismo módulo

#### Acceptance Criteria

- [ ] el documento especifica al menos un directorio observable y los criterios
      de selección por el usuario
- [ ] el documento especifica explícitamente que no hay monitoring en background
- [ ] el documento especifica los controles de privacidad mínimos (consentimiento,
      revocación, visualización en Privacy Dashboard)
- [ ] el documento declara qué extensiones de archivo entran en scope y cuáles no
- [ ] el documento declara explícitamente la separación entre FS Watcher
      (detección de sesión local) y Pattern Detector (patrones longitudinales) — R12
- [ ] el documento es aprobado por el Technical Architect antes de que
      comience ninguna implementación de FS Watcher

#### Risks

- que el documento amplíe el scope de observación más allá de lo necesario para
  el caso de uso (monitoring de sistema, background, directorios no declarados)
- que el documento mezcle FS Watcher con Pattern Detector como si FS Watcher
  "generara los patrones" — FS Watcher genera eventos; Pattern Detector los analiza

#### Required Handoff

Al Technical Architect para revisión y aprobación antes de cualquier
implementación.

---

### T-2-001 — Pattern Detector

task_id: T-2-001
title: Pattern Detector — detección de patrones longitudinales
phase: 2
owner_agent: Desktop Tauri Shell Specialist (revisión obligatoria: Technical Architect)
depends_on: ninguno (puede comenzar en paralelo a T-2-000)

#### Objective

Implementar `pattern_detector.rs` como módulo independiente que analiza el
historial de recursos almacenados en SQLCipher para detectar patrones recurrentes
por domain/category a lo largo del tiempo.

**Distinción obligatoria respecto a Episode Detector (R12):**
- `episode_detector.rs`: opera sobre una sesión activa; agrupa recursos por
  similitud Jaccard en tiempo real; no persiste estado.
- `pattern_detector.rs`: opera sobre el historial completo; detecta combinaciones
  de domain/category que se repiten con una firma temporal (hora del día, día de
  la semana); persiste patrones detectados.

Un patrón no es "lo que ocurrió en una sesión". Es "lo que ocurre regularmente".

El baseline debe funcionar sin LLM (D8). Solo accede a domain y category de la
base de datos — nunca a url ni title (D1).

#### In Scope

- módulo Rust `src-tauri/src/pattern_detector.rs` independiente de
  `episode_detector.rs`
- lectura exclusiva de domain, category, captured_at desde SQLCipher (D1)
- algoritmo baseline determinístico: frecuencia de co-ocurrencia de
  (category, domain) dentro de ventanas temporales (franjas horarias + días de
  la semana)
- firma temporal del patrón: `time_of_day_bucket` (mañana/tarde/noche) +
  `day_of_week_mask` (bitmask 0-6)
- tipos de salida: `DetectedPattern` con campos: pattern_id (UUID), label
  (derivado de dominant_category + time_bucket), category_signature
  (Vec<CategoryWeight>), domain_signature (Vec<DomainWeight>), temporal_window,
  frequency (usize), first_seen (i64), last_seen (i64)
- umbral mínimo de frecuencia configurable (no hardcoded) — no requiere LLM
- LLM como mejora opcional para generar etiquetas más descriptivas (declarar
  explícitamente en el TS de implementación si se añade; no es requisito)

#### Out Of Scope

- acceso a url o title (D1 — nunca)
- uso de `episode_detector.rs` como base o herencia (R12)
- background analysis sin trigger explícito desde commands.rs
- guardar patrones en tablas SQLCipher en esta tarea (la persistencia puede ser
  en memoria hasta que T-2-002 valide la estructura de datos — el Technical
  Architect decide en AR)
- integración con FS Watcher (entrada opcional, no bloqueante)
- correlación entre usuarios (no hay multi-usuario en este scope)

#### Acceptance Criteria

- [ ] `pattern_detector.rs` existe como módulo independiente y no importa desde
      `episode_detector.rs`
- [ ] el módulo declara explícitamente en comentario de cabecera la distinción
      Pattern Detector vs Episode Detector (R12)
- [ ] el módulo solo lee domain, category, captured_at — ninguna query accede
      a url ni title
- [ ] dado un conjunto sintético de N recursos con patrones conocidos,
      `detect_patterns()` devuelve al menos los patrones esperados (test determinístico)
- [ ] el umbral de frecuencia mínima es un parámetro, no una constante fija
- [ ] `DetectedPattern` incluye: pattern_id, label, category_signature,
      domain_signature, temporal_window, frequency, first_seen, last_seen
- [ ] los tests de cargo test pasan (sin regresiones en los 14 tests existentes)
- [ ] TypeScript: si se añade comando Tauri, npx tsc --noEmit limpio

#### Risks

- que se use episode_detector.rs como punto de partida "para reutilizar código"
  — viola R12; compartir código de utilidad es aceptable, pero el módulo debe
  ser independiente semánticamente
- que el algoritmo dependa de datos de URL o título para mejorar la precisión
  — viola D1; si el baseline con domain/category es insuficiente, la solución
  es ajustar umbrales, no acceder a más campos
- que se adelante la persistencia en SQLCipher antes de que el Technical Architect
  haya revisado el esquema de tabla de patrones

#### Required Handoff

Al Technical Architect para revisar que el contrato de `DetectedPattern` es
coherente con los inputs esperados por Trust Scorer (T-2-002) y que la lectura
de SQLCipher no accede a campos prohibidos.

---

### T-2-002 — Trust Scorer

task_id: T-2-002
title: Trust Scorer — score de confianza determinístico por patrón
phase: 2
owner_agent: Desktop Tauri Shell Specialist (revisión obligatoria: Technical Architect)
depends_on: T-2-001 (Pattern Detector aprobado)

#### Objective

Implementar `trust_scorer.rs` que recibe `Vec<DetectedPattern>` del Pattern
Detector y produce un score de confianza y estabilidad por patrón.

El Trust Scorer no toma decisiones de acción. Su output es input para la State
Machine (D4). La State Machine tiene autoridad; el trust_score es uno de los dos
factores de la condición de transición.

El baseline es determinístico (D8): función ponderada de frecuencia, recencia
y coherencia temporal. El score de estabilidad usa slot concentration score con
entropía normalizada (D5), acotado entre 0.0 y 1.0.

#### In Scope

- módulo Rust `src-tauri/src/trust_scorer.rs`
- input: `Vec<DetectedPattern>` desde pattern_detector.rs
- función baseline: `trust_score = f(frequency, recency_weight, temporal_coherence)`
  donde todos los factores son determinísticos y sin dependencia de LLM
- `stability_score` usando la fórmula D5: slot concentration score con entropía
  normalizada — acotado estrictamente entre 0.0 y 1.0
- tipos de salida: `TrustScore` con campos: pattern_id (UUID, referencia a
  DetectedPattern), trust_score (f64, 0.0–1.0), stability_score (f64, 0.0–1.0),
  recency_weight (f64), confidence_tier (Low/Medium/High derivado de umbrales)
- umbrales de confidence_tier configurables (no hardcoded)
- LLM como mejora opcional para ajustar pesos (declarar en TS si se añade; no requisito)

#### Out Of Scope

- acceso directo a SQLCipher (Trust Scorer recibe patrones, no lee la BD)
- toma de decisiones de acción (ese rol es exclusivo de la State Machine — D4)
- acceso a url o title (D1)
- score global del usuario (solo scores por patrón)

#### Acceptance Criteria

- [ ] `trust_scorer.rs` existe como módulo independiente
- [ ] dado un `Vec<DetectedPattern>` sintético con frecuencias y timestamps
      conocidos, `score_patterns()` produce `Vec<TrustScore>` con valores en [0.0, 1.0]
- [ ] `stability_score` usa entropía normalizada como define D5 y nunca supera 1.0
      ni baja de 0.0
- [ ] los umbrales de confidence_tier son parámetros, no constantes fijas
- [ ] `TrustScore` incluye: pattern_id, trust_score, stability_score,
      recency_weight, confidence_tier
- [ ] el módulo incluye comentario de cabecera declarando que Trust Scorer
      produce inputs para la State Machine y no toma decisiones de acción (D4)
- [ ] los tests de cargo test pasan sin regresiones

#### Risks

- que Trust Scorer exponga un método `recommend_action()` o similar — viola D4;
  las acciones son responsabilidad exclusiva de la State Machine
- que stability_score pueda salir del rango [0.0, 1.0] bajo inputs extremos
  (patrón con una sola ocurrencia, entropía máxima)

#### Required Handoff

Al Technical Architect para verificar que el contrato de `TrustScore` es
coherente con los inputs esperados por la State Machine (T-2-003).

---

### T-2-003 — State Machine

task_id: T-2-003
title: State Machine — máquina de estados de confianza con autoridad sobre acciones
phase: 2
owner_agent: Desktop Tauri Shell Specialist (revisión obligatoria: Technical Architect)
depends_on: T-2-002 (Trust Scorer aprobado)

#### Objective

Implementar `state_machine.rs` que gestiona las transiciones de estado de
confianza del usuario y determina qué acciones automatizadas están autorizadas
en cada estado.

La State Machine tiene autoridad sobre las decisiones de acción (D4). El
trust_score del Trust Scorer es uno de los dos factores de la condición de
transición: (1) trust_score supera el umbral de transición Y (2) el usuario no
ha bloqueado o revertido el patrón. Ambas condiciones deben cumplirse.

El usuario puede ver el estado actual y las transiciones disponibles desde el
Privacy Dashboard (T-2-004).

#### In Scope

- módulo Rust `src-tauri/src/state_machine.rs`
- cuatro estados: Observing → Learning → Trusted → Autonomous
  - **Observing**: el sistema recoge datos, no hace sugerencias
  - **Learning**: patrones detectados, el sistema hace sugerencias suaves (no automáticas)
  - **Trusted**: scores consistentemente altos, el sistema puede pre-preparar
    el workspace silenciosamente
  - **Autonomous**: preparación automática activa — solo entra por acción
    explícita del usuario desde Privacy Dashboard
- transiciones permitidas:
  - Observing → Learning: `pattern_count >= MIN_PATTERNS && trust_score > THRESHOLD_LOW`
  - Learning → Trusted: `trust_score > THRESHOLD_HIGH && !user_blocked`
  - Trusted → Autonomous: solo por acción explícita del usuario (nunca automática)
  - Cualquier estado → Observing: acción de reset del usuario
- umbrales MIN_PATTERNS, THRESHOLD_LOW, THRESHOLD_HIGH configurables
- tipo de salida: `TrustState` con campos: current_state (enum), available_transitions
  (Vec<Transition>), active_patterns_count (usize), last_transition_at (i64)
- comando Tauri `get_trust_state` para que el frontend consulte el estado actual
- comando Tauri `reset_trust_state` para que el usuario vuelva a Observing
- persistencia del estado actual en SQLCipher (solo el estado, no los scores)

#### Out Of Scope

- delegación de autoridad de decisión a Trust Scorer (D4)
- transición automática a Autonomous (siempre requiere acción explícita del usuario)
- exposición de url o title en ningún campo de TrustState (D1)
- lógica de "sugerencias" en este módulo (el frontend las renderiza; la State
  Machine solo expone qué está autorizado)

#### Acceptance Criteria

- [ ] `state_machine.rs` existe como módulo independiente
- [ ] los cuatro estados están definidos como enum: Observing, Learning, Trusted, Autonomous
- [ ] la transición a Autonomous solo es posible mediante acción explícita del
      usuario; no hay path de transición automática a Autonomous
- [ ] la transición requiere doble condición: trust_score > umbral Y
      !user_blocked_pattern (D4)
- [ ] `reset_trust_state` devuelve el sistema a Observing desde cualquier estado
- [ ] los umbrales son configurables, no hardcoded
- [ ] el comando Tauri `get_trust_state` devuelve el estado actual y las
      transiciones disponibles
- [ ] dado un `Vec<TrustScore>` sintético, la máquina de estados produce las
      transiciones esperadas (test determinístico)
- [ ] los tests de cargo test pasan sin regresiones

#### Risks

- que se añada una transición automática a Autonomous "para mejorar la UX" —
  viola el principio de confianza progresiva y el contrato explícito del producto
- que Trust Scorer sea quien llame a las transiciones en lugar de la State
  Machine — invierte la autoridad (D4)
- que el estado actual se almacene en memoria sin persistir, perdiendo el estado
  al reiniciar la app

#### Required Handoff

Al Technical Architect para verificar que el esquema de persistencia del estado
en SQLCipher no introduce campos que violen D1, y que el contrato de `TrustState`
es suficiente para que T-2-004 lo consuma.

---

### T-2-004 — Privacy Dashboard Completo

task_id: T-2-004
title: Privacy Dashboard completo — visibilidad y control total del usuario
phase: 2
owner_agent: Desktop Tauri Shell Specialist (revisión obligatoria: Technical Architect + Privacy Guardian)
depends_on: T-2-001 (Pattern Detector implementado), T-2-003 (State Machine implementada)
prerequisite_of: Fase 3 (D14 — obligatorio antes de beta)

#### Objective

Expandir `PrivacyDashboard.tsx` para que el usuario tenga visibilidad completa
de qué observa el sistema, qué ha detectado y qué controles tiene sobre el
comportamiento automatizado.

El Privacy Dashboard completo expone tres dimensiones:
1. **Qué veo**: recursos capturados por domain/category (ya existe en 0b)
2. **Qué he aprendido**: patrones detectados por Pattern Detector (nuevo)
3. **Qué puedo hacer**: estado de la State Machine y acciones disponibles (nuevo)

Solo opera sobre domain y category (D1). Ninguna pantalla del dashboard puede
exponer url ni title bajo ninguna circunstancia.

#### In Scope

- expansión de `PrivacyDashboard.tsx` con tres secciones diferenciadas
- sección 1 (ya existe): resource_count, categories, domains — sin cambios
- sección 2 (nueva): lista de patrones detectados (label, category_signature,
  domain_signature, frequency, last_seen) — solo campos en claro (D1)
  - por cada patrón: botón "Bloquear este patrón" (envía comando Tauri)
  - por cada patrón bloqueado: botón "Desbloquear"
- sección 3 (nueva): estado actual de la State Machine (current_state, tiempo
  en estado actual, número de patrones activos)
  - botón "Resetear confianza" (vuelve a Observing) visible siempre
  - si estado es Trusted: botón "Activar preparación automática" (→ Autonomous)
    con aviso explícito de lo que implica
- sección FS Watcher (si implementado): directorios observados, estado
  (activo/inactivo), número de eventos en sesión actual — botón "Dejar de observar"
- separación visual clara "Qué sé de ti" / "Qué no veo nunca" (url, título
  completo, contenido de páginas)
- nuevos tipos TypeScript: `PatternSummary`, `TrustStateView` en `src/types.ts`
- nuevos comandos Tauri consumidos: `get_detected_patterns`, `block_pattern`,
  `unblock_pattern`, `get_trust_state`, `reset_trust_state`

#### Out Of Scope

- exposición de url o title en ningún campo o tooltip (D1 — sin excepciones)
- telemetría ni envío de datos a servicios externos
- configuración de umbrales por el usuario (eso es Fase 3 — calibración)
- historial de transiciones de la State Machine (exposición de historial es
  Fase 3)

#### Acceptance Criteria

- [ ] el dashboard muestra las tres secciones diferenciadas: Recursos, Patrones,
      Estado de confianza
- [ ] la sección de patrones muestra label, category_signature, domain_signature,
      frequency — ningún campo expone url ni title
- [ ] por cada patrón se puede bloquear y desbloquear desde el dashboard
- [ ] el estado actual de la State Machine (Observing/Learning/Trusted/Autonomous)
      es visible sin necesidad de abrir configuración
- [ ] el botón "Resetear confianza" está siempre visible y funcional
- [ ] la transición a Autonomous requiere interacción explícita con confirmación
      visible (no un toggle accidental)
- [ ] la sección "Qué no veo nunca" nombra explícitamente url y título completo
- [ ] npx tsc --noEmit limpio tras añadir los nuevos tipos en src/types.ts
- [ ] los tests de cargo test pasan sin regresiones

#### Risks

- que se añada un tooltip o detalle que muestre el título de un recurso
  "para contexto" — viola D1 sin importar cuán útil parezca
- que la transición a Autonomous sea un toggle sin confirmación ni aviso —
  el diseño debe hacer obvio qué implica
- que la sección de patrones sea tan técnica (UUIDs, bitmasks) que el usuario
  no entienda qué controla — el label y la firma deben ser legibles para
  un usuario no técnico

#### Required Handoff

Al Privacy Guardian para verificar que ningún campo del dashboard expone datos
que violen D1, y al QA Auditor para verificar que la expansión no introduce
regresiones en la sección de recursos existente.

---

## Hipótesis Que Fase 2 Debe Validar (Gate De Salida)

Antes de pasar el gate de Fase 2, debe existir evidencia de que:

- Pattern Detector, Trust Scorer y State Machine quedan unidos al roadmap de
  confianza progresiva con baseline determinístico sin LLM
- la State Machine tiene autoridad real sobre las acciones automatizadas y la
  transición a Autonomous requiere acción explícita del usuario
- el Privacy Dashboard completo expone los patrones detectados y el estado de
  confianza usando solo domain y category (D1)
- la lógica longitudinal no rompe la narrativa de privacidad: el usuario entiende
  qué observa el sistema y puede bloquearlo
- la distinción Pattern Detector vs Episode Detector (R12) es declarada
  explícitamente en código y documentación
- FS Watcher tiene documento de delimitación formal aprobado (T-2-000)

### Condiciones de no-paso (phase-gates.md)

- aparece aprendizaje longitudinal sin control del usuario
- se diluye la autoridad de la State Machine (pasa a ser consultiva)
- el Privacy Dashboard completo sigue incompleto antes de cerrar Fase 2

---

## Track Paralelo iOS — Sigue Abierto

Share Extension iOS y Sync Layer (Fase 0b) siguen pendientes por dependencia
de plataforma macOS. Son independientes del gate de Fase 2.

| Módulo | Bloqueo | Estado |
| --- | --- | --- |
| Share Extension iOS | Requiere macOS + Xcode | Pendiente — independiente de Fase 2 |
| Sync Layer MVP (D6/iCloud) | Requiere Share Extension operativa | Pendiente — independiente de Fase 2 |
