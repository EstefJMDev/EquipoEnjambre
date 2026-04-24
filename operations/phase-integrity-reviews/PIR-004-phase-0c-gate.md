# Phase Integrity Review

owner_agent: Phase Guardian
document_id: PIR-004
phase_protected: 0c
review_type: gate de salida de Fase 0c
date: 2026-04-24
referenced_od: OD-005-phase-0c-activation.md
referenced_backlog: backlog-phase-0c.md
referenced_ar: AR-0c-001-phase-0c-contracts.md
referenced_qa:
  - qa-review-0c-T0c-000-T0c-001.md (QA-REVIEW-0c-001)
  - qa-review-0c-T0c-002-003-004.md (QA-REVIEW-0c-002)
orchestrator_decision_applied: Option B sobre O-002 (E2E relay como prerequisito pre-beta,
  no bloquea gate técnico — mismo patrón que gate de demo de Fase 1 en PIR-003)
status: PASADO CON CONDICIÓN — O-002 documentada como prerequisito pre-beta

---

## Objetivo

Evaluar si la implementación de Fase 0c satisface las condiciones del gate de salida
definidas en backlog-phase-0c.md, verificar que ninguna condición de no-paso está
activa, que el scope de Fase 0c no contamina Fase 2 ni posterior, y registrar
formalmente el estado del track iOS.

Este documento es el gate formal de Fase 0c. La decisión del Orchestrator
(Option B sobre O-002) está recogida en el prompting de esta revisión y se
aplica en la sección 2 (condición 2).

---

## Documentos Revisados

| Documento | Revisado |
| --- | --- |
| `operations/orchestration-decisions/OD-005-phase-0c-activation.md` | ✓ |
| `operations/backlogs/backlog-phase-0c.md` | ✓ |
| `operations/architecture-reviews/AR-0c-001-phase-0c-contracts.md` | ✓ |
| `operations/qa-reviews/qa-review-0c-T0c-000-T0c-001.md` | ✓ |
| `operations/qa-reviews/qa-review-0c-T0c-002-003-004.md` | ✓ |
| `operations/handoffs/HO-007-phase-0c-subcycle-1-close.md` | ✓ |
| `operations/architecture-notes/arch-note-T-0c-000-milestone0-result.md` | ✓ |
| `Project-docs/decisions-log.md` (D1, D8, D9, D14, D19, D20, D21) | ✓ |
| `operating-system/phase-gates.md` | referenciado |

---

## 1. Condiciones de Gate — Evaluación por Hipótesis

El backlog-phase-0c.md declara cuatro hipótesis que el gate debe validar con evidencia.

---

### Condición 1 — El usuario abre la app Android y encuentra sus capturas organizadas sin abrir el desktop

**Estado: SATISFECHA.**

**Evidencia:**

- `MobileGallery.tsx` consume `get_mobile_resources()`, que lee de SQLite Android
  local sin ninguna llamada de red ni dependencia del proceso desktop.
- El Classifier y el Grouper son el mismo crate Rust compilado para `aarch64-linux-android`.
  La categorización ocurre en el dispositivo en el momento de la captura via Share Intent.
- El pipeline completo es: Share Intent → captura → cifra url/title → INSERT SQLite
  Android → classify_domain() → group_by_category() → get_mobile_resources() → galería.
  Ningún paso de este pipeline requiere conexión al desktop.
