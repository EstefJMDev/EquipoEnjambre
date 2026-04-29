# Revisión Arquitectónica — Backlog Fase 3

document_id: AR-3-001
owner_agent: Technical Architect
phase: 3
date: 2026-04-28
status: APROBADO
documents_reviewed:
  - operations/backlogs/backlog-phase-3.md
  - operations/orchestration-decisions/OD-006-phase-3-activation.md
  - operating-system/phase-gates.md
  - Project-docs/decisions-log.md
  - operations/architecture-reviews/AR-2-001-phase-2-backlog-review.md
reference_normativo:
  - Project-docs/decisions-log.md (D1, D4, D8, D9 rev. 2026-04-28, D14, D17, D19, D22, R12)
  - operations/architecture-reviews/AR-CR-002-mobile-observer.md
  - operations/architecture-reviews/PGR-CR-002-mobile-observer.md
  - operations/orchestration-decisions/OD-006-phase-3-activation.md
precede_a: implementación de T-3-001 (Desktop Tauri Shell Specialist + Android Share Intent Specialist), inicio paralelo de especificación TS formal T-3-004

---

## Objetivo De Esta Revisión

Esta revisión es pre-implementación. Verifica que el backlog de Fase 3 recoge
fielmente los entregables y prerequisitos definidos en OD-006, que la cadena de
dependencias es coherente con los contratos cerrados de Fase 2, que cada tarea
declara criterios de aceptación verificables, y que los constraints activos (D1,
D4, D8, D9, D14, D22, CR-002, R12) están correctamente blindados contra las vías
de interpretación más probables en beta.

Ninguna implementación de Fase 3 puede comenzar hasta que esta AR confirme la
coherencia de los contratos. T-3-004 requiere adicionalmente una TS formal
aprobada por Technical Architect y Privacy Guardian antes de cualquier línea de
código. T-3-005 requiere decisión explícita del Orchestrator basada en datos de
beta.

---

## Resultado Global

| Elemento revisado | Resultado | Bloqueos | Observaciones |
| --- | --- | --- | --- |
| P-0 Verificación E2E Relay OAuth | APROBADO | ninguno | ACs verificables; riesgo de credenciales bien declarado |
| P-1 Criterio #18 AR-2-007 background-persistent | APROBADO | ninguno | ACs correctos; el riesgo de implementación no background-persistent está declarado |
| T-3-001 Infraestructura de beta | APROBADO | ninguno | ACs suficientes; riesgo de certificado de código identificado |
| T-3-002 Telemetría dentro de D1 | APROBADO | ninguno | Schema declarado en backlog; revisión obligatoria de Privacy Guardian antes de implementar |
| T-3-003 Calibración de umbrales State Machine | APROBADO | ninguno | D4 y R12 blindados; AR formal requerida antes de implementar cambios |
| T-3-004 Observer semi-pasivo Android | APROBADO | TS formal (bloqueante) | Bloqueado correctamente hasta TS; ACs referencian AC-1 a AC-12 de AR-CR-002 |
| T-3-005 LLM local opcional | APROBADO | decisión Orchestrator (condicional) | D8 blindado; activación condicional correctamente declarada |
| Cadena de dependencias | APROBADA | ninguno | P-0 y P-1 bloquean beta pública; T-3-004 y T-3-005 tienen sus propios bloqueos declarados |
| Coherencia con OD-006 | CONFORME | ninguno | El backlog recoge fielmente todos los entregables y prerequisitos de OD-006 |

El backlog-phase-3.md queda aprobado para implementación a partir de esta AR.

---

## A. Verificación De Coherencia Con OD-006

OD-006 define los siguientes entregables y condiciones para Fase 3:

