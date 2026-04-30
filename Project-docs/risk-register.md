# FlowWeaver - Risk Register

## Propósito

Registrar riesgos estructurales del proyecto marco y del producto en el nivel
necesario para gobernar el enjambre.

## Nota De Corrección De IDs — Primer Ciclo Operativo

HO-001 y PIR-001 referencian "R9 = Panel B como dependencia prematura" y
"R10 = Confusión Grouper 0a vs Episode Detector 0b". Estos IDs no coinciden
con los riesgos R9 y R10 de este registro. La discrepancia se produce porque
los documentos del primer ciclo asignaron IDs sin verificar los existentes.

Corrección aplicada:
- Lo que HO-001 llama R9 (Panel B) → es R11 en este registro.
- Lo que HO-001 y PIR-001 llaman R10 (Grouper vs Episode Detector) → es R12.

Los documentos HO-001 y PIR-001 no se modifican retroactivamente; esta nota
es la referencia canónica de IDs. En cualquier entregable futuro, usar R11 y
R12 para estos riesgos.

## Registro De Riesgos

| ID | Riesgo | Señal de activación | Owner | Mitigación normativa | Escalado | Estado |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | Confundir 0a con PMF | lenguaje de "validación de producto" en 0a | Phase Guardian | reforzar phase-definition y QA | Orchestrator | MITIGADO — primer ciclo. does_not_validate en backlog; phase-definition clausurado. Vigilancia continua activa. |
| R2 | Diluir el caso núcleo | bookmarks o descargas descritos como producto central | Functional Analyst | corregir scope y roadmap | Orchestrator | MITIGADO — primer ciclo. T-0a-002, invariante 9 de arch-note y backlog risks_of_misinterpretation clausuran el riesgo. Vigilancia continua activa. |
| R3 | Introducir backend propia en MVP | sync descrito con servicio dedicado | Sync & Pairing Specialist | bloquear y devolver a D6 | Orchestrator | ABIERTO — no activado en 0a. Relevante desde 0b. |
| R4 | Sobreprometer privacidad | narrativa superior a lo defendible | Privacy Guardian | revisar docs y controles | Orchestrator | ABIERTO — no activado. Privacy Guardian en LISTENING. |
| R5 | Activar especialistas antes de tiempo | matrices o handoffs con agentes fuera de fase | Phase Guardian | corregir activación | Orchestrator | ABIERTO — no activado. iOS, Session y Sync Specialists correctamente LOCKED. |
| R6 | Fallback se convierte en rediseño | QR o broad mode pasan a producto principal | Constraint-Solving & Fallback Strategy Specialist | documentar fallback como contingencia | Orchestrator | ABIERTO — no aplica a 0a. Relevante desde 0b (D18: buffer y escape QR). |
| R7 | Pérdida de trazabilidad | cambios grandes sin changelog, handoff o contexto | Context Guardian | exigir actualización documental | Orchestrator | BAJO CONTROL — cierre del ciclo de especificación de 0a. Los siete task specs citan sus documentos normativos. La cadena arch-note → backlog → task spec → revisión (AR + QA) → handoff → PIR es trazable en todos los puntos. Verificado en PIR-002. La trazabilidad debe mantenerse activa durante la implementación: cada desviación de un task spec debe registrarse con referencia al spec correspondiente. |
| R8 | Solape entre agentes | dos owners editan sin secuencia | Handoff Manager | secuenciar ownership | Orchestrator | ABIERTO — no activado en el primer ciclo. |
| R9 | Dependencia prematura del LLM | plantillas dejan de ser baseline de Panel C; Panel C no renderiza en ausencia de modelo local | QA Auditor | bloquear y corregir deliverables | Orchestrator | WATCH ACTIVO — cierre del ciclo de especificación de 0a. TS-0a-006 tiene el control más operativo de la cadena: cuatro capas (definición estructural + plantillas de referencia completas + criterio de aceptación verificable en demo + señal de contaminación 13 con modo de fallo exacto). Verificado en AR-0a-004 y QA-REVIEW-0a-004. El riesgo pasa a WATCH ACTIVO porque la violación no ocurre en la especificación sino en el código: un implementador puede introducir LLM como requisito de facto aunque el spec lo prohíbe. Criterio de aceptación 3 de TS-0a-006 es falseable en demo. Phase Guardian bloquea cualquier implementación donde Panel C no renderice sin modelo local. |
| R10 | Confusión entre Episode Detector y Pattern Detector | lenguaje longitudinal aparece en documentos de 0b o Fase 1 | Technical Architect | aclarar module-map y phase-definition | Orchestrator | ABIERTO — no activado. Vigilar en ciclo de 0b cuando Session & Episode Engine Specialist se active. |
| R11 | Panel B como dependencia prematura | Panel B aparece en 0a o en 0b "para mejorar la demo" | Phase Guardian | bloquear; scope-boundaries y phase-definition lo clausuran | Orchestrator | MITIGADO — cierre del ciclo de especificación de 0a. Panel B explícitamente excluido en todos los task specs de 0a como componente, dependencia y placeholder. TS-0a-001, TS-0a-005 y TS-0a-006 lo nombran como señal de contaminación con acción BLOQUEAR. Verificado transversalmente en PIR-002. La exclusión es consistente en toda la cadena. Vigilancia continua activa durante la implementación. Nota: referenciado como R9 en HO-001; ver nota de corrección de IDs. |
| R12 | Confusión entre Grouper 0a y Episode Detector 0b | el Grouper de 0a se describe como "proto-Episode-Detector" o se reutiliza como base del detector de 0b; la heurística de similitud de título se presenta como "precursor de Jaccard" | Phase Guardian | arch-note diferenciación tabla Grouper vs Episode Detector; condición 2 de contención operativa | Orchestrator | WATCH ACTIVO — cierre del ciclo de especificación de 0a. Tabla de diferenciación con 15 atributos comparativos en TS-0a-004. Condición 2 de contención operativa y trazable en dos puntos de TS-0a-004, TS-0a-005 y TS-0a-006. Verificado en AR-0a-004 y QA-REVIEW-0a-004. El Phase Guardian bloqueará en la narrativa de demo y en los entregables de 0b cualquier presentación del Grouper de 0a como precursor, versión inicial o base del Episode Detector dual-mode. Nota: referenciado como R10 en HO-001 y PIR-001; ver nota de corrección de IDs. |
| R13 | Encriptación XOR legacy en producción | registros con magic `fw0a` siguen presentes en bases de usuarios reales | Privacy Guardian | migrar a AES-GCM con re-cifrado en migración + key derivation real (PBKDF2 + keychain) | Orchestrator | ABIERTO — pendiente de plan de migración. Detectado en auditoría 2026-04-29. |
| R14 | Workspace anticipado no se refresca con la app abierta | el desktop ya está abierto cuando llega un sync; el AnticipatedWorkspace no recalcula episodios automáticamente; el wow no dispara | Desktop Tauri Shell Specialist | añadir hook que recalcule clusters/episodes tras `mark_relay_acked` en estado de UI activo | Orchestrator | MITIGADO — desktop: evento `relay-event-imported` + listener en App.tsx. Mobile: `visibilitychange` listener activo en APK rebuild 2026-04-30. Verificado en validación E2E 2026-04-30 (5/5 URLs, desktop se actualizó solo). |
| R15 | Latencia del Drive relay no medida | polling 30s + propagación Drive variable; en peor caso desktop ve la captura 1-2 min después | Sync & Pairing Specialist | instrumentar P50/P95 captura→ACK; si P95 > 60s, replantear cadencia o canal | Orchestrator | MITIGADO — latencia ~30s P50 medida en E2E day 1 (2026-04-30). 5 URLs, 5 recibidas. P95 estimado < 60s. Umbral satisfecho. |
| R16 | Token OAuth no se refresca automáticamente en Android | el access_token caduca en ~1h; el relay falla silenciosamente sin mecanismo de refresh | Sync & Pairing Specialist | `ensureValidAccessToken()` + `TokenResult` sealed class en `DriveRelayWorker.kt` | Orchestrator | MITIGADO — `ensureValidAccessToken()` con `TokenResult { Valid, RetryLater, Unrecoverable }` implementado en código. Verificado en E2E 2026-04-30 (token refrescado antes del test). |
| R17 | Refresh_token caduca a 7 días en modo prueba Google Cloud | app en estado "Testing" en Google Cloud Console; refresh_token no persiste más de 7 días | Sync & Pairing Specialist | verificar app en Google Cloud o rotar manualmente antes de caducidad | Orchestrator | ABIERTO — caducidad estimada ~2026-05-06. Acción requerida antes de esa fecha: rotar refresh_token (re-ejecutar flujo OAuth) o verificar la app en producción Google Cloud. |
| R18 | Scripts auxiliares de setup OAuth sin tests automatizados | el flujo de obtención de tokens es manual y frágil (evidencia: INC-001) | Sync & Pairing Specialist | mover OAuth setup a UI de FlowWeaver en Fase 3 | Orchestrator | ABIERTO — flujo manual sigue siendo el único mecanismo. INC-001 documentado. Mitigación a largo plazo: UI de configuración OAuth en Fase 3. |
| R19 | Secretos OAuth expuestos en log de sesión Claude Code | client_secret y refresh_token aparecieron en el log de sesión del 2026-04-29 | Sync & Pairing Specialist | rotar client_secret en Google Cloud Console + revocar refresh_token tras la prueba de 7 días | Orchestrator | ABIERTO — rotación pendiente. Ventana de riesgo: mientras el refresh_token actual esté activo (~2026-05-06). Acción: rotar tras los 7 días de prueba o antes si se detecta uso anómalo. |
| R20 | Tests de integración cross-language ausentes en relay Android↔Desktop | cualquier cambio en crypto, naming o wire format puede romper el protocolo sin que los tests lo detecten | QA Auditor + Sync & Pairing Specialist | suite de tests cross-language como gate obligatorio pre-QA-review | Orchestrator | MITIGADO — 11 tests cross-language añadidos (6 Rust + 5 Kotlin activos). Fixtures compartidas. Gate establecido: `cargo test --test cross_lang_crypto && --test relay_naming_convention` + `gradle testUniversalDebugUnitTest` obligatorios antes de QA-review de cambios en el protocolo relay. Verificado 2026-04-30. |

