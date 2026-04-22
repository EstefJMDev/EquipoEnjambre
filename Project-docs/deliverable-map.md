# FlowWeaver - Deliverable Map

## Entregables Permitidos En Este Repo

* documento normativo
* propuesta de cambio
* auditoria
* matriz
* plantilla
* handoff
* checklist
* revision de coherencia
* analisis de riesgo
* nota de cierre de fase

## Entregables Prohibidos En Este Repo

* codigo funcional del producto
* modulos del producto
* apps del producto
* servicios del producto
* infraestructura del producto

## Leyenda Operativa

* `owner`: puede ser owner y producir el entregable
* `review_only`: puede revisar o asesorar, pero no ser owner
* `watch_only`: solo vigila violaciones
* `escalation_only`: solo produce output tras escalado explicito por bloqueo
* `no`: no debe producir ese output en esa fase

## Entregables Por Agente Y Fase

| Agent | Deliverables principales | 0a | 0b | 1 | 2 | 3 | V1/V2+ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Orchestrator | decisiones operativas, activaciones, bloqueos, escalados | owner | owner | owner | owner | owner | owner |
| Functional Analyst | breakdowns funcionales, criterios, limites de scope | owner | owner | owner | owner | owner | owner |
| Technical Architect | arquitectura conceptual, decisiones modulares, contratos documentales | owner | owner | owner | owner | owner | owner |
| QA Auditor | auditorias, gate reviews, bloqueos de calidad | owner | owner | owner | owner | owner | owner |
| Context Guardian | updates de contexto, changelog, alertas de consistencia | owner | owner | owner | owner | owner | owner |
| Privacy Guardian | revisiones de privacidad, notas de limite de datos, alertas | watch_only | owner | owner | owner | owner | owner |
| Phase Guardian | revisiones de integridad de fase, notas de activacion | owner | owner | owner | owner | owner | owner |
| Handoff Manager | handoffs estandar, rechazos de transferencia, notas de continuidad | owner | owner | owner | owner | owner | owner |
| Constraint-Solving & Fallback Strategy Specialist | analisis de fallback, trade-off notes, rutas de contingencia | escalation_only | escalation_only | escalation_only | escalation_only | escalation_only | escalation_only |
| Desktop Tauri Shell Specialist | specs del shell, limites de paneles, checklists desktop | owner | owner | owner | review_only | review_only | review_only |
| iOS Share Extension Specialist | contrato de captura, reglas de payload, checklist del observer | no | owner | review_only | review_only | review_only | review_only |
| Session & Episode Engine Specialist | contrato de Session Builder, notas del detector, matrices precise/broad | no | owner | owner | review_only | review_only | review_only |
| Sync & Pairing Specialist | protocolo de relay cifrado, reglas ACK/idempotencia, notas de fallback QR | no | owner | review_only | review_only | review_only | owner |

## Regla

Todo output de este mapa debe seguir siendo gobernanza, no implementacion.
Si empieza a parecer scaffolding, build logic o codigo del producto, queda fuera
de scope para este repositorio.