| Elemento en OD-006 | Recogido en backlog-phase-3.md | Conforme |
| --- | --- | --- |
| P-0: O-002 relay E2E con OAuth activo (bloqueante de beta) | P-0 con ACs y riesgos completos | CONFORME |
| P-1: criterio #18 AR-2-007 escenario 3 background-persistent (bloqueante de beta) | P-1 con ACs y riesgo de implementación | CONFORME |
| T-3-001: infraestructura de beta (onboarding, distribución) | T-3-001 con ACs detallados | CONFORME |
| T-3-002: telemetría dentro de D1 (solo domain/category) | T-3-002 con schema declarado y revisión Privacy Guardian | CONFORME |
| T-3-003: calibración de umbrales con datos reales (AR formal antes de implementar) | T-3-003 con cadena de aprobación declarada | CONFORME |
| T-3-004: observer Android tier paid (TS formal bloqueante) | T-3-004 BLOQUEADO hasta TS formal — correctamente declarado | CONFORME |
| T-3-005: LLM local opcional (condicional a datos de beta + decisión Orchestrator) | T-3-005 CONDICIONAL con condiciones de activación explícitas | CONFORME |
| D1 operativo en telemetría | Schema de T-3-002 excluye url/title/filename/path | CONFORME |
| D4: calibración no toca lógica de transición | T-3-003 Out of Scope declara la prohibición | CONFORME |
| D8: baseline determinístico sin LLM | T-3-005 solo activable con datos + decisión Orchestrator | CONFORME |
| D9 rev.: background-persistent desktop; tile sesión mobile | Recogido en constraints y en T-3-004 | CONFORME |
| D14: Privacy Dashboard no regresiona | Declarado en constraints; T-3-004 requiere sección en dashboard | CONFORME |
| D22 + CR-002: T-3-004 es tier paid | Declarado en T-3-004 con referencia a AR-CR-002 y PGR-CR-002 | CONFORME |
| R12: segregar señales longitudinales vs sesión | Declarado en telemetría T-3-002, calibración T-3-003 y T-3-004 | CONFORME |
| Track iOS sigue abierto; no bloquea gate Fase 3 | Declarado en sección "Track Paralelo iOS" | CONFORME |

**Veredicto A: el backlog recoge fielmente OD-006 en todos sus puntos. Sin desviaciones.**

---

## B. Verificación De La Cadena De Dependencias

```
Fase 2 cerrada (pattern_detector.rs + trust_scorer.rs + state_machine.rs +
                PrivacyDashboard.tsx con FsWatcherSection)
    │
    ├──► P-0  O-002 — relay E2E verificado con OAuth activo
    │        │ Bloquea: apertura de beta pública con usuarios reales
    │        │ No bloquea: trabajo documental y especificación
    │
    ├──► P-1  Criterio #18 AR-2-007 — QA background-persistent FS Watcher
    │        │ Bloquea: apertura de beta pública con usuarios reales
    │        │ No bloquea: trabajo documental y especificación
    │
    ├── [P-0 Y P-1 resueltos → desbloqueado despliegue con usuarios reales]
    │        │
    │        ▼
    │   T-3-001  Infraestructura de beta
    │        │
    │        ▼
    │   T-3-002  Telemetría dentro de D1
    │        │
    │        ▼
    │   T-3-003  Calibración de umbrales (requiere AR formal antes de implementar)
    │
    ├──► T-3-004  Observer semi-pasivo Android — Tile de sesión
    │            [BLOQUEADO hasta TS formal aprobada por Technical Architect
    │             y Privacy Guardian; puede especificarse en paralelo a T-3-001/002]
    │
    └──► T-3-005  LLM local opcional
                 [CONDICIONAL — requiere datos de beta de T-3-002/T-3-003
                  y decisión explícita del Orchestrator]
```

### B.1 Prerequisitos P-0 y P-1

El backlog declara correctamente que P-0 y P-1 son bloqueantes de la beta pública
con usuarios reales, pero no bloquean el trabajo documental, de especificación ni
la preparación de infraestructura (T-3-001, T-3-002 en su fase de preparación).
Esta distinción es coherente con el patrón ya establecido en PIR-003 y PIR-004.

El riesgo declarado en P-1 — que la implementación actual del FS Watcher no sea
realmente background-persistent en todos los entornos Windows — es el único camino
que podría requerir corrección antes de marcar PASS. El backlog lo nombra
explícitamente. Si se materializara, el responsable es el implementador de FS
Watcher en Fase 2 (fuera del scope de este backlog), no el QA Auditor.

**B.1: cadena de prerequisitos correctamente declarada.**

### B.2 Cadena T-3-001 → T-3-002 → T-3-003

La secuencia es necesaria y suficiente: T-3-001 establece la infraestructura base
sobre la que opera T-3-002; T-3-002 produce los datos que T-3-003 analiza. La
dependencia de T-3-003 en "al menos 10 usuarios activos durante al menos 2 semanas"
está correctamente declarada en los ACs como condición cuantitativa verificable,
no como estimación cualitativa.

**B.2: cadena secuencial verificable y con criterio cuantitativo de activación.**

