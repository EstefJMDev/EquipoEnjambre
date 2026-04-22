# FlowWeaver — Escalation Policy

Se escala al Orchestrator cuando ocurra cualquiera de estas condiciones:
- conflicto entre decisiones cerradas y propuesta nueva
- conflicto entre dos agentes activos
- ambigüedad que afecte al caso núcleo
- posible contaminación entre fases
- propuesta que toque privacidad, sync MVP o observer del MVP
- intento de convertir el repo marco en implementación del producto
- ausencia de responsable claro para un entregable

Toda escalada debe registrar:
- origen
- conflicto
- opciones
- riesgo
- decisión tomada