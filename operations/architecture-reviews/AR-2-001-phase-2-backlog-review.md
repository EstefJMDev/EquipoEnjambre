# Revisión Arquitectónica — Backlog Fase 2

document_id: AR-2-001
owner_agent: Technical Architect
phase: 2
date: 2026-04-24
status: APROBADO CON DECISIÓN — un punto abierto resuelto; sin bloqueos; sin correcciones
documents_reviewed:
  - operations/backlogs/backlog-phase-2.md
  - operations/orchestration-decisions/OD-004-phase-2-activation.md
reference_normativo:
  - Project-docs/decisions-log.md (D1, D4, D5, D8, D9, D14, D17)
  - Project-docs/risk-register.md (R12 WATCH ACTIVO)
  - operations/architecture-reviews/AR-1-001-panel-b-review.md
precede_a: implementación en paralelo de T-2-000 (Functional Analyst) + T-2-001 (Desktop Tauri Shell Specialist)

---

## Objetivo De Esta Revisión

Esta revisión es pre-implementación. Verifica que los contratos de los cuatro módulos
nuevos de Fase 2 (Pattern Detector, Trust Scorer, State Machine, Privacy Dashboard
completo) son arquitectónicamente coherentes entre sí y con las decisiones cerradas.

El backlog-phase-2.md deja un punto abierto explícito para el Technical Architect:
la persistencia de patrones durante T-2-001. Esta AR lo resuelve como decisión formal.

Ninguna implementación puede comenzar hasta que esta AR confirme la coherencia
de contratos. La aprobación de la delimitación de FS Watcher (T-2-000) es
responsabilidad del Technical Architect cuando el Functional Analyst entregue
el documento.

---

## Resultado Global

| Módulo | Resultado | Bloqueos | Correcciones |
| --- | --- | --- | --- |
| T-2-000 Delimitación FS Watcher | APROBADO para producir | ninguno | ninguna |
| T-2-001 Pattern Detector | APROBADO con decisión de persistencia | ninguno | ninguna |
| T-2-002 Trust Scorer | APROBADO | ninguno | ninguna |
| T-2-003 State Machine | APROBADO | ninguno | ninguna |
| T-2-004 Privacy Dashboard completo | APROBADO | ninguno | ninguna |
| Cadena de dependencias | APROBADA | ninguno | ninguna |

El backlog-phase-2.md queda aprobado para implementación a partir de esta AR.

---

## A. Verificación De La Cadena De Contratos

La cadena de módulos de Fase 2 produce y consume los siguientes tipos:

```
storage.rs (SQLCipher)
    domain, category, captured_at  [campos en claro — D1]
         │
         ▼
pattern_detector.rs  →  Vec<DetectedPattern>
         │
         ▼
trust_scorer.rs  →  Vec<TrustScore>
         │
         ▼
state_machine.rs  →  TrustState
         │
         ▼  (+ Vec<DetectedPattern> directo)
PrivacyDashboard.tsx
```

### A.1 Coherencia DetectedPattern → TrustScore

Trust Scorer necesita de cada DetectedPattern los siguientes campos para calcular
`trust_score = f(frequency, recency_weight, temporal_coherence)`:

| Campo de DetectedPattern | Uso en Trust Scorer | Declarado en backlog |
| --- | --- | --- |
| `frequency: usize` | factor de frecuencia en trust_score | ✅ |
| `first_seen: i64` + `last_seen: i64` | base de recency_weight | ✅ |
| `temporal_window` | factor de coherencia temporal | ✅ |
| `pattern_id: UUID` | referencia cruzada en TrustScore | ✅ |

Trust Scorer no necesita `category_signature` ni `domain_signature` — esos campos
los consume el Privacy Dashboard directamente. La separación es correcta: Trust
Scorer trabaja sobre métricas cuantitativas; el contenido semántico del patrón
es transparente para el scorer. El acoplamiento es mínimo e intencional.

**Veredicto A.1: contrato DetectedPattern → TrustScore coherente y sin acoplamiento innecesario.**

### A.2 Coherencia TrustScore → State Machine

La condición de transición doble (D4) requiere:

```
Observing → Learning: pattern_count >= MIN_PATTERNS && trust_score > THRESHOLD_LOW
Learning → Trusted:   trust_score > THRESHOLD_HIGH && !user_blocked
Trusted → Autonomous: solo acción explícita del usuario (nunca automática)
```

State Machine necesita de cada TrustScore:

