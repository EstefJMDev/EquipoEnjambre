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
| R7 | Pérdida de trazabilidad | cambios grandes sin changelog, handoff o contexto | Context Guardian | exigir actualización documental | Orchestrator | ABIERTO — monitoreado activamente. Todos los entregables del primer ciclo tienen trazabilidad explícita. |
| R8 | Solape entre agentes | dos owners editan sin secuencia | Handoff Manager | secuenciar ownership | Orchestrator | ABIERTO — no activado en el primer ciclo. |
| R9 | Dependencia prematura del LLM | plantillas dejan de ser baseline de Panel C | QA Auditor | bloquear y corregir deliverables | Orchestrator | MITIGADO — primer ciclo. T-0a-006 y TS-0a-001 confirman baseline por plantillas sin LLM. Invariante 4 de arch-note. D8 enforced. Vigilancia continua activa. |
| R10 | Confusión entre Episode Detector y Pattern Detector | lenguaje longitudinal aparece en documentos de 0b o Fase 1 | Technical Architect | aclarar module-map y phase-definition | Orchestrator | ABIERTO — no activado. Vigilar en ciclo de 0b cuando Session & Episode Engine Specialist se active. |
| R11 | Panel B como dependencia prematura | Panel B aparece en 0a o en 0b "para mejorar la demo" | Phase Guardian | bloquear; scope-boundaries y phase-definition lo clausuran | Orchestrator | MITIGADO — primer ciclo. Clausurado en scope-boundaries.md, phase-definition.md y arch-note. Invariante 5. Vigilancia continua activa. Nota: referenciado como R9 en HO-001; ver nota de corrección de IDs. |
| R12 | Confusión entre Grouper 0a y Episode Detector 0b | el Grouper de 0a se describe como "proto-Episode-Detector" o se reutiliza como base del detector de 0b | Phase Guardian | arch-note diferenciación tabla Grouper vs Episode Detector | Orchestrator | WATCH ACTIVO — tabla de diferenciación explícita en arch-note. El Phase Guardian bloqueará cualquier entregable de 0b que reutilice el Grouper de 0a como punto de partida del Episode Detector. Nota: referenciado como R10 en HO-001 y PIR-001; ver nota de corrección de IDs. |

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