- T-0c-000 y T-0c-001 verificados por QA-REVIEW-0c-001 (APROBADO).
- T-0c-003 verificado por QA-REVIEW-0c-002 (APROBADO). Criterio 2.7 ("funcional
  sin conexión") verificado explícitamente como PASS.
- Commits FlowWeaver: d219a69 (fallback), a45ad65 (get_mobile_resources), 4a97d2a (galería).

**Valoración del Phase Guardian:** evidencia directa y de alta verificabilidad.
La condición se satisface por diseño arquitectónico (SQLite local soberano), no por
circunstancia. La galería no tiene path de fallo que requiera desktop.

---

### Condición 2 — El relay bidireccional sincroniza sin pérdida ni duplicación (E2E test desktop → galería móvil)

**Estado: SATISFECHA CON CONDICIÓN — Option B aplicada por decisión del Orchestrator.**

**Evidencia de código (verificada por QA-REVIEW-0c-002):**

- Desktop: `relay_events` table con `UNIQUE event_id` + `insert_or_ignore` en uuid.
  Funciones `enqueue_relay_event()`, `pending_relay_events()`, `mark_relay_acked()`.
  `drive_relay.rs run_relay_cycle()` emite a `desktop-<device_id>/pending/` y lee
  `android-<device_id>/acked/`. Loop `tauri::async_runtime::spawn` cada 30 segundos
  al arrancar la app desktop.
- Android: `DriveRelayWorker.kt` implementa 3 direcciones. Lee `desktop-<device_id>/pending/`,
  clasifica con tabla estática Kotlin (D8 conforme), persiste en `LocalDb` via
  `insertOrIgnore()` + `uuidExists()`. Escribe ACK en `desktop-<device_id>/acked/`.
- Idempotencia: clave `(device_id, event_id)` por namespaces separados en Drive.
  Un mismo `event_id` no puede producir dos recursos en ninguno de los dispositivos.
- Regla de no-autoconsumo: Android no lee `android-<device_id>/` (safety check explícito
  en Worker). Desktop no lee `desktop-<device_id>/` (path hard-coded solo a `android-<id>/`).
- Todos los criterios de código de T-0c-002 verificados PASS en QA-REVIEW-0c-002.
- O-001 (XOR → AES-256-GCM) cerrada: `FieldCrypto.kt` AES-256-GCM fw1a + migración
  de registros XOR en primera ejecución del Worker. Clave constante derivada
  (`FIELD_KEY_PASSPHRASE`) en lugar de Android Keystore — variación aprobada por
  Technical Architect por bloqueante estructural documentado (clave hardware-bound
  no readable por runtime Rust). Commits: f83e4b4 (Android), 0ccc29c (desktop).

**Condición pendiente (O-002):**

La verificación E2E del relay (captura en desktop → aparece en galería móvil con
OAuth activo configurado) no es verificable en el entorno actual sin credenciales
OAuth de Google Drive (`client_id`, `client_secret`, `refresh_token`, `paired_android_id`).
El loop de 30 segundos en desktop corre pero ejecuta `silently skip` sin credenciales.

El Orchestrator ha elegido Option B: el gate técnico pasa ahora con los mecanismos
de código verificados; la verificación E2E queda documentada como prerequisito
obligatorio de beta pública. Este patrón es idéntico al aplicado en PIR-003 para
el gate de demo de Fase 1 (FS Watcher delimitado no bloqueó OD-004).

**Valoración del Phase Guardian:** la aplicación de Option B es legítima y coherente
con el precedente de PIR-003. La condición O-002 no representa un defecto de
implementación — el código existe, es correcto y está auditado. La imposibilidad
de verificación E2E es una limitación del entorno de test, no una brecha de
funcionalidad. Sin embargo, esta condición NO puede quedar olvidada: debe ser un
bloqueo documentado y explícito antes de cualquier despliegue con usuarios reales.
Se registra como condición viva en la sección 7.

---

### Condición 3 — La galería móvil funciona sin conexión a internet

**Estado: SATISFECHA.**

**Evidencia:**

- `MobileGallery.tsx`: el path de renderizado completo opera sobre `get_mobile_resources()`
  que lee de SQLite local. No hay llamada de red en el ciclo de carga ni de refresco
  de datos de la galería.
- Los favicons usan `loading="lazy"` — si no hay red, los datos de texto (domain,
  title, captured_at) se muestran íntegros; solo los favicons no cargan. La galería
  sigue siendo funcional.
- Pull-to-refresh: el botón [⟳] recarga `get_mobile_resources()` (datos locales).
  El one-shot WorkManager para trigger de relay inmediato está deferido a V1
  — esta deuda no afecta al criterio de offline-first porque el relay es async y
  el criterio de gate exige que la galería funcione sin conexión, no que sincronice
  sin conexión.
- QA-REVIEW-0c-002, criterio 2.7: PASS explícito.

**Valoración del Phase Guardian:** la condición está satisfecha sin ambigüedad.
La deuda de V1 (pull-to-refresh trigger WorkManager) es una mejora de experiencia
sobre un criterio que ya está cumplido, y está correctamente documentada como tal.

---

### Condición 4 — El Privacy Dashboard móvil es honesto y comprensible para un usuario no técnico

**Estado: SATISFECHA.**

**Evidencia:**

- `MobilePrivacyDashboard.tsx` implementa los dos textos de transparencia ("Qué guarda
  FlowWeaver en este dispositivo" y "Qué nunca guarda") directamente visibles en la
  pantalla principal del dashboard, sin navegación adicional.
- El botón "Eliminar todos mis datos del móvil" está implementado con `window.confirm()`
  y llama exclusivamente a `clear_all_resources()` — no afecta al desktop ni a Drive.
- Privacy Guardian revisó y aprobó los textos con 3 correcciones aplicadas:
  (1) "solo tú puedes leerlos" precisa el nivel de protección real sin implicar
  control de clave por el usuario;
  (2) "ni ninguna información personal" eliminado — domain sí se guarda en claro per D1;
  (3) relay: "se almacenan" → "se transmiten / carpeta privada" (precisión técnica).
- Indicador de relay: "carpeta privada de Google Drive que solo FlowWeaver puede ver".
  Menciona Google Drive por nombre, honesto sobre el mecanismo.
- Acceso directo desde la galería via botón en el header. Commit: 3847730.
- QA-REVIEW-0c-002, criterios 3.1 a 3.6: todos PASS.

**Valoración del Phase Guardian:** los textos aprobados por Privacy Guardian son
técnicamente precisos y accesibles. La corrección de la frase "ni ninguna información
personal" es especialmente importante — domain se guarda en claro y ocultarlo
habría sido una representación incorrecta. D14 (Privacy Dashboard completo obligatorio
antes de beta) sigue activo para Fase 2; T-0c-004 satisface el nivel mínimo
correspondiente a esta fase sin anticipar ni sustituir el completo.

---

## 2. Condiciones de No-Paso — Verificación

| Condición de no-paso | Activa | Evidencia de no-activación |
| --- | --- | --- |
| La galería requiere el desktop encendido para mostrar datos | NO | `get_mobile_resources()` lee de SQLite local. Sin dependencia de red ni de proceso desktop. Verificado en condición 1 y condición 3 de este gate. QA-REVIEW-0c-002 criterio 2.7 PASS. |
| Aparece contenido de páginas, texto de URLs o información personal en la galería | NO | `url` nunca llega al frontend — `open_resource_url(uuid)` resuelve en backend. Solo `domain` (en claro per D1) y `title` (descifrado por backend antes de enviar al frontend). `get_privacy_stats()` solo expone `category` y `count`. QA-REVIEW-0c-002 criterios 2.3, 2.4, 3.1 PASS. |
| El relay bidireccional produce duplicados en alguno de los dispositivos | NO en código | `insertOrIgnore()` + `uuidExists()` en Android; UNIQUE `event_id` + `insert_or_ignore` en desktop; namespaces separados en Drive. Verificación E2E pendiente per O-002 / Option B. QA-REVIEW-0c-002 criterio 1.4 PASS. |
| El Privacy Dashboard no incluye el botón de borrado o el texto de transparencia | NO | Botón implementado con `window.confirm()`. Textos visibles sin submenús. Privacy Guardian APROBADO. QA-REVIEW-0c-002 criterios 3.2 y 3.3 PASS. |
| Aparece cualquier módulo prohibido (Episode Detector, Pattern Detector, Panel B, sync en tiempo real) en la implementación | NO | Ver sección 3 (Scope Integrity). R12 verificado limpio en todos los componentes de Fase 0c por QA-REVIEW-0c-002. |

**Resultado: ninguna condición de no-paso activada.**

---

## 3. Scope Integrity — ¿Contamina Fase 0c a Fase 2 o posterior?

### 3.1 Módulos de Fase 2 ausentes en Fase 0c

| Módulo prohibido | Presente en Fase 0c | Evidencia |
| --- | --- | --- |
| Pattern Detector | NO | Ninguna referencia en MobileGallery.tsx, MobilePrivacyDashboard.tsx, DriveRelayWorker.kt, raw_event.rs, drive_relay.rs, commands.rs (para el path Android). R12 declarado explícitamente en doc comment de raw_event.rs. |
| Trust Scorer | NO | No existe en el codebase de Fase 0c. Fase 2 desktop primero. |
| State Machine (confianza) | NO | No existe en Fase 0c. D4 y D5 son Fase 2. |
| FS Watcher activo | NO | D9 activo: no hay observer activo fuera del Share Intent. El loop de 30s en desktop escribe/lee en Drive — no observa filesystem local. WorkManager Android usa `NETWORK_CONNECTED`, no filesystem. QA-REVIEW-0c-002 criterio D9 PASS. |
| Panel B en Android | NO | OD-005 lo prohíbe explícitamente. No presente en ningún archivo de Fase 0c. |
| Episode Detector en Android | NO | Ausente. El relay transporta raw_events (D21), no episodios. R12 declarado en raw_event.rs. |
| Session Builder en Android | NO | Ausente. El workspace narrativo es patrimonio del desktop. |
| Sync en tiempo real | NO | Relay async: 15 min WorkManager (Android), 30s loop (desktop). Sin WebSocket, sin push. |

QA-REVIEW-0c-002, sección 5: 7 prohibiciones de OD-005 verificadas ausentes.

### 3.2 Evaluación de contaminación hacia Fase 2

**No existe contaminación.**

La implementación de Fase 0c es aditiva y bien delimitada:

- El backend Android (SQLite + Classifier + Grouper) es autónomo. No pre-carga
  ni configura estructuras que Fase 2 necesitaría modificar de forma incompatible.
- El relay bidireccional es el canal de transporte de raw_events — exactamente como
  D21 lo declara. No anticipa ningún protocolo de Fase 2.
- `MobileGallery.tsx` y `MobilePrivacyDashboard.tsx` son componentes de Fase 0c
  con responsabilidades claramente acotadas. No contienen lógica que pertenezca a
  fases superiores.
- R12 está declarado explícitamente en raw_event.rs y verificado por QA en los tres
  módulos nuevos de Fase 0c.

**Observación activa del Phase Guardian:** la única zona que requiere vigilancia
continuada hacia Fase 2 es el relay en desktop (`drive_relay.rs`). Cuando Fase 2
añada Pattern Detector y State Machine, existe riesgo de que un agente intente
"enriquecer" el raw_event payload con datos de estado de la máquina o con señales
del Pattern Detector. Esto violaría D21 (raw_events en el relay, no estados
procesados) y D4 (la State Machine tiene autoridad — no delega a través del relay).
Este riesgo debe declararse en el backlog de Fase 2 y en el TS correspondiente.

---

## 4. Track iOS — ¿Su ausencia bloquea el gate?

**Estado: NO BLOQUEA. Track independiente con causa de bloqueo legítima.**

**Evaluación:**

OD-005, sección 8 declara explícitamente: "El track iOS sigue abierto como track
paralelo secundario e independiente." El backlog-phase-0c.md (sección "Track iOS")
confirma:

| Módulo | Bloqueo | Estado |
| --- | --- | --- |
| Share Extension iOS | Requiere macOS + Xcode | Pendiente — independiente de Fase 0c |
| Sync Layer MVP (iCloud) | Requiere Share Extension operativa | Pendiente — independiente de Fase 0c |

D19 establece Android + Windows como plataforma primaria. iOS es track paralelo
secundario que requiere entorno macOS. La ausencia de macOS en el entorno actual
es un bloqueo de infraestructura, no una decisión de scope.

**Valoración del Phase Guardian:** la ausencia del track iOS no es un incumplimiento
del gate de Fase 0c — el gate está definido para Android. El track iOS está
explícitamente fuera del scope de Fase 0c por decisión del Orchestrator (OD-005)
y por dependencia de plataforma. Su apertura depende de la disponibilidad de un
entorno macOS, que es un prerequisito externo al enjambre.

**Lo que no puede ocurrir:** que el track iOS permanezca indefinidamente en estado
"pendiente" sin una fecha de evaluación. El Phase Guardian recomienda que el
Orchestrator incluya en el backlog de Fase 2 o Fase 3 una condición de activación
explícita del track iOS (ej. "cuando esté disponible entorno macOS, activar
TS-iOS-001").

---

## 5. Verificación de Constraints Activos No-Negociables

| Constraint | Verificación en Fase 0c | Estado |
| --- | --- | --- |
| D1 — url/title siempre cifrados; domain/category en claro | AES-256-GCM fw1a via FieldCrypto.kt en Android (O-001 cerrada). Rust backend cifra antes del INSERT. Frontend nunca recibe url. Solo domain (en claro) y title (descifrado en backend). | ✅ CONFORME |
| D4 — State Machine tiene autoridad | State Machine no existe en Fase 0c. Trust_score no existe en Fase 0c. No hay anticipación de Fase 2. | ✅ CONFORME (ausencia correcta) |
| D5 — Stability score con entropía normalizada | No aplicable en Fase 0c (Fase 2). No adelantado. | ✅ CONFORME (ausencia correcta) |
| D8 — Baseline determinístico sin LLM | Classifier: mismo crate Rust, tabla hash, D8 declarado. DriveRelayWorker.kt usa tabla estática Kotlin idéntica. Sin modelo externo. | ✅ CONFORME |
| D9 — FS Watcher es el único observer activo en Fase 2; no antes | Ningún observer activo en Fase 0c. Share Intent es el único punto de captura. Loop desktop 30s escribe/lee Drive (no filesystem). WorkManager network-bound (no filesystem). | ✅ CONFORME |
| D14 — Privacy Dashboard completo obligatorio antes de beta | T-0c-004 es el dashboard mínimo móvil de Fase 0c. D14 requiere el completo en Fase 2. Sin anticipación. Privacy Guardian aprobado. | ✅ CONFORME (nivel correcto para Fase 0c) |
| D17 — Pattern Detector completo en Fase 2; no dividido entre fases | Pattern Detector completamente ausente de Fase 0c. | ✅ CONFORME |
| D19 — Android + Windows primario | Fase 0c es nativa de Android. iOS track paralelo secundario. | ✅ CONFORME |
| D20 — App Android como cliente completo | T-0c-001 + T-0c-003 son la implementación directa de D20. | ✅ SATISFECHO |
| D21 — Sync bidireccional via Google Drive relay | T-0c-002 es la implementación directa de D21. | ✅ SATISFECHO (con O-002 pendiente) |
| R12 WATCH — Pattern Detector ≠ Episode Detector | Declarado explícitamente en raw_event.rs, TS-0c-002 y TS-0c-003. Ninguna confusión de propósito. El relay transporta raw_events; la galería muestra recursos; ninguno es un episodio ni un patrón longitudinal. | ✅ WATCH ACTIVO — limpio |

---

## 6. Coherencia Documental — Trazabilidad del Ciclo de Fase 0c

| Artefacto | Estado |
| --- | --- |
| OD-005 (apertura de Fase 0c) | COMPLETADO — 2026-04-24 |
| AR-0c-001 (contratos de arquitectura) | COMPLETADO — 2026-04-24 |
| backlog-phase-0c.md (ACs por tarea) | COMPLETADO — todos los ACs marcados |
| arch-note-T-0c-000-milestone0-result.md (resultado build pipeline) | COMPLETADO |
| TS-0c-002 y TS-0c-003 (task specs) | COMPLETADOS |
| QA-REVIEW-0c-001 (T-0c-000 + T-0c-001) | APROBADO |
| QA-REVIEW-0c-002 (T-0c-002 + T-0c-003 + T-0c-004) | APROBADO CON CONDICIÓN (O-002) |
| HO-007 (cierre sub-ciclo 1) | COMPLETADO |
| Commits FlowWeaver | f0385c5/d219a69 (T-0c-000), a45ad65 (T-0c-001), f83e4b4/0ccc29c (T-0c-002), 4a97d2a (T-0c-003), 3847730 (T-0c-004) |
| O-001 (XOR → AES-256-GCM) | CERRADA en QA-REVIEW-0c-002 |
| O-002 (E2E relay sin OAuth) | ABIERTA — tratada con Option B por Orchestrator |
| PIR-004 (este documento) | EN PRODUCCIÓN |
| HO-008 (cierre formal de Fase 0c) | PENDIENTE — Handoff Manager post-gate |

**Ciclo completo y trazable.** No existe ninguna tarea de Fase 0c sin revisión QA
asociada. La cadena documental es coherente y continua desde OD-005 hasta este gate.

---

## 7. Condiciones Vivas Post-Gate

Estas condiciones no bloquean el gate de Fase 0c pero deben tener seguimiento activo.

| ID | Descripción | Severidad | Responsable | Condición de cierre |
| --- | --- | --- | --- | --- |
| O-002 | Verificación E2E del relay bidireccional con credenciales OAuth de Google Drive configuradas (captura desktop → galería móvil). Option B aplicada. | ALTA para beta | Orchestrator / product owner | Requisito bloqueante antes de beta pública con usuarios reales. Debe documentarse como gate de Fase 3 o como prerequisito de apertura de beta. |
| V1-debt-pull-to-refresh | One-shot WorkManager para trigger de relay inmediato desde pull-to-refresh. El botón [⟳] actual recarga datos locales, no lanza sync. | BAJA | Android Share Intent Specialist | Deferida a V1. No es condición de correctitud. |
| iOS-track | Share Extension iOS + Sync Layer iCloud pendientes por dependencia macOS. | MEDIA a largo plazo | Orchestrator | Condición de activación debe definirse explícitamente (ej. disponibilidad de entorno macOS). |
| Fase-2-relay-guard | Vigilar que Fase 2 no enriquezca raw_events con datos de State Machine o Pattern Detector. Declarar explícitamente en TS de Fase 2. | MEDIA preventiva | Phase Guardian / Technical Architect | Debe incluirse como restricción en el backlog de Fase 2 (backlog-phase-2.md ya está aprobado — verificar si lo recoge; si no, añadir). |

---

## 8. Resultado

| Condición de gate | Estado |
| --- | --- |
| 1 — Galería organizada sin desktop | ✅ SATISFECHA |
| 2 — Relay bidireccional sin pérdida ni duplicación | ✅ SATISFECHA CON CONDICIÓN (O-002 / Option B) |
| 3 — Galería funcional sin conexión | ✅ SATISFECHA |
| 4 — Privacy Dashboard honesto y comprensible | ✅ SATISFECHA |
| Ninguna condición de no-paso activada | ✅ PASS |
| Scope integrity: sin contaminación a Fase 2 o posterior | ✅ PASS |
| Track iOS: ausencia no bloquea el gate | ✅ PASS (track independiente con bloqueo legítimo) |
| Constraints D1–D21 y R12 conformes | ✅ PASS |

**VEREDICTO: PASADO CON CONDICIÓN.**

El gate técnico de Fase 0c está PASADO. La implementación completa de T-0c-000
a T-0c-004 satisface todas las hipótesis del backlog, no activa ninguna condición
de no-paso y está libre de scope creep. Los constraints no-negociables están
verificados conforme en todos los módulos nuevos de la fase.

La condición O-002 (verificación E2E del relay con OAuth activo) no bloquea el
gate técnico por decisión explícita del Orchestrator (Option B), coherente con
el precedente de PIR-003. Esta condición queda registrada como prerequisito
obligatorio de beta pública y debe formalizarse como gate de entrada a Fase 3
o condición de apertura de beta, sin excepción.

---

## 9. Siguiente Agente Responsable

**Handoff Manager → HO-008**

PIR-004 cierra el gate de Fase 0c sin bloqueos activos. El Handoff Manager produce
HO-008 para:
- Registrar el cierre formal de Fase 0c conforme a OD-005.
- Declarar O-002 como condición heredada hacia la apertura de beta.
- Confirmar que Fase 2 está abierta (OD-004 ya emitido el 2026-04-24).
- Incluir la recomendación de vigilancia del relay en el contexto de Fase 2
  (punto Fase-2-relay-guard de la sección 7).

---

## 10. Trazabilidad

| Acción | Archivo | Estado |
| --- | --- | --- |
| Gate de Fase 0c evaluado | operations/phase-integrity-reviews/PIR-004-phase-0c-gate.md | este documento |
| Gate PASADO CON CONDICIÓN declarado | PIR-004 | 2026-04-24 |
| O-002 registrada como condición viva | sección 7 de este documento | activa |
| Siguiente agente notificado | Handoff Manager — HO-008 | pendiente |