| Campo de TrustScore | Uso en State Machine | Declarado en backlog |
| --- | --- | --- |
| `trust_score: f64` | comparación con THRESHOLD_LOW y THRESHOLD_HIGH | ✅ |
| `pattern_id: UUID` | verificar `!user_blocked_pattern` por patrón | ✅ |
| `confidence_tier` | optimización opcional del cálculo de umbrales | ✅ |

La autoridad reside en la State Machine: tiene el estado, evalúa ambas condiciones
y determina la transición. Trust Scorer produce scores y no llama a ningún método
de transición. El boundary D4 es implementable con estos contratos.

**Veredicto A.2: contrato TrustScore → State Machine coherente. D4 implementable.**

### A.3 Coherencia TrustState + Vec<DetectedPattern> → Privacy Dashboard

Privacy Dashboard (T-2-004) consume dos fuentes:

**TrustState** (de T-2-003): `current_state`, `available_transitions`,
`active_patterns_count`, `last_transition_at` — todos declarados en el backlog de
T-2-003. Ningún campo contiene url ni title. D1 operativo en TrustState.

**Vec<DetectedPattern>** (de T-2-001): `label`, `category_signature`,
`domain_signature`, `frequency`, `last_seen` — todos campos en claro (D1).
El dashboard puede renderizar estos campos sin procesamiento adicional.

**Veredicto A.3: Privacy Dashboard puede construirse sobre los contratos declarados.
Los dos inputs son suficientes para las tres secciones del dashboard.**

---

## B. Verificación De Separación R12 — Pattern Detector vs Episode Detector

OD-004 extiende R12 WATCH ACTIVO a Fase 2. El backlog-phase-2.md declara la
distinción en tres niveles:

1. **risks_of_misinterpretation** (nivel de backlog): "extender episode_detector.rs
   para hacer Pattern Detector 'gradualmente' viola R12".
2. **In Scope de T-2-001**: exige módulo `pattern_detector.rs` independiente de
   `episode_detector.rs`.
3. **Acceptance Criteria de T-2-001**: "pattern_detector.rs existe como módulo
   independiente y no importa desde episode_detector.rs" + "el módulo declara
   explícitamente en comentario de cabecera la distinción Pattern Detector vs
   Episode Detector (R12)".

La distinción semántica está correctamente definida:

| Dimensión | Episode Detector | Pattern Detector |
| --- | --- | --- |
| Unidad de análisis | sesión activa | historial completo |
| Escala temporal | tiempo real (minutos) | días/semanas |
| Persistencia | no persiste estado | persiste patrones detectados |
| Input | recursos de la sesión actual | domain/category/captured_at de SQLCipher |
| Output | Episode (grupos por sesión) | DetectedPattern (firma longitudinal) |
| Trigger | evento de sesión | análisis bajo demanda desde commands.rs |

El criterio "no importa desde episode_detector.rs" es verificable en `cargo check`.
Compartir utilidades de cálculo (funciones matemáticas, helpers de fechas) es
aceptable; importar tipos o lógica de detección de episode_detector.rs no lo es.

**R12: separación correctamente declarada en backlog y verificable en criterios de
aceptación. No requiere corrección adicional en backlog.**

---

## C. Verificación De Constraints Activos

### C.1 — D1: Solo domain/category en claro (url/title prohibidos)

| Módulo | Prohibición declarada | Verificable en AC |
| --- | --- | --- |
| T-2-001 Pattern Detector | "solo lee domain, category, captured_at — ninguna query accede a url ni title" | ✅ AC: "el módulo solo lee domain, category, captured_at" |
| T-2-002 Trust Scorer | "Acceso a url o title (D1)" en Out of Scope | ✅ Trust Scorer recibe Vec<DetectedPattern> — no accede a SQLCipher directamente |
| T-2-003 State Machine | "exposición de url o title en ningún campo de TrustState (D1)" en Out of Scope | ✅ TrustState no tiene campos que deriven de url/title |
| T-2-004 Privacy Dashboard | declarado en In Scope, AC y Risks | ✅ AC: "ningún campo expone url ni title"; sección "Qué no veo nunca" es criterio de aceptación |

**D1: operativo en todos los módulos de Fase 2. Sin excepción.**

### C.2 — D4: State Machine tiene autoridad; Trust Scorer no toma decisiones

El backlog de T-2-002 declara en Out of Scope: "toma de decisiones de acción
(ese rol es exclusivo de la State Machine — D4)". El riesgo nombrado es explícito:
"Trust Scorer exponga un método `recommend_action()` o similar — viola D4".