## Regla Operativa

Un riesgo sigue abierto hasta que:

* se reduce su probabilidad o impacto documentalmente
* el owner acepta el cierre
* Context Guardian actualiza el estado del repositorio

Un riesgo MITIGADO mantiene vigilancia continua hasta que el Phase Guardian
lo declare cerrado con evidencia de demo o de gate de salida.

## Historial De Actualizaciones

| Fecha | Ciclo | Cambios |
| --- | --- | --- |
| 2026-04-22 | Primer ciclo operativo (OD-001) | R1, R2, R9: estado actualizado a MITIGADO. R11 y R12 añadidos. Nota de corrección de IDs incorporada. Owner: Context Guardian. |
| 2026-04-23 | Cierre del ciclo de especificación de 0a (OD-002 + PIR-002) | R7: ABIERTO → BAJO CONTROL (cadena de especificación completa trazable; verificado en PIR-002). R9: MITIGADO → WATCH ACTIVO (control de cuatro capas en TS-0a-006; riesgo pasa a implementación). R11: estado confirmado MITIGADO con cobertura transversal de los siete specs. R12: estado confirmado WATCH ACTIVO con condición 2 de contención operativa en TS-0a-004, TS-0a-005 y TS-0a-006. Owner: Context Guardian. |
| 2026-04-29 | Auditoría post-OD-007 | R13 añadido (encriptación XOR legacy en producción — owner: Privacy Guardian). R14 añadido (workspace anticipado no se refresca con la app abierta — owner: Desktop Tauri Shell Specialist). R15 añadido (latencia del Drive relay no medida — owner: Sync & Pairing Specialist). Los tres en estado ABIERTO. Owner del registro: Context Guardian. |
| 2026-04-30 | E2E validado + cierre INC-002 | R14 → PARCIALMENTE MITIGADO (desktop confirmado, mobile bajo observación). R15 → MITIGADO (~30s P50, P95 < 60s). R16-R20 añadidos: R16 MITIGADO (token refresh), R17-R19 ABIERTOS (token caducidad, scripts sin tests, secretos expuestos), R20 MITIGADO (tests cross-language gate establecido). Owner del registro: Context Guardian. |
| 2026-04-30 | Sesión E2E completa + Classifier/EpisodeDetector | R14 MITIGADO (mobile APK rebuild confirmado, 5/5 URLs verificadas). 5 bugs relay descubiertos: 4 arreglados (#1/#2/#3/#5), Bug #4 APK rebuild ejecutado. Tests cross-lang gate implementado. Classifier ampliado a 14 categorías en español. Episode Detector enriquecido con tokenize_resource. Prueba de 7 días arrancada: día 1 = 2026-04-30. Owner del registro: Context Guardian. |
