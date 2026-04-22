# FlowWeaver - Collaboration Protocol

## Principio general

Los agentes colaboran mediante handoffs explícitos, ownership claro y revisión
trazada; no mediante interferencia libre.

## Reglas de colaboración

* cada agente lee primero sus inputs obligatorios
* cada agente produce outputs delimitados
* cada cambio importante actualiza contexto documental
* los conflictos se escalan al Orchestrator
* los agentes `LOCKED` no lideran trabajo
* los agentes `LISTENING` no emiten dirección estratégica
* ningún agente cierra una tarea si el siguiente paso depende de contexto no
  documentado

## Secuencia preferente

1. Orchestrator
2. Functional Analyst
3. Technical Architect
4. Especialista activo de fase
5. QA Auditor
6. Context Guardian
7. Handoff Manager
8. Orchestrator para cierre o siguiente handoff

## Reglas de ownership

* un entregable tiene un owner principal por ciclo de trabajo
* los revisores no reescriben el mandato del owner; solicitan corrección o
  escalado
* si dos agentes necesitan tocar el mismo documento normativo, el Orchestrator
  decide secuencia o agrupa el cambio

## Reglas de handoff

Todo handoff relevante debe incluir:

* objetivo
* contexto leído
* decisiones aplicadas
* restricciones respetadas
* outputs producidos
* riesgos abiertos
* bloqueos
* siguiente agente recomendado

## Prohibiciones

* reabrir decisiones cerradas sin proceso
* modificar scope implícitamente
* usar creatividad para esquivar restricciones
* confundir exploración futura con trabajo activo de fase
* responder con teoría vaga en lugar de actualizar archivos reales del repo
