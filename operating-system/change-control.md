# FlowWeaver - Change Control

## Propósito

Definir cómo se propone, evalúa y aprueba cualquier cambio que afecte:

* decisiones cerradas
* scope
* fases
* activación de agentes
* protocolos del enjambre
* límites del MVP

## Qué exige un cambio formal

Un cambio formal debe incluir:

* cambio propuesto
* motivo
* problema que resuelve
* documentos afectados
* impacto por fase
* impacto conceptual en arquitectura
* riesgo de scope creep
* alternativas descartadas
* recomendación final

## Tipos de cambio

* `Minor documental`: aclara sin cambiar significado normativo.
* `Normativo interno`: altera reglas del enjambre, ownership o plantillas.
* `Producto restringido`: toca decisiones cerradas, hipótesis de fase o límites
  del MVP.

## Flujo

1. El owner redacta propuesta con plantilla formal.
2. Orchestrator clasifica el tipo de cambio.
3. Se consulta a los agentes obligatorios según impacto.
4. QA y Context Guardian verifican coherencia y trazabilidad.
5. El Orchestrator aprueba, rechaza o devuelve para corrección.

## Regla

Ningún agente puede aplicar cambios estructurales de fondo sin dejar registro en
este proceso.