El backlog de T-2-003 establece la doble condición de transición que D4 exige:
- factor 1: trust_score > umbral (producido por Trust Scorer)
- factor 2: !user_blocked_pattern (estado interno de la State Machine)

Ambas condiciones deben cumplirse. Trust Scorer produce inputs; la decisión
de transición la evalúa y ejecuta la State Machine.

**D4: correcto. El boundary de autoridad está declarado en ambos módulos.**

### C.3 — D5: Slot concentration score con entropía normalizada (0–1)

El backlog de T-2-002 declara: "stability_score usando la fórmula D5: slot
concentration score con entropía normalizada — acotado estrictamente entre 0.0 y 1.0".
El AC verifica: "stability_score usa entropía normalizada como define D5 y nunca
supera 1.0 ni baja de 0.0".

La fórmula exacta está en decisions-log.md (D5). El backlog referencia correctamente
D5 como fuente autoritativa. El implementador de T-2-002 debe leer decisions-log.md
antes de escribir la función de entropía. El AC garantiza el rango en test.

**D5: referencia correcta. Fuente: decisions-log.md (D5).**

### C.4 — D8: Baseline determinístico sin LLM obligatorio

| Módulo | Baseline declarado | LLM |
| --- | --- | --- |
| T-2-001 | frecuencia de co-ocurrencia en ventanas temporales | mejora opcional — declarar en TS |
| T-2-002 | trust_score = f(frequency, recency_weight, temporal_coherence) — todos determinísticos | mejora opcional — declarar en TS |
| T-2-003 | lógica de transición de estados (pura — sin inferencia) | no aplica |
| T-2-004 | renderizado de datos existentes | no aplica |

La declaración "declarar explícitamente en TS si se añade" obliga a que ningún
LLM entre silenciosamente como dependencia. El baseline es verificable sin
modelo local: los tests de T-2-001 y T-2-002 usan datos sintéticos determinísticos.

**D8: correcto en todos los módulos.**

### C.5 — D9: FS Watcher es el único módulo que introduce observación activa

Pattern Detector, Trust Scorer y State Machine no introducen observación activa:
- Pattern Detector lee de SQLCipher bajo demanda explícita desde commands.rs.
- Trust Scorer recibe Vec<DetectedPattern> como input; no lanza procesos.
- State Machine persiste y expone estado; no tiene timers ni watchers.

FS Watcher está contenido en T-2-000 (delimitación documental) y su implementación
bloqueada hasta aprobación de T-2-000 por el Technical Architect.

**D9: operativo. El backlog out_of_scope incluye: "background monitoring sin
consentimiento activo del usuario".**

### C.6 — D14: Privacy Dashboard completo obligatorio antes de beta

T-2-004 tiene campo `prerequisite_of: Fase 3 (D14 — obligatorio antes de beta)`.
La cadena de dependencias garantiza que T-2-004 no puede completarse hasta que
T-2-001 y T-2-003 estén implementados.

**D14: satisfecho en estructura de dependencias.**

### C.7 — D17: Pattern Detector completo en Fase 2

El backlog de T-2-001 define el módulo completo. No hay cláusula de "implementación
parcial" ni postergación de algún componente a Fase 3.

**D17: correcto.**

---

## D. Decisión Formal — Persistencia De Patrones En T-2-001

El backlog de T-2-001 deja abierto: "guardar patrones en tablas SQLCipher en
esta tarea (la persistencia puede ser en memoria hasta que T-2-002 valide la
estructura de datos — el Technical Architect decide en AR)".

**Decisión**: Pattern Detector NO persiste patrones en SQLCipher durante T-2-001.

**Razón**: el esquema de tabla de patrones depende de qué campos de DetectedPattern
necesita Trust Scorer exactamente para sus cálculos de entropía y recencia. Si
T-2-002 ajusta el contrato de DetectedPattern, el esquema en SQLCipher requeriría
una migración inmediata. Diferir la persistencia hasta la AR de T-2-002 elimina
ese riesgo sin coste funcional: en esta fase no hay otro módulo que necesite leer
patrones persistidos entre sesiones.

**Implicaciones para el implementador de T-2-001**:
- `detect_patterns()` retorna `Vec<DetectedPattern>` desde memoria.
- Si se expone el comando Tauri `get_detected_patterns`, devuelve el resultado
  del último análisis en sesión — no persiste entre reinicios.