### B.3 T-3-004 y T-3-005 como ramas independientes con bloqueos propios

T-3-004 puede especificarse (TS formal) en paralelo a T-3-001/T-3-002, pero su
implementación no puede comenzar hasta que la TS esté aprobada por Technical
Architect y Privacy Guardian. Esta distinción entre especificación e implementación
está correctamente recogida en el backlog.

T-3-005 no tiene una secuencia de preparación paralela: es completamente condicional
a datos de beta. La condición de activación —datos de T-3-002 y T-3-003 que
demuestren insuficiencia del baseline, más decisión explícita del Orchestrator— es
verificable y no delegable al implementador.

**B.3: ramas independientes con mecanismos de bloqueo correctos y distintos.**

---

## C. Verificación De Constraints Activos

### C.1 — D1: Solo domain/category en claro (url/title/filename/path prohibidos)

| Tarea | Prohibición D1 declarada | Verificable en AC |
| --- | --- | --- |
| T-3-002 Telemetría | Schema explícito: campos prohibidos declarados por tipo de evento | AC: "ningún campo contiene url, title, filename ni path" — verificable por inspección del módulo |
| T-3-002 Telemetría | Tabla `telemetry_events` sin columnas url/title | AC: "verificable por inspección del schema" |
| T-3-003 Calibración | Datos de análisis exclusivamente domain/category/trust_score/stability_score | AC: "ningún campo prohibido por D1" |
| T-3-004 Observer Android | Cifrado inmediato ≤ 500 ms en RAM antes de persistir | AC-8 de AR-CR-002: "ninguna query SQLCipher Android accede a url o title en claro" |
| T-3-005 LLM | Input del LLM exclusivamente domain/category | AC: "ningún campo contiene url ni title" |
| P-0 Relay E2E | Verificación de que url/title nunca expuestos en claro en el relay | AC: "datos en tránsito cifrados; url/title nunca expuestos en claro" |

El risk más probable de violación de D1 en Fase 3 es el campo de "contexto" o
"label" en telemetría T-3-002: un label de patrón generado por LLM sobre el título
de una URL podría derivar indirectamente de un campo prohibido. El backlog lo
nombra en la sección Risks de T-3-002 y la instrucción es clara: "verificar el
origen de cada campo antes de aprobar el schema". La revisión de Privacy Guardian
del schema antes de implementar es el control operativo que cierra este riesgo.

**D1: operativo en todas las tareas de Fase 3. Sin excepción declarada.**

### C.2 — D4: State Machine tiene autoridad; calibración ajusta parámetros, no lógica

El backlog de T-3-003 declara en Out of Scope:
- modificación de la lógica de transición de la State Machine
- eliminación de la condición doble (trust_score > umbral Y !user_blocked_pattern)
- delegación de autoridad de decisión a los datos o métricas

La distinción crítica está explícita en el objetivo de T-3-003: "la calibración
ajusta los parámetros de entrada de la State Machine [...]. No modifica la lógica
de transición, no le quita autoridad al módulo y no hace las transiciones
consultivas. La cadena canónica `detect_patterns → score_patterns →
evaluate_transition` no cambia de estructura."

El AC verifica: "la lógica de transición de la State Machine no ha sido modificada
— solo los valores de los parámetros de configuración". Este criterio es verificable
en code review por diff de `state_machine.rs`.

**D4: operativo. El boundary de autoridad está declarado y el AC es verificable.**

### C.3 — D8: Baseline determinístico sin LLM obligatorio

T-3-005 no puede activarse sin:
1. datos de beta de T-3-002 y T-3-003 que demuestren insuficiencia del baseline, Y
2. decisión explícita del Orchestrator documentada.

El AC de T-3-005 incluye: "Ollama se integra como proceso opcional: si no está
disponible, el sistema arranca y funciona con el baseline sin errores"; y "`cargo
test` pasa sin regresiones cuando Ollama está disponible Y cuando no lo está — ambos
escenarios verificados".

El riesgo de "activación implícita como dependencia" está declarado en T-3-005 Risks
y es el riesgo prioritario del constraint D8 en Fase 3.

**D8: operativo. T-3-005 está correctamente aislado como condicional.**

### C.4 — D9 revisado: background-persistent desktop; observer Android solo con Tile activo

**Desktop (D9 rev. 2026-04-28):** P-1 cierra la verificación de que el FS Watcher
implementado en Fase 2 es efectivamente background-persistent. El backlog no requiere
ningún cambio en FS Watcher — solo la verificación QA del escenario de background.

