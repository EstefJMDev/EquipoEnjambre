# Orchestration Decision

## OD-006 — Cierre Formal De Fase 2 Y Apertura De Fase 3

document_id: OD-006
date: 2026-04-28
issued_by: Orchestrator
status: APPROVED
referenced_pir: PIR-005-phase-2-gate.md
referenced_handoff: HO-020-phase-2-ho-fw-pd-close.md

---

## Issue

HO-020 aprobado por el Orchestrator el 2026-04-28 confirma que el último
entregable de Fase 2 está completo: `FsWatcherSection.tsx` ha sido creado e
integrado en `PrivacyDashboard.tsx`. D14 (Privacy Dashboard completo antes de
beta) queda completamente satisfecho. La cadena de entregables T-2-000 →
T-2-001 → T-2-002 → T-2-003 → T-2-004 está cerrada y verificada.

PIR-005 confirma que el gate de salida de Fase 2 está pasado: las tres
condiciones mínimas están satisfechas (escalera de confianza unida al roadmap,
Privacy Dashboard completo definido, lógica longitudinal sin romper la
narrativa de privacidad) y ninguna condición de no-paso ha sido activada.

Fase 2 ha validado lo que debía validar:
- aprendizaje longitudinal con control del usuario
- escalera de confianza progresiva (Pattern Detector → Trust Scorer → State Machine)
- tolerancia del usuario a automatización progresiva documentada como hipótesis
  a medir en Fase 3
- Privacy Dashboard completo antes de beta, con visibilidad y control sobre
  todos los mecanismos de observación de Fase 2

La `phase-definition.md` y el roadmap definen Fase 3 como beta pública con:
- validación con usuarios reales externos
- métricas de aceptación de sugerencias automáticas
- calibración de umbrales de la State Machine con datos reales
- evaluación de tolerancia real a la automatización progresiva
- LLM local como mejora opcional, no requisito (D8 sigue activo)
- telemetría dentro del marco de privacidad aprobado (D1 sigue activo)

---

## Affected Phase

3

## Agents Involved

| Agente | Rol en Fase 3 |
| --- | --- |
| Orchestrator | Emite esta OD; coordina el ciclo; valida go/no-go del gate de salida |
| Functional Analyst | Produce backlog-phase-3.md con T-3-001 a T-3-00N |
| Technical Architect | Revisa nuevos contratos: telemetría, calibración, observer Android (T-3-004) |
| QA Auditor | Completa criterio #18 AR-2-007 (prerequisito heredado); verifica nuevos entregables |
| Privacy Guardian | Audita telemetría (D1 estricto en métricas); revisa TS del observer Android (CR-002) |
| Phase Guardian | Vigilancia de condiciones de no-paso del gate de Fase 3 |
| Desktop Tauri Shell Specialist | Implementación desktop (T-3-001, T-3-002, T-3-003, T-3-005 si aplica) |
| Android Share Intent Specialist | Implementación observer Android (T-3-004) |

---

## Decision

1. El gate de salida de Fase 2 queda **cerrado como PASADO** a partir de esta
   decisión. Fase 2 (aprendizaje longitudinal, escalera de confianza, Privacy
   Dashboard completo) queda formalmente completada.

2. El repositorio del producto queda autorizado para el ciclo de Fase 3 a
   partir de esta decisión.

3. Dos **prerequisitos heredados de fases anteriores** bloquean el inicio de
   la beta pública con usuarios reales. Ambos deben resolverse antes de que
   haya usuarios externos en el sistema:

   a. **O-002 (heredado de PIR-004, Fase 0c):** verificación E2E del relay
      bidireccional con credenciales OAuth de Google Drive activas (captura
      desktop → galería móvil). Registrado como prerequisito bloqueante de
      beta pública en PIR-004 §"Condiciones vivas" y en OD-005. Sin O-002
      verificado, no puede desplegarse ningún usuario real con relay activo.
      Responsable: Orchestrator / product owner.

   b. **Criterio #18 AR-2-007 escenario 3 actualizado (heredado de Fase 2):**
      el QA Auditor debe ejecutar y pasar el escenario background-persistent
      del FS Watcher (evento DEBE estar presente tras pérdida de foco, conforme
      a la revisión de D9 registrada el 2026-04-28 en decisions-log.md commit
      64294e4). El escenario 3 original ("buffer se purga al perder el foco")
      fue superado por la decisión de FS Watcher background-persistent. AR-2-007
      criterio #18 escenario 3 debe actualizarse y marcarse PASS antes del gate
      de Fase 3. Responsable: QA Auditor.

   Estos prerequisitos no bloquean la producción del backlog ni las tareas de
   infraestructura y telemetría. Solo bloquean la beta pública propiamente dicha.