- No se crean tablas SQLCipher para patrones en T-2-001.
- El diseño del esquema de persistencia de patrones es entregable documental
  del AR de T-2-002 (AR-2-002), emitido después de que Trust Scorer valide
  la estructura de DetectedPattern.

**Esta decisión cierra el único punto abierto del backlog-phase-2.md.**

---

## E. Verificación De Dependencias Estrictas

| Dependencia | Declarada en backlog | Mecanismo de garantía |
| --- | --- | --- |
| T-2-001 antes de T-2-002 | sí | AC de T-2-002: "dado un Vec<DetectedPattern> sintético" — sin T-2-001 aprobado, la integración no tiene input real |
| T-2-002 antes de T-2-003 | sí | AC de T-2-003: "dado un Vec<TrustScore> sintético" — sin T-2-002 aprobado, la máquina no tiene scores reales |
| T-2-001 + T-2-003 antes de T-2-004 | sí | T-2-004 consume get_detected_patterns + get_trust_state — sin los dos módulos no hay datos que renderizar |
| T-2-000 antes de implementación FS Watcher | sí | declarado en out_of_scope del backlog y reforzado en esta AR |

**Cadena de dependencias verificada y aplicable. No hay path de implementación
paralela que no esté explícitamente autorizado en el backlog.**

---

## F. Correcciones

**Ninguna.**

---

## G. Hallazgos

| Tipo | Descripción | Referencia | Acción |
| --- | --- | --- | --- |
| PASS | Cadena de contratos coherente de extremo a extremo: DetectedPattern → TrustScore → TrustState | backlog-phase-2.md sección A | ninguna |
| PASS | D1: ningún módulo accede a url/title en inputs, outputs ni campos de persistencia | T-2-001, T-2-002, T-2-003, T-2-004 | ninguna |
| PASS | D4: Trust Scorer produce scores; State Machine tiene autoridad exclusiva sobre transiciones | T-2-002, T-2-003 | ninguna |
| PASS | D5: stability_score referenciado correctamente; fórmula en decisions-log.md | T-2-002 | ninguna |
| PASS | D8: baseline determinístico declarado en todos los módulos; LLM explícitamente opcional | T-2-001, T-2-002 | ninguna |
| PASS | D9: ningún módulo nuevo introduce observación activa en background | backlog out_of_scope | ninguna |
| PASS | D14: T-2-004 declarado como prerequisito bloqueante de Fase 3 | T-2-004 | ninguna |
| PASS | D17: Pattern Detector completo en Fase 2 sin partición entre fases | T-2-001 | ninguna |
| PASS | R12: distinción Pattern Detector / Episode Detector declarada en backlog y verificable en AC de T-2-001 | T-2-001 | ninguna |
| PASS | Cadena de dependencias estricta: T-2-001 → T-2-002 → T-2-003; T-2-001+T-2-003 → T-2-004 | backlog, sección E | ninguna |
| DECISIÓN | T-2-001 no persiste patrones en SQLCipher. Esquema definido en AR-2-002 (post T-2-002) | sección D | cierra punto abierto del backlog |
| OBSERVACIÓN | State Machine persiste solo current_state en SQLCipher (una fila). Esquema simple: current_state (TEXT), last_transition_at (INTEGER). No requiere campos cifrados — D1 operativo | T-2-003 | no requiere corrección |

---

## H. Bloqueos

**Ninguno.**

---

## I. Siguiente Agente Responsable

**T-2-000**: Functional Analyst. Puede comenzar inmediatamente. Entrega al Technical
Architect para aprobación antes de cualquier implementación de FS Watcher.

**T-2-001**: Desktop Tauri Shell Specialist. Puede comenzar en paralelo a T-2-000.

El backlog-phase-2.md queda APROBADO por esta AR. El Desktop Tauri Shell Specialist
debe leer antes de implementar:

- `operations/backlogs/backlog-phase-2.md` — contrato completo de T-2-001
- `operations/architecture-reviews/AR-2-001-phase-2-backlog-review.md` — esta AR
  (decisión de persistencia en sección D)
- `Project-docs/decisions-log.md` — D1, D4, D5, D8, D9
- `operations/architecture-reviews/AR-1-001-panel-b-review.md` — referencia de
  cómo se cumplió D1/D8/D9 en Fase 1

---

## J. Trazabilidad De Entregable

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado | operations/backlogs/backlog-phase-2.md | APROBADO — status actualizado |
| Creado | operations/architecture-reviews/AR-2-001-phase-2-backlog-review.md | este documento |
