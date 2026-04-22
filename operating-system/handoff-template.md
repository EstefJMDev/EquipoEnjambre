# FlowWeaver - Handoff Template

## Uso

Plantilla canónica para transferencias relevantes entre agentes.

```md
# Standard Handoff

from_agent:
to_agent:
status:
phase:

## Objective

## Context Read

## Decisions Applied

## Constraints Respected

## Outputs Produced

## Open Risks

## Blockers

## Required Documents To Update

## Recommended Next Step
```

## Reglas

* `status` debe ser uno de `ready_for_execution`, `ready_for_review`,
  `blocked_pending_decision`
* debe quedar claro si existe riesgo de contaminación de fase
* si faltan restricciones, el handoff es inválido