4. El orden orientativo de entregables de Fase 3 sigue la cadena de dependencias
   del roadmap:

   ```
   Prerequisitos heredados (resolver antes de beta pública):
     O-002       — relay E2E verificado con OAuth activo
     AR-2-007 #18 escenario 3 — QA FS Watcher background-persistent

   Entregables orientativos:
   T-3-001  Infraestructura de beta (onboarding, distribución)
   T-3-002  Telemetría dentro de D1 (métricas de uso anónimas: solo domain/category)
   T-3-003  Calibración de umbrales State Machine con datos reales
            (MIN_PATTERNS, THRESHOLD_LOW, THRESHOLD_HIGH)
   T-3-004  Observer semi-pasivo Android — Tile de sesión (D9 extensión / CR-002)
            [Feature paid — requiere TS formal aprobada por Technical Architect
            y Privacy Guardian antes de implementar]
   T-3-005  LLM local opcional (Ollama) — mejora sobre baseline determinístico
            [No es requisito; se activa solo si el baseline es insuficiente en
            beta con datos reales]
   ```

   La numeración es orientativa. El Functional Analyst define el orden definitivo,
   las dependencias exactas y los criterios de aceptación en backlog-phase-3.md.

5. Ninguna implementación de Fase 3 puede introducirse sin backlog aprobado.
   T-3-004 (observer Android) requiere además TS formal aprobada por Technical
   Architect y revisada por Privacy Guardian antes de cualquier implementación.
   T-3-005 (LLM local) requiere decisión explícita del Orchestrator basada en
   datos de beta antes de activarse.

6. La calibración de umbrales (T-3-003) no da autoridad a datos o a métricas
   sobre la State Machine. La State Machine mantiene autoridad de decisión (D4).
   La calibración ajusta los parámetros de entrada; el contrato de autoridad
   del módulo no se toca.

7. El track iOS (Share Extension + Sync Layer, Fase 0b/0c) sigue abierto como
   track paralelo. Su condición de activación permanece supeditada a
   disponibilidad de entorno macOS. No interfiere con el gate de Fase 3.

8. D22 (freemium mobile) y CR-002 (observer semi-pasivo Android) están aprobados
   en intención. T-3-004 es la materialización técnica de esta decisión en Fase 3.
   Hasta que la TS de T-3-004 esté aprobada, no existe autorización de
   implementación para el observer Android.

---

## Rationale

Fase 3 puede abrirse porque:

- El gate de Fase 2 está pasado con evidencia real: 58 tests Rust sin
  regresión, TypeScript limpio, Privacy Dashboard completo con FsWatcherSection
  integrada, verificación visual manual confirmada por el Orchestrator
  (2026-04-28, HO-020 §"Verificación").
- D14 satisfecho íntegramente: el Privacy Dashboard cubre los dos mecanismos
  de observación de Fase 2 (Share Intent móvil + FS Watcher desktop) más
  patrones y estado de confianza.
- Ninguna condición de no-paso del gate formal de Fase 2 (phase-gates.md) ha
  sido activada.

