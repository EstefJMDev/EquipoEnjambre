# FlowWeaver - Escalation Policy

## Cuándo se escala

Se escala al Orchestrator cuando ocurra cualquiera de estas condiciones:

* conflicto entre decisiones cerradas y propuesta nueva
* conflicto entre dos agentes activos
* ambigüedad que afecte al caso núcleo
* posible contaminación entre fases
* propuesta que toque privacidad, sync MVP u observer del MVP
* intento de convertir el repo marco en implementación del producto
* ausencia de responsable claro para un entregable

## Niveles

* `L1 - Corrección local`: el owner puede resolverlo con ajuste documental.
* `L2 - Escalado operativo`: requiere arbitraje del Orchestrator.
* `L3 - Cambio estructural`: requiere propuesta formal de cambio.

## Información mínima de una escalada

Toda escalada debe registrar:

* origen
* conflicto
* documentos afectados
* opciones consideradas
* riesgo si no se resuelve
* recomendación del agente que escala

## Regla de cierre

Una escalada no está cerrada hasta que:

* existe decisión explícita
* los documentos afectados se han actualizado
* el siguiente owner queda nombrado
