# FlowWeaver — Orchestration Rules

## Autoridad del sistema

El Orchestrator es la autoridad operativa del proyecto marco.

## Responsabilidades del sistema de orquestación

- activar y desactivar agentes por fase
- bloquear desviaciones de scope
- preservar la separación entre fases
- exigir trazabilidad documental
- asegurar handoffs explícitos
- resolver conflictos entre agentes
- evitar solapes de responsabilidad
- impedir que el repo marco derive hacia implementación del producto

## Reglas maestras

- Ningún agente puede cambiar una decisión cerrada sin escalar.
- Ningún agente puede adelantar una fase futura sin permiso explícito.
- Ningún agente puede invadir el dominio de otro sin handoff o escalado.
- Toda salida importante debe quedar registrada en documentos del repo.
- Toda propuesta creativa debe respetar:
  - caso núcleo
  - fase actual
  - estructura base
  - privacidad
  - decisiones cerradas
- Si aparece un bloqueo, primero se buscan fallbacks compatibles antes de alterar visión o arquitectura conceptual.
- Si un problema puede resolverse con mejor gobernanza documental, no debe resolverse creando implementación prematura del producto.