**Mobile (D9 extensión, AR-CR-002):** T-3-004 declara en Out of Scope:
- Accessibility Service (rechazado permanentemente)
- acceso a historial del navegador (rechazado permanentemente)
- handler declarado estáticamente en AndroidManifest (rechazado)
- observación en background sin tile activo

El constraint "el handler de captura debe registrarse dinámicamente al activar el
tile y desregistrarse al desactivarlo" está reflejado en el In Scope de T-3-004 y
en el AC correspondiente (AC-1 de AR-CR-002: "con tile OFF, ACTION_SEND no produce
ningún raw_event en SQLCipher Android"). La verificación del AndroidManifest como
punto de control está declarada en T-3-004 Risks.

**D9: operativo en ambas plataformas. Sin desviación detectada.**

### C.5 — D14: Privacy Dashboard no regresiona; nuevos mecanismos requieren representación

El backlog declara en Constraints Activos: "T-3-002 (telemetría) y T-3-004 (observer
Android) deben representarse en el Privacy Dashboard si añaden mecanismos visibles
al usuario."

T-3-002 incluye en su In Scope: "el Privacy Dashboard incluye sección 'Qué datos
se analizan' visible al usuario" y "control de activación visible para el usuario:
la telemetría debe poder desactivarse desde el Privacy Dashboard". El AC lo verifica.

T-3-004 incluye en su In Scope y ACs: "Privacy Dashboard mobile incluye la sección
del observer con estado, capturas, historial de activaciones y botón de purga
(PGR-CR-002, C2)" y "timeout automático configurable desde 5 minutos a 4 horas en
Privacy Dashboard (PGR-CR-002, C5)".

**D14: operativo. Representación en Privacy Dashboard declarada para cada nuevo
mecanismo de observación.**

### C.6 — D17: Pattern Detector cerrado desde Fase 2; no se reabre en Fase 3

El backlog declara en out_of_scope: "reescritura o revisión de Pattern Detector,
Trust Scorer ni State Machine (D17 — los módulos de Fase 2 están cerrados)". T-3-003
incluye en Out of Scope: "reapertura o modificación del algoritmo de Pattern
Detector (D17 — cerrado en Fase 2)".

El riesgo de reapertura "para ajustar el algoritmo" está explícitamente nombrado en
risks_of_misinterpretation del backlog. La distinción entre ajustar parámetros de
configuración (permitido en T-3-003) y modificar el algoritmo (prohibido por D17)
está claramente declarada.

**D17: operativo. La prohibición está declarada en backlog y en T-3-003.**

### C.7 — D22 + CR-002: T-3-004 es tier paid; requiere TS formal

El backlog declara T-3-004 como "tier: paid (D22 + CR-002)" y la nota de atención
al inicio de la sección es inequívoca: "T-3-004 está BLOQUEADO hasta que exista una
Task Spec (TS) formal aprobada por el Technical Architect y revisada por el Privacy
Guardian. La TS debe producirse como documento independiente antes de que cualquier
línea de código del observer Android sea escrita."

El AC verifica: "la TS formal existe como documento aprobado por Technical Architect
y revisado por Privacy Guardian antes de comenzar ninguna implementación". Este AC
es el primer criterio de la lista de T-3-004 — el bloqueo es estructural y no
salteble por el implementador.

**D22 + CR-002: operativos. El bloqueo de implementación es verificable y
pre-condición de todos los demás ACs de T-3-004.**

### C.8 — R12: Pattern Detector (longitudinal) ≠ Episode Detector (sesión)

El backlog aplica R12 en tres niveles de Fase 3:

**Nivel de telemetría (T-3-002):** "los eventos de telemetría deben segregar
explícitamente el origen de la señal: eventos generados por el Pattern Detector
(señales longitudinales) vs eventos generados por el Episode Detector (señales de
sesión)". El AC verifica: "los eventos de origen longitudinal y de sesión están
segregados en tipos de evento distintos — no se mezclan en ningún registro".

**Nivel de calibración (T-3-003):** "los datos usados para la calibración deben
segregar explícitamente las señales del Pattern Detector (longitudinales) de las
del Episode Detector (sesión). Los umbrales de la State Machine se calibran sobre
señales del Pattern Detector — nunca sobre señales de sesión del Episode Detector."
El AC verifica: "los datos de análisis declaran explícitamente la segregación de
origen R12".

