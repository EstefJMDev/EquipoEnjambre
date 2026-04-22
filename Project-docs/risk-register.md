# FlowWeaver - Risk Register

## Propósito

Registrar riesgos estructurales del proyecto marco y del producto en el nivel
necesario para gobernar el enjambre.

| ID | Riesgo | Señal de activación | Owner | Mitigación normativa | Escalado |
| --- | --- | --- | --- | --- | --- |
| R1 | Confundir 0a con PMF | lenguaje de "validación de producto" en 0a | Phase Guardian | reforzar phase-definition y QA | Orchestrator |
| R2 | Diluir el caso núcleo | bookmarks o descargas descritos como producto central | Functional Analyst | corregir scope y roadmap | Orchestrator |
| R3 | Introducir backend propia en MVP | sync descrito con servicio dedicado | Sync & Pairing Specialist | bloquear y devolver a D6 | Orchestrator |
| R4 | Sobreprometer privacidad | narrativa superior a lo defendible | Privacy Guardian | revisar docs y controles | Orchestrator |
| R5 | Activar especialistas antes de tiempo | matrices o handoffs con agentes fuera de fase | Phase Guardian | corregir activación | Orchestrator |
| R6 | Fallback se convierte en rediseño | QR o broad mode pasan a producto principal | Constraint-Solving & Fallback Strategy Specialist | documentar fallback como contingencia | Orchestrator |
| R7 | Pérdida de trazabilidad | cambios grandes sin changelog, handoff o contexto | Context Guardian | exigir actualización documental | Orchestrator |
| R8 | Solape entre agentes | dos owners editan sin secuencia | Handoff Manager | secuenciar ownership | Orchestrator |
| R9 | Dependencia prematura del LLM | plantillas dejan de ser baseline | QA Auditor | bloquear y corregir deliverables | Orchestrator |
| R10 | Confusión entre Episode Detector y Pattern Detector | lenguaje longitudinal en 0b/1 | Technical Architect | aclarar module-map y phase-definition | Orchestrator |

## Regla operativa

Un riesgo sigue abierto hasta que:

* se reduce su probabilidad o impacto documentalmente
* el owner acepta el cierre
* Context Guardian actualiza el estado del repositorio
