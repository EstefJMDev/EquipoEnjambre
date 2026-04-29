# Backlog Funcional — Fase 3

date: 2026-04-28
owner_agent: Functional Analyst
phase: 3
status: APROBADO — AR-3-001 (2026-04-28)
referenced_decision: OD-006-phase-3-activation.md

---

## Functional Breakdown

phase: 3
objective: Validar FlowWeaver con usuarios beta reales, calibrar umbrales de la State
           Machine con datos reales y medir tolerancia a la automatización progresiva.

validates:
- comportamiento del sistema con 20-50 usuarios beta reales (externos)
- métricas de valor: aceptación de sugerencias automáticas, retención del estado de
  confianza, engagement con Privacy Dashboard
- precisión del Pattern Detector con patrones reales (no sintéticos)
- calibración de umbrales MIN_PATTERNS, THRESHOLD_LOW, THRESHOLD_HIGH con datos reales
- tolerancia real del usuario a la automatización progresiva (escalera Observing →
  Learning → Trusted → Autonomous)
- suficiencia del baseline determinístico antes de evaluar LLM (D8)

does_not_validate:
- escalado comercial definitivo
- product-market fit a escala de mercado
- paridad de funcionalidades con plataformas no completadas (iOS)
- que el LLM sea necesario — el baseline debe seguir funcionando sin LLM (D8)
- despliegue en tienda de aplicaciones (distribución beta directa)

in_scope:
- P-0: verificación E2E del relay bidireccional con OAuth de Google Drive activo
  (prerequisito bloqueante de beta — heredado de PIR-004)
- P-1: criterio #18 AR-2-007 escenario background-persistent FS Watcher — QA
  (prerequisito bloqueante de beta — heredado de Fase 2)
- T-3-001: Infraestructura de beta — distribución directa (sideload Android, build
  firmado Windows), onboarding, proceso de inscripción
- T-3-002: Telemetría dentro de D1 — métricas de uso anónimas sobre domain/category,
  nunca url/title
- T-3-003: Calibración de umbrales State Machine con datos reales de beta
- T-3-004: Observer semi-pasivo Android — Tile de sesión (tier paid, D9 extensión,
  CR-002) [BLOQUEADO hasta TS formal aprobada por Technical Architect y Privacy Guardian]
- T-3-005: LLM local opcional (Ollama) — mejora sobre baseline determinístico
  [CONDICIONAL — solo si datos de beta demuestran insuficiencia del baseline, D8]

out_of_scope:
- distribución en Google Play Store o Microsoft Store (Fase 3 es beta cerrada directa)
- iOS Share Extension y Sync Layer (track paralelo — bloqueo de entorno macOS)
- escalado a más de 50 usuarios beta en esta fase
- LLM como requisito de ningún módulo core (D8 — baseline determinístico obligatorio)
- exposición de url o title en métricas, dashboards o exportaciones (D1)
- reescritura o revisión de Pattern Detector, Trust Scorer ni State Machine (D17 —
  los módulos de Fase 2 están cerrados)
- nuevos paneles en el Shell desktop (Panel D u otros)
- calibración de umbrales que quite autoridad de decisión a la State Machine (D4)

dependencies:
- cadena completa de Fase 2 implementada y verificada: pattern_detector.rs,
  trust_scorer.rs, state_machine.rs, PrivacyDashboard.tsx (FsWatcherSection incluida)