**Nivel del observer Android (T-3-004):** el Episode Detector mobile es un módulo
separado (`episode_detector_mobile.rs` o configuración parametrizada); no modifica
ni hereda de `episode_detector.rs` desktop. El AC verifica: "`episode_detector.rs`
desktop no contiene ningún condicional de plataforma `#[cfg(target_os = "android")]`
(AC-6 de AR-CR-002)".

**R12: declarado en los tres vectores de riesgo de contaminación de Fase 3 y con
ACs verificables en cada uno.**

---

## D. Evaluación Individual De Tareas

### D.1 P-0 — Verificación E2E Relay OAuth (O-002)

Los ACs son verificables: el escenario de captura Android → desktop y el inverso
son ejecutables con credenciales OAuth reales. La condición "O-002 RESUELTO
documentado formalmente" cierra el prerequisito de forma trazable.

El riesgo de credenciales OAuth con permisos insuficientes o tokens expirados en
producción es el único vector técnico con probabilidad no trivial. El backlog lo
nombra. Su resolución depende del product owner (Orchestrator), no del enjambre de
agentes.

**Observación D.1:** el AC "datos en tránsito por Google Drive están cifrados (url
y title nunca expuestos en claro en el relay)" es funcional pero su verificación
requiere inspección del payload en tránsito, no solo el resultado visible en la UI.
El QA Auditor debe confirmar qué mecanismo de verificación usa (logs de red,
inspección del archivo en Drive antes de descifrado). Este punto no bloquea la
aprobación — es una aclaración de método de verificación que la TS de P-0 (si se
produce) o el documento de cierre deben especificar.

**P-0: APROBADO. ACs suficientes.**

### D.2 P-1 — Criterio #18 AR-2-007 Background-Persistent

Los ACs son verificables: el escenario exacto está definido (app pierde foco, se
produce evento de archivo, el evento queda en SQLCipher). La condición de PASS en
AR-2-007 criterio #18 escenario 3 es el cierre formal trazable.

El riesgo de que la implementación actual no sea realmente background-persistent
en todos los entornos Windows (EMUI, MIUI no aplica aquí, pero sí comportamientos
de gestión de procesos de Windows en versiones Pro vs Home) está nombrado. Si el
QA Auditor marca FAIL, el camino de corrección es el implementador de FS Watcher,
no una tarea nueva de Fase 3.

**P-1: APROBADO. ACs suficientes.**

### D.3 T-3-001 — Infraestructura De Beta

Los ACs cubren los dos vectores de riesgo más probables en distribución directa:
el proceso de sideload Android (con documentación de error más común: fuentes
desconocidas) y el instalador Windows (con condición de certificado de código válido
sin avisos de publicador desconocido).

El AC de builds — "`cargo test` al 100% + `npx tsc --noEmit` limpio sobre el build
de producción antes de distribuir" — es el control de regresión antes de que
usuarios reales tengan acceso al sistema.

**Observación D.3 (menor):** el backlog no especifica el canal de distribución
directa para los builds. "Canal de entrega seguro" es correcto en principio, pero
no nombra la solución concreta (Google Drive privado, enlace de descarga autenticado,
repositorio privado, etc.). Esto no es un gap arquitectónico — es un detalle
operativo que el Desktop Tauri Shell Specialist + Android Share Intent Specialist
pueden decidir al implementar. No requiere corrección en el backlog.

**T-3-001: APROBADO. ACs suficientes.**

### D.4 T-3-002 — Telemetría Dentro De D1

El schema de telemetría está declarado explícitamente en el backlog —seis tipos de
evento con campos permitidos y campos prohibidos por evento— lo que cumple el
requerimiento de OD-006 de que "el backlog declare el schema" y permite a Privacy
Guardian revisarlo antes de que comience la implementación.

La segregación R12 está declarada como obligatoria en el schema: eventos de origen
longitudinal (Pattern Detector) y de sesión (Episode Detector) en tipos distintos.
El control de activación desde Privacy Dashboard y la tabla `telemetry_events` en
SQLCipher (nunca en texto plano) cierran el contrato de privacidad a nivel de módulo.

El AC de revisión de Privacy Guardian como condición previa a implementación es el
control operativo más importante de T-3-002. Si este AC no se verifica antes de
implementar, todos los demás ACs de D1 en telemetría quedan sin el gate de entrada.
El backlog lo posiciona correctamente como primer AC de la lista.

