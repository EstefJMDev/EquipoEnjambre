# FlowWeaver - Module Map

## Proposito

Mapear los modulos conceptuales del producto para que el sistema multiagente
sepa que existe en cada fase, quien posee la documentacion y que debe quedar
fuera.

Cada modulo tiene un solo owner documental.
Los roles consultados no crean co-ownership.

| Modulo | Primera fase permitida | Owner documental primario | Consultados obligatorios | Inputs | Outputs | Restriccion dura |
| --- | --- | --- | --- | --- | --- | --- |
| Desktop Workspace Shell | 0a | Desktop Tauri Shell Specialist | Technical Architect, Functional Analyst | recursos agrupados, decisiones de fase | contrato del contenedor workspace, limites de paneles activos | solo documental en este repo |
| Bookmark Importer Retroactive | 0a | Desktop Tauri Shell Specialist | Functional Analyst, Phase Guardian | bookmarks Safari/Chrome | recursos bootstrap normalizados para 0a | solo bootstrap; no es observer ni caso nucleo |
| Share Extension iOS | 0b | iOS Share Extension Specialist | Privacy Guardian, Technical Architect | URL compartida, metadata explicita | contrato del evento capturado | no antes de 0b |
| Session Builder | 0b | Session & Episode Engine Specialist | Technical Architect, Functional Analyst | eventos capturados | contrato de sesion candidata | no antes de 0b |
| Episode Detector Dual-Mode | 0b | Session & Episode Engine Specialist | Technical Architect, QA Auditor | sesiones candidatas, taxonomia | contrato de episodio accionable o no accionable | no antes de 0b |
| Sync Relay MVP | 0b | Sync & Pairing Specialist | Privacy Guardian, Technical Architect, QA Auditor | senial cifrada, ACK, retries | contrato del protocolo relay | solo relay cifrado; no backend propia ni P2P en MVP |
| Privacy Dashboard Minimum | 0b | Privacy Guardian | Functional Analyst, QA Auditor | inventario de datos, controles minimos | contrato de superficie minima de control | solo minimo hasta Fase 2 |
| FS Watcher | 1 | Desktop Tauri Shell Specialist | Phase Guardian, Technical Architect | archivos locales permitidos | contrato de eventos de archivo | no antes de Fase 1 |
| Panel B Templates | 1 | Desktop Tauri Shell Specialist | Functional Analyst | episodio o set de archivos organizado | contrato de siguiente paso guiado por plantilla | no antes de Fase 1 |
| Pattern Detector | 2 | Technical Architect | Session & Episode Engine Specialist, QA Auditor | historial longitudinal | contrato de patron recurrente | no antes de Fase 2 |
| Trust Scorer | 2 | Technical Architect | QA Auditor | patrones y seniales longitudinales | contrato de score de apoyo | no antes de Fase 2 |
| State Machine | 2 | Technical Architect | QA Auditor, Phase Guardian | trust score, reglas de transicion | contrato de autoridad de automatizacion | no antes de Fase 2 |
| Explainability Log | 2 | Privacy Guardian | Technical Architect, QA Auditor | decisiones del sistema | contrato de explicacion auditable | no antes de Fase 2 |

## Reglas De Uso

* si un modulo no esta permitido todavia, solo puede aparecer como restriccion
  futura
* ningun modulo futuro puede colarse en matrices, backlog o handoffs como trabajo
  activo
* ownership documental nunca autoriza implementacion funcional en este repo
