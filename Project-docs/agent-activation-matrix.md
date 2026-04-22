# FlowWeaver - Agent Activation Matrix

## Significado De Estados

| Estado | Permiso operativo | Uso correcto |
| --- | --- | --- |
| ACTIVE | Puede liderar trabajo y producir entregables. | El agente es owner principal de esa fase o tarea. |
| LISTENING | Puede revisar, alertar y asesorar, pero no liderar. | Debe seguir disponible sin tomar control. |
| LOCKED | Todavia no puede participar. | La fase no habilita su dominio. |
| ARCHIVAL | Solo referencia historica. | No tiene mandato operativo actual. |

## Regla De Autoridad

Esta matriz es la autoridad de estado por fase.
Si un archivo individual de agente sugiere otro `default_state`, esta matriz
manda.

## Matriz Por Fase

| Agent | 0a | 0b | 1 | 2 | 3 | V1/V2+ | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Orchestrator | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | Autoridad operativa permanente. |
| Functional Analyst | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | Scope y aceptacion siguen activos en todas las fases. |
| Technical Architect | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | Arquitectura conceptual activa en todas las fases. |
| QA Auditor | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | Revision critica obligatoria en todas las fases. |
| Context Guardian | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | La trazabilidad siempre esta activa. |
| Privacy Guardian | LISTENING | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | Vigila en 0a; lidera revision de privacidad desde 0b. |
| Phase Guardian | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | Lidera integridad de fase en todo el roadmap. |
| Handoff Manager | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | ACTIVE | Estructura de transferencia y continuidad siempre activas. |
| Constraint-Solving & Fallback Strategy Specialist | LISTENING | LISTENING | LISTENING | LISTENING | LISTENING | LISTENING | Solo puede pasar a ACTIVE a nivel de tarea si hay escalado explicito por bloqueo. |
| Desktop Tauri Shell Specialist | ACTIVE | ACTIVE | ACTIVE | LISTENING | LISTENING | LISTENING | Lidera shell desktop en 0a-1; despues solo revisa o apoya continuidad. |
| iOS Share Extension Specialist | LOCKED | ACTIVE | LISTENING | LISTENING | LISTENING | LISTENING | No tiene ownership legitimo antes de 0b. |
| Session & Episode Engine Specialist | LOCKED | ACTIVE | ACTIVE | LISTENING | LISTENING | LISTENING | Lidera Session Builder y Episode Detector solo en 0b-1. |
| Sync & Pairing Specialist | LOCKED | ACTIVE | LISTENING | LISTENING | LISTENING | ACTIVE | Lidera sync MVP en 0b y recupera ownership en V1/V2+. |

## Errores Comunes De Activacion Temprana

* activar iOS Share Extension Specialist en 0a y adelantar el puente antes de
  validar el workspace
* activar Sync & Pairing Specialist en 0a e importar sync MVP demasiado pronto
* dejar al especialista de fallbacks de facto al mando y convertir contingencia
  en diseno principal
* activar especialistas de fases futuras "para dejarlo preparado"

## Por Que Algunos Agentes Existen Antes De Liderar

El sistema debe poder nombrar, consultar y bloquear estos agentes desde el
principio sin permitir que arrastren trabajo futuro a la fase actual.