**Observación D.4 (menor):** el campo `timestamp_bucket` (granularidad horaria, no
de minuto) en los eventos de telemetría reduce el riesgo de re-identificación por
timing. El backlog lo declara pero no especifica si esta granularidad es configurable
o fija. Se recomienda que la TS de T-3-002 lo fije como constante no configurable
por el implementador (solo modificable por decisión de Technical Architect), dado
que reducir la granularidad a minutos podría facilitar la correlación entre usuarios.
Esta observación no bloquea la aprobación del backlog.

**T-3-002: APROBADO. Schema declarado. ACs suficientes con revisión de Privacy
Guardian como condición de entrada.**

### D.5 T-3-003 — Calibración De Umbrales State Machine

Los ACs cubren la distinción D4 de forma verificable: "la lógica de transición de
la State Machine no ha sido modificada — solo los valores de los parámetros de
configuración" es verificable por diff de `state_machine.rs` en code review. El
requisito de "al menos 10 usuarios activos durante al menos 2 semanas" es el umbral
cuantitativo mínimo para que la propuesta de calibración tenga validez estadística.

La cadena de aprobación —análisis documentado → propuesta con justificación
cuantitativa → AR formal del Technical Architect → implementación → `cargo test`
sin regresiones— es completa y no deja espacio para que el implementador avance
a la implementación sin aprobación previa.

**T-3-003: APROBADO. ACs suficientes. La AR formal requerida antes de implementar
es el gate de entrada correcto.**

### D.6 T-3-004 — Observer Semi-Pasivo Android — Tile De Sesión

Los ACs de T-3-004 referencian los AC-1 a AC-12 de AR-CR-002 como criterios
canónicos, más los controles de privacidad de PGR-CR-002 (C1, C2, C5). Esta
estructura es correcta: los contratos del observer ya están definidos en AR-CR-002
y PGR-CR-002 y son más detallados que lo que un backlog puede declarar. La función
del backlog es declarar el scope y el bloqueo de implementación hasta TS formal.

El primer AC de T-3-004 — "la TS formal existe como documento aprobado por Technical
Architect y revisado por Privacy Guardian antes de comenzar ninguna implementación"
— es el control operativo que garantiza que todos los demás ACs se ejecutan sobre
un contrato de implementación formalmente aprobado, no sobre la interpretación del
implementador del backlog.

**Observación D.6 (acción requerida post-AR):** la TS formal de T-3-004 no existe
todavía como documento. Esta AR aprueba el backlog, lo que autoriza al Technical
Architect a producir la TS formal de T-3-004 en paralelo a T-3-001/T-3-002. La TS
debe traducir AR-CR-002 y PGR-CR-002 en criterios de implementación ejecutables,
con el mismo nivel de detalle que las TS de Fase 2. La TS de T-3-004 requiere
revisión del Privacy Guardian antes de ser usada como documento de implementación.

**T-3-004: APROBADO en backlog. BLOQUEADO para implementación hasta TS formal.**

### D.7 T-3-005 — LLM Local Opcional (Ollama)

Los ACs de T-3-005 solo aplican si la tarea ha sido activada por el Orchestrator.
El AC "existe una decisión explícita del Orchestrator documentada que autoriza
T-3-005 basada en datos de beta" es el primer criterio de la lista y es la
condición de activación de todos los demás.

Los tres riesgos declarados — activación sin datos, LLM recibiendo url/title, y
fallo de degradación graceful — cubren las tres vías de violación más probables de
D8 y D1. El AC de doble escenario en `cargo test` (Ollama disponible Y Ollama no
disponible) cierra el riesgo de degradación graceful con verificación determinística.

**T-3-005: APROBADO. CONDICIONAL hasta decisión explícita del Orchestrator.**

---

## E. Verificación De Criterios Del Gate De Salida De Fase 3

| Condición mínima (phase-gates.md) | Estado en backlog | Verificable |
| --- | --- | --- |
| beta y métricas quedan definidas sin reescribir el caso núcleo | T-3-001 + T-3-002 cubren beta e infraestructura; backlog declara explícitamente que no añade paneles nuevos ni reescribe módulos de Fase 2 | sí |
| los objetivos de calibración de umbrales son explícitos | T-3-003 declara MIN_PATTERNS, THRESHOLD_LOW, THRESHOLD_HIGH como objetivos de calibración con justificación cuantitativa requerida | sí |
| el LLM sigue siendo opcional | T-3-005 condicional; baseline funciona sin LLM; AC doble escenario | sí |