Los prerequisitos heredados (O-002, criterio #18) no bloquean la apertura del
ciclo de Fase 3 por el mismo patrón ya establecido en PIR-003 (gate de Fase 1)
y PIR-004 (gate de Fase 0c): las condiciones pendientes no son defectos de
implementación — son limitaciones de entorno de test y actualizaciones de
documentación QA. Bloquean únicamente la beta pública, no el ciclo documental
y de especificación de Fase 3.

La distinción entre telemetría y datos de usuario (D1) es no negociable en
Fase 3. Ninguna métrica puede exponer url ni title; solo domain y category en
claro. El backlog-phase-3.md debe declarar explícitamente el schema de cada
métrica y someterla a revisión de Privacy Guardian antes de implementar.

---

## Constraints Respected

- **D1:** telemetría de beta opera exclusivamente sobre domain y category en
  claro. Nunca url, title, ruta completa ni nombre de archivo. El Functional
  Analyst debe declarar el schema de telemetría en backlog-phase-3.md; el
  Privacy Guardian lo revisa antes de que T-3-002 se implemente.

- **D4:** la calibración de umbrales en T-3-003 ajusta los parámetros de
  configuración de la State Machine (`StateMachineConfig`) con datos reales.
  No le quita autoridad de decisión al módulo. La cadena canónica
  `detect_patterns → score_patterns → evaluate_transition` no cambia de
  estructura.

- **D8:** LLM local (T-3-005) sigue siendo mejora opcional, no requisito. El
  baseline determinístico (Pattern Detector + Trust Scorer + State Machine)
  debe seguir funcionando sin LLM en cualquier hardware. T-3-005 no puede
  introducirse como dependencia de ningún entregable core de Fase 3.

- **D9:** FS Watcher desktop opera como background-persistent (decisión
  registrada en decisions-log.md, 2026-04-28, commit 64294e4). Observer
  Android (T-3-004) opera solo con sesión explícita iniciada por el usuario
  mediante Tile de sesión (extensión de D9 aprobada en AR-CR-002 y
  PGR-CR-002). Ningún mecanismo de observación puede activarse sin acción
  explícita del usuario en mobile.

- **D14:** satisfecho por Fase 2 — el Privacy Dashboard completo existe y está
  verificado. En Fase 3, no puede regresionarse: cualquier nuevo mecanismo
  de observación (T-3-004) debe tener representación en el Privacy Dashboard
  antes de activarse con usuarios reales.

- **D22 + CR-002:** el observer semi-pasivo Android (Tile de sesión) es
  feature paid de Fase 3. Requiere TS formal aprobada por Technical Architect
  y Privacy Guardian antes de implementar. La captura explícita via Share
  Intent sigue siendo siempre free.

- **R12 WATCH ACTIVO:** Pattern Detector ≠ Episode Detector. Esta distinción
  debe declararse explícitamente en cada TS de Fase 3 que toque módulos de
  inferencia. T-3-003 (calibración) y T-3-004 (observer Android) son los
  vectores de riesgo de contaminación de propósito más probables en Fase 3.

---

## Next Agent

**Functional Analyst → producir `operations/backlogs/backlog-phase-3.md`** tomando:

- `Project-docs/roadmap.md` (entregables de Fase 3)
- `Project-docs/phase-definition.md` (qué valida y qué no valida Fase 3)
- `operating-system/phase-gates.md` (gate de salida de Fase 3)
- `Project-docs/decisions-log.md` (D1, D4, D8, D9 extensión, D14, D22, CR-002)
- `operations/architecture-reviews/AR-CR-002-mobile-observer.md` y
  `operations/architecture-reviews/PGR-CR-002-mobile-observer.md`
  (contratos del observer Android)
- Esta OD como contrato de apertura

El backlog debe:
- Declarar el schema de telemetría de T-3-002 y someterlo a revisión de Privacy
  Guardian antes de marcar T-3-002 como listo para implementación.
- Declarar explícitamente en T-3-003 que la calibración ajusta parámetros de
  entrada, no la autoridad de la State Machine (D4).
- Tratar T-3-004 como bloqueado hasta que exista TS formal aprobada.
- Tratar T-3-005 como condicional a decisión explícita del Orchestrator.
- Reproducir R12 en toda TS que toque módulos de inferencia.

---

## Documentation Updates Required

| Archivo | Acción | Urgencia | Estado |
| --- | --- | --- | --- |
| `operations/backlogs/backlog-phase-3.md` | Functional Analyst produce | PRIMER PASO | PENDIENTE |
| `operations/phase-integrity-reviews/PIR-005-phase-2-gate.md` | Phase Guardian emite gate formal de Fase 2 | REQUERIDO (referenciado en esta OD) | PENDIENTE |
| `operations/architecture-reviews/AR-2-007-fs-watcher-review.md` | QA Auditor actualiza y marca PASS criterio #18 escenario 3 (background-persistent) | ANTES DEL GATE DE FASE 3 | PENDIENTE |
| `Project-docs/decisions-log.md` | Registrar apertura de Fase 3 (OD-006) | CONTEXTUAL | PENDIENTE |
| TS formal T-3-004 (observer Android) | Technical Architect + Privacy Guardian aprueban antes de implementar | ANTES DE IMPLEMENTAR T-3-004 | PENDIENTE |
