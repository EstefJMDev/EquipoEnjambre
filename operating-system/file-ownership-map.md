# FlowWeaver - File Ownership Map

## Regla

Este mapa asigna ownership documental primario.
Evita solapes, pero no elimina revision obligatoria.

Si una fila con wildcard y una fila especifica aplican a la vez, gana la fila
especifica.

## Mapa De Ownership

| Area documental | Owner primario | Revisores obligatorios | Notas |
| --- | --- | --- | --- |
| `AGENTS.md` | Orchestrator | Context Guardian, QA Auditor | Rulebook global del repositorio. |
| `project-docs/vision.md` | Functional Analyst | Orchestrator, Privacy Guardian | Cambios de alto riesgo. |
| `project-docs/product-thesis.md` | Functional Analyst | Orchestrator, Phase Guardian | No redefine roadmap por si solo. |
| `project-docs/scope-boundaries.md` | Functional Analyst | Phase Guardian, QA Auditor | Debe mantener in-scope y out-of-scope explicitos. |
| `project-docs/roadmap.md` | Phase Guardian | Orchestrator, Functional Analyst | Autoridad de secuencia del producto. |
| `project-docs/phase-definition.md` | Phase Guardian | Functional Analyst, QA Auditor | Define lo que valida cada fase. |
| `project-docs/decisions-log.md` | Context Guardian | Orchestrator, QA Auditor | Registro canonico de decisiones cerradas. |
| `project-docs/agent-activation-matrix.md` | Orchestrator | Phase Guardian, QA Auditor | Autoridad de estado por fase. |
| `project-docs/agent-responsibility-matrix.md` | Orchestrator | Context Guardian, QA Auditor | Autoridad de ownership entre agentes. |
| `project-docs/deliverable-map.md` | Handoff Manager | QA Auditor, Context Guardian | Outputs permitidos por agente y fase. |
| `project-docs/architecture-overview.md` | Technical Architect | Privacy Guardian, Phase Guardian | Solo conceptual, nunca implementativo. |
| `project-docs/module-map.md` | Technical Architect | Functional Analyst, QA Auditor | Un owner primario por modulo. |
| `project-docs/risk-register.md` | Context Guardian | Orchestrator, Privacy Guardian, QA Auditor | Riesgos vivos y mitigaciones. |
| `project-docs/task-template.md` | Functional Analyst | QA Auditor | Estructura de tareas documentales. |
| `project-docs/acceptance-criteria-template.md` | Functional Analyst | QA Auditor | Estructura de criterios de aceptacion. |
| `operating-system/*` | Orchestrator | QA Auditor, Context Guardian | Owner por defecto de reglas operativas salvo fila mas especifica. |
| `operating-system/handoff-template.md` | Handoff Manager | Context Guardian, QA Auditor | Plantilla canonica de transferencias. |
| `operating-system/templates/*` | Handoff Manager | QA Auditor, Context Guardian | Plantillas operativas reutilizables. |
| `agents/*.md` | Owner del agente | Orchestrator, QA Auditor | Cada agente gobierna su mandato; Orchestrator alinea el sistema. |