| Condición de no-paso (phase-gates.md) | Riesgo presente en backlog | Blindaje |
| --- | --- | --- |
| beta depende de componentes aún no aceptados | P-0 y P-1 identificados como prerequisitos bloqueantes | sí — P-0 y P-1 deben cerrarse antes de beta pública |
| la medición exige telemetría fuera del marco de privacidad aprobado | schema de T-3-002 declarado; revisión Privacy Guardian como AC #1 | sí — ningún evento incluye url/title; revisión previa a implementación |
| los objetivos de calibración de umbrales no están documentados con datos reales | T-3-003 requiere análisis de distribuciones documentado formalmente y AR formal | sí |
| el LLM se ha convertido en dependencia implícita del sistema | T-3-005 CONDICIONAL; `cargo test` ambos escenarios | sí |

**Veredicto E: el backlog satisface todas las condiciones mínimas del gate de Fase 3
y blinda las cuatro condiciones de no-paso con mecanismos verificables.**

---

## F. Observaciones De Diseño

### F.1 Tamaño mínimo de muestra en T-3-003

El umbral de "al menos 10 usuarios activos durante al menos 2 semanas" es el mínimo
declarado para validar estadísticamente la propuesta de calibración. Este umbral
proviene del backlog y no está respaldado por un análisis formal de potencia
estadística. En la práctica, con distribuciones de patrones que probablemente
tienen alta varianza entre usuarios (diferentes dominios de trabajo, diferentes
cadencias), 10 usuarios pueden ser insuficientes para detectar diferencias
significativas en MIN_PATTERNS.

Esta observación no bloquea el backlog — el umbral mínimo es el que garantiza que
el análisis puede empezarse; el Technical Architect evaluará en la AR de T-3-003
si los datos son estadísticamente suficientes para la propuesta concreta antes de
aprobar cambios. El mecanismo de gate doble (datos suficientes + AR formal) es
adecuado.

### F.2 Schema de telemetría y aggregación sin identificador de sesión persistente

El backlog menciona el riesgo de identificadores de sesión que permitan correlacionar
comportamientos individuales y recomienda "identificadores de sesión efímeros o
contadores sin correlación entre sesiones". La TS de T-3-002 debe especificar
explícitamente el mecanismo: un UUID de sesión generado en arranque y descartado
al cerrar la app (sin persistir en SQLCipher) es el modelo canónico que satisface
este requerimiento.

### F.3 Certificado de código Windows en T-3-001

El riesgo de que el certificado de código para Windows no esté disponible a tiempo
es un riesgo operativo con impacto directo en la experiencia del beta tester:
un instalador con aviso de "publicador desconocido" genera desconfianza y abandono
en el proceso de instalación. El backlog lo nombra correctamente. La resolución
depende del product owner antes de que T-3-001 pueda completar su AC de instalador
firmado.

### F.4 Segregación de datos tier free vs tier paid en SQLCipher (T-3-004)

El In Scope de T-3-004 incluye "etiquetado en SQLCipher para separar datos del tier
paid (observer) de datos del tier free (Share Intent) — purga independiente". Este
etiquetado es un requisito de privacidad relevante (PGR-CR-002, Condición 5) que
afecta al esquema de la base de datos Android. La TS formal de T-3-004 debe declarar
el schema concreto de este etiquetado (columna adicional en `raw_events`, tabla
separada, o prefix en la clave primaria) para que el Privacy Guardian pueda
verificarlo antes de la implementación.

---

## G. Correcciones

**Ninguna.** El backlog no requiere correcciones antes de su aprobación. Las
observaciones de las secciones D y F son aclaraciones de diseño para las TS
subsiguientes y no afectan a la coherencia arquitectónica del backlog ni a los
constraints D1 o D9 (que son los únicos que justificarían bloqueo de aprobación).

---

## H. Hallazgos

