# FlowWeaver - Orchestration Rules

## Autoridad Del Sistema

El Orchestrator es la autoridad operativa del proyecto marco.
Esa autoridad aplica al sistema multiagente, no a la implementacion del
producto.

## Precedencia De Autoridad

Si documentos operativos parecen chocar, aplica este orden:

1. `AGENTS.md`
2. `project-docs/decisions-log.md`
3. `project-docs/agent-activation-matrix.md`
4. `project-docs/agent-responsibility-matrix.md`
5. `operating-system/*`
6. archivos individuales de agente en `agents/*`

Los conflictos de estado por fase se resuelven con la matriz de activacion.
El `default_state` de un agente no puede imponerse sobre la matriz por fase.

## Responsabilidades De Orquestacion

* activar y desactivar agentes por fase y por tipo de tarea
* bloquear desvio de scope o de fase
* preservar la separacion entre fases
* exigir trazabilidad documental
* exigir handoffs explicitos
* resolver conflictos entre agentes
* impedir solapes de responsabilidad
* impedir que este repo derive a implementacion del producto

## Reglas Maestras

* ningun agente cambia una decision cerrada sin escalado
* ningun agente adelanta una fase futura sin permiso explicito
* ningun agente invade otro dominio sin handoff o escalado
* toda salida importante debe quedar capturada en archivos del repo
* toda propuesta creativa debe respetar caso nucleo, fase activa, limites del
  MVP, privacidad y decisiones cerradas
* si aparece un bloqueo, primero se exploran fallbacks compatibles antes de
  alterar vision o arquitectura conceptual
* si un problema puede resolverse con mejor gobernanza, no debe resolverse
  creando implementacion prematura del producto

## Secuencia Operativa Por Defecto

1. Orchestrator encuadra la tarea y valida fase.
2. Functional Analyst aclara scope y aceptacion cuando haga falta.
3. Technical Architect traduce limites a estructura conceptual cuando haga
   falta.
4. El especialista activo produce o corrige la pieza asignada.
5. QA Auditor revisa el resultado.
6. Context Guardian y Handoff Manager cierran trazabilidad y continuidad.
7. Orchestrator decide cierre, correccion o siguiente activacion.

## Estados Operativos

* `ACTIVE`: lidera trabajo y emite entregables
* `LISTENING`: revisa, alerta o asesora, pero no lidera
* `LOCKED`: no puede participar porque la fase o la tarea no lo habilitan
* `ARCHIVAL`: solo referencia historica

El Orchestrator puede degradar un agente de `ACTIVE` a `LISTENING` o `LOCKED`
cuando aparezcan solape, duplicacion o contaminacion de fase.

## Seniales De Bloqueo Inmediato

* 0a se trata como PMF
* bookmarks se describen como caso nucleo
* desktop se vuelve observer activo en MVP
* sync MVP se presenta como backend propia o como P2P
* Pattern Detector, Trust Scorer o State Machine aparecen antes de Fase 2
* el LLM se trata como requisito
* una propuesta convierte este repo en scaffolding del producto

## Salida Minima De Una Decision De Orquestacion

* issue
* fase afectada
* agentes implicados
* decision
* restricciones respetadas
* siguiente owner
* documentos que deben cambiar