- SQLCipher con domain, category, captured_at operativos en desktop y Android
- relay Google Drive operativo (O-002 — prerequisito P-0)
- FS Watcher background-persistent verificado (criterio #18 AR-2-007 — prerequisito P-1)
- build firmado de la app desktop (Windows) y APK de Android disponibles para distribución

risks_of_misinterpretation:
- incluir url o title en cualquier evento de telemetría "para mejorar la precisión del
  análisis" — viola D1 sin excepción; las métricas operan exclusivamente sobre
  domain/category/extension/estado de confianza
- hacer la State Machine consultiva durante la calibración de umbrales (T-3-003) —
  viola D4; la calibración ajusta parámetros de entrada, no la autoridad del módulo
- activar T-3-005 (LLM) sin decisión explícita del Orchestrador basada en datos de beta
  — viola D8; el LLM no puede introducirse como dependencia implícita
- comenzar T-3-004 (observer Android) sin TS formal aprobada por Technical Architect
  y Privacy Guardian — viola el contrato de CR-002 y D9 extensión
- adelantar usuarios reales antes de cerrar P-0 y P-1 — estos prerequisitos son
  bloqueantes de beta pública; no son bloqueantes de trabajo documental y de
  especificación
- mezclar señales longitudinales (Pattern Detector) con señales de sesión (Episode
  Detector) en T-3-002 o T-3-003 — viola R12; la telemetría debe segregar
  explícitamente qué señal pertenece a qué módulo
- reabrir Pattern Detector en Fase 3 "para ajustar el algoritmo" — viola D17; el
  Pattern Detector queda cerrado desde Fase 2; la calibración en T-3-003 ajusta
  parámetros, no el algoritmo

---

## Mapa De Dependencias

```
Fase 2 cerrada (pattern_detector.rs + trust_scorer.rs + state_machine.rs +
                PrivacyDashboard.tsx con FsWatcherSection)
    │
    ├──► P-0  O-002 — relay E2E verificado con OAuth activo
    │        │
    │        └──► (desbloqueado: usuarios reales pueden usar relay)
    │
    ├──► P-1  Criterio #18 AR-2-007 — QA background-persistent FS Watcher
    │        │
    │        └──► (desbloqueado: FS Watcher apto para usuarios reales)
    │
    ├── [P-0 Y P-1 resueltos]
    │        │
    │        ▼
    │   T-3-001  Infraestructura de beta
    │        │
    │        ▼
    │   T-3-002  Telemetría dentro de D1
    │        │
    │        ▼
    │   T-3-003  Calibración de umbrales State Machine
    │
    ├──► T-3-004  Observer semi-pasivo Android — Tile de sesión
    │            [BLOQUEADO hasta TS formal aprobada por Technical Architect
    │             y Privacy Guardian — puede arrancar en paralelo a T-3-001/
    │             T-3-002 una vez la TS esté aprobada; no depende de T-3-003]
    │
    └──► T-3-005  LLM local opcional (Ollama)
                 [CONDICIONAL — requiere decisión explícita del Orchestrator
                  basada en datos de beta de T-3-002/T-3-003; no puede
                  activarse antes de que existan datos reales]
```

P-0 y P-1 no bloquean la producción del backlog ni las tareas documentales y de
especificación. Solo bloquean la apertura de la beta pública con usuarios reales.
T-3-001 y T-3-002 pueden prepararse (infraestructura, schema de telemetría) antes de
que P-0 y P-1 cierren, pero no pueden desplegarse con usuarios reales hasta que ambos
prerequisitos estén resueltos.
T-3-004 puede especificarse (TS formal) en paralelo a T-3-001/T-3-002, pero su
implementación no puede comenzar hasta que la TS esté aprobada por Technical Architect
y Privacy Guardian.

---

## Constraints Activos

| ID | Constraint | Impacto en Fase 3 |
| --- | --- | --- |
| D1 | Solo domain y category en claro; url/title siempre cifrados | Telemetría (T-3-002) nunca puede incluir url, title, ruta completa ni nombre de archivo. Métricas exclusivamente sobre domain/category/extension/estado de confianza. El schema de telemetría debe declararse en el backlog y ser revisado por Privacy Guardian antes de implementar T-3-002. |
| D4 | State Machine tiene autoridad; trust_score es input | La calibración de umbrales (T-3-003) ajusta parámetros de entrada de la State Machine (MIN_PATTERNS, THRESHOLD_LOW, THRESHOLD_HIGH). No modifica la lógica de transición ni delega autoridad de decisión a los datos o métricas. |
| D8 | Baseline determinístico sin LLM | T-3-005 es mejora opcional, no requisito. El baseline Pattern Detector + Trust Scorer + State Machine debe seguir funcionando sin LLM en cualquier hardware. T-3-005 no puede introducirse como dependencia implícita de ningún entregable core. |
| D9 rev. | FS Watcher background-persistent en desktop; observer Android solo con Tile de sesión activo (tier paid) | T-3-004 requiere TS formal aprobada por Technical Architect y Privacy Guardian. El Tile de sesión es el único mecanismo autorizado de observer semi-pasivo en Android (AR-CR-002, PGR-CR-002). El handler de captura debe registrarse dinámicamente al activar el tile y desregistrarse al desactivarlo — nunca declarado estáticamente. |
| D14 | Privacy Dashboard completo — satisfecho en Fase 2 | No regresionar. T-3-002 (telemetría) y T-3-004 (observer Android) deben representarse en el Privacy Dashboard si añaden mecanismos visibles al usuario. T-3-004 requiere sección específica del observer en el Privacy Dashboard mobile (Control C2 de PGR-CR-002). |
| D17 | Pattern Detector completo en Fase 2 | Ya cerrado. No dividir ni reabrir en Fase 3. La calibración de T-3-003 ajusta parámetros de configuración, no el algoritmo del Pattern Detector. |
| D19 | Android + Windows primario | iOS track paralelo secundario — pendiente de entorno macOS. No interfiere con el gate de Fase 3. |
| D22 + CR-002 | Freemium mobile: tier free (Share Intent) + tier paid (observer semi-pasivo Tile) | T-3-004 es la materialización del tier paid en Fase 3. Requiere TS formal + aprobación de Technical Architect y Privacy Guardian. La captura vía Share Intent sigue siendo siempre free. |
| R12 WATCH ACTIVO | Pattern Detector ≠ Episode Detector | T-3-002 (telemetría) y T-3-003 (calibración) son los vectores de riesgo de contaminación más probables en Fase 3. La telemetría debe segregar explícitamente señales longitudinales (Pattern Detector) de señales de sesión (Episode Detector). Declarar explícitamente en cada TS que toque módulos de inferencia. |

---

## Tareas Y Criterios De Aceptación

---

### P-0 — Verificación E2E Relay OAuth (O-002)

task_id: P-0
title: O-002 — Verificación E2E del relay bidireccional con credenciales OAuth activas
phase: 3 (prerequisito heredado de PIR-004, Fase 0c)
owner_agent: QA Auditor (verifica) + Orchestrator (cierra formalmente)
tipo: prerequisito bloqueante — no es tarea de implementación
bloquea: apertura de beta pública con usuarios reales
depends_on: relay Google Drive implementado (Fase 0b/0c)

#### Objective

Verificar que el relay bidireccional entre desktop y móvil funciona de extremo a extremo
con credenciales OAuth de Google Drive activas y reales. Esta verificación fue registrada
como condición viva en PIR-004 y reconfirmada en PIR-005 y OD-006. Sin O-002 cerrado,
ningún usuario real puede usar el relay para sincronizar capturas móviles con el workspace
desktop.

La verificación no es una tarea de desarrollo — es una verificación funcional E2E que
el QA Auditor ejecuta con credenciales reales y el Orchestrator cierra formalmente.

#### In Scope

- ejecución del escenario E2E completo: captura en Android via Share Intent → cifrado
  SQLCipher local → relay Google Drive (OAuth activo) → descifrado en desktop
- verificación del flujo inverso: recurso añadido en desktop → visible en galería móvil
- confirmación de que el cifrado E2E (D6/D21) se mantiene en tránsito (url y title nunca
  en claro fuera del dispositivo)
- registro del resultado en un documento de cierre de O-002

#### Out Of Scope

- implementación de nuevas funcionalidades del relay
- pruebas de carga o volumen
- credenciales de prueba sintéticas (deben ser OAuth reales de Google Drive)

#### Acceptance Criteria

- [ ] el escenario de captura Android → desktop completa el ciclo sin errores con
      credenciales OAuth de Google Drive activas (no simuladas)
- [ ] el escenario desktop → galería móvil completa el ciclo inverso sin errores
- [ ] los datos en tránsito por Google Drive están cifrados (url y title nunca expuestos
      en claro en el relay)
- [ ] el resultado queda documentado formalmente como O-002 RESUELTO en el registro
      de condiciones vivas (referenciado desde PIR-004 y OD-006)
- [ ] el Orchestrator emite cierre formal de O-002 antes de autorizar el inicio de la
      beta pública

#### Risks

- que las credenciales OAuth requieran configuración adicional en el entorno de producción
  (tokens expirados, permisos de scopes insuficientes)
- que el relay funcione en entorno de desarrollo pero presente problemas con credenciales
  de usuarios reales distintos a la cuenta de desarrollo

#### Required Handoff

Al Orchestrator para cierre formal de O-002. El Orchestrator autoriza el inicio de la
beta pública solo cuando P-0 y P-1 están ambos resueltos.

---

### P-1 — Criterio #18 AR-2-007 FS Watcher Background-Persistent

task_id: P-1
title: Criterio #18 AR-2-007 — QA escenario background-persistent del FS Watcher
phase: 3 (prerequisito heredado de Fase 2)
owner_agent: QA Auditor (ejecuta y marca PASS)
tipo: prerequisito bloqueante — no es tarea de implementación
bloquea: apertura de beta pública con usuarios reales
depends_on: FS Watcher implementado (Fase 2, background-persistent per D9 rev. 2026-04-28)

#### Objective

El escenario 3 del criterio #18 en AR-2-007 fue redactado originalmente como "buffer se
purga al perder el foco" — comportamiento que quedó superado por la revisión de D9
registrada el 2026-04-28 (commit 64294e4), que establece FS Watcher como
background-persistent. El QA Auditor debe actualizar AR-2-007 criterio #18 escenario 3
con el comportamiento correcto (evento DEBE capturarse mientras la app está en background)
y ejecutar el escenario para marcarlo como PASS.

Sin este prerequisito cerrado, el FS Watcher no está formalmente verificado para la beta.

#### In Scope

- actualización del escenario 3 del criterio #18 en AR-2-007 con el comportamiento
  background-persistent (evento se captura con la app en background — no se purga)
- ejecución del escenario actualizado con la implementación real del FS Watcher
- marcado formal de criterio #18 escenario 3 como PASS en AR-2-007
- registro del resultado en el documento de cierre

#### Out Of Scope

- implementación de cambios en FS Watcher (el módulo ya está implementado)
- verificación de otros criterios de AR-2-007 (solo el criterio #18 escenario 3)

#### Acceptance Criteria

- [ ] el escenario 3 del criterio #18 en AR-2-007 está actualizado con el comportamiento
      correcto: "evento DEBE capturarse mientras la app está en background (FS Watcher
      background-persistent, D9 rev. 2026-04-28)"
- [ ] el QA Auditor ha ejecutado el escenario con la implementación real: la app pierde
      el foco, se produce un evento de archivo en el directorio observado, el evento
      queda registrado en SQLCipher
- [ ] criterio #18 escenario 3 marcado PASS en AR-2-007
- [ ] el resultado está referenciado desde el documento de cierre de prerequisitos de
      Fase 3

#### Risks

- que la implementación actual del FS Watcher no sea realmente background-persistent
  en todos los entornos Windows (requeriría corrección antes de poder marcar PASS)
- que AR-2-007 no esté disponible para edición (verificar que el archivo existe en el
  repo antes de iniciar)

#### Required Handoff

Al Orchestrator junto con P-0 para autorización de la beta pública. Ambos prerequisitos
deben estar resueltos antes de T-3-001 puede desplegar usuarios reales.

---

### T-3-001 — Infraestructura De Beta

task_id: T-3-001
title: Infraestructura de beta — distribución directa, onboarding y build firmado
phase: 3
owner_agent: Desktop Tauri Shell Specialist (desktop) + Android Share Intent Specialist (Android)
depends_on: P-0 y P-1 resueltos (antes de desplegar usuarios reales); backlog aprobado por
            Technical Architect

#### Objective

Preparar la infraestructura técnica y operativa necesaria para que 20-50 usuarios beta
reales puedan instalar FlowWeaver en sus dispositivos, completar el onboarding y usar el
sistema. La distribución es directa (sideload APK en Android, build firmado MSI/NSIS en
Windows) — no implica publicación en tiendas de aplicaciones.

La infraestructura incluye: build de producción firmado para cada plataforma, proceso de
inscripción de beta testers, flujo de onboarding en la app y documentación mínima de
instalación para usuarios no técnicos.

#### In Scope

- build de producción firmado para Android (APK firmado con certificado de release) y
  Windows (instalador MSI o NSIS firmado con certificado de código)
- proceso de distribución directa: canal de entrega seguro para los builds (no una tienda
  de aplicaciones)
- flujo de onboarding en la app: pantallas de bienvenida, explicación del caso de uso
  principal, configuración inicial de directorios observados (FS Watcher) y permisos
  Android (Share Intent)
- proceso de inscripción de beta testers: formulario o mecanismo de registro que
  identifique a los 20-50 usuarios (sin recopilar datos que violen D1)
- documentación de instalación para usuarios no técnicos (instrucciones de sideload
  Android, instalación Windows)
- verificación de que el build de producción pasa todos los tests antes de distribuirse:
  `cargo test` completo + `npx tsc --noEmit` + verificación manual de los flujos críticos

#### Out Of Scope

- publicación en Google Play Store o Microsoft Store
- backend de gestión de usuarios o autenticación centralizada
- sistema de actualización automática (OTA) de builds — la beta se actualiza
  distribuyendo nuevos builds directamente
- más de 50 usuarios beta en esta fase
- funcionalidades nuevas que no estén en el scope de Fase 3 — el onboarding presenta
  el sistema tal como existe, no promete funcionalidades futuras

#### Acceptance Criteria

- [ ] el build APK Android está firmado con certificado de release y puede instalarse
      por sideload en dispositivos Android 8.0 o superior sin errores
- [ ] el instalador Windows está firmado con certificado de código válido y puede
      instalarse sin avisos de "publicador desconocido" en Windows 10 Pro o superior
- [ ] `cargo test` pasa al 100% (sin regresiones) sobre el build de producción antes
      de distribuir
- [ ] `npx tsc --noEmit` limpio sobre el build de producción antes de distribuir
- [ ] el flujo de onboarding en la app explica correctamente el caso de uso principal
      (workspace preparado automáticamente a partir de lo que el usuario guarda desde
      el móvil) sin prometer funcionalidades no disponibles
- [ ] el onboarding Android incluye el flujo de consentimiento para Share Intent con
      explicación de qué captura el sistema y dónde se almacena
- [ ] el proceso de distribución directa está operativo: un usuario beta puede recibir
      el build, instalarlo y completar el onboarding sin asistencia técnica directa
- [ ] el proceso de inscripción de beta testers está operativo y no recopila datos que
      violen D1 (no se solicita url de navegación, historial de archivos ni información
      sensible)
- [ ] la documentación de instalación cubre los casos de error más comunes en sideload
      Android (habilitar fuentes desconocidas) e instalación Windows

#### Risks

- que el proceso de sideload sea demasiado técnico para usuarios beta no técnicos —
  la documentación de instalación debe cubrir el caso de error estándar en Android
- que el certificado de código para Windows no esté disponible a tiempo — investigar
  opciones de firma disponibles (self-signed con instrucciones de instalación, o
  certificado comercial)
- que el build de producción introduzca diferencias de comportamiento respecto al build
  de desarrollo que no se detecten sin una sesión de QA dedicada sobre el build firmado

#### Required Handoff

Al QA Auditor para verificación del build de producción antes de distribución, y al
Orchestrator para autorización del inicio de la beta.

---

### T-3-002 — Telemetría Dentro De D1

task_id: T-3-002
title: Telemetría dentro de D1 — métricas de uso anónimas sobre domain/category
phase: 3
owner_agent: Desktop Tauri Shell Specialist (implementación) + Privacy Guardian (revisión
             obligatoria del schema antes de implementar)
depends_on: T-3-001 (infraestructura de beta operativa)

#### Objective

Implementar un sistema de telemetría de uso anónima que permita medir el comportamiento
del sistema con usuarios beta reales. La telemetría opera exclusivamente dentro del marco
de D1: solo domain y category en claro, nunca url ni title. Los eventos son locales por
defecto — se agregan para métricas sin transmitir datos individuales a ningún servidor
externo, o se transmiten como eventos completamente anonimizados sin identificador de
usuario.

**Schema de telemetría declarado (D1 operativo):**

Los únicos tipos de evento permitidos son:

| Evento | Campos permitidos | Campos prohibidos |
|---|---|---|
| sugerencia_emitida | suggestion_type, trust_state, domain (en claro), category (en claro), timestamp_bucket (granularidad horaria, no minuto) | url, title, filename, path, user_id |
| sugerencia_aceptada | suggestion_type, trust_state, domain (en claro), category (en claro) | ídem |
| sugerencia_rechazada | suggestion_type, trust_state, domain (en claro), category (en claro) | ídem |
| transicion_estado | from_state, to_state, pattern_count, timestamp_bucket | url, title, pattern_label si deriva de url/title |
| patron_bloqueado | category (en claro), timestamp_bucket | domain específico, url, title |
| reset_confianza | timestamp_bucket | cualquier dato de contenido |

Este schema debe ser aprobado formalmente por Privacy Guardian antes de comenzar la
implementación de T-3-002.

**Distinción R12 en telemetría (obligatoria):**
Los eventos de telemetría deben segregar explícitamente el origen de la señal:
- eventos generados por el Pattern Detector (señales longitudinales — días/semanas)
- eventos generados por el Episode Detector (señales de sesión — tiempo real)
Estos dos orígenes no pueden mezclarse en el mismo tipo de evento ni en el mismo
dashboard de análisis.

#### In Scope

- módulo de telemetría en Rust (`src-tauri/src/telemetry.rs`) que emite los eventos
  del schema declarado
- almacenamiento local de eventos en SQLCipher (tabla `telemetry_events`) — nunca
  en texto plano
- mecanismo de exportación o agregación que permita al Orchestrator/product owner
  analizar las métricas sin exponer datos individuales de usuarios
- comando Tauri `get_telemetry_summary` que devuelve métricas agregadas sin
  identificadores de usuario ni campos prohibidos
- control de activación visible para el usuario: la telemetría debe poder desactivarse
  desde el Privacy Dashboard sin que ello afecte el funcionamiento del sistema
- representación en el Privacy Dashboard de que la telemetría está activa y qué
  tipos de eventos se recogen (sección "Qué datos se analizan")
- schema de telemetría declarado en este backlog y aprobado por Privacy Guardian antes
  de implementar

#### Out Of Scope

- transmisión de eventos individuales a servidores externos (ningún endpoint externo
  de telemetría en Fase 3 — la telemetría es local por defecto)
- identificadores de usuario que permitan correlacionar eventos entre sesiones de
  diferentes usuarios
- url, title, nombre de archivo, ruta completa ni cualquier otro campo prohibido
  por D1 en ningún evento
- telemetría del LLM (T-3-005 — si se activa, tiene sus propias condiciones)
- métricas de rendimiento del sistema (CPU, memoria, latencia) — la telemetría es de
  uso y comportamiento del producto, no de infraestructura

#### Acceptance Criteria

- [ ] el schema de telemetría declarado en este backlog ha sido aprobado formalmente
      por Privacy Guardian antes de iniciar la implementación
- [ ] `telemetry.rs` existe como módulo independiente y los campos de todos los eventos
      se ajustan estrictamente al schema aprobado — ningún campo contiene url, title,
      filename ni path
- [ ] la tabla `telemetry_events` en SQLCipher no contiene ninguna columna con url,
      title ni ningún campo prohibido por D1 — verificable por inspección del schema
- [ ] los eventos de origen longitudinal (Pattern Detector) y de sesión (Episode
      Detector) están segregados en tipos de evento distintos — no se mezclan en
      ningún registro (R12)
- [ ] el comando Tauri `get_telemetry_summary` devuelve métricas agregadas sin
      identificadores individuales de usuario
- [ ] el Privacy Dashboard incluye sección "Qué datos se analizan" visible al usuario
      con la lista de tipos de evento recogidos y el control de desactivación
- [ ] la desactivación de telemetría desde el Privacy Dashboard es efectiva: tras
      desactivar, ningún evento se registra en `telemetry_events`
- [ ] `cargo test` pasa sin regresiones
- [ ] `npx tsc --noEmit` limpio

#### Risks

- que el implementador añada un campo de "contexto" o "label" en un evento que derive
  indirectamente de url o title (por ejemplo, el label del patrón si fue generado con
  LLM sobre el título) — verificar el origen de cada campo antes de aprobar el schema
- que la agregación de métricas requiera un identificador de sesión que permita
  reconocer comportamientos individuales — usar identificadores de sesión efímeros o
  contadores sin correlación entre sesiones
- que R12 se viole en el análisis de datos post-beta: el product owner debe recibir
  los datos con la segregación de origen ya incorporada para no mezclarlos durante
  el análisis

#### Required Handoff

Al Privacy Guardian para revisión y aprobación del schema de telemetría antes de
implementar. Al Technical Architect para verificar que el módulo no accede a campos
prohibidos de SQLCipher.

---

### T-3-003 — Calibración De Umbrales State Machine

task_id: T-3-003
title: Calibración de umbrales State Machine con datos reales de beta
phase: 3
owner_agent: Desktop Tauri Shell Specialist (implementa cambios) + Technical Architect
             (aprueba nuevos valores via AR) + Orchestrator (autoriza la calibración
             tras análisis de datos)
depends_on: T-3-002 (datos de telemetría de beta recogidos), T-3-001 (beta en curso con
            usuarios reales)

#### Objective

Ajustar los valores de MIN_PATTERNS, THRESHOLD_LOW y THRESHOLD_HIGH en `state_machine.rs`
con datos reales recogidos durante la beta. El proceso es:

1. Recoger datos de T-3-002 durante el período de beta inicial.
2. Analizar las distribuciones de patrones detectados y scores de confianza con
   usuarios reales.
3. Proponer nuevos valores de umbrales basados en los datos.
4. Someter la propuesta a revisión del Technical Architect (AR formal).
5. Implementar los nuevos valores aprobados en `state_machine.rs`.

**Distinción crítica (D4):** la calibración ajusta los parámetros de entrada de la
State Machine. No modifica la lógica de transición, no le quita autoridad al módulo
y no hace las transiciones consultivas. La cadena canónica
`detect_patterns → score_patterns → evaluate_transition` no cambia de estructura.

**Distinción R12 (obligatoria):** los datos usados para la calibración deben
segregar explícitamente las señales del Pattern Detector (longitudinales) de las
del Episode Detector (sesión). Los umbrales de la State Machine se calibran sobre
señales del Pattern Detector — nunca sobre señales de sesión del Episode Detector.

#### In Scope

- análisis de distribuciones de: frecuencia de patrones detectados por Pattern
  Detector, valores de trust_score y stability_score producidos por Trust Scorer,
  y distribución de estados actuales de los usuarios beta en la State Machine
- propuesta documentada de nuevos valores de MIN_PATTERNS, THRESHOLD_LOW,
  THRESHOLD_HIGH con justificación cuantitativa basada en los datos
- revisión de la propuesta por el Technical Architect (AR) y aprobación antes
  de implementar
- implementación de los nuevos valores en `StateMachineConfig` en `state_machine.rs`
- actualización del documento de umbrales (si existe) con los valores calibrados
  y su justificación

#### Out Of Scope

- modificación de la lógica de transición de la State Machine (las transiciones
  permanecen igual — D4)
- eliminación de la condición de doble requisito para transiciones (trust_score >
  umbral Y !user_blocked_pattern — D4)
- delegación de autoridad de decisión a los datos o métricas (la State Machine sigue
  siendo el módulo con autoridad de decisión — D4)
- reapertura o modificación del algoritmo de Pattern Detector (D17 — cerrado en Fase 2)
- uso de datos que incluyan url o title para la calibración (D1 — los únicos datos
  disponibles son domain/category, trust_score, stability_score, estado de la SM)
- calibración del observer Android (T-3-004 es independiente y tiene sus propios
  umbrales declarados en AR-CR-002)

#### Acceptance Criteria

- [ ] el análisis de distribuciones está documentado formalmente: distribuciones de
      frecuencia de patrones, trust_score, stability_score y estados SM observados en
      la beta — con datos reales de al menos 10 usuarios beta activos
- [ ] los datos de análisis utilizan exclusivamente domain, category, trust_score,
      stability_score y estado SM — ningún campo prohibido por D1
- [ ] los datos de análisis declaran explícitamente la segregación de origen R12:
      señales del Pattern Detector (longitudinales) vs Episode Detector (sesión)
- [ ] la propuesta de nuevos valores de MIN_PATTERNS, THRESHOLD_LOW, THRESHOLD_HIGH
      está justificada cuantitativamente con los datos de distribución
- [ ] la propuesta ha sido revisada y aprobada por el Technical Architect mediante AR
      formal antes de implementar
- [ ] los nuevos valores están implementados en `StateMachineConfig` en `state_machine.rs`
      y son configurables (no hardcoded)
- [ ] la lógica de transición de la State Machine no ha sido modificada — solo los
      valores de los parámetros de configuración
- [ ] `cargo test` pasa sin regresiones tras los cambios de valores
- [ ] el documento de decisión registra los valores anteriores, los nuevos valores y
      la justificación basada en datos reales

#### Risks

- que los datos de beta sean insuficientes (menos de 10 usuarios activos, menos de
  2 semanas de uso) para sacar conclusiones estadísticas sólidas — en ese caso, la
  calibración debe posponerse hasta tener datos suficientes
- que el análisis sugiera modificar la lógica de transición en lugar de solo los
  umbrales — el Technical Architect debe rechazar cualquier propuesta que toque la
  lógica de transición (D4)
- que se usen señales del Episode Detector para calibrar umbrales del Pattern Detector
  — viola R12; los umbrales de la State Machine se calibran sobre señales longitudinales

#### Required Handoff

Al Technical Architect para revisión de la propuesta de nuevos umbrales y emisión de
AR formal antes de implementar. Al Orchestrator para autorización si la calibración
implica cambios materiales en el comportamiento del sistema para los usuarios beta.

---

### T-3-004 — Observer Semi-Pasivo Android — Tile De Sesión

task_id: T-3-004
title: Observer semi-pasivo Android — Tile de sesión (tier paid, D9 extensión, CR-002)
phase: 3
owner_agent: Android Share Intent Specialist (implementación) + Technical Architect
             (TS formal) + Privacy Guardian (revisión TS)
depends_on: TS formal aprobada por Technical Architect Y revisada por Privacy Guardian
            (PREREQUISITO BLOQUEANTE DE IMPLEMENTACIÓN)
tier: paid (D22 + CR-002)

> **ATENCIÓN: T-3-004 está BLOQUEADO hasta que exista una Task Spec (TS) formal
> aprobada por el Technical Architect y revisada por el Privacy Guardian. La TS
> debe producirse como documento independiente antes de que cualquier línea de
> código del observer Android sea escrita. Este backlog describe el scope y los
> criterios orientativos — la TS formal es el documento de implementación
> autorizado. Referencia: OD-006, AR-CR-002-mobile-observer, PGR-CR-002-mobile-observer.**

#### Objective

Implementar el observer semi-pasivo Android como primer entregable del tier paid de
FlowWeaver Mobile. El mecanismo es el Tile de sesión (Quick Settings tile) que activa
y desactiva una ventana de captura semi-pasiva de URLs de navegación.

La arquitectura está definida en AR-CR-002-mobile-observer.md y sus controles de
privacidad en PGR-CR-002-mobile-observer.md. La implementación debe seguir exactamente
los contratos declarados en esos documentos — la TS formal los traduce a criterios
de implementación ejecutables.

**Decisión de mecanismo (AR-CR-002, sección 1):** el observer usa Tile de sesión
con handler dinámico. El handler se registra al activar el tile y se desregistra al
desactivarlo. No se declara estáticamente en AndroidManifest. El foreground service
es obligatorio durante la sesión activa con notificación visible e interactiva.

**Distinción R12 aplicada a mobile (AR-CR-002, sección 4):** el Episode Detector
mobile es un módulo separado (`episode_detector_mobile.rs` o configuración
parametrizada). No modifica ni hereda de `episode_detector.rs` desktop. Ningún
condicional de plataforma en `episode_detector.rs` desktop.

#### In Scope

(orientativo — la TS formal define el scope ejecutable)

- TileService Android (Quick Settings tile) que activa/desactiva la sesión de captura
- foreground service con notificación visible, persistente y con acción de cierre
  directamente accesible durante la sesión activa
- handler de captura dinámico: registrado al activar el tile, desregistrado al
  desactivarlo — nunca estático en AndroidManifest
- cifrado inmediato en RAM (≤ 500 ms) antes de persistir en SQLCipher Android (D1)
- Session Builder mobile con umbrales aprobados: GAP_SECS = 2_700 s, MAX_WINDOW_SECS
  = 7_200 s (AR-CR-002, sección 2)
- Episode Detector mobile como módulo separado: PRECISE_MIN = 2, BROAD_MIN = 2,
  JACCARD_THRESHOLD = 0.20, modo broad primario para sesiones < 3 capturas
- Pattern Detector, Trust Scorer y State Machine compilados para Android via NDK
  sin modificación de lógica Rust
- timeout automático de sesión: default 30 minutos (configurable 5 min – 4 h,
  PGR-CR-002, Control C5)
- pantalla de consentimiento explícito antes del primer uso del tile (PGR-CR-002,
  Control C1)
- sección del observer en el Privacy Dashboard mobile: estado, capturas por sesión,
  historial de activaciones, botón de purga (PGR-CR-002, Control C2)
- desactivación accesible desde tile, Privacy Dashboard y notificación (PGR-CR-002,
  Control C3)
- paywall: con suscripción inactiva el tile muestra paywall y no inicia el foreground
  service (PGR-CR-002, PV-M-005)
- etiquetado en SQLCipher para separar datos del tier paid (observer) de datos del
  tier free (Share Intent) — purga independiente (PGR-CR-002, Condición 5)

#### Out Of Scope

- Accessibility Service (rechazado permanentemente — AR-CR-002, PGR-CR-002)
- acceso a historial del navegador (rechazado permanentemente)
- handler declarado estáticamente en AndroidManifest (rechazado — Condición 2
  de PGR-CR-002)
- modificación de `episode_detector.rs` desktop (R12 — módulos separados)
- observación en background sin tile activo
- captura de contenido completo de páginas, metadatos de red o credenciales

#### Acceptance Criteria

(los criterios AC-1 a AC-12 de AR-CR-002 son los criterios de aceptación canónicos;
los criterios adicionales completan el contrato de privacidad)

- [ ] la TS formal existe como documento aprobado por Technical Architect y revisado
      por Privacy Guardian antes de comenzar ninguna implementación
- [ ] el tile activa/desactiva la sesión; con tile OFF, ACTION_SEND no produce ningún
      raw_event en SQLCipher Android (AC-1 de AR-CR-002)
- [ ] el foreground service inicia con tile ON y termina con tile OFF o por
      MAX_WINDOW_SECS = 7_200 s (AC-2 de AR-CR-002)
- [ ] la notificación del foreground service incluye acción de cierre de sesión; el
      cierre desde notificación apaga el tile (AC-3 de AR-CR-002)
- [ ] el Session Builder mobile usa GAP_SECS = 2_700 y MAX_WINDOW_SECS = 7_200 (AC-4)
- [ ] el Episode Detector mobile usa PRECISE_MIN = 2, BROAD_MIN = 2; 2 URLs de la
      misma categoría producen episodio en modo Broad (AC-5 de AR-CR-002)
- [ ] `episode_detector.rs` desktop no contiene ningún condicional de plataforma
      `#[cfg(target_os = "android")]` (AC-6 de AR-CR-002 — R12)
- [ ] Pattern Detector compilado para aarch64-linux-android pasa sus tests sin
      modificar `pattern_detector.rs` (AC-7 de AR-CR-002)
- [ ] ninguna query SQLCipher Android accede a url o title en claro (AC-8 de AR-CR-002 — D1)
- [ ] con suscripción inactiva el tile muestra paywall y no inicia foreground service
      (AC-9 de AR-CR-002 — D22)
- [ ] el Episode Detector mobile declara en cabecera la distinción con el desktop y
      con Pattern Detector (AC-10 de AR-CR-002 — R12)
- [ ] `cargo test` desktop pasa sin regresiones (AC-11 de AR-CR-002)
- [ ] `npx tsc --noEmit` limpio (AC-12 de AR-CR-002)
- [ ] la pantalla de consentimiento explícito aparece antes del primer uso del tile;
      el tile no es activable hasta que el usuario complete el flujo (PGR-CR-002, C1)
- [ ] el Privacy Dashboard mobile incluye la sección del observer con estado, capturas,
      historial de activaciones y botón de purga (PGR-CR-002, C2)
- [ ] el timeout automático de sesión está implementado con default 30 minutos y es
      configurable desde 5 minutos a 4 horas en Privacy Dashboard (PGR-CR-002, C5)

#### Risks

- que el implementador reutilice `episode_detector.rs` con parámetros modificados en
  lugar de crear un módulo separado — viola R12; la TS formal debe declarar
  explícitamente el módulo separado como obligatorio
- que el handler de captura quede declarado estáticamente en AndroidManifest —
  verifica el AndroidManifest antes de declarar implementación completa
- que OEMs Android (EMUI, MIUI) maten el foreground service — documentar en el
  onboarding como limitación conocida; implementar `onTaskRemoved` para cierre limpio
- que la verificación de suscripción bloquee el flujo de activación del tile — el
  estado de suscripción debe estar cacheado localmente (PGR-CR-002, R-M-007)

#### Required Handoff

Al Technical Architect para emisión de TS formal. Al Privacy Guardian para revisión
de la TS formal. Solo tras la aprobación conjunta puede el implementador iniciar el
desarrollo. La implementación completa requiere verificación por QA Auditor y Privacy
Guardian antes de desplegarse con usuarios beta.

---

### T-3-005 — LLM Local Opcional (Ollama)

task_id: T-3-005
title: LLM local opcional (Ollama) — mejora sobre baseline determinístico
phase: 3
owner_agent: Desktop Tauri Shell Specialist (si se activa)
depends_on: datos de beta de T-3-002 y T-3-003 que justifiquen insuficiencia del
            baseline + decisión explícita del Orchestrator (PREREQUISITO DE ACTIVACIÓN)

> **ATENCIÓN: T-3-005 es CONDICIONAL. Solo puede activarse si:
> (1) los datos de beta de T-3-002 y T-3-003 demuestran que el baseline
> determinístico (Pattern Detector + Trust Scorer + State Machine) es insuficiente
> para el caso de uso con usuarios reales, Y
> (2) el Orchestrator emite una decisión explícita de activar esta tarea basada en
> esos datos.
> En ausencia de esa decisión, T-3-005 no existe como tarea activa. No puede
> activarse como "mejora preventiva" ni por iniciativa del implementador.
> Constraint D8 es no negociable: el baseline determinístico debe seguir funcionando
> sin LLM en cualquier caso.**

#### Objective

Si el baseline determinístico demuestra limitaciones medibles con datos reales de beta
(por ejemplo: labels de patrones poco descriptivos que reducen la aceptación de
sugerencias, o agrupaciones de domain/category que no capturan la intención real del
usuario), el LLM local puede añadirse como capa de mejora opcional sobre el baseline.

El LLM no reemplaza ningún módulo existente. Es una capa de enriquecimiento que opera
sobre el output del Pattern Detector (label generation, mejora de la descripción del
patrón) o del Trust Scorer (ajuste de pesos) — sin acceder a url ni title (D1).

El baseline debe seguir funcionando sin LLM en cualquier hardware donde Ollama no
esté instalado o no pueda ejecutarse.

#### In Scope

(solo si T-3-005 es activada por el Orchestrator)

- integración de Ollama como proceso local opcional en el desktop
- uso del LLM exclusivamente para mejora de labels del Pattern Detector (generar
  etiquetas más descriptivas a partir de domain/category — nunca a partir de url/title)
  o para ajuste de pesos del Trust Scorer
- declaración explícita en código de que LLM es mejora opcional — el sistema debe
  degradar gracefully si Ollama no está disponible
- control visible en el Privacy Dashboard de que el LLM está activo y qué hace
- comando Tauri `get_llm_status` que devuelve si Ollama está activo y la versión
  del modelo usado

#### Out Of Scope

- LLM como requisito de ningún módulo — si Ollama no está, el sistema funciona
  con el baseline (D8 — no negociable)
- acceso del LLM a url o title bajo ninguna circunstancia (D1)
- uso del LLM para tomar decisiones de acción (eso es exclusivo de la State Machine — D4)
- activación automática del LLM sin intervención del usuario
- modelos de LLM que requieran conexión a servidores externos (Ollama es local — D8)

#### Acceptance Criteria

(solo aplican si T-3-005 ha sido activada por el Orchestrator)

- [ ] existe una decisión explícita del Orchestrator documentada que autoriza T-3-005
      basada en datos de beta que demuestran insuficiencia del baseline
- [ ] Ollama se integra como proceso opcional: si no está disponible, el sistema
      arranca y funciona con el baseline sin errores ni degradación de funcionalidades
      core
- [ ] el LLM solo accede a domain y category en su input — ningún campo contiene
      url ni title (D1)
- [ ] el LLM no puede iniciar transiciones de la State Machine ni tomar decisiones de
      acción — su output es exclusivamente text enrichment del Pattern Detector o
      ajuste de pesos del Trust Scorer (D4)
- [ ] el Privacy Dashboard incluye sección "Modelo local" visible al usuario cuando
      el LLM está activo, con control de desactivación
- [ ] `cargo test` pasa sin regresiones cuando Ollama está disponible Y cuando no
      lo está (ambos escenarios verificados)
- [ ] `npx tsc --noEmit` limpio
- [ ] el modelo usado está declarado explícitamente en la configuración (versión,
      tamaño, origen) para que el usuario pueda verificar qué modelo procesa sus datos

#### Risks

- que el implementador active T-3-005 sin datos que lo justifiquen, convirtiendo el
  LLM en una dependencia implícita del flujo — viola D8
- que el LLM reciba url o title como parte de su contexto de inferencia — viola D1
- que el sistema no degrade gracefully cuando Ollama no está disponible, convirtiendo
  una mejora opcional en un requisito de hecho

#### Required Handoff

Al Orchestrator para decisión de activación basada en datos de beta. Al Privacy
Guardian para verificar que el input del LLM no contiene campos prohibidos por D1.
Al Technical Architect para revisión del contrato de integración con Ollama.

---

## Hipótesis Que Fase 3 Debe Validar (Gate De Salida)

Antes de pasar el gate de Fase 3, debe existir evidencia de que:

- la beta con usuarios reales ha producido datos suficientes (al menos 10 usuarios
  activos durante al menos 2 semanas) para evaluar el comportamiento del sistema
- las métricas de aceptación de sugerencias (sugerencias aceptadas / emitidas) son
  medibles y están dentro de un rango que justifica el producto
- la calibración de umbrales MIN_PATTERNS, THRESHOLD_LOW, THRESHOLD_HIGH tiene
  propuestas concretas basadas en datos reales, aprobadas por Technical Architect
- la telemetría opera exclusivamente dentro del marco de D1: ningún evento de
  telemetría contiene url, title ni ningún campo prohibido — verificado por Privacy
  Guardian
- el LLM sigue siendo opcional: el baseline determinístico funciona correctamente
  sin Ollama en todos los dispositivos de la beta
- T-3-004 (observer Android) solo se ha implementado si existe TS formal aprobada
  por Technical Architect y Privacy Guardian; si no se implementó, el gate no
  queda bloqueado por su ausencia
- la Privacy Dashboard no ha sufrido regresiones: los mecanismos de observación
  activos siguen siendo visibles y controlables por el usuario
- beta y métricas quedan definidas sin reescribir el caso núcleo del producto

### Condiciones de no-paso (phase-gates.md)

- beta depende de componentes aún no aceptados (P-0 o P-1 sin resolver antes de
  abrir la beta pública)
- la medición exige telemetría fuera del marco de privacidad aprobado (cualquier
  evento de telemetría que contenga url, title o campos prohibidos por D1)
- los objetivos de calibración de umbrales no están documentados con datos reales
  (propuesta de calibración sin evidencia cuantitativa)
- el LLM se ha convertido en dependencia implícita del sistema (el baseline no
  funciona sin Ollama)

---

## Track Paralelo iOS — Sigue Abierto

Share Extension iOS y Sync Layer (Fase 0b) siguen pendientes por dependencia
de plataforma macOS. Son independientes del gate de Fase 3.

| Módulo | Bloqueo | Estado |
| --- | --- | --- |
| Share Extension iOS | Requiere macOS + Xcode | Pendiente — independiente de Fase 3 |
| Sync Layer MVP (D6/iCloud) | Requiere Share Extension operativa | Pendiente — independiente de Fase 3 |