| Tipo | Descripción | Referencia | Acción |
| --- | --- | --- | --- |
| PASS | Coherencia con OD-006: todos los entregables y prerequisitos de OD-006 recogidos en el backlog | sección A | ninguna |
| PASS | D1: schema de telemetría declarado sin url/title/filename/path; campo de origen del label como riesgo nombrado | T-3-002, T-3-003, T-3-004, T-3-005 | Privacy Guardian revisa schema antes de implementar T-3-002 |
| PASS | D4: calibración ajusta parámetros de configuración; Out of Scope prohibe modificar lógica de transición; AC verificable por diff | T-3-003 | ninguna |
| PASS | D8: T-3-005 CONDICIONAL con doble condición de activación; AC de doble escenario en cargo test | T-3-005 | ninguna |
| PASS | D9: P-1 cierra verificación background-persistent desktop; T-3-004 declara handler dinámico y Out of Scope correcto | P-1, T-3-004 | ninguna |
| PASS | D14: representación en Privacy Dashboard declarada para telemetría (T-3-002) y observer Android (T-3-004) | T-3-002, T-3-004 | ninguna |
| PASS | D17: Pattern Detector cerrado en Fase 2; T-3-003 distingue calibración de parámetros vs reapertura de algoritmo | T-3-003, out_of_scope | ninguna |
| PASS | D22 + CR-002: T-3-004 tier paid con TS formal bloqueante como AC #1 | T-3-004 | ninguna |
| PASS | R12: segregación declarada en telemetría (T-3-002), calibración (T-3-003) y observer Android (T-3-004) con ACs verificables | sección C.8 | ninguna |
| PASS | Gate de Fase 3: condiciones mínimas satisfechas; cuatro condiciones de no-paso blindadas | sección E | ninguna |
| OBSERVACIÓN | P-0: método de verificación de cifrado en tránsito debe especificarse en documento de cierre | D.1 | QA Auditor especifica método en documento de cierre O-002 |
| OBSERVACIÓN | T-3-002: timestamp_bucket recomendado como constante no configurable por implementador | D.4 | TS de T-3-002 fija granularidad horaria como constante |
| OBSERVACIÓN | T-3-002: UUID de sesión efímero (no persistido) recomendado como mecanismo de agregación sin correlación | F.2 | TS de T-3-002 especifica mecanismo |
| OBSERVACIÓN | T-3-004: schema de etiquetado tier free/paid en SQLCipher Android debe declararse en TS formal | F.4 | TS de T-3-004 (Technical Architect) declara schema |
| ACCIÓN POST-AR | TS formal de T-3-004 debe producirse en paralelo a T-3-001/T-3-002 | D.6 | Technical Architect + Privacy Guardian |

---

## I. Bloqueos

**Ninguno.** El backlog queda aprobado sin bloqueos. Los bloqueos de implementación
son internos a las tareas (T-3-004 hasta TS formal; T-3-005 hasta decisión
Orchestrator) y están correctamente declarados en el backlog.

---

## J. Solicitud Resultante

**backlog-phase-3.md queda APROBADO por esta AR.**

El status del backlog debe actualizarse de "PENDIENTE DE APROBACIÓN — Technical
Architect" a "APROBADO — AR-3-001 (2026-04-28)".

**Siguiente paso inmediato:**

1. **Desktop Tauri Shell Specialist + Android Share Intent Specialist** pueden
   comenzar T-3-001 una vez que P-0 y P-1 estén en progreso (no bloqueados por
   la AR — la AR estaba pendiente). T-3-001 puede prepararse; el despliegue con
   usuarios reales espera a que P-0 y P-1 cierren.

2. **Technical Architect** debe producir la TS formal de T-3-004 en paralelo al
   inicio de T-3-001/T-3-002. La TS traduce AR-CR-002 y PGR-CR-002 en criterios
   de implementación ejecutables. La TS requiere revisión del Privacy Guardian
   antes de usarse como documento de implementación.

3. **Privacy Guardian** revisa el schema de telemetría de T-3-002 (declarado en
   el backlog) antes de que el Desktop Tauri Shell Specialist comience la
   implementación de `telemetry.rs`.

---

## K. Trazabilidad De Entregable

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado | operations/backlogs/backlog-phase-3.md | APROBADO — status debe actualizarse |
| Revisado | operations/orchestration-decisions/OD-006-phase-3-activation.md | conforme |
| Revisado | operating-system/phase-gates.md | gate de Fase 3 verificado |
| Revisado | Project-docs/decisions-log.md | D1, D4, D8, D9, D14, D17, D19, D22, R12 verificados |
| Creado | operations/architecture-reviews/AR-3-001-phase-3-backlog-review.md | este documento |
| Pendiente | operations/task-specs/TS-3-004-observer-android.md | Technical Architect produce en paralelo a T-3-001/T-3-002 |

---

## Firma

Technical Architect
AR-3-001 — 2026-04-28
Estado: APROBADO